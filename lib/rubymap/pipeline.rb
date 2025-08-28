# frozen_string_literal: true

require "fileutils"

module Rubymap
  # Orchestrates the complete mapping pipeline
  class Pipeline
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    # Run the complete pipeline
    # @param paths [Array<String>] Paths to process
    # @return [Hash] The final mapping result
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
      return [] unless graph && graph.respond_to?(:edges)

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
        classes: enrichment_result.classes.map { |c| class_to_hash(c) },
        modules: enrichment_result.modules.map { |m| module_to_hash(m) },
        methods: enrichment_result.methods,
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

    def class_to_hash(enriched_class)
      {
        name: enriched_class.name,
        fqname: enriched_class.fqname,
        type: enriched_class.kind,
        superclass: enriched_class.superclass,
        file: enriched_class.respond_to?(:file) ? enriched_class.file : nil,
        line: nil, # enriched_class doesn't have line info
        namespace: enriched_class.namespace_path.join("::"),
        documentation: nil,
        instance_methods: enriched_class.instance_methods,
        class_methods: enriched_class.class_methods,
        metrics: {
          complexity_score: enriched_class.complexity_score,
          maintainability_score: enriched_class.maintainability_score,
          test_coverage: enriched_class.test_coverage
        }
      }
    end

    def module_to_hash(enriched_module)
      {
        name: enriched_module.name,
        fqname: enriched_module.fqname,
        type: "module",
        file: enriched_module.respond_to?(:file) ? enriched_module.file : nil,
        line: nil,
        namespace: enriched_module.namespace_path.join("::"),
        documentation: nil,
        instance_methods: enriched_module.respond_to?(:instance_methods) ? (enriched_module.instance_methods || []) : [],
        class_methods: enriched_module.respond_to?(:class_methods) ? (enriched_module.class_methods || []) : [],
        metrics: {}
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
      configuration.exclude_patterns.any? do |pattern|
        File.fnmatch?(pattern, path, File::FNM_PATHNAME)
      end
    end

    def merge_result!(target, result)
      # Convert Result object data to hash format expected by pipeline
      if result.classes
        result.classes.each do |class_info|
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
      end

      if result.modules
        result.modules.each do |mod_info|
          target[:modules] << {
            name: mod_info.name,
            type: "module",
            file: result.file_path,
            line: mod_info.location&.start_line,
            namespace: mod_info.namespace,
            documentation: mod_info.doc
          }
        end
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
