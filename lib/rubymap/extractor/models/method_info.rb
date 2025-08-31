# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about a Ruby method definition
    class MethodInfo
      attr_accessor :name, :visibility, :receiver_type, :params, :location,
        :doc, :namespace, :owner, :rubymap

      def initialize(name:, visibility: "public", receiver_type: "instance",
        params: [], location: nil, doc: nil, namespace: nil, owner: nil, rubymap: nil)
        @name = name
        @visibility = visibility
        @receiver_type = receiver_type
        @params = params
        @location = location
        @doc = doc
        @namespace = namespace
        @owner = owner
        @rubymap = rubymap
      end

      def full_name
        prefix = namespace || owner
        return name unless prefix

        separator = (receiver_type == "instance") ? "#" : "."
        "#{prefix}#{separator}#{name}"
      end

      def scope
        (receiver_type == "class") ? "class" : "instance"
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the MethodInfo object
      def to_h
        {
          name: name,
          visibility: visibility,
          receiver_type: receiver_type,
          params: params,
          parameters: params, # Alias for backward compatibility
          location: convert_location_to_hash(location),
          doc: doc,
          namespace: namespace,
          owner: owner,
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
