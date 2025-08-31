# frozen_string_literal: true

require "fileutils"

module Rubymap
  # Orchestrates the complete code analysis pipeline from extraction to output.
  #
  # The Pipeline coordinates all Rubymap components in sequence, managing data
  # flow between extraction, normalization, indexing, enrichment, and emission
  # stages. It provides progress tracking, error handling, and configurable
  # processing options.
  #
  # @rubymap Orchestrates the complete analysis pipeline from code to documentation
  #
  # @example Basic pipeline execution
  #   config = Rubymap::Configuration.new(
  #     format: :llm,
  #     output_dir: "docs/"
  #   )
  #
  #   pipeline = Rubymap::Pipeline.new(config)
  #   result = pipeline.run(["lib/", "app/"])
  #
  #   # Result contains generated documentation paths
  #
  # @example Pipeline with custom configuration
  #   config = Rubymap::Configuration.new(
  #     format: :json,
  #     verbose: true,
  #     exclude_patterns: ["**/test/**", "**/spec/**"]
  #   )
  #
  #   pipeline = Rubymap::Pipeline.new(config)
  #   result = pipeline.run(["."])
  #
  # @example Step-by-step processing
  #   # The pipeline executes these steps:
  #   # 1. Extract: Parse Ruby files to extract symbols
  #   # 2. Index: Build searchable indexes and graphs
  #   # 3. Normalize: Standardize names and resolve references
  #   # 4. Enrich: Calculate metrics and detect patterns
  #   # 5. Emit: Generate output in requested format
  #
  class Pipeline
    # @return [Configuration] Pipeline configuration settings
    attr_reader :configuration

    # Creates a new Pipeline instance.
    #
    # @param configuration [Configuration] Configuration object with processing options
    #
    # @example
    #   config = Rubymap::Configuration.default
    #   pipeline = Rubymap::Pipeline.new(config)
    def initialize(configuration)
      @configuration = configuration
    end

    # Executes the complete analysis pipeline.
    #
    # Processes the specified paths through all pipeline stages:
    # extraction, indexing, normalization, enrichment, and emission.
    # Provides progress logging and handles errors gracefully.
    #
    # @param paths [Array<String>] File or directory paths to analyze
    # @return [Hash] Output result with format and file paths
    #
    # @example Process specific directories
    #   result = pipeline.run(["app/models", "app/controllers"])
    #   result[:path]   # => "output/map.json"
    #   result[:format] # => :json
    #
    # @example Process entire project
    #   result = pipeline.run(["."])
    def run(paths)
      log "Starting Rubymap pipeline..."

      # Step 1: Extract data from source files
      log "Step 1/5: Extracting data from Ruby files..."
      extracted_data = extract(paths)
      log "  → Extracted #{extracted_data[:classes]&.size || 0} classes, #{extracted_data[:modules]&.size || 0} modules"

      # Step 2: Index the extracted data
      log "Step 2/5: Indexing extracted data..."
      indexed_data = index(extracted_data)
      log "  → Created index with #{indexed_data[:index]&.size || 0} symbols"

      # Step 3: Normalize the data
      log "Step 3/5: Normalizing data..."
      normalized_data = normalize(indexed_data)
      log "  → Normalized and deduplicated data"

      # Step 4: Enrich with additional metadata
      log "Step 4/5: Enriching with metadata..."
      enriched_data = enrich(normalized_data)
      log "  → Added metrics and relationships"

      # Step 5: Emit output in requested format
      log "Step 5/5: Emitting output..."
      result = emit(enriched_data)
      log "  → Generated output in #{configuration.format} format"

      log "Pipeline completed successfully!"
      result
    end

    private

    def extract(paths)
      extractor = Extractor.new

      all_data = {
        classes: [],
        modules: [],
        methods: [],
        constants: [],
        metadata: {
          extracted_at: Time.now.iso8601,
          ruby_version: RUBY_VERSION,
          source_paths: paths
        }
      }

      paths.each do |path|
        if File.directory?(path)
          ruby_files = Dir.glob(File.join(path, "**", "*.rb"))
          ruby_files.each do |file|
            next if should_exclude?(file)

            log "  Processing: #{file}" if configuration.verbose
            begin
              result = extractor.extract_from_file(file)
              merge_result!(all_data, result)
            rescue => e
              log "  Warning: Failed to extract from #{file}: #{e.message}"
            end
          end
        elsif File.file?(path) && path.end_with?(".rb")
          log "  Processing: #{path}" if configuration.verbose
          result = extractor.extract_from_file(path)
          merge_result!(all_data, result)
        end
      end

      all_data
    end

    def index(data)
      indexer = Indexer.new
      indexed_result = indexer.build(data)

      # Merge indexed data into original data structure
      data[:index] = indexed_result.symbols if indexed_result.respond_to?(:symbols)

      # Convert Graph objects to array format expected by emitters
      if indexed_result.respond_to?(:inheritance_graph)
        data[:graphs] = {
          inheritance: graph_to_array(indexed_result.inheritance_graph),
          dependencies: graph_to_array(indexed_result.dependency_graph),
          method_calls: graph_to_array(indexed_result.method_call_graph),
          mixins: graph_to_array(indexed_result.mixin_graph)
        }
      end

      data
    end

    def graph_to_array(graph)
      return [] unless graph&.respond_to?(:edges)

      graph.edges.map do |edge|
        {
          from: edge.from,
          to: edge.to,
          type: edge.type || graph.type
        }
      end
    end

    def normalize(data)
      normalizer = Normalizer.new
      normalized_result = normalizer.normalize(data)

      # Keep graphs from indexed data if available
      graphs = data[:graphs] if data.is_a?(Hash) && data[:graphs]

      # Return the NormalizedResult but store graphs for later
      @graphs_cache = graphs
      normalized_result
    end

    def enrich(normalized_result)
      enricher = Enricher.new
      enrichment_result = enricher.enrich(normalized_result)

      # Convert EnrichmentResult to hash format expected by emitters
      {
        classes: enrichment_result.classes.map(&:to_h),
        modules: enrichment_result.modules.map(&:to_h),
        methods: enrichment_result.methods.map(&:to_h),
        metadata: {
          enriched_at: enrichment_result.enriched_at,
          project_name: "Ruby Project",
          ruby_version: RUBY_VERSION,
          total_classes: enrichment_result.classes.size,
          total_methods: enrichment_result.methods.size
        },
        graphs: @graphs_cache || {}
      }
    end

    def emit(data)
      # Ensure output directory exists
      FileUtils.mkdir_p(configuration.output_dir)

      case configuration.format
      when :json
        emitter = Emitters::JSON.new
        output = emitter.emit(data)
        write_output("map.json", output)
      when :yaml
        emitter = Emitters::YAML.new
        output = emitter.emit(data)
        write_output("map.yaml", output)
      when :llm
        emitter = Emitters::LLM.new
        emitter.emit_to_directory(data, configuration.output_dir)
        {format: :llm, output_dir: configuration.output_dir}
      when :graphviz, :dot
        emitter = Emitters::GraphViz.new
        output = emitter.emit(data)
        write_output("map.dot", output)
      else
        raise ConfigurationError, "Unknown format: #{configuration.format}"
      end
    end

    def should_exclude?(path)
      configuration.filter["exclude_patterns"].any? do |pattern|
        File.fnmatch?(pattern, path, File::FNM_PATHNAME)
      end
    end

    def merge_result!(target, result)
      # Convert Result object data to hash format expected by pipeline
      result.classes&.each do |class_info|
        target[:classes] << {
          name: class_info.name,
          type: class_info.type,
          superclass: class_info.superclass,
          file: result.file_path,
          line: class_info.location&.start_line,
          namespace: class_info.namespace,
          documentation: class_info.doc
        }
      end

      result.modules&.each do |mod_info|
        target[:modules] << {
          name: mod_info.name,
          type: "module",
          file: result.file_path,
          line: mod_info.location&.start_line,
          namespace: mod_info.namespace,
          documentation: mod_info.doc
        }
      end

      # Add methods
      if result.methods&.any?
        result.methods.each do |method_info|
          target[:methods] << {
            name: method_info.name,
            visibility: method_info.visibility,
            receiver_type: method_info.receiver_type,
            params: method_info.params,
            file: result.file_path,
            line: method_info.location&.start_line,
            namespace: method_info.namespace,
            owner: method_info.owner,
            documentation: method_info.doc
          }
        end
      end

      # Add constants
      if result.constants&.any?
        result.constants.each do |const_info|
          target[:constants] << {
            name: const_info.name,
            value: const_info.value,
            file: result.file_path,
            line: const_info.location&.start_line,
            namespace: const_info.namespace,
            documentation: const_info.respond_to?(:doc) ? const_info.doc : nil
          }
        end
      end
    end

    def write_output(filename, content)
      output_path = File.join(configuration.output_dir, filename)
      File.write(output_path, content)
      {format: configuration.format, path: output_path}
    end

    def log(message)
      puts message if configuration.verbose || configuration.progress
    end
  end
end
