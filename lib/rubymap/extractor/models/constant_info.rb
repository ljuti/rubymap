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
          constant: name, # Alias expected by ProcessingPipeline
          type: type,
          location: LocationConverter.to_h(location),
          namespace: namespace
        }.compact
      end

      private

      def infer_type
        return "unknown" unless value

        case value
        when /^\d+$/ then "integer"
        when /^\d+\.\d+$/ then "float"
        when /^["']/ then "string"
        when /^:/ then "symbol"
        when /^\[/ then "array"
        when /^\{/ then "hash"
        when /^true|false$/ then "boolean"
        when /^nil$/ then "nil"
        when /^[A-Z]/ then "constant_ref"
        else "expression"
        end
      end
    end
  end
end
