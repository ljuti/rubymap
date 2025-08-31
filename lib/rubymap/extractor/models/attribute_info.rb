# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about Ruby attribute declarations (attr_reader, attr_writer, attr_accessor)
    class AttributeInfo
      attr_accessor :name, :type, :location, :namespace

      def initialize(name:, type:, location: nil, namespace: nil)
        @name = name
        @type = type
        @location = location
        @namespace = namespace
      end

      def readable?
        type == "reader" || type == "accessor"
      end

      def writable?
        type == "writer" || type == "accessor"
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the AttributeInfo object
      def to_h
        {
          name: name,
          type: type,
          location: convert_location_to_hash(location),
          namespace: namespace
        }.compact
      end

      private

      def convert_location_to_hash(location)
        return nil unless location

        # Handle Prism::Location objects
        if location.respond_to?(:start_line)
          {
            line: location.start_line,
            column: location.respond_to?(:start_column) ? location.start_column : nil,
            end_line: location.respond_to?(:end_line) ? location.end_line : nil,
            end_column: location.respond_to?(:end_column) ? location.end_column : nil
          }.compact
        else
          location
        end
      end
    end
  end
end
