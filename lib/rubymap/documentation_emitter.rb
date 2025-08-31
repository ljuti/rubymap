# frozen_string_literal: true

require_relative "documentation_emitter/markdown_formatter"
require_relative "documentation_emitter/json_formatter"
require_relative "documentation_emitter/yaml_formatter"

module Rubymap
  # Generates comprehensive documentation from enriched pipeline results.
  #
  # The DocumentationEmitter aggregates outputs from all pipeline stages
  # (Extractor, Normalizer, Indexer, Enricher) and produces structured
  # documentation in various formats (Markdown, JSON, YAML, HTML).
  #
  # @rubymap Generates documentation in multiple formats from enriched data
  #
  # @example Basic usage
  #   enriched_result = enricher.enrich(indexed_data)
  #   emitter = Rubymap::DocumentationEmitter.new
  #   documentation = emitter.emit(enriched_result, format: :markdown)
  #
  # @example Generate multiple formats
  #   emitter = Rubymap::DocumentationEmitter.new
  #   markdown_doc = emitter.emit(enriched_result, format: :markdown)
  #   json_doc = emitter.emit(enriched_result, format: :json)
  #
  class DocumentationEmitter
    # Supported output formats
    FORMATS = %i[markdown json yaml].freeze

    attr_reader :config

    # Creates a new DocumentationEmitter instance.
    #
    # @param config [Hash] Configuration options
    # @option config [Boolean] :include_private (false) Include private methods
    # @option config [Boolean] :include_metrics (true) Include quality metrics
    # @option config [Boolean] :include_relationships (true) Include dependency graphs
    # @option config [Integer] :max_complexity_shown (20) Max complexity to display
    def initialize(config = {})
      @config = default_config.merge(config)
      @formatters = {
        markdown: MarkdownFormatter.new(@config),
        json: JsonFormatter.new(@config),
        yaml: YamlFormatter.new(@config)
      }
    end

    # Generates documentation from enriched pipeline results.
    #
    # @param enriched_result [Enricher::EnrichmentResult] The enriched data from pipeline
    # @param format [Symbol] Output format (:markdown, :json, :yaml)
    # @return [String] Formatted documentation
    # @raise [ArgumentError] if format is not supported
    def emit(enriched_result, format: :markdown)
      validate_format!(format)

      documentation_data = aggregate_documentation(enriched_result)
      formatter = @formatters[format]
      formatter.format(documentation_data)
    end

    # Generates documentation for a specific class or module.
    #
    # @param enriched_result [Enricher::EnrichmentResult] The enriched data
    # @param symbol_name [String] Name of the class/module to document
    # @param format [Symbol] Output format
    # @return [String] Formatted documentation for the specific symbol
    def emit_for_symbol(enriched_result, symbol_name, format: :markdown)
      validate_format!(format)

      documentation_data = aggregate_documentation_for_symbol(enriched_result, symbol_name)
      return nil unless documentation_data

      formatter = @formatters[format]
      formatter.format(documentation_data)
    end

    private

    def default_config
      {
        include_private: false,
        include_metrics: true,
        include_relationships: true,
        max_complexity_shown: 20,
        include_inherited: true,
        include_file_info: true
      }
    end

    def validate_format!(format)
      unless FORMATS.include?(format)
        raise ArgumentError, "Unsupported format: #{format}. Supported formats: #{FORMATS.join(", ")}"
      end
    end

    def aggregate_documentation(enriched_result)
      {
        overview: build_overview(enriched_result),
        classes: build_class_documentation(enriched_result.classes),
        modules: build_module_documentation(enriched_result.modules),
        relationships: build_relationships(enriched_result),
        metrics: build_metrics_summary(enriched_result),
        issues: build_issues_summary(enriched_result),
        patterns: build_patterns_summary(enriched_result)
      }
    end

    def aggregate_documentation_for_symbol(enriched_result, symbol_name)
      symbol = find_symbol(enriched_result, symbol_name)
      return nil unless symbol

      {
        overview: build_symbol_overview(symbol),
        architecture: build_symbol_architecture(symbol),
        api: build_api_documentation(symbol),
        data_structures: build_data_structures(symbol),
        relationships: build_symbol_relationships(symbol, enriched_result),
        metrics: build_symbol_metrics(symbol),
        issues: build_symbol_issues(symbol)
      }
    end

    def find_symbol(enriched_result, symbol_name)
      enriched_result.classes.find { |c| c.name == symbol_name || c.fqname == symbol_name } ||
        enriched_result.modules.find { |m| m.name == symbol_name || m.fqname == symbol_name }
    end

    def build_overview(enriched_result)
      {
        total_classes: enriched_result.classes.size,
        total_modules: enriched_result.modules.size,
        total_methods: enriched_result.methods.size,
        total_files: enriched_result.respond_to?(:files) ? enriched_result.files.size : 0,
        total_loc: enriched_result.respond_to?(:total_loc) ? enriched_result.total_loc : 0,
        avg_complexity: calculate_average_complexity(enriched_result),
        coverage: enriched_result.respond_to?(:overall_coverage) ? enriched_result.overall_coverage : 0
      }
    end

    def build_class_documentation(classes)
      classes.map do |klass|
        {
          name: klass.name,
          fqname: klass.fqname,
          namespace: klass.namespace_path.join("::"),
          superclass: klass.superclass,
          location: format_location(klass.location),
          mixins: klass.mixins,
          methods: document_methods((klass.respond_to?(:methods) && klass.methods.is_a?(Array)) ? klass.methods : []),
          constants: klass.respond_to?(:constants) ? klass.constants : [],
          attributes: klass.respond_to?(:attributes) ? klass.attributes : [],
          complexity: klass.respond_to?(:total_complexity) ? klass.total_complexity : nil,
          cohesion: klass.respond_to?(:cohesion_score) ? klass.cohesion_score : nil,
          coupling: {
            fan_in: klass.respond_to?(:fan_in) ? klass.fan_in : nil,
            fan_out: klass.respond_to?(:fan_out) ? klass.fan_out : nil
          }
        }
      end
    end

    def build_module_documentation(modules)
      modules.map do |mod|
        {
          name: mod.name,
          fqname: mod.fqname,
          namespace: mod.namespace_path.join("::"),
          location: format_location(mod.location),
          methods: document_methods((mod.respond_to?(:methods) && mod.methods.is_a?(Array)) ? mod.methods : []),
          constants: mod.respond_to?(:constants) ? mod.constants : [],
          included_in: mod.respond_to?(:included_in) ? mod.included_in : [],
          extended_in: mod.respond_to?(:extended_in) ? mod.extended_in : []
        }
      end
    end

    def document_methods(methods)
      return [] if methods.nil? || methods.empty?

      # Filter out non-method objects (like symbols)
      valid_methods = methods.select { |m| m.respond_to?(:name) && m.respond_to?(:visibility) }

      methods_to_document = @config[:include_private] ? valid_methods : valid_methods.select { |m| m.visibility == "public" }

      methods_to_document.map do |method|
        {
          name: method.name,
          visibility: method.visibility,
          scope: method.respond_to?(:scope) ? method.scope : nil,
          parameters: method.respond_to?(:parameters) ? method.parameters : nil,
          complexity: method.respond_to?(:cyclomatic_complexity) ? method.cyclomatic_complexity : nil,
          lines: method.respond_to?(:line_count) ? method.line_count : nil,
          location: method.respond_to?(:location) ? format_location(method.location) : nil,
          rubymap: method.respond_to?(:rubymap) ? method.rubymap : nil
        }
      end
    end

    def build_relationships(enriched_result)
      {
        inheritance_tree: build_inheritance_tree(enriched_result),
        dependencies: build_dependency_graph(enriched_result),
        method_calls: build_call_graph(enriched_result),
        circular_dependencies: enriched_result.respond_to?(:circular_dependencies) ? enriched_result.circular_dependencies : []
      }
    end

    def build_metrics_summary(enriched_result)
      {
        complexity: {
          highest: find_highest_complexity(enriched_result),
          average: calculate_average_complexity(enriched_result),
          distribution: build_complexity_distribution(enriched_result)
        },
        coupling: {
          tightly_coupled: find_tightly_coupled(enriched_result),
          loosely_coupled: find_loosely_coupled(enriched_result)
        },
        size: {
          largest_classes: find_largest_classes(enriched_result),
          longest_methods: find_longest_methods(enriched_result)
        }
      }
    end

    def build_issues_summary(enriched_result)
      {
        code_smells: enriched_result.respond_to?(:code_smells) ? enriched_result.code_smells : [],
        missing_references: enriched_result.respond_to?(:missing_references) ? enriched_result.missing_references : [],
        circular_dependencies: enriched_result.respond_to?(:circular_dependencies) ? enriched_result.circular_dependencies : [],
        high_complexity: find_high_complexity_items(enriched_result),
        low_cohesion: find_low_cohesion_classes(enriched_result)
      }
    end

    def build_patterns_summary(enriched_result)
      {
        design_patterns: enriched_result.respond_to?(:detected_patterns) ? enriched_result.detected_patterns : [],
        ruby_idioms: enriched_result.respond_to?(:ruby_idioms) ? enriched_result.ruby_idioms : [],
        rails_patterns: enriched_result.respond_to?(:rails_patterns) ? enriched_result.rails_patterns : []
      }
    end

    def format_location(location)
      return nil unless location
      {
        file: location.file,
        line: location.start_line,
        column: location.start_column
      }
    end

    def build_inheritance_tree(enriched_result)
      # Build a tree structure showing inheritance relationships
      tree = {}
      enriched_result.classes.each do |klass|
        tree[klass.fqname] = {
          parent: klass.superclass,
          children: enriched_result.classes
            .select { |c| c.respond_to?(:superclass) && c.superclass == klass.fqname }
            .map(&:fqname)
        }
      end
      tree
    end

    def build_dependency_graph(enriched_result)
      # Build dependency relationships
      graph = {}
      enriched_result.classes.each do |klass|
        dependencies = klass.respond_to?(:dependencies) ? klass.dependencies : []
        graph[klass.fqname] = {
          depends_on: dependencies,
          depended_by: enriched_result.classes
            .select { |c| c.respond_to?(:dependencies) && c.dependencies && c.dependencies.include?(klass.fqname) }
            .map(&:fqname)
        }
      end
      graph
    end

    def build_call_graph(enriched_result)
      # Build method call relationships
      return {} unless enriched_result.respond_to?(:method_calls) && enriched_result.method_calls

      enriched_result.method_calls.group_by { |call| call.respond_to?(:from) ? call.from : nil }.transform_values do |calls|
        calls.map { |call| call.respond_to?(:to) ? call.to : nil }.compact.uniq
      end.compact
    end

    def calculate_average_complexity(enriched_result)
      complexities = enriched_result.methods.map { |m| m.respond_to?(:cyclomatic_complexity) ? m.cyclomatic_complexity : nil }.compact
      return 0 if complexities.empty?
      (complexities.sum.to_f / complexities.size).round(2)
    end

    def find_highest_complexity(enriched_result)
      enriched_result.methods
        .select { |m| m.respond_to?(:cyclomatic_complexity) && m.cyclomatic_complexity && m.cyclomatic_complexity <= @config[:max_complexity_shown] }
        .max_by { |m| m.cyclomatic_complexity }
        &.then { |m| {method: "#{m.owner}##{m.name}", complexity: m.cyclomatic_complexity} }
    end

    def build_complexity_distribution(enriched_result)
      enriched_result.methods
        .select { |m| m.respond_to?(:complexity_category) }
        .group_by(&:complexity_category)
        .transform_values(&:count)
    end

    def find_tightly_coupled(enriched_result)
      enriched_result.classes
        .select { |c| c.respond_to?(:coupling_strength) && c.coupling_strength && c.coupling_strength > 0.7 }
        .map { |c| {class: c.fqname, coupling: c.coupling_strength} }
    end

    def find_loosely_coupled(enriched_result)
      enriched_result.classes
        .select { |c| c.respond_to?(:coupling_strength) && c.coupling_strength && c.coupling_strength < 0.3 }
        .map { |c| {class: c.fqname, coupling: c.coupling_strength} }
    end

    def find_largest_classes(enriched_result, limit = 5)
      enriched_result.classes
        .sort_by { |c| -c.methods.size }
        .take(limit)
        .map { |c| {class: c.fqname, method_count: c.methods.size} }
    end

    def find_longest_methods(enriched_result, limit = 5)
      enriched_result.methods
        .select { |m| m.respond_to?(:line_count) && m.line_count }
        .sort_by { |m| -m.line_count }
        .take(limit)
        .map { |m| {method: "#{m.owner}##{m.name}", lines: m.line_count} }
    end

    def find_high_complexity_items(enriched_result)
      enriched_result.methods
        .select { |m| m.respond_to?(:cyclomatic_complexity) && m.cyclomatic_complexity && m.cyclomatic_complexity > 10 }
        .map { |m| {method: "#{m.owner}##{m.name}", complexity: m.cyclomatic_complexity} }
    end

    def find_low_cohesion_classes(enriched_result)
      enriched_result.classes
        .select { |c| c.respond_to?(:cohesion_score) && c.cohesion_score && c.cohesion_score < 0.3 }
        .map { |c| {class: c.fqname, cohesion: c.cohesion_score} }
    end

    # Symbol-specific documentation builders
    def build_symbol_overview(symbol)
      {
        name: symbol.name,
        type: symbol.class.name.split("::").last.downcase,
        fqname: symbol.fqname,
        namespace: symbol.namespace_path.join("::"),
        location: format_location(symbol.location),
        documentation: symbol.respond_to?(:doc) ? symbol.doc : nil,
        rubymap: symbol.respond_to?(:rubymap) ? symbol.rubymap : nil
      }
    end

    def build_symbol_architecture(symbol)
      {
        inheritance: symbol.respond_to?(:superclass) ? symbol.superclass : nil,
        mixins: symbol.respond_to?(:mixins) ? symbol.mixins : [],
        namespace_path: symbol.namespace_path,
        file_path: symbol.location&.file
      }
    end

    def build_api_documentation(symbol)
      return {} unless symbol.respond_to?(:methods)

      {
        public_methods: document_methods(symbol.methods.select { |m| m.visibility == "public" }),
        protected_methods: document_methods(symbol.methods.select { |m| m.visibility == "protected" }),
        private_methods: @config[:include_private] ?
          document_methods(symbol.methods.select { |m| m.visibility == "private" }) : []
      }
    end

    def build_data_structures(symbol)
      {
        constants: symbol.respond_to?(:constants) ? symbol.constants : [],
        attributes: symbol.respond_to?(:attributes) ? symbol.attributes : [],
        class_variables: symbol.respond_to?(:class_variables) ? symbol.class_variables : []
      }
    end

    def build_symbol_relationships(symbol, enriched_result)
      {
        dependencies: symbol.respond_to?(:dependencies) ? symbol.dependencies : [],
        dependents: find_dependents(symbol, enriched_result),
        method_calls_made: find_method_calls_from(symbol, enriched_result),
        method_calls_received: find_method_calls_to(symbol, enriched_result)
      }
    end

    def build_symbol_metrics(symbol)
      {
        complexity: symbol.respond_to?(:total_complexity) ? symbol.total_complexity : nil,
        cohesion: symbol.respond_to?(:cohesion_score) ? symbol.cohesion_score : nil,
        coupling: {
          fan_in: symbol.respond_to?(:fan_in) ? symbol.fan_in : nil,
          fan_out: symbol.respond_to?(:fan_out) ? symbol.fan_out : nil
        },
        size: {
          method_count: symbol.respond_to?(:methods) ? symbol.methods.size : 0,
          loc: symbol.respond_to?(:line_count) ? symbol.line_count : nil
        }
      }
    end

    def build_symbol_issues(symbol)
      issues = []

      if symbol.respond_to?(:total_complexity) && symbol.total_complexity && symbol.total_complexity > 50
        issues << {type: :high_complexity, value: symbol.total_complexity}
      end

      if symbol.respond_to?(:cohesion_score) && symbol.cohesion_score < 0.3
        issues << {type: :low_cohesion, value: symbol.cohesion_score}
      end

      if symbol.respond_to?(:fan_out) && symbol.fan_out > 10
        issues << {type: :high_coupling, value: symbol.fan_out}
      end

      issues
    end

    def find_dependents(symbol, enriched_result)
      all_symbols = enriched_result.classes + enriched_result.modules
      all_symbols
        .select { |s| s.respond_to?(:dependencies) && s.dependencies && s.dependencies.include?(symbol.fqname) }
        .map(&:fqname)
    end

    def find_method_calls_from(symbol, enriched_result)
      return [] unless enriched_result.respond_to?(:method_calls) && enriched_result.method_calls

      enriched_result.method_calls
        .select { |call| call.respond_to?(:from) && call.from && call.from.start_with?(symbol.fqname) }
        .map { |call| call.respond_to?(:to) ? call.to : nil }
        .compact
        .uniq
    end

    def find_method_calls_to(symbol, enriched_result)
      return [] unless enriched_result.respond_to?(:method_calls) && enriched_result.method_calls

      enriched_result.method_calls
        .select { |call| call.respond_to?(:to) && call.to && call.to.start_with?(symbol.fqname) }
        .map { |call| call.respond_to?(:from) ? call.from : nil }
        .compact
        .uniq
    end
  end
end
