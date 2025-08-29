# frozen_string_literal: true

require "anyway_config"
require "pathname"
require "yaml"

module Rubymap
  # Configuration for Rubymap mapping process
  class Configuration < Anyway::Config
    # Define configuration attributes with defaults
    attr_config(
      # Output settings
      output_dir: ".rubymap",
      format: :llm,

      # General settings
      verbose: false,
      parallel: true,
      progress: true,
      max_depth: 10,
      follow_symlinks: false,

      # Static analysis settings
      static: {
        paths: ["."],
        exclude: ["vendor/", "node_modules/"],
        follow_requires: false,
        parse_yard: false,
        parse_rbs: false,
        max_file_size: 1_000_000
      },

      # Output settings (nested)
      output: {
        directory: ".rubymap",
        format: "llm",
        split_files: false,
        include_source: false,
        include_todos: false,
        redact_sensitive: true
      },

      # Runtime analysis settings
      runtime: {
        enabled: false,
        timeout: 30,
        safe_mode: true,
        environment: "development",
        skip_initializers: [],
        load_paths: []
      },

      # Filter settings
      filter: {
        include_private: false,
        include_protected: true,
        exclude_patterns: [
          "**/node_modules/**",
          "**/vendor/**",
          "**/tmp/**",
          "**/log/**",
          "**/.git/**",
          "**/coverage/**",
          "**/spec/**",
          "**/test/**"
        ],
        include_patterns: ["**/*.rb"],
        exclude_methods: [],
        include_only: nil
      },

      # Cache settings
      cache: {
        enabled: true,
        directory: ".rubymap_cache",
        ttl: 86400  # 24 hours
      }
    )

    # Backward compatibility methods
    def include_private
      filter["include_private"]
    end

    def include_private=(value)
      filter["include_private"] = value
    end

    def include_protected
      filter["include_protected"]
    end

    def include_protected=(value)
      filter["include_protected"] = value
    end

    def exclude_patterns
      filter["exclude_patterns"]
    end

    def exclude_patterns=(value)
      filter["exclude_patterns"] = value
    end

    def include_patterns
      filter["include_patterns"]
    end

    def include_patterns=(value)
      filter["include_patterns"] = value
    end

    def runtime_introspection
      runtime["enabled"]
    end

    def runtime_introspection=(value)
      runtime["enabled"] = value
    end

    # Configure the config name (for loading from .rubymap.yml)
    config_name :rubymap

    # Allow loading from environment variables with RUBYMAP_ prefix
    env_prefix :rubymap

    # Validation
    required :output_dir
    required :format

    # Coerce types (using anyway_config's supported types)
    coerce_types(
      verbose: :boolean,
      parallel: :boolean,
      progress: :boolean,
      follow_symlinks: :boolean,
      static: {
        follow_requires: :boolean,
        parse_yard: :boolean,
        parse_rbs: :boolean,
        max_file_size: :integer
      },
      output: {
        split_files: :boolean,
        include_source: :boolean,
        include_todos: :boolean,
        redact_sensitive: :boolean
      },
      runtime: {
        enabled: :boolean,
        timeout: :integer,
        safe_mode: :boolean
      },
      filter: {
        include_private: :boolean,
        include_protected: :boolean
      },
      cache: {
        enabled: :boolean,
        ttl: :integer
      }
    )

    # Custom type casting for format (symbol) and other attributes
    on_load do
      self.format = format.to_sym if format.is_a?(String)

      # Apply type coercion for direct assignments
      self.verbose = to_bool(verbose) if verbose.is_a?(String)
      self.parallel = to_bool(parallel) if parallel.is_a?(String)
      self.progress = to_bool(progress) if progress.is_a?(String)
      self.follow_symlinks = to_bool(follow_symlinks) if follow_symlinks.is_a?(String)
      self.max_depth = max_depth.to_i if max_depth.is_a?(String)
    end

    # Override setters to handle type coercion
    def verbose=(value)
      super(value.is_a?(String) ? to_bool(value) : value)
    end

    def parallel=(value)
      super(value.is_a?(String) ? to_bool(value) : value)
    end

    def progress=(value)
      super(value.is_a?(String) ? to_bool(value) : value)
    end

    def follow_symlinks=(value)
      super(value.is_a?(String) ? to_bool(value) : value)
    end

    def max_depth=(value)
      super(value.is_a?(String) ? value.to_i : value)
    end

    def format=(value)
      super(value.is_a?(String) ? value.to_sym : value)
    end

    # Load a predefined profile
    def self.for_profile(profile_name)
      new.tap { |config| config.apply_profile(profile_name) }
    end

    # Convenience methods for loading profiles
    def self.development
      for_profile(:development)
    end

    def self.production
      for_profile(:production)
    end

    def self.ci
      for_profile(:ci)
    end

    # Apply a predefined profile
    def apply_profile(profile_name)
      case profile_name.to_sym
      when :development
        self.verbose = true
        self.output_dir = "tmp/rubymap"
        output["directory"] = "tmp/rubymap"
        runtime["safe_mode"] = false
        cache["enabled"] = false
        filter["include_private"] = true
      when :production
        self.verbose = false
        self.output_dir = "docs/rubymap"
        output["directory"] = "docs/rubymap"
        runtime["safe_mode"] = true
        cache["enabled"] = true
        filter["include_private"] = false
        output["redact_sensitive"] = true
      when :ci
        self.verbose = true
        self.output_dir = "artifacts/rubymap"
        output["directory"] = "artifacts/rubymap"
        runtime["enabled"] = false
        self.parallel = false
        self.progress = false
      else
        raise ConfigurationError, "Unknown profile: #{profile_name}"
      end
      self
    end

    # Custom validation
    def validate!
      errors = []

      # Validate format
      valid_formats = [:json, :yaml, :llm, :graphviz, :dot]
      unless valid_formats.include?(format.to_sym)
        errors << "Invalid format: #{format}. Must be one of: #{valid_formats.join(", ")}"
      end

      # Validate output directory is writable (if it exists)
      if output_dir && File.exist?(File.dirname(output_dir))
        unless File.writable?(File.dirname(output_dir))
          errors << "Output directory is not writable: #{output_dir}"
        end
      end

      # Validate timeout
      if runtime["timeout"] && runtime["timeout"] <= 0
        errors << "Timeout must be a positive integer: #{runtime["timeout"]}"
      end

      # Validate environment
      valid_envs = %w[development test staging production]
      unless valid_envs.include?(runtime["environment"])
        errors << "Invalid environment: #{runtime["environment"]}. Must be one of: #{valid_envs.join(", ")}"
      end

      # Validate paths exist
      if static["paths"]
        static["paths"].each do |path|
          resolved_path = resolve_path(path)
          unless File.exist?(resolved_path)
            errors << "Path does not exist: #{path}"
          end
        end
      end

      raise ConfigurationError, errors.join("\n") if errors.any?
      true
    end

    # Shorter alias for validation
    def validate
      validate!
    rescue ConfigurationError
      false
    end

    # Validate and provide detailed explanation
    def validate_and_explain
      validate!
      "Configuration is valid"
    rescue ConfigurationError => e
      "Configuration validation failed:\n#{e.message}"
    end

    # Provide human-readable description
    def describe
      <<~DESC
        Rubymap Configuration:
        
        Static Analysis:
          Paths: #{static["paths"].join(", ")}
          Exclude: #{static["exclude"].join(", ")}
          Parse YARD: #{static["parse_yard"]}
          Parse RBS: #{static["parse_rbs"]}
        
        Output:
          Directory: #{output["directory"]}
          Format: #{output["format"]}
          Split Files: #{output["split_files"]}
          Include Source: #{output["include_source"]}
        
        Runtime Analysis:
          Enabled: #{runtime["enabled"]}
          Timeout: #{runtime["timeout"]}s
          Environment: #{runtime["environment"]}
        
        Filter:
          Include Private: #{filter["include_private"]}
          Include Protected: #{filter["include_protected"]}
          Exclude Patterns: #{filter["exclude_patterns"].join(", ")}
      DESC
    end

    # Deep merge configurations
    def merge(other_config)
      # Create a new instance with current config
      result = self.class.new

      # Copy current config
      %i[output_dir format verbose parallel progress max_depth follow_symlinks].each do |key|
        result.send("#{key}=", send(key))
      end

      # Copy nested configs
      %w[static output runtime filter cache].each do |section|
        result.send(section).replace(send(section).dup)
      end

      # Merge the other config
      if other_config.is_a?(Hash)
        result.deep_merge!(other_config)
      elsif other_config.is_a?(Configuration)
        # Merge top-level attributes
        %i[output_dir format verbose parallel progress max_depth follow_symlinks].each do |key|
          result.send("#{key}=", other_config.send(key))
        end

        # Merge nested configs
        %w[static output runtime filter cache].each do |section|
          result.send(section).merge!(other_config.send(section))
        end
      end

      result
    end

    # Deep merge in place
    def deep_merge!(hash)
      hash.each do |key, value|
        key_str = key.to_s

        # Handle top-level attributes
        if respond_to?("#{key_str}=") && !%w[static output runtime filter cache].include?(key_str)
          send("#{key_str}=", value)
        # Handle nested configuration sections
        elsif %w[static output runtime filter cache].include?(key_str)
          if value.is_a?(Hash)
            current = send(key_str)
            value.each do |k, v|
              # Apply type coercion for known nested integer fields
              current[k.to_s] = if key_str == "runtime" && k.to_s == "timeout" && v.is_a?(String)
                v.to_i
              elsif key_str == "cache" && k.to_s == "ttl" && v.is_a?(String)
                v.to_i
              elsif key_str == "static" && k.to_s == "max_file_size" && v.is_a?(String)
                v.to_i
              # Apply type coercion for known nested boolean fields
              elsif %w[enabled safe_mode follow_requires parse_yard parse_rbs split_files include_source include_todos redact_sensitive include_private include_protected].include?(k.to_s) && v.is_a?(String)
                to_bool(v)
              else
                v
              end
            end
          end
        end
      end

      # Ensure format is symbol
      self.format = format.to_sym if format.is_a?(String)

      self
    end

    # Show differences between configurations
    def diff(other)
      differences = {}

      # Compare top-level attributes
      %i[output_dir format verbose parallel progress max_depth follow_symlinks].each do |key|
        if send(key) != other.send(key)
          differences[key] = {from: send(key), to: other.send(key)}
        end
      end

      # Compare nested configs
      %w[static output runtime filter cache].each do |section|
        section_sym = section.to_sym
        mine = send(section)
        theirs = other.send(section)

        if mine != theirs
          differences[section_sym] = {from: mine, to: theirs}
        end
      end

      differences
    end

    # Convert to YAML (safe for loading)
    def to_yaml
      stringify_keys(to_h).to_yaml
    end

    # Override to_h to match expected structure
    def to_hash
      {
        static: static,
        output: output,
        runtime: runtime,
        filter: filter,
        cache: cache
      }
    end

    alias_method :to_h, :to_hash

    # Resolve environment variables
    def resolve_environment_variables
      # anyway_config handles this automatically, but we can add custom logic if needed
      if static["paths"]
        static["paths"] = static["paths"].map { |path| expand_env_vars(path) }
      end
      if output["directory"]
        output["directory"] = expand_env_vars(output["directory"])
      end
      if cache["directory"]
        cache["directory"] = expand_env_vars(cache["directory"])
      end
    end

    # Load from file with better error handling
    def self.load_from_file(path)
      raise ConfigurationError, "Configuration file not found: #{path}" unless File.exist?(path)

      yaml_content = File.read(path)
      load_from_string(yaml_content, path)
    rescue Errno::ENOENT
      raise ConfigurationError, "Configuration file not found: #{path}"
    rescue => e
      raise ConfigurationError, "Failed to load configuration: #{e.message}"
    end

    # Load from YAML string
    def self.load_from_string(yaml_content, source_file = nil)
      data = YAML.safe_load(yaml_content, permitted_classes: [Symbol])
      from_hash(data)
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "Invalid YAML configuration: #{e.message}"
    end

    # Create from hash
    def self.from_hash(hash)
      new.tap do |config|
        if hash
          # Apply the hash
          config.deep_merge!(hash)

          # Manually trigger type coercion for string values
          config.verbose = config.verbose if config.verbose.is_a?(String)
          config.parallel = config.parallel if config.parallel.is_a?(String)
          config.progress = config.progress if config.progress.is_a?(String)
          config.max_depth = config.max_depth if config.max_depth.is_a?(String)
          config.format = config.format if config.format.is_a?(String)
        end
      end
    end

    private

    def to_bool(value)
      return value unless value.is_a?(String)
      value.downcase == "true"
    end

    def resolve_path(path)
      return path if Pathname.new(path).absolute?
      File.expand_path(path)
    end

    def expand_env_vars(str)
      return str unless str.is_a?(String)

      str.gsub(/\$\{([^}]+)\}|\$([A-Z_][A-Z0-9_]*)/) do
        var_name = $1 || $2
        ENV[var_name] || "${#{var_name}}"
      end
    end

    def stringify_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      when Symbol
        obj.to_s
      else
        obj
      end
    end
  end
end
