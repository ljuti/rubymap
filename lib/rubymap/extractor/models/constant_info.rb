# frozen_string_literal: true

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
