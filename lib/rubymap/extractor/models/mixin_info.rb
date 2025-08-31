# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about module mixins (include, extend, prepend)
    class MixinInfo
      attr_accessor :type, :module_name, :target, :location

      def initialize(type:, module_name:, target:, location: nil)
        @type = type
        @module_name = module_name
        @target = target
        @location = location
      end

      # Convert object to hash representation
      # @return [Hash] Hash representation of the MixinInfo object
      def to_h
        {
          type: type,
          module: module_name, # ProcessingPipeline expects :module, not :module_name
          module_name: module_name, # Keep original for compatibility
          target: target,
          location: convert_location_to_hash(location)
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
