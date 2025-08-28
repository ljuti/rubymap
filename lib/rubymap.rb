# frozen_string_literal: true

require_relative "rubymap/version"
require_relative "rubymap/configuration"
require_relative "rubymap/extractor"
require_relative "rubymap/normalizer"
require_relative "rubymap/enricher"
require_relative "rubymap/indexer"
require_relative "rubymap/emitter"
require_relative "rubymap/pipeline"

module Rubymap
  class Error < StandardError; end
  class NotFoundError < Error; end
  class ConfigurationError < Error; end
  
  class << self
    # Main entry point for mapping a Ruby codebase
    # @param paths [String, Array<String>] Path(s) to map
    # @param options [Hash] Mapping options
    # @return [Hash] The mapping result
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
