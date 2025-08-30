# frozen_string_literal: true

require_relative "rubymap/version"
require_relative "rubymap/configuration"
require_relative "rubymap/extractor"
require_relative "rubymap/normalizer"
require_relative "rubymap/enricher"
require_relative "rubymap/indexer"
require_relative "rubymap/emitter"
require_relative "rubymap/documentation_emitter"
require_relative "rubymap/pipeline"

# Comprehensive Ruby codebase analysis and documentation tool.
#
# Rubymap provides a complete suite of tools for analyzing Ruby codebases,
# extracting structural information, enriching it with metrics and insights,
# and generating comprehensive documentation. It combines static analysis
# with pattern detection to create a full knowledge graph of your code.
#
# @rubymap Main module providing codebase analysis and documentation generation
#
# @example Basic usage - analyze current directory
#   result = Rubymap.map
#   puts result.classes.count
#   puts result.methods.count
#
# @example Analyze specific path with options
#   result = Rubymap.map("lib/", 
#     enable_metrics: true,
#     include_private: false
#   )
#
# @example Configure Rubymap globally
#   Rubymap.configure do |config|
#     config.enable_metrics = true
#     config.complexity_threshold = 10
#     config.output_format = :markdown
#   end
#
module Rubymap
  class Error < StandardError; end

  class NotFoundError < Error; end

  class ConfigurationError < Error; end

  class << self
    # Main entry point for mapping a Ruby codebase.
    #
    # Creates a complete analysis of the specified paths, running them through
    # the full pipeline: extraction, normalization, enrichment, and indexing.
    #
    # @rubymap Analyzes Ruby code and returns comprehensive mapping results
    #
    # @param paths [String, Array<String>] Path(s) to map (defaults to current directory)
    # @param options [Hash] Mapping options
    # @option options [Boolean] :enable_metrics (true) Enable metric calculation
    # @option options [Boolean] :include_private (false) Include private methods
    # @option options [Symbol] :output_format (:hash) Output format (:hash, :json, :yaml)
    # @return [Hash] The complete mapping result with all extracted information
    #
    # @example
    #   result = Rubymap.map("app/models")
    #   result[:classes].each { |c| puts c.name }
    def map(paths = Dir.pwd, **options)
      paths = Array(paths)

      # Validate paths exist
      paths.each do |path|
        raise NotFoundError, "Path does not exist: #{path}" unless File.exist?(path)
      end

      # Create and run the pipeline
      pipeline = Pipeline.new(configuration.merge(options))
      pipeline.run(paths)
    end

    # Configure Rubymap
    # @yield [Configuration] configuration object
    # @return [Configuration] The configuration object
    def configure
      yield configuration if block_given?
      configuration
    end

    # Reset configuration to defaults
    def reset_configuration!
      @configuration = nil
    end

    # Access the current configuration
    # @return [Configuration] Current configuration
    def configuration
      @configuration ||= Configuration.new
    end
  end
end
