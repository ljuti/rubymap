# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module Rubymap
  module Emitter
    # Manages emission of indexed data to output formats.
    #
    # Coordinates format-specific emitters and generates unified manifest
    # metadata for the output directory.
    #
    # @rubymap Coordinates emission across formats and generates output manifests
    class EmitterManager
      attr_reader :options

      def initialize(**options)
        @options = options
      end

      # Emits data in the specified formats and generates a unified manifest.
      #
      # @param indexed_data [Hash] Indexed codebase data
      # @param output_dir [String] Directory for output files
      # @param formats [Array<Symbol>] Formats to emit (currently only :llm)
      # @return [Hash] Result with formats, files, errors, manifest path, and duration
      def emit_all(indexed_data, output_dir, formats: [:llm])
        ensure_output_directory(output_dir)

        results = {}
        errors = []
        start_time = Time.now

        formats.each do |format|
          emitter = create_emitter(format, **@options)
          results[format] = emit_format(emitter, indexed_data, output_dir, format)
        rescue => e
          errors << "#{format.capitalize} emission failed: #{e.message}"
          raise
        end

        manifest_path = generate_unified_manifest(output_dir, results, errors, indexed_data, start_time)

        {
          formats: results.keys,
          files: results.values.flatten,
          errors: errors,
          manifest: manifest_path,
          duration: Time.now - start_time
        }
      end

      # Emits data in specified formats with per-format configuration.
      #
      # @param indexed_data [Hash] Indexed codebase data
      # @param output_dir [String] Directory for output files
      # @param formats [Array<Symbol>] Formats to emit
      # @param configs [Hash] Per-format configuration overrides
      # @return [Hash] Results keyed by format
      def emit(indexed_data, output_dir, formats:, configs: {})
        ensure_output_directory(output_dir)

        results = {}

        formats.each do |format|
          config = configs[format] || {}
          emitter = create_emitter(format, **config)
          results[format] = emit_format(emitter, indexed_data, output_dir, format)
        end

        results
      end

      private

      def ensure_output_directory(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def emit_format(emitter, indexed_data, output_dir, format)
        case format
        when :llm
          emitter.emit_to_directory(indexed_data, output_dir)
        else
          raise ArgumentError, "Unknown format: #{format}. Supported: #{SUPPORTED_FORMATS.map(&:inspect).join(", ")}"
        end
      end

      def create_emitter(format, **config)
        case format
        when :llm
          Emitters::LLM.new(**config)
        else
          raise ArgumentError, "Unknown format: #{format}. Supported: #{SUPPORTED_FORMATS.map(&:inspect).join(", ")}"
        end
      end

      def generate_unified_manifest(output_dir, results, errors, indexed_data, start_time)
        duration_ms = ((Time.now - start_time) * 1000).round

        manifest = {
          schema_version: 1,
          generator: {
            name: "rubymap",
            version: Rubymap.gem_version
          },
          generated_at: Time.now.utc.iso8601,
          source: {
            project_name: indexed_data.dig(:metadata, :project_name),
            total_classes: indexed_data.dig(:metadata, :total_classes),
            total_methods: indexed_data.dig(:metadata, :total_methods)
          },
          outputs: {},
          performance: {
            total_duration_ms: duration_ms
          },
          errors: errors
        }

        results.each do |format, files|
          manifest[:outputs][format] = {
            file_count: files.size,
            total_size: files.sum { |f| f[:size] || 0 }
          }

          if format == :llm
            manifest[:outputs][:llm_chunks] = {
              index_url: "index.md",
              chunk_count: files.count { |f| f[:relative_path]&.include?("chunks/") }
            }
          end
        end

        manifest_path = File.join(output_dir, "manifest.json")
        File.write(manifest_path, JSON.pretty_generate(manifest))
        manifest_path
      end
    end
  end
end
