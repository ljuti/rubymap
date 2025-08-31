# frozen_string_literal: true

require "thor"
require "tty-prompt"
require "tty-progressbar"
require "tty-spinner"
require "tty-table"
require "pastel"

module Rubymap
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "map [PATH]", "Map a Ruby codebase at the specified path"
    option :format, type: :string, enum: %w[json yaml llm dot graphviz], default: "llm",
      desc: "Output format (json, yaml, llm, dot, graphviz)"
    option :output, type: :string, aliases: "-o", default: "rubymap_output",
      desc: "Output directory for the generated map"
    option :exclude, type: :array, aliases: "-e",
      desc: "Patterns to exclude from mapping (glob patterns)"
    option :verbose, type: :boolean, aliases: "-v", default: false,
      desc: "Enable verbose output"
    option :no_progress, type: :boolean, default: false,
      desc: "Disable progress indicators"
    option :config, type: :string, aliases: "-c",
      desc: "Path to configuration file"
    option :runtime, type: :boolean, default: false,
      desc: "Enable runtime introspection (loads the application)"
    option :skip_initializer, type: :array,
      desc: "Skip specified initializers during runtime mapping"
    def map(path = ".")
      pastel = Pastel.new

      # Configure Rubymap
      configure_rubymap(options)

      # Display header
      puts pastel.cyan.bold("\n🗺️  Rubymap - Ruby Codebase Mapper\n")
      puts pastel.dim("Mapping: #{File.expand_path(path)}")
      puts pastel.dim("Output:  #{options[:output]}")
      puts pastel.dim("Format:  #{options[:format]}\n")

      # Run the mapping with progress indicators
      result = if options[:no_progress] || options[:verbose]
        run_mapping_verbose(path)
      else
        run_mapping_with_progress(path)
      end

      # Display results
      display_results(result, pastel)
    rescue => e
      handle_error(e, pastel)
    end

    desc "version", "Show version information"
    def version
      pastel = Pastel.new
      puts pastel.cyan.bold("Rubymap #{Rubymap.gem_version}")
      puts pastel.dim("Ruby #{RUBY_VERSION}")
    end

    desc "formats", "List available output formats"
    def formats
      pastel = Pastel.new

      formats_info = [
        ["json", "Machine-readable, ideal for tool integration"],
        ["yaml", "Human-readable, good for configuration"],
        ["llm", "Optimized for AI/LLM consumption"],
        ["dot", "GraphViz format for visualization"]
      ]

      puts pastel.cyan.bold("\n📋 Available Output Formats\n")

      table = TTY::Table.new(["Format", "Description"], formats_info)
      renderer = TTY::Table::Renderer::Unicode.new(table, padding: [0, 1])

      puts renderer.render
      puts
    end

    desc "update [PATH]", "Update existing map with changes"
    option :since, type: :string, desc: "Update files changed since timestamp"
    option :format, type: :string, enum: %w[json yaml llm dot graphviz], default: "llm"
    option :output, type: :string, aliases: "-o", default: "rubymap_output"
    option :verbose, type: :boolean, aliases: "-v", default: false
    def update(path = ".")
      pastel = Pastel.new

      # Check if output directory exists
      output_dir = options[:output]
      unless Dir.exist?(output_dir)
        puts pastel.yellow("No existing map found. Performing full mapping...")
        map(path)
        return
      end

      puts pastel.cyan.bold("\n🔄 Updating Rubymap\n")
      puts pastel.dim("Path: #{File.expand_path(path)}")

      # For now, just do a full map (incremental updates not implemented)
      map(path)
    end

    desc "view SYMBOL", "Display information about a class or module"
    option :format, type: :string, default: "text", enum: %w[text json yaml]
    def view(symbol_name)
      pastel = Pastel.new

      # Look for existing map data
      output_dir = "rubymap_output"
      unless Dir.exist?(output_dir)
        puts pastel.red("No map found. Run 'rubymap map' first.")
        exit(1)
      end

      puts pastel.cyan.bold("\n🔍 Symbol: #{symbol_name}\n")

      # For now, just show a placeholder
      puts pastel.yellow("Symbol viewing not yet fully implemented")
      puts pastel.dim("Would show information about: #{symbol_name}")
    end

    desc "clean", "Remove cache and output files"
    option :all, type: :boolean, desc: "Remove all generated files"
    def clean
      pastel = Pastel.new

      puts pastel.cyan.bold("\n🧹 Cleaning Rubymap Files\n")

      dirs_to_clean = ["rubymap_output", ".rubymap", ".rubymap_cache"]

      dirs_to_clean.each do |dir|
        if Dir.exist?(dir)
          FileUtils.rm_rf(dir)
          puts pastel.green("✓ Removed #{dir}")
        end
      end

      puts pastel.dim("\nCleanup complete.")
    end

    desc "init", "Initialize a .rubymap configuration file"
    def init
      prompt = TTY::Prompt.new
      pastel = Pastel.new

      puts pastel.cyan.bold("\n🎯 Initialize Rubymap Configuration\n")

      # Check if config already exists
      if File.exist?(".rubymap.yml")
        overwrite = prompt.yes?("Configuration file already exists. Overwrite?")
        return unless overwrite
      end

      # Gather configuration options
      config = {}

      config["format"] = prompt.select("Default output format:",
        %w[json yaml llm dot],
        default: "llm")

      config["output_dir"] = prompt.ask("Default output directory:",
        default: "rubymap_output")

      config["exclude_patterns"] = []
      if prompt.yes?("Add exclusion patterns?")
        loop do
          pattern = prompt.ask("Pattern to exclude (or press Enter to finish):")
          break if pattern.nil? || pattern.empty?
          config["exclude_patterns"] << pattern
        end
      end

      if prompt.yes?("Include default exclusions? (spec, test, vendor, node_modules)")
        config["exclude_patterns"] += %w[
          **/spec/**
          **/test/**
          **/vendor/**
          **/node_modules/**
        ]
      end

      config["verbose"] = prompt.yes?("Enable verbose output by default?")

      # Write configuration
      require "yaml"
      File.write(".rubymap.yml", config.to_yaml)

      puts pastel.green.bold("\n✅ Configuration saved to .rubymap.yml")
      puts pastel.dim("\nYou can now run 'rubymap map' to use these defaults")
    end

    desc "status", "Show current mapping status"
    def status
      pastel = Pastel.new

      puts pastel.cyan.bold("\n📊 Rubymap Status\n")

      if Dir.exist?("rubymap_output")
        files = Dir.glob("rubymap_output/**/*").select { |f| File.file?(f) }
        puts pastel.green("✓ Map exists")
        puts pastel.dim("  Files: #{files.size}")
        puts pastel.dim("  Location: rubymap_output/")

        if files.any?
          latest = files.max_by { |f| File.mtime(f) }
          puts pastel.dim("  Last updated: #{File.mtime(latest)}")
        end
      else
        puts pastel.yellow("No map found. Run 'rubymap map' to create one.")
      end

      if File.exist?(".rubymap.yml")
        puts pastel.green("✓ Configuration file exists")
      end
    end

    private

    def configure_rubymap(cli_options)
      # Load config from file if it exists
      config_file = cli_options["config"] || find_config_file
      file_config = load_config_file(config_file) if config_file

      # Merge CLI options with file config (CLI takes precedence)
      merged_config = (file_config || {}).merge(cli_options.transform_keys(&:to_s))

      Rubymap.configure do |config|
        config.format = merged_config["format"].to_sym if merged_config["format"]
        config.output_dir = merged_config["output"] || merged_config["output_dir"] || "rubymap_output"
        config.verbose = merged_config["verbose"] || false
        config.progress = !merged_config["no_progress"]

        # Handle exclusion patterns
        patterns = merged_config["exclude"] || merged_config["exclude_patterns"] || []
        config.filter["exclude_patterns"] = patterns.is_a?(Array) ? patterns : [patterns]

        # Always exclude the output directory to prevent recursion
        config.filter["exclude_patterns"] << "#{config.output_dir}/**"

        # Handle runtime options
        if merged_config["runtime"]
          config.runtime["enabled"] = true
          if merged_config["skip_initializer"]
            config.runtime["skip_initializers"] = merged_config["skip_initializer"]
          end
        end
      end
    end

    def find_config_file
      %w[.rubymap.yml .rubymap.yaml rubymap.yml rubymap.yaml].find do |name|
        File.exist?(name)
      end
    end

    def load_config_file(path)
      require "yaml"
      YAML.load_file(path)
    rescue => e
      warn "Warning: Failed to load config file #{path}: #{e.message}"
      nil
    end

    def run_mapping_verbose(path)
      Rubymap.map(path)
    end

    def run_mapping_with_progress(path)
      Pastel.new
      result = nil

      # Create a multi-spinner for pipeline steps
      spinners = TTY::Spinner::Multi.new("[:spinner] :title", format: :dots)

      steps = [
        "Extracting data from Ruby files",
        "Indexing extracted data",
        "Normalizing data",
        "Enriching with metadata",
        "Emitting output"
      ]

      step_spinners = steps.map do |step|
        spinners.register("[:spinner] #{step}", format: :dots)
      end

      # Start the pipeline with progress tracking
      thread = Thread.new do
        # Monkey-patch Pipeline#log to update spinners
        original_log = Rubymap::Pipeline.instance_method(:log)
        current_step = 0

        Rubymap::Pipeline.define_method(:log) do |message|
          if message.start_with?("Step")
            step_spinners[current_step].success if current_step < step_spinners.length
            current_step += 1
            step_spinners[current_step].auto_spin if current_step < step_spinners.length
          end
          original_log.bind_call(self, message) if Rubymap.configuration.verbose
        end

        result = Rubymap.map(path)

        # Restore original log method
        Rubymap::Pipeline.define_method(:log, original_log)
      end

      step_spinners.first.auto_spin
      thread.join

      # Mark final spinner as complete
      step_spinners.each { |s| s.success unless s.done? }

      result
    end

    def display_results(result, pastel)
      puts pastel.green.bold("\n✅ Mapping completed successfully!\n")

      # Display statistics if available
      if result.is_a?(Hash)
        if result[:metadata]
          metadata = result[:metadata]
          stats = [
            ["Classes", metadata[:total_classes] || 0],
            ["Modules", metadata[:total_modules] || 0],
            ["Methods", metadata[:total_methods] || 0],
            ["Files", metadata[:total_files] || 0]
          ]

          table = TTY::Table.new(["Type", "Count"], stats)
          renderer = TTY::Table::Renderer::Unicode.new(table, padding: [0, 1])

          puts pastel.cyan.bold("📊 Statistics:")
          puts renderer.render
        end

        puts pastel.dim("\n📁 Output location: #{result[:output_dir] || result[:path] || Rubymap.configuration.output_dir}")
      end
    end

    def handle_error(error, pastel)
      puts pastel.red.bold("\n❌ Error: #{error.message}\n")

      if options[:verbose]
        puts pastel.dim("Backtrace:")
        error.backtrace.first(10).each do |line|
          puts pastel.dim("  #{line}")
        end
      else
        puts pastel.dim("Run with --verbose for more details")
      end

      exit(1)
    end
  end
end
