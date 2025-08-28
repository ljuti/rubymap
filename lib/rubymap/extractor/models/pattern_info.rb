# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about detected patterns (e.g., ActiveSupport::Concern)
    class PatternInfo
      attr_accessor :type, :target, :location, :indicators

      def initialize(type:, target:, location: nil, indicators: [])
        @type = type
        @target = target
        @location = location
        @indicators = indicators
      end
    end
  end
end
