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
    end
  end
end
