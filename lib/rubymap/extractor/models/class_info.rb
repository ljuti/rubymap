# frozen_string_literal: true

require_relative "../location_converter"

module Rubymap
  class Extractor
    # Information about a Ruby class definition
    class ClassInfo
      attr_accessor :name, :type, :superclass, :location, :doc, :namespace, :rubymap

      def initialize(name:, type: "class", superclass: nil, location: nil, doc: nil, namespace: nil, rubymap: nil)
        @name = name
        @type = type
        @superclass = superclass
        @location = location
        @doc = doc
        @namespace = namespace
        @rubymap = rubymap
      end

      def full_name
        namespace ? "#{namespace}::#{name}" : name
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the ClassInfo object
      def to_h
        {
          name: name,
          type: type,
          superclass: superclass,
          location: LocationConverter.to_h(location),
          doc: doc,
          namespace: namespace,
          rubymap: rubymap
        }.compact
      end
    end
  end
end
