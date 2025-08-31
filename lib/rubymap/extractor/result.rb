# frozen_string_literal: true

module Rubymap
  class Extractor
    # Container for symbols and metadata extracted from Ruby source code.
    #
    # The Result object aggregates all structural information discovered during
    # extraction, including classes, modules, methods, and their relationships.
    # It also tracks any errors encountered during parsing.
    #
    # @example Accessing extracted symbols
    #   result = extractor.extract_from_file("user.rb")
    #
    #   # Access different symbol types
    #   result.classes     # => Array of ClassInfo objects
    #   result.modules     # => Array of ModuleInfo objects
    #   result.methods     # => Array of MethodInfo objects
    #   result.constants   # => Array of ConstantInfo objects
    #
    #   # Check for errors
    #   if result.errors.any?
    #     puts "Parse errors: #{result.errors.map { |e| e[:message] }}"
    #   end
    #
    # @example Finding specific symbols
    #   user_class = result.classes.find { |c| c.name == "User" }
    #   user_methods = result.methods.select { |m| m.owner == "User" }
    #
    class Result
      # @return [Array<ClassInfo>] Extracted class definitions
      attr_accessor :classes

      # @return [Array<ModuleInfo>] Extracted module definitions
      attr_accessor :modules

      # @return [Array<MethodInfo>] Extracted method definitions
      attr_accessor :methods

      # @return [Array<ConstantInfo>] Extracted constant definitions
      attr_accessor :constants

      # @return [Array<AttributeInfo>] Extracted attribute accessors (attr_reader, attr_writer, attr_accessor)
      attr_accessor :attributes

      # @return [Array<MixinInfo>] Extracted module inclusions, extensions, and prepends
      attr_accessor :mixins

      # @return [Array<DependencyInfo>] Extracted require and load statements
      attr_accessor :dependencies

      # @return [Array<ClassVariableInfo>] Extracted class variable definitions
      attr_accessor :class_variables

      # @return [Array<AliasInfo>] Extracted method aliases
      attr_accessor :aliases

      # @return [Array<Hash>] Parse errors and extraction failures
      attr_accessor :errors

      # @return [String, nil] Source file path if extracted from a file
      attr_accessor :file_path

      # @return [Array<PatternInfo>] Detected code patterns (concerns, callbacks, etc.)
      attr_accessor :patterns

      # Creates a new Result with empty collections for all symbol types.
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

      # Records an error encountered during extraction.
      #
      # @param error [Exception] The error that occurred
      # @param context [String, nil] Optional context about where the error occurred
      #
      # @example
      #   result.add_error(SyntaxError.new("unexpected token"), "line 42")
      def add_error(error, context = nil)
        @errors << {
          message: error.message,
          type: error.class.name,
          context: context
        }
      end

      # Convert result to hash representation
      # @return [Hash] Hash representation with arrays converted to hashes
      def to_h
        {
          classes: convert_array_to_hashes(@classes),
          modules: convert_array_to_hashes(@modules),
          methods: convert_array_to_hashes(@methods),
          constants: convert_array_to_hashes(@constants),
          attributes: convert_array_to_hashes(@attributes),
          mixins: convert_array_to_hashes(@mixins),
          dependencies: convert_array_to_hashes(@dependencies),
          class_variables: convert_array_to_hashes(@class_variables),
          aliases: convert_array_to_hashes(@aliases),
          errors: @errors,
          patterns: convert_array_to_hashes(@patterns),
          file_path: @file_path
        }.compact
      end

      private

      def convert_array_to_hashes(array)
        return array if array.empty?
        
        array.map do |item|
          item.respond_to?(:to_h) ? item.to_h : item
        end
      end
    end
  end
end
