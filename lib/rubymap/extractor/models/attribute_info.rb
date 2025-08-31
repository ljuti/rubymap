# frozen_string_literal: true

require_relative "../location_converter"

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
          location: LocationConverter.to_h(location),
          namespace: namespace
        }.compact
      end
    end
  end
end
