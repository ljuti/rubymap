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
    end
  end
end
