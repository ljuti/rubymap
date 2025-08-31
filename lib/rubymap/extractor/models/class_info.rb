# frozen_string_literal: true

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
          location: convert_location_to_hash(location),
          doc: doc,
          namespace: namespace,
          rubymap: rubymap
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
