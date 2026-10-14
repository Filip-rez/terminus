# frozen_string_literal: true

require "core"
require "dry/monads"
require "initable"
require "yaml"

module Terminus
  module Aspects
    module Extensions
      module Importers
        module Local
          # Creates extension from zip file export.
          class Creator
            include Deps[
              "aspects.unzipper",
              "aspects.errors.detailer",
              extension_creator: "aspects.extensions.importers.local.creators.extension",
              exchange_creator: "aspects.extensions.importers.local.creators.exchange"
            ]
            include Initable[
              key_map: {
                "settings.yml" => :configuration,
                "configuration.yml" => :configuration,
                "full.liquid" => :template,
                "template.html.liquid" => :template
              }
            ]
            include Dry::Monads[:result]

            def initialize(schema: Schemas::Import, **)
              @schema = schema
              super(**)
            end

            def call io, attributes: {}
              unzipper.call(io)
                    .bind { |entries| transform entries }
                    .fmap { attributes.replace it }
                    .bind { schema.call(it).to_monad }
                    .alt_map { detailer.call it, "Import " }
                    .bind { extension_creator.call attributes }
                    .bind { create_exchanges it, attributes }
            end

            private

            attr_reader :schema

            def transform entries
              normalized_entries = {}

              entries.each do |filename, content|
                clean_name = File.basename(filename.to_s)
                mapped_key = key_map[clean_name] || clean_name.to_sym
                normalized_entries[mapped_key] = content
              end

              config_content = normalized_entries[:configuration]
              return Failure(["Brak pliku konfiguracyjnego (settings.yml / configuration.yml) w archiwum ZIP!"]) unless config_content

              parsed_config = YAML.safe_load(config_content)
              return Failure(["Niepoprawny format pliku YAML w konfiguracji."]) unless parsed_config.is_a?(Hash)

              Success({ **normalized_entries, **parsed_config })
            end

            def create_exchanges extension, attributes
              attributes.fetch("exchanges", Core::EMPTY_ARRAY)
                        .reduce(Success(extension)) { |result, item| create_exchange result, item }
            end

            def create_exchange result, attributes
              result.bind do |extension|
                exchange_creator.call(attributes.merge!(extension_id: extension.id))
                              .fmap { extension }
              end
            end
          end
        end
      end
    end
  end
end
