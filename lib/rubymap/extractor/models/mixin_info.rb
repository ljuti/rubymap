# frozen_string_literal: true

require_relative "../location_converter"

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
          module_name: module_name,
          target: target,
          location: LocationConverter.to_h(location)
        }.compact
      end
    end
  end
end
