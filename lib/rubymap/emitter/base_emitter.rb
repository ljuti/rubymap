# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "time"

module Rubymap
  module Emitter
    class BaseEmitter
      attr_reader :options

      def initialize(**options)
        @options = default_options.merge(options)
        @redactor = Processors::Redactor.new(@options[:redaction_rules]) if @options[:redact]
        @formatter = Formatters::DeterministicFormatter.new
      end

      def emit(indexed_data)
        raise NotImplementedError, "#{self.class} must implement #emit"
      end

      def emit_to_file(indexed_data, file_path)
        ensure_directory_exists(File.dirname(file_path))

        output = emit(indexed_data)
        File.write(file_path, output)

        {
          path: file_path,
          size: File.size(file_path),
          checksum: Digest::SHA256.hexdigest(output)
        }
      end

      def emit_to_directory(indexed_data, output_dir)
        ensure_directory_exists(output_dir)

        files = generate_files(indexed_data)
        written_files = []

        files.each do |file_info|
          file_path = File.join(output_dir, file_info[:path])
          ensure_directory_exists(File.dirname(file_path))

          File.write(file_path, file_info[:content])
          written_files << {
            path: file_path,
            relative_path: file_info[:path],
            size: file_info[:content].bytesize,
            checksum: Digest::SHA256.hexdigest(file_info[:content])
          }
        end

        generate_manifest(output_dir, written_files, indexed_data)
        written_files
      end

      protected

      def default_options
        {
          redact: false,
          redaction_rules: [],
          include_private: true,
          deterministic: true,
          include_metadata: true
        }
      end

      def generate_files(indexed_data)
        [{
          path: default_filename,
          content: emit(indexed_data)
        }]
      end

      def default_filename
        "output.#{format_extension}"
      end

      def format_extension
        raise NotImplementedError, "#{self.class} must implement #format_extension"
      end

      def ensure_directory_exists(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def apply_redaction(content)
        return content unless @redactor
        @redactor.redact(content)
      end

      def apply_deterministic_formatting(data)
        return data unless @options[:deterministic]
        @formatter.format(data)
      end

      def filter_data(indexed_data)
        filtered = indexed_data.dup

        unless @options[:include_private]
          filtered[:classes] = filter_private_symbols(filtered[:classes])
          filtered[:modules] = filter_private_symbols(filtered[:modules])
        end

        filtered
      end

      def filter_private_symbols(symbols)
        return [] unless symbols

        symbols.select do |symbol|
          visibility = symbol[:visibility] || symbol["visibility"]
          visibility != "private" && visibility != :private
        end
      end

      def generate_manifest(output_dir, files, indexed_data)
        manifest = {
          schema_version: 1,
          generator: {
            name: "rubymap",
            version: Rubymap.gem_version,
            emitter_type: self.class.name.split("::").last.downcase
          },
          generated_at: Time.now.utc.iso8601,
          source: {
            project_name: indexed_data.dig(:metadata, :project_name),
            total_classes: indexed_data.dig(:metadata, :total_classes),
            total_methods: indexed_data.dig(:metadata, :total_methods)
          },
          outputs: {
            format: format_extension,
            file_count: files.size,
            total_size: files.sum { |f| f[:size] }
          },
          files: files.map { |f| f[:relative_path] },
          checksums: files.each_with_object({}) { |f, h| h[f[:relative_path]] = f[:checksum] }
        }

        manifest_path = File.join(output_dir, "manifest.json")
        File.write(manifest_path, JSON.pretty_generate(manifest))
        manifest_path
      end
    end
  end
end
