# frozen_string_literal: true

require_relative "../location_converter"

module Rubymap
  class Extractor
    # Information about a Ruby module definition
    class ModuleInfo
      attr_accessor :name, :location, :doc, :namespace, :is_concern, :type, :rubymap

      def initialize(name:, location: nil, doc: nil, namespace: nil, is_concern: false, type: "module", rubymap: nil)
        @name = name
        @location = location
        @doc = doc
        @namespace = namespace
        @is_concern = is_concern
        @type = type
        @rubymap = rubymap
      end

      def full_name
        namespace ? "#{namespace}::#{name}" : name
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the ModuleInfo object
      def to_h
        {
          name: name,
          type: type,
          location: LocationConverter.to_h(location),
          doc: doc,
          namespace: namespace,
          rubymap: rubymap
        }.compact
      end
    end
  end
end
