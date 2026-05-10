# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about detected patterns (e.g., ActiveSupport::Concern)
    class PatternInfo
      attr_accessor :type, :target, :location, :indicators, :method

      def initialize(type:, target:, location: nil, indicators: [], method: nil)
        @type = type
        @target = target
        @location = location
        @indicators = indicators
        @method = method
      end

      def to_h
        {
          type: type,
          target: target,
          location: location,
          indicators: indicators,
          method: method
        }.compact
      end
    end
  end
end
