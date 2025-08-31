# frozen_string_literal: true

module Rubymap
  class Extractor
    # Centralized location converter following "Tell, Don't Ask" principle
    # Handles conversion of various location formats to hash representation
    class LocationConverter
      # Convert a location object to hash format
      # @param location [Object] Location object (e.g., Prism::Location)
      # @return [Hash, nil] Hash representation of location or nil
      def self.to_h(location)
        return nil unless location

        # Handle Prism::Location objects and similar
        if location.respond_to?(:start_line)
          {
            line: location.start_line,
            column: location.respond_to?(:start_column) ? location.start_column : nil,
            end_line: location.respond_to?(:end_line) ? location.end_line : nil,
            end_column: location.respond_to?(:end_column) ? location.end_column : nil
          }.compact
        elsif location.is_a?(Hash)
          # Already a hash, return as-is
          location
        else
          # Unknown format, return nil
          nil
        end
      end
    end
  end
end
