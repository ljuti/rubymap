# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about file dependencies (require, require_relative, autoload)
    class DependencyInfo
      attr_accessor :type, :path, :location, :constant

      def initialize(type:, path:, location: nil, constant: nil)
        @type = type
        @path = path
        @location = location
        @constant = constant # For autoload
      end

      def external?
        type == "require" && !path.start_with?("./", "../")
      end

      def internal?
        !external?
      end

      # Alias for backward compatibility with tests
      def name
        # For simple requires like 'require "json"', the name is the path
        path if external?
      end

      def external
        external?
      end
    end
  end
end
