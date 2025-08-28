# frozen_string_literal: true

module Rubymap
  # Configuration for Rubymap mapping process
  class Configuration
    attr_accessor :output_dir, :format, :verbose, :include_private, :include_protected,
                  :max_depth, :exclude_patterns, :include_patterns, :follow_symlinks,
                  :parallel, :progress, :runtime_introspection

    def initialize
      set_defaults
    end

    # Set default configuration values
    def set_defaults
      @output_dir = ".rubymap"
      @format = :llm
      @verbose = false
      @include_private = false
      @include_protected = true
      @max_depth = 10
      @exclude_patterns = default_exclude_patterns
      @include_patterns = ["**/*.rb"]
      @follow_symlinks = false
      @parallel = true
      @progress = true
      @runtime_introspection = false
    end

    # Reset to default values
    def reset!
      set_defaults
      self
    end

    # Merge with options hash
    # @param options [Hash] Options to merge
    # @return [Configuration] New configuration with merged options
    def merge(options)
      config = dup
      options.each do |key, value|
        config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
      end
      config
    end

    # Convert to hash
    # @return [Hash] Configuration as hash
    def to_h
      {
        output_dir: output_dir,
        format: format,
        verbose: verbose,
        include_private: include_private,
        include_protected: include_protected,
        max_depth: max_depth,
        exclude_patterns: exclude_patterns,
        include_patterns: include_patterns,
        follow_symlinks: follow_symlinks,
        parallel: parallel,
        progress: progress,
        runtime_introspection: runtime_introspection
      }
    end

    private

    def default_exclude_patterns
      [
        "**/node_modules/**",
        "**/vendor/**",
        "**/tmp/**",
        "**/log/**",
        "**/.git/**",
        "**/coverage/**",
        "**/spec/**",
        "**/test/**"
      ]
    end
  end
end