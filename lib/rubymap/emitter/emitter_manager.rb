# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module Rubymap
  module Emitter
    class EmitterManager
      attr_reader :options

      def initialize(**options)
        @options = options
        @parallel = options[:parallel] || false
        @continue_on_error = options[:continue_on_error] || false
        @transactional = options[:transactional] || false
      end

      def emit_all(indexed_data, output_dir, formats: [:json, :yaml, :llm, :graphviz])
        ensure_output_directory(output_dir)

        results = {}
        errors = []
        start_time = Time.now

        if @transactional
          emit_transactional(indexed_data, output_dir, formats, results, errors)
        elsif @parallel
          emit_parallel(indexed_data, output_dir, formats, results, errors)
        else
          emit_sequential(indexed_data, output_dir, formats, results, errors)
        end

        # Generate unified manifest
        manifest_path = generate_unified_manifest(output_dir, results, errors, indexed_data, start_time)

        {
          formats: results.keys,
          files: results.values.flatten,
          errors: errors,
          manifest: manifest_path,
          duration: Time.now - start_time
        }
      end

      def emit(indexed_data, output_dir, formats:, configs: {})
        ensure_output_directory(output_dir)

        results = {}

        formats.each do |format|
          config = configs[format] || {}
          emitter = create_emitter(format, **config)

          case format
          when :json, :yaml
            results[format] = emitter.emit_to_directory(indexed_data, output_dir)
          when :llm
            llm_dir = File.join(output_dir, "chunks")
            results[format] = emitter.emit_to_directory(indexed_data, llm_dir)
          when :graphviz
            graphs_dir = File.join(output_dir, "graphs")
            results[format] = emitter.emit_to_directory(indexed_data, graphs_dir,
              include_makefile: config[:include_makefile],
              include_readme: config[:include_readme])
          end
        end

        results
      end

      def emit_incremental(updated_data, output_dir)
        # Load existing manifest to determine what changed
        manifest_path = File.join(output_dir, "manifest.json")
        previous_manifest = load_previous_manifest(manifest_path)

        # Determine changes
        changes = detect_changes(previous_manifest, updated_data)

        updated_files = []
        unchanged_files = []

        # Update only changed files
        changes[:added].each do |symbol|
          files = emit_symbol(symbol, updated_data, output_dir)
          updated_files.concat(files)
        end

        changes[:modified].each do |symbol|
          files = emit_symbol(symbol, updated_data, output_dir)
          updated_files.concat(files)
        end

        # Update manifest with delta information
        update_manifest_with_delta(manifest_path, changes, updated_data)

        {
          updated_files: updated_files,
          unchanged_files: unchanged_files,
          delta: changes
        }
      end

      def create_package(output_dir, package_path)
        begin
          require "zip"
        rescue
          nil
        end # Optional dependency

        if defined?(Zip)
          create_zip_package(output_dir, package_path)
        else
          create_tar_package(output_dir, package_path)
        end
      end

      private

      def ensure_output_directory(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def emit_sequential(indexed_data, output_dir, formats, results, errors)
        formats.each do |format|
          emitter = create_emitter(format, **@options)
          results[format] = emit_format(emitter, indexed_data, output_dir, format)
        rescue => e
          errors << "#{format.capitalize} emission failed: #{e.message}"
          raise unless @continue_on_error
        end
      end

      def emit_parallel(indexed_data, output_dir, formats, results, errors)
        begin
          require "concurrent"
        rescue
          nil
        end

        if defined?(Concurrent)
          emit_with_concurrent(indexed_data, output_dir, formats, results, errors)
        else
          emit_with_threads(indexed_data, output_dir, formats, results, errors)
        end
      end

      def emit_with_threads(indexed_data, output_dir, formats, results, errors)
        threads = formats.map do |format|
          Thread.new do
            emitter = create_emitter(format, **@options)
            Thread.current[:result] = emit_format(emitter, indexed_data, output_dir, format)
            Thread.current[:format] = format
          rescue => e
            Thread.current[:error] = "#{format.capitalize} emission failed: #{e.message}"
          end
        end

        threads.each do |thread|
          thread.join
          if thread[:error]
            errors << thread[:error]
            raise thread[:error] unless @continue_on_error
          else
            results[thread[:format]] = thread[:result]
          end
        end
      end

      def emit_with_concurrent(indexed_data, output_dir, formats, results, errors)
        pool = Concurrent::FixedThreadPool.new(formats.size)
        futures = {}

        formats.each do |format|
          futures[format] = Concurrent::Future.execute(executor: pool) do
            emitter = create_emitter(format, **@options)
            emit_format(emitter, indexed_data, output_dir, format)
          end
        end

        futures.each do |format, future|
          results[format] = future.value!
        rescue => e
          errors << "#{format.capitalize} emission failed: #{e.message}"
          raise unless @continue_on_error
        end

        pool.shutdown
        pool.wait_for_termination
      end

      def emit_transactional(indexed_data, output_dir, formats, results, errors)
        temp_dir = "#{output_dir}.tmp.#{Process.pid}"

        begin
          ensure_output_directory(temp_dir)

          # Emit all formats to temp directory
          formats.each do |format|
            emitter = create_emitter(format, **@options)
            results[format] = emit_format(emitter, indexed_data, temp_dir, format)
          end

          # If all successful, move temp to final location
          FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
          FileUtils.mv(temp_dir, output_dir)
        rescue => e
          # Rollback on any failure
          FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
          raise e
        end
      end

      def emit_format(emitter, indexed_data, output_dir, format)
        case format
        when :llm
          emitter.emit_to_directory(indexed_data, output_dir)
        when :graphviz
          graphs_dir = File.join(output_dir, "graphs")
          emitter.emit_to_directory(indexed_data, graphs_dir)
        else
          emitter.emit_to_directory(indexed_data, output_dir)
        end
      end

      def create_emitter(format, **config)
        case format
        when :json
          Emitters::JSON.new(**config)
        when :yaml
          Emitters::YAML.new(**config)
        when :llm
          Emitters::LLM.new(**config)
        when :graphviz, :dot
          Emitters::GraphViz.new(**config)
        else
          raise ArgumentError, "Unknown format: #{format}"
        end
      end

      def generate_unified_manifest(output_dir, results, errors, indexed_data, start_time)
        duration_ms = ((Time.now - start_time) * 1000).round

        manifest = {
          schema_version: 1,
          generator: {
            name: "rubymap",
            version: Rubymap::VERSION
          },
          generated_at: Time.now.utc.iso8601,
          source: {
            project_name: indexed_data.dig(:metadata, :project_name),
            total_classes: indexed_data.dig(:metadata, :total_classes),
            total_methods: indexed_data.dig(:metadata, :total_methods)
          },
          outputs: {},
          performance: {
            total_duration_ms: duration_ms,
            format_durations: {}
          },
          errors: errors
        }

        # Add output information for each format
        results.each do |format, files|
          manifest[:outputs][format] = {
            file_count: files.size,
            total_size: files.sum { |f| f[:size] || 0 }
          }

          # Add format-specific metadata
          case format
          when :llm
            manifest[:outputs][:llm_chunks] = {
              index_url: "index.md",
              chunk_count: files.count { |f| f[:relative_path]&.include?("chunks/") }
            }
          when :graphviz
            manifest[:outputs][:graphs] = {
              viewer_url: "graphs/complete.dot",
              graph_count: files.count { |f| f[:relative_path]&.end_with?(".dot") }
            }
          end
        end

        manifest_path = File.join(output_dir, "manifest.json")
        File.write(manifest_path, JSON.pretty_generate(manifest))

        # Generate checksums file
        generate_checksums(output_dir, results)

        manifest_path
      end

      def generate_checksums(output_dir, results)
        checksums = []

        results.each do |_format, files|
          files.each do |file|
            if file[:checksum] && file[:relative_path]
              checksums << "#{file[:checksum]}  #{file[:relative_path]}"
            end
          end
        end

        checksums_path = File.join(output_dir, "checksums.sha256")
        File.write(checksums_path, checksums.join("\n"))
      end

      def detect_changes(previous_manifest, updated_data)
        changes = {
          added: [],
          modified: [],
          removed: []
        }

        # Simple change detection - would be more sophisticated in production
        previous_classes = previous_manifest.dig("source", "total_classes") || 0
        current_classes = updated_data.dig(:metadata, :total_classes) || 0

        if current_classes > previous_classes
          # Assume new classes were added
          new_count = current_classes - previous_classes
          changes[:added] = updated_data[:classes].last(new_count) if updated_data[:classes]
        end

        changes
      end

      def load_previous_manifest(manifest_path)
        return {} unless File.exist?(manifest_path)

        JSON.parse(File.read(manifest_path))
      rescue JSON::ParserError
        {}
      end

      def emit_symbol(symbol, indexed_data, output_dir)
        # Emit a single symbol across all formats
        []

        # Would implement per-symbol emission logic here
        # For now, returning empty array
      end

      def update_manifest_with_delta(manifest_path, changes, updated_data)
        manifest = load_previous_manifest(manifest_path)

        manifest["last_update"] = Time.now.utc.iso8601
        manifest["delta"] = {
          "added_classes" => changes[:added].map { |c| c[:fqname] },
          "modified_classes" => changes[:modified].map { |c| c[:fqname] },
          "removed_classes" => changes[:removed].map { |c| c[:fqname] }
        }

        File.write(manifest_path, JSON.pretty_generate(manifest))
      end

      def create_zip_package(output_dir, package_path)
        require "zip"

        file_count = 0
        total_size = 0

        Zip::File.open(package_path, Zip::File::CREATE) do |zipfile|
          Dir.glob("#{output_dir}/**/*").each do |file|
            next if File.directory?(file)

            relative_path = file.sub("#{output_dir}/", "")
            zipfile.add(relative_path, file)
            file_count += 1
            total_size += File.size(file)
          end
        end

        {
          path: package_path,
          size_mb: (File.size(package_path) / 1024.0 / 1024.0).round(2),
          file_count: file_count,
          uncompressed_size_mb: (total_size / 1024.0 / 1024.0).round(2)
        }
      end

      def create_tar_package(output_dir, package_path)
        # Fallback to tar if zip gem not available
        system("tar", "-czf", package_path, "-C", File.dirname(output_dir), File.basename(output_dir))

        {
          path: package_path,
          size_mb: (File.size(package_path) / 1024.0 / 1024.0).round(2),
          file_count: Dir.glob("#{output_dir}/**/*").count { |f| !File.directory?(f) }
        }
      end
    end
  end
end
