# frozen_string_literal: true

module Rubymap
  class Extractor
    # Result object containing all extracted symbols from Ruby code
    class Result
      attr_accessor :classes, :modules, :methods, :constants, :attributes,
        :mixins, :dependencies, :class_variables, :aliases,
        :errors, :file_path, :patterns

      def initialize
        @classes = []
        @modules = []
        @methods = []
        @constants = []
        @attributes = []
        @mixins = []
        @dependencies = []
        @class_variables = []
        @aliases = []
        @errors = []
        @patterns = []
      end

      def add_error(error, context = nil)
        @errors << {
          message: error.message,
          type: error.class.name,
          context: context
        }
      end
    end
  end
end
