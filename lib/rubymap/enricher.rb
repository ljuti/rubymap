# frozen_string_literal: true

require_relative "enricher/enricher_registry"
require_relative "enricher/enrichment_result"
require_relative "enricher/converters/converter_factory"

module Rubymap
  # Enriches normalized code data with metrics, patterns, and quality insights.
  #
  # The Enricher analyzes normalized symbols to calculate complexity metrics,
  # detect design patterns, identify code smells, and provide quality assessments.
  # It adds valuable metadata for understanding code health, maintainability,
  # and architectural patterns.
  #
  # @example Basic enrichment
  #   normalizer = Rubymap::Normalizer.new
  #   normalized = normalizer.normalize(extracted_data)
  #
  #   enricher = Rubymap::Enricher.new
  #   enriched = enricher.enrich(normalized)
  #
  #   # Access calculated metrics
  #   user_class = enriched.classes.find { |c| c.name == "User" }
  #   user_class.complexity_score  # => 4.5
  #   user_class.test_coverage     # => 85.0
  #   user_class.api_surface       # => 12
  #
  # @example Pattern detection
  #   enriched = enricher.enrich(normalized)
  #
  #   # Detected design patterns
  #   enriched.detected_patterns   # => ["Singleton", "Observer", "Factory"]
  #
  #   # Ruby idioms
  #   enriched.detected_idioms     # => ["duck_typing", "enumerable_usage"]
  #
  # @example Quality analysis
  #   enriched = enricher.enrich(normalized)
  #
  #   # Code quality issues
  #   enriched.quality_issues      # => Large classes, deep inheritance, high coupling
  #   enriched.coupling_hotspots   # => Classes with high fan-out
  #   enriched.complexity_hotspots # => Methods with high cyclomatic complexity
  #
  class Enricher
    # Creates a new Enricher instance.
    #
    # @param config [Hash] Configuration options
    # @option config [Boolean] :enable_metrics (true) Calculate complexity metrics
    # @option config [Boolean] :enable_patterns (true) Detect design patterns
    # @option config [Boolean] :enable_rails (true) Apply Rails-specific enrichment
    # @option config [Integer] :complexity_threshold (10) Threshold for complexity warnings
    # @option config [Integer] :api_size_threshold (5) Threshold for public API size
    # @option config [Integer] :inheritance_depth_threshold (4) Max inheritance depth
    # @option config [Integer] :fan_out_threshold (3) Max dependencies before warning
    #
    # @example Custom thresholds
    #   enricher = Rubymap::Enricher.new(
    #     complexity_threshold: 15,
    #     fan_out_threshold: 5
    #   )
    def initialize(config = {})
      @config = default_config.merge(config)
      @registry = EnricherRegistry.new
      setup_components
    end

    # Enriches normalized data with metrics and insights.
    #
    # Applies multiple analysis passes:
    # 1. Calculates code metrics (complexity, coupling, cohesion)
    # 2. Detects design patterns and idioms
    # 3. Identifies quality issues and hotspots
    # 4. Applies framework-specific analysis (Rails, Sinatra, etc.)
    # 5. Calculates composite quality scores
    #
    # @param normalized_data [NormalizedResult, Hash] Normalized symbol data
    # @return [EnrichmentResult] Enriched data with metrics and insights
    #
    # @example
    #   enriched = enricher.enrich(normalized_data)
    #
    #   enriched.total_complexity      # => 245.5
    #   enriched.average_complexity    # => 3.2
    #   enriched.maintainability_score # => 72.5
    #   enriched.test_coverage         # => 82.3
    def enrich(normalized_data)
      # Convert to proper input format if needed
      input = ensure_normalized_result(normalized_data)

      # Create enriched result from normalized data
      result = EnrichmentResult.from_normalized(input)

      # Apply metrics calculation
      apply_metrics(result)

      # Apply pattern detection
      apply_analyzers(result)

      # Apply Rails-specific enrichment if applicable
      apply_rails_enrichment(result) if rails_project?(result)

      # Calculate composite scores
      calculate_composite_scores(result)

      # Identify issues and hotspots
      identify_issues(result)

      result
    end

    private

    def default_config
      {
        enable_metrics: true,
        enable_patterns: true,
        enable_rails: true,
        complexity_threshold: 10,
        api_size_threshold: 5,
        inheritance_depth_threshold: 4,
        fan_out_threshold: 3,
        churn_threshold: 10,
        coverage_threshold: 80
      }
    end

    def setup_components
      setup_metrics
      setup_analyzers
      setup_rails_enrichers
    end

    def setup_metrics
      @metrics = [
        @registry.get_metric(:complexity),
        @registry.get_metric(:dependency),
        @registry.get_metric(:inheritance),
        @registry.get_metric(:api_surface),
        @registry.get_metric(:coverage),
        @registry.get_metric(:churn),
        @registry.get_metric(:stability)
      ].compact
    end

    def setup_analyzers
      @analyzers = [
        @registry.get_analyzer(:pattern_detector),
        @registry.get_analyzer(:idiom_detector),
        @registry.get_analyzer(:hotspot_analyzer),
        @registry.get_analyzer(:quality_analyzer)
      ].compact
    end

    def setup_rails_enrichers
      @rails_enrichers = [
        @registry.get_rails_enricher(:model),
        @registry.get_rails_enricher(:controller),
        @registry.get_rails_enricher(:route)
      ].compact
    end

    def ensure_normalized_result(data)
      case data
      when Normalizer::NormalizedResult
        data
      when Hash
        convert_hash_to_normalized_result(data)
      else
        raise ArgumentError, "Expected NormalizedResult or Hash, got #{data.class}"
      end
    end

    # Converts hash data to NormalizedResult using converter factory pattern.
    #
    # This method has been refactored to use the Strategy and Factory patterns,
    # delegating entity-specific conversion logic to specialized converter classes.
    # This improves maintainability, testability, and follows SOLID principles.
    #
    # @param hash [Hash] Hash data to convert
    # @return [NormalizedResult] Converted normalized result
    def convert_hash_to_normalized_result(hash)
      result = Normalizer::NormalizedResult.new

      # Convert each entity type using appropriate converter
      result.classes = convert_entities(hash[:classes], :classes)
      result.modules = convert_entities(hash[:modules], :modules)
      result.methods = convert_entities(hash[:methods], :methods)
      
      # Method calls don't need conversion (simple array)
      result.method_calls = hash[:method_calls] || []
      
      result
    end

    private

    # Converts entities of a specific type using the appropriate converter.
    #
    # @param entities [Array] Array of entity hashes to convert
    # @param type [Symbol] Entity type (:classes, :modules, :methods)
    # @return [Array] Array of converted normalized entities
    def convert_entities(entities, type)
      return [] unless entities

      converter = Converters::ConverterFactory.create_converter(type)
      converter.convert(entities)
    end

    def apply_metrics(result)
      return unless @config[:enable_metrics]

      @metrics.each do |metric|
        metric.calculate(result, @config)
      end
    end

    def apply_analyzers(result)
      return unless @config[:enable_patterns]

      @analyzers.each do |analyzer|
        analyzer.analyze(result, @config)
      end
    end

    def apply_rails_enrichment(result)
      return unless @config[:enable_rails]

      @rails_enrichers.each do |enricher|
        enricher.enrich(result, @config)
      end
    end

    def calculate_composite_scores(result)
      result.classes.each do |klass|
        klass.stability_score = calculate_stability_score(klass)
        klass.complexity_score = calculate_complexity_score(klass)
        klass.maintainability_score = calculate_maintainability_score(klass)
      end
    end

    def calculate_stability_score(klass)
      age_factor = normalize_age(klass.age_in_days || 0)
      coverage_factor = (klass.test_coverage || 0) / 100.0
      churn_factor = 1.0 - normalize_churn(klass.churn_score || 0)
      doc_factor = (klass.documentation_coverage || 0) / 100.0

      (age_factor * 0.2 + coverage_factor * 0.3 + churn_factor * 0.3 + doc_factor * 0.2).round(2)
    end

    def calculate_complexity_score(klass)
      return 0.0 unless klass.respond_to?(:metrics)

      methods = klass.methods || []
      return 0.0 if methods.empty?

      avg_complexity = methods.sum { |m| m.cyclomatic_complexity || 1 } / methods.size.to_f
      (avg_complexity / 10.0).clamp(0.0, 1.0).round(2)
    end

    def calculate_maintainability_score(klass)
      stability = klass.stability_score || 0
      complexity = 1.0 - (klass.complexity_score || 0)
      coupling = 1.0 - normalize_coupling(klass.coupling_strength || 0)

      ((stability + complexity + coupling) / 3.0).round(2)
    end

    def identify_issues(result)
      identify_quality_issues(result)
      identify_design_issues(result)
      identify_hotspots(result)
    end

    def identify_quality_issues(result)
      result.quality_issues ||= []

      # Low test coverage
      result.methods.each do |method|
        if method.test_coverage && method.test_coverage < @config[:coverage_threshold]
          result.quality_issues << QualityIssue.new(
            type: "low_test_coverage",
            severity: coverage_severity(method.test_coverage),
            location: "#{method.owner}##{method.name}",
            method: method.name,
            suggestion: "Add test coverage for this method"
          )
        end
      end
    end

    def identify_design_issues(result)
      result.design_issues ||= []

      # Deep inheritance
      result.classes.each do |klass|
        if klass.inheritance_depth && klass.inheritance_depth > @config[:inheritance_depth_threshold]
          result.design_issues << DesignIssue.new(
            type: "deep_inheritance",
            severity: "warning",
            class: klass.name,
            depth: klass.inheritance_depth,
            suggestion: "Consider composition over inheritance"
          )
        end

        # Large public API
        if klass.public_api_surface && klass.public_api_surface >= @config[:api_size_threshold]
          result.design_issues << DesignIssue.new(
            type: "large_public_api",
            severity: "warning",
            class: klass.name,
            api_size: klass.public_api_surface,
            suggestion: "Consider splitting responsibilities"
          )
        end
      end
    end

    def identify_hotspots(result)
      result.hotspots ||= []
      result.coupling_hotspots ||= []

      # High churn hotspots
      result.classes.each do |klass|
        if klass.churn_score && klass.churn_score > @config[:churn_threshold]
          result.hotspots << Hotspot.new(
            type: "high_churn",
            class: klass.name,
            score: klass.churn_score,
            commits: klass.git_commits
          )
        end

        # High coupling hotspots - handled by dependency_metric
        # Removed to avoid duplication
      end
    end

    def rails_project?(result)
      result.classes.any? { |c| c.superclass&.include?("ApplicationRecord") || c.superclass&.include?("ApplicationController") }
    end

    def coverage_severity(coverage)
      case coverage
      when 0...30 then "high"
      when 30...60 then "medium"
      else "low"
      end
    end

    def normalize_age(days)
      (days / 365.0).clamp(0.0, 1.0)
    end

    def normalize_churn(score)
      (score / 100.0).clamp(0.0, 1.0)
    end

    def normalize_coupling(strength)
      (strength / 10.0).clamp(0.0, 1.0)
    end
  end
end
