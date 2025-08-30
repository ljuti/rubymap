# frozen_string_literal: true

require "prism"

# Load all extractor components
require_relative "extractor/result"
require_relative "extractor/extraction_context"
require_relative "extractor/node_visitor"
require_relative "extractor/concerns/result_mergeable"

# Load all model classes
require_relative "extractor/models/class_info"
require_relative "extractor/models/module_info"
require_relative "extractor/models/method_info"
require_relative "extractor/models/constant_info"
require_relative "extractor/models/attribute_info"
require_relative "extractor/models/mixin_info"
require_relative "extractor/models/dependency_info"
require_relative "extractor/models/class_variable_info"
require_relative "extractor/models/alias_info"
require_relative "extractor/models/pattern_info"

module Rubymap
  # Extracts structural information from Ruby source code using static analysis.
  #
  # The Extractor parses Ruby files using the Prism parser and builds a comprehensive
  # representation of the code structure including classes, modules, methods, constants,
  # and their relationships. It performs purely static analysis without executing any code.
  #
  # @rubymap Parses Ruby source files to extract classes, methods, and relationships
  #
  # @example Extract symbols from a single file
  #   extractor = Rubymap::Extractor.new
  #   result = extractor.extract_from_file("app/models/user.rb")
  #   result.classes  # => [ClassInfo(name: "User", namespace: "Models", ...)]
  #   result.methods  # => [MethodInfo(name: "find", owner: "User", ...)]
  #
  # @example Extract from Ruby code string
  #   code = <<~RUBY
  #     class User < ApplicationRecord
  #       def full_name
  #         "#{first_name} #{last_name}"
  #       end
  #     end
  #   RUBY
  #   result = extractor.extract_from_code(code)
  #   result.classes.first.superclass  # => "ApplicationRecord"
  #
  # @example Extract from an entire directory
  #   result = extractor.extract_from_directory("lib/")
  #   result.modules.count  # => 42
  #   result.errors.any?    # => false (if all files parsed successfully)
  #
  class Extractor
    include Concerns::ResultMergeable

    # Creates a new Extractor instance.
    #
    # The extractor is stateless - each extraction operation creates its own
    # internal context for tracking namespaces and visibility.
    #
    # @rubymap Initializes a new extractor instance for static code analysis
    def initialize
      # No instance state needed - each extraction gets its own context
    end

    # Extracts symbols from a Ruby file on disk.
    #
    # @rubymap Extracts all symbols from a single Ruby file
    # @param file_path [String] Path to the Ruby file to analyze
    # @return [Result] Extraction result containing all discovered symbols
    # @raise [ArgumentError] if the file does not exist
    #
    # @example
    #   result = extractor.extract_from_file("lib/user.rb")
    #   result.file_path  # => "lib/user.rb"
    #   result.classes    # => Array of ClassInfo objects
    #   result.methods    # => Array of MethodInfo objects
    def extract_from_file(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

      code = File.read(file_path)
      result = extract_from_code(code)
      result.file_path = file_path
      result
    rescue => e
      create_error_result(e, file_path)
    end

    # Extracts symbols from a Ruby code string.
    #
    # Parses the provided Ruby code and extracts all structural information
    # without executing the code. Handles parse errors gracefully by including
    # them in the result.
    #
    # @param code [String] Ruby source code to analyze
    # @return [Result] Extraction result with symbols and any parse errors
    #
    # @example Basic usage
    #   code = "class User; def name; @name; end; end"
    #   result = extractor.extract_from_code(code)
    #   result.classes.first.name  # => "User"
    #
    # @example Handling parse errors
    #   result = extractor.extract_from_code("class User; def")
    #   result.errors.any?  # => true
    #   result.errors.first.message  # => "unexpected end-of-input"
    def extract_from_code(code)
      result = Result.new
      parse_result = Prism.parse(code)

      if parse_result.success?
        context = ExtractionContext.new
        context.comments = parse_result.comments
        visitor = NodeVisitor.new(context, result)
        visitor.visit(parse_result.value)
      else
        parse_result.errors.each do |error|
          result.add_error(error, "Parse error")
        end
      end

      result
    end

    # Extracts symbols from all Ruby files in a directory.
    #
    # Recursively processes all files matching the given pattern and merges
    # the results into a single Result object. Continues processing even if
    # individual files have errors.
    #
    # @param directory_path [String] Path to the directory to scan
    # @param pattern [String] Glob pattern for finding Ruby files (default: "**/*.rb")
    # @return [Result] Combined extraction results from all processed files
    # @raise [ArgumentError] if the directory does not exist
    #
    # @example Process all Ruby files
    #   result = extractor.extract_from_directory("app/")
    #   result.classes.count  # => 25
    #
    # @example Process only specific files
    #   result = extractor.extract_from_directory("lib/", "**/models/*.rb")
    #   result.modules.select { |m| m.namespace.include?("Models") }
    def extract_from_directory(directory_path, pattern = "**/*.rb")
      raise ArgumentError, "Directory not found: #{directory_path}" unless Dir.exist?(directory_path)

      combined_result = Result.new

      Dir.glob(File.join(directory_path, pattern)).each do |file_path|
        next unless File.file?(file_path)

        file_result = extract_from_file(file_path)
        merge_results(combined_result, file_result)
      end

      combined_result
    end

    private

    def create_error_result(error, file_path = nil)
      result = Result.new
      result.file_path = file_path
      result.add_error(error)
      result
    end

    def merge_results(target, source)
      merge_results!(target, source)
    end
  end
end
