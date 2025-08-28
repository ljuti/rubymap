# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about class variables (@@variable)
    class ClassVariableInfo
      attr_accessor :name, :location, :namespace, :initial_value

      def initialize(name:, location: nil, namespace: nil, initial_value: nil)
        @name = name
        @location = location
        @namespace = namespace
        @initial_value = initial_value
      end
    end
  end
end
