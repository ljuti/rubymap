# frozen_string_literal: true

require_relative "../location_converter"

module Rubymap
  class Extractor
    # Information about a Ruby constant definition
    class ConstantInfo
      attr_accessor :name, :value, :location, :namespace, :type

      def initialize(name:, value: nil, location: nil, namespace: nil)
        @name = name
        @value = value
        @location = location
        @namespace = namespace
        @type = infer_type
      end

      def full_name
        namespace ? "#{namespace}::#{name}" : name
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the ConstantInfo object
      def to_h
        {
          name: name,
          value: value,
          type: type,
          location: LocationConverter.to_h(location),
          namespace: namespace
        }.compact
      end

      private

      def infer_type
        return "unknown" unless value

        case value
        when /\A\d+\z/ then "integer"
        when /\A\d+\.\d+\z/ then "float"
        when /\A["']/ then "string"
        when /\A:/ then "symbol"
        when /\A\[/ then "array"
        when /\A\{/ then "hash"
        when /\A(?:true|false)\z/ then "boolean"
        when /\Anil\z/ then "nil"
        when /\A[A-Z]/ then "constant_ref"
        else "expression"
        end
      end
    end
  end
end
