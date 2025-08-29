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
  # Main extractor class that coordinates the extraction of Ruby symbols
  class Extractor
    include Concerns::ResultMergeable

    def initialize
      # No instance state needed - each extraction gets its own context
    end

    # Extract symbols from a Ruby file
    def extract_from_file(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

      code = File.read(file_path)
      result = extract_from_code(code)
      result.file_path = file_path
      result
    rescue => e
      create_error_result(e, file_path)
    end

    # Extract symbols from Ruby code string
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

    # Extract symbols from a directory of Ruby files
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
