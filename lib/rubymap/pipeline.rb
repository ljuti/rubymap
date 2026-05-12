# frozen_string_literal: true

require "fileutils"
require_relative "error_collector"
require_relative "retry_handler"

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

    # @return [ErrorCollector] Error collector for the pipeline
    attr_reader :error_collector

    # Creates a new Pipeline instance.
    #
    # @param configuration [Configuration] Configuration object with processing options
    #
    # @example
    #   config = Rubymap::Configuration.default
    #   pipeline = Rubymap::Pipeline.new(config)
    def initialize(configuration)
      @configuration = configuration
      @error_collector = ErrorCollector.new(
        max_errors: configuration.respond_to?(:max_errors) ? configuration.max_errors : 100
      )
      @retry_handler = RetryHandler.new(
        max_retries: configuration.respond_to?(:retry_max) ? configuration.retry_max : 3,
        base_delay: 0.1
      )
      @on_step = nil
    end

    # Register a callback for pipeline step progress.
    # @yield [step_number, step_name, total_steps] Called at each pipeline step
    def on_step(&block)
      @on_step = block
    end

    # Executes the complete analysis pipeline.
    #
    # Processes the specified paths through all pipeline stages:
    # extraction, normalization, enrichment, indexing, and emission.
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
      @error_collector.clear  # Clear any previous errors

      # Step 1: Extract data from source files
      step(1, 5, "Extracting data from Ruby files...")
      extracted_data = extract(paths)
      log "  → Extracted #{extracted_data[:classes]&.size || 0} classes, #{extracted_data[:modules]&.size || 0} modules"

      # Step 2: Normalize the data
      step(2, 5, "Normalizing data...")
      normalized_data = normalize(extracted_data)
      log "  → Normalized and deduplicated data"

      # Step 3: Enrich with additional metadata
      step(3, 5, "Enriching with metadata...")
      enriched_data = enrich(normalized_data)
      log "  → Added metrics and relationships"

      # Step 4: Index the enriched data
      step(4, 5, "Indexing enriched data...")
      indexed_data = index(enriched_data)
      log "  → Created index with #{indexed_data[:index]&.size || 0} symbols"

      # Step 5: Emit output in requested format
      step(5, 5, "Emitting output...")
      result = emit(indexed_data)
      log "  → Generated output in #{configuration.format} format"

      # Add error summary to result
      if @error_collector.any?
        log ""
        log @error_collector.report(verbose: configuration.verbose)
        result[:error_summary] = @error_collector.summary
        result[:errors] = @error_collector.to_h[:errors] if configuration.verbose
      end

      log "Pipeline completed #{@error_collector.critical? ? "with critical errors" : "successfully"}!"
      result
    end

    private

    def extract(paths)
      extractor = Extractor.new
      cache = build_cache

      all_data = {
        classes: [],
        modules: [],
        methods: [],
        constants: [],
        mixins: [],
        attributes: [],
        dependencies: [],
        patterns: [],
        class_variables: [],
        aliases: [],
        method_calls: [],
        metadata: {
          extracted_at: Time.now.iso8601,
          ruby_version: RUBY_VERSION,
          source_paths: paths
        }
      }

      paths.each do |path|
        if File.directory?(path)
          Dir.glob(File.join(path, "**", "*.rb")).each do |file|
            next if should_exclude?(file)
            extract_file(extractor, cache, file, all_data)
          end
        elsif File.file?(path) && path.end_with?(".rb")
          extract_file(extractor, cache, path, all_data)
        else
          unless File.directory?(path)
            @error_collector.add_warning(
              :filesystem,
              "Path is not a directory or Ruby file",
              file: path
            )
          end
        end
      end

      all_data
    end

    def build_cache
      return nil unless configuration.respond_to?(:cache) && configuration.cache.is_a?(Hash)
      return nil unless configuration.cache["enabled"]

      PipelineCache.new(configuration.cache["directory"] || ".rubymap_cache")
    end

    def extract_file(extractor, cache, file, all_data)
      # Check cache first
      if cache
        cached = cache.fetch(file)
        if cached
          merge_cached_result!(all_data, cached)
          log "  Cached: #{file}" if configuration.verbose
          return
        end
      end

      log "  Processing: #{file}" if configuration.verbose
      begin
        result = @retry_handler.with_retry(error_collector: @error_collector, file: file) do
          extractor.extract_from_file(file)
        end
        merge_result!(all_data, result)

        if result.respond_to?(:error_collector) && result.error_collector.any?
          @error_collector.merge!(result.error_collector)
        end

        # Store in cache for future runs
        cache&.store(file, extract_result_to_cache(result))
      rescue => e
        @error_collector.add_error(
          :filesystem,
          "Failed to extract from file: #{e.message}",
          severity: :error,
          file: file
        )
        log "  Warning: Failed to extract from #{file}: #{e.message}"
      end
    end

    def extract_result_to_cache(result)
      temp = {classes: [], modules: [], methods: [], constants: [], mixins: [], attributes: [], dependencies: [], patterns: [], class_variables: [], aliases: [], method_calls: []}
      merge_result!(temp, result)
      temp
    end

    def merge_cached_result!(target, cached)
      target[:classes].concat(cached[:classes] || [])
      target[:modules].concat(cached[:modules] || [])
      target[:methods].concat(cached[:methods] || [])
      target[:constants].concat(cached[:constants] || [])
      target[:mixins].concat(cached[:mixins] || [])
      target[:attributes].concat(cached[:attributes] || [])
      target[:dependencies].concat(cached[:dependencies] || [])
      target[:patterns].concat(cached[:patterns] || [])
      target[:class_variables].concat(cached[:class_variables] || [])
      target[:aliases].concat(cached[:aliases] || [])
      target[:method_calls].concat(cached[:method_calls] || [])
    end

    def index(data)
      indexer = Indexer.new
      begin
        indexed_result = indexer.build(data)
      rescue => e
        @error_collector.add_error(
          :runtime,
          "Indexing failed: #{e.message}",
          severity: :error
        )
        log "  Error during indexing: #{e.message}"
        return data  # Return original data on failure
      end

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
      begin
        normalized_result = normalizer.normalize(data)
      rescue => e
        @error_collector.add_error(
          :runtime,
          "Normalization failed: #{e.message}",
          severity: :error
        )
        log "  Error during normalization: #{e.message}"
        # Return a basic normalized result on failure
        return data
      end

      # Return the NormalizedResult
      normalized_result
    end

    def enrich(normalized_result)
      enricher = Enricher.new
      begin
        enrichment_result = enricher.enrich(normalized_result)
      rescue => e
        @error_collector.add_error(
          :runtime,
          "Enrichment failed: #{e.message}",
          severity: :warning  # Warning because enrichment is optional
        )
        log "  Warning during enrichment: #{e.message}"
        # Return a basic result on enrichment failure
        method_calls = if normalized_result.respond_to?(:method_calls)
          normalized_result.method_calls.map do |mc|
            mc.respond_to?(:to_h) ? mc.to_h : mc
          end
        else
          []
        end

        {
          classes: normalized_result.respond_to?(:classes) ? normalized_result.classes.map(&:to_h) : [],
          modules: normalized_result.respond_to?(:modules) ? normalized_result.modules.map(&:to_h) : [],
          methods: normalized_result.respond_to?(:methods) ? normalized_result.methods.map(&:to_h) : [],
          method_calls: method_calls,
          patterns: extract_attached_from_normalized(normalized_result, :patterns),
          attributes: extract_attached_from_normalized(normalized_result, :attributes),
          class_variables: extract_attached_from_normalized(normalized_result, :class_variables),
          aliases: extract_attached_from_normalized(normalized_result, :aliases),
          metadata: {
            enriched_at: Time.now.iso8601,
            project_name: "Ruby Project",
            ruby_version: RUBY_VERSION,
            enrichment_failed: true
          }
        }
      end

      # Convert EnrichmentResult to hash format expected by emitters
      method_calls = if enrichment_result.respond_to?(:method_calls)
        enrichment_result.method_calls.map do |mc|
          mc.respond_to?(:to_h) ? mc.to_h : mc
        end
      else
        []
      end

      {
        classes: enrichment_result.classes.map(&:to_h),
        modules: enrichment_result.modules.map(&:to_h),
        methods: enrichment_result.methods.map(&:to_h),
        method_calls: method_calls,
        patterns: enrichment_result.respond_to?(:patterns) ? enrichment_result.patterns : extract_attached_from_normalized(normalized_result, :patterns),
        attributes: enrichment_result.respond_to?(:attributes) ? enrichment_result.attributes : extract_attached_from_normalized(normalized_result, :attributes),
        class_variables: enrichment_result.respond_to?(:class_variables) ? enrichment_result.class_variables : extract_attached_from_normalized(normalized_result, :class_variables),
        aliases: enrichment_result.respond_to?(:aliases) ? enrichment_result.aliases : extract_attached_from_normalized(normalized_result, :aliases),
        metadata: {
          enriched_at: enrichment_result.enriched_at,
          project_name: "Ruby Project",
          ruby_version: RUBY_VERSION,
          total_classes: enrichment_result.classes.size,
          total_methods: enrichment_result.methods.size
        }
      }
    end

    def emit(data)
      # Ensure output directory exists
      begin
        FileUtils.mkdir_p(configuration.output_dir)
      rescue => e
        @error_collector.add_critical(
          :output,
          "Failed to create output directory: #{e.message}",
          file: configuration.output_dir
        )
        return {format: configuration.format, output_dir: nil, error: e.message}
      end

      # Validate format is supported
      supported = Emitter::SUPPORTED_FORMATS
      unless supported.include?(configuration.format.to_sym)
        msg = "Unsupported format: #{configuration.format}"
        @error_collector.add_critical(:config, msg)
        return {format: configuration.format, output_dir: nil, error: msg}
      end

      emitter = Emitters::LLM.new(
        use_templates: configuration.respond_to?(:templates_enabled) && configuration.templates_enabled,
        template_dir: configuration.respond_to?(:template_dir) ? configuration.template_dir : nil
      )
      begin
        emitter.emit_to_directory(data, configuration.output_dir)
      rescue => e
        @error_collector.add_error(
          :output,
          "Failed to emit LLM format: #{e.message}",
          severity: :error
        )
        return {format: configuration.format, output_dir: configuration.output_dir, error: e.message}
      end
      {format: :llm, output_dir: configuration.output_dir}
    end

    def should_exclude?(path)
      configuration.filter["exclude_patterns"].any? do |pattern|
        File.fnmatch?(pattern, path, File::FNM_PATHNAME)
      end
    end

    def merge_result!(target, result)
      adapted = ResultAdapter.adapt(result)
      target[:classes].concat(adapted[:classes])
      target[:modules].concat(adapted[:modules])
      target[:methods].concat(adapted[:methods])
      target[:constants].concat(adapted[:constants])
      target[:mixins].concat(adapted[:mixins])
      target[:attributes].concat(adapted[:attributes])
      target[:dependencies].concat(adapted[:dependencies])
      target[:patterns].concat(adapted[:patterns])
      target[:class_variables].concat(adapted[:class_variables])
      target[:aliases].concat(adapted[:aliases])
      target[:method_calls].concat(adapted[:method_calls])
    end

    def write_output(filename, content)
      output_path = File.join(configuration.output_dir, filename)
      begin
        File.write(output_path, content)
      rescue Errno::EACCES => e
        @error_collector.add_critical(
          :output,
          "Permission denied writing output file: #{e.message}",
          file: output_path
        )
        raise ConfigurationError, "Cannot create output directory: #{configuration.output_dir} - Permission denied"
      rescue => e
        @error_collector.add_critical(
          :output,
          "Failed to write output file: #{e.message}",
          file: output_path
        )
        raise
      end
      {format: configuration.format, path: output_path}
    end

    def log(message)
      puts message if configuration.verbose || configuration.progress
    end

    def step(number, total, name)
      @on_step&.call(number, name, total)
      log "Step #{number}/#{total}: #{name}"
    end

    # Extracts metadata attached to normalized classes/modules by AttachMetadataStep.
    # Used as fallback when EnrichmentResult does not carry these fields.
    def extract_attached_from_normalized(normalized_result, key)
      return [] unless normalized_result.respond_to?(:classes) && normalized_result.respond_to?(:modules)

      all = []
      (normalized_result.classes || []).each do |c|
        vals = c.respond_to?(key) ? c.send(key) : nil
        all.concat(vals) if vals.is_a?(Array)
      end
      (normalized_result.modules || []).each do |m|
        vals = m.respond_to?(key) ? m.send(key) : nil
        all.concat(vals) if vals.is_a?(Array)
      end
      all
    end
  end
end

