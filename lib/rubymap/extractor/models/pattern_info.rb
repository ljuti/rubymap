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

      def to_h
        {
          type: type,
          target: target,
          location: location,
          indicators: indicators
        }.compact
      end
    end
  end
end
