# frozen_string_literal: true

require_relative "emitter/base_emitter"
require_relative "emitter/emitters/json_emitter"
require_relative "emitter/emitters/yaml_emitter"
require_relative "emitter/emitters/llm_emitter"
require_relative "emitter/emitters/graphviz_emitter"
require_relative "emitter/emitter_manager"
require_relative "emitter/formatters/deterministic_formatter"
require_relative "emitter/processors/redactor"
require_relative "emitter/processors/cross_linker"

module Rubymap
  # Generates various output formats from indexed codebase data.
  #
  # The Emitter module provides a unified interface for generating documentation,
  # visualizations, and machine-readable formats from analyzed code. It supports
  # multiple output formats optimized for different use cases.
  #
  # @example Generate JSON output
  #   indexed_data = indexer.build(enriched_data)
  #
  #   # Generate JSON string
  #   json = Rubymap::Emitter.emit(indexed_data, format: :json)
  #
  #   # Write to directory
  #   Rubymap::Emitter.emit(indexed_data, format: :json, output_dir: "docs/")
  #
  # @example Generate multiple formats
  #   Rubymap::Emitter.emit_all(indexed_data, "output/",
  #     formats: [:json, :yaml, :llm, :graphviz]
  #   )
  #
  # @example Custom configuration
  #   Rubymap::Emitter.emit(indexed_data,
  #     format: :llm,
  #     output_dir: "docs/",
  #     chunk_size: 2000,
  #     include_source: false,
  #     redact: true
  #   )
  #
  module Emitter
    class << self
      # Emits indexed data in the specified format.
      #
      # @param indexed_data [IndexedResult, Hash] Indexed codebase data
      # @param format [Symbol] Output format (:json, :yaml, :llm, :graphviz)
      # @param output_dir [String, nil] Directory to write files, or nil for string output
      # @param options [Hash] Format-specific options
      #
      # @return [String, Hash] Generated output (string if no output_dir, file paths if output_dir)
      # @raise [ArgumentError] if format is unknown
      #
      # @example JSON output
      #   json_string = Emitter.emit(data, format: :json)
      #
      # @example LLM-optimized markdown
      #   Emitter.emit(data, format: :llm, output_dir: "docs/", chunk_size: 3000)
      def emit(indexed_data, format: :json, output_dir: nil, **options)
        emitter = create_emitter(format, **options)

        if output_dir
          emitter.emit_to_directory(indexed_data, output_dir)
        else
          emitter.emit(indexed_data)
        end
      end

      # Emits indexed data in multiple formats simultaneously.
      #
      # Generates all requested formats in a single operation, ensuring
      # consistency across outputs and creating a unified manifest.
      #
      # @param indexed_data [IndexedResult, Hash] Indexed codebase data
      # @param output_dir [String] Directory for all output files
      # @param formats [Array<Symbol>] List of formats to generate
      # @param options [Hash] Options applied to all formats
      #
      # @return [Hash] Paths to generated files by format
      #
      # @example
      #   results = Emitter.emit_all(data, "docs/",
      #     formats: [:json, :llm],
      #     redact: true
      #   )
      #   results[:json]  # => ["docs/rubymap.json"]
      #   results[:llm]   # => ["docs/chunks/overview.md", ...]
      def emit_all(indexed_data, output_dir, formats: [:json, :yaml, :llm, :graphviz], **options)
        manager = EmitterManager.new(**options)
        manager.emit_all(indexed_data, output_dir, formats: formats)
      end

      private

      def create_emitter(format, **options)
        case format
        when :json
          Emitters::JSON.new(**options)
        when :yaml
          Emitters::YAML.new(**options)
        when :llm
          Emitters::LLM.new(**options)
        when :graphviz, :dot
          Emitters::GraphViz.new(**options)
        else
          raise ArgumentError, "Unknown emitter format: #{format}"
        end
      end
    end
  end

  # Convenience aliases
  module Emitters
    JSON = Emitter::Emitters::JSON
    YAML = Emitter::Emitters::YAML
    LLM = Emitter::Emitters::LLM
    GraphViz = Emitter::Emitters::GraphViz
  end
end
