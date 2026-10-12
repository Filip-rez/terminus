# auto_register: false
# frozen_string_literal: true

require "initable"

module Terminus
  module Serializers
    # A model serializer for specific keys.
    class Firmware
      include Deps[model_repository: "repositories.firmware_model"]
      include Initable[transformer: proc { Terminus::Serializers::Transformers::Time }]

      KEYS = %i[id version created_at updated_at].freeze

      def initialize(record, keys: KEYS, **)
        @record = record
        @keys = keys
        super(**)
      end

      def to_h
        attributes = record.to_h.slice(*keys).merge!(file_name: "#{record.version}.bin")

        attributes.transform_values!(&transformer)
        add_metadata attributes, record
        add_model_ids attributes, record

        attributes
      end

      private

      attr_reader :record, :keys

      # :reek:UtilityFunction
      def add_metadata attributes, record
        return unless record.attachment_id

        attributes.merge!(
          **record.attachment_attributes[:metadata].slice(:mime_type, :size),
          uri: record.attachment_uri
        )
      end

      def add_model_ids attributes, record
        attributes[:model_ids] = model_repository.where(firmware_id: record.id).map(&:model_id)
      end
    end
  end
end
