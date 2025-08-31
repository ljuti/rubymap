# frozen_string_literal: true

require_relative "enricher/enricher_registry"
require_relative "enricher/enrichment_result"
require_relative "enricher/converters/converter_factory"
require_relative "enricher/factories/component_factory"
require_relative "enricher/pipeline/enrichment_pipeline"
require_relative "enricher/pipeline/metrics_stage"
require_relative "enricher/pipeline/analysis_stage"
require_relative "enricher/pipeline/rails_stage"
require_relative "enricher/pipeline/scoring_stage"
require_relative "enricher/pipeline/issue_identification_stage"
require_relative "enricher/processors/data_normalizer"
require_relative "enricher/processors/composite_score_calculator"
require_relative "enricher/processors/issue_identifier"
require_relative "enricher/detectors/rails_detector"

module Rubymap
  # Enriches normalized code data with metrics, patterns, and quality insights.
  #
  # This refactored version uses a pipeline architecture with separated concerns:
  # - Pipeline stages handle different aspects of enrichment
  # - Processors handle specific calculations and identifications
  # - Factories manage component creation
  # - Detectors identify project characteristics
  #
  # @rubymap Adds metrics, patterns, and quality insights to normalized data
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
  class Enricher
    attr_reader :config, :registry, :component_factory, :pipeline

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
    # @option config [Integer] :churn_threshold (10) Threshold for churn warnings
    # @option config [Integer] :coverage_threshold (80) Threshold for coverage warnings
    def initialize(config = {})
      @config = default_config.merge(config || {})
      @registry = EnricherRegistry.new
      @component_factory = Factories::ComponentFactory.new(registry, @config)
      setup_pipeline
    end

    # Enriches normalized data with metrics and insights.
    #
    # @param normalized_data [NormalizedResult, Hash] Normalized symbol data
    # @return [EnrichmentResult] Enriched data with metrics and insights
    def enrich(normalized_data)
      # Convert to proper input format if needed
      input = ensure_normalized_result(normalized_data)

      # Execute the enrichment pipeline
      pipeline.execute(EnrichmentResult.from_normalized(input))
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

    def setup_pipeline
      # Create components
      metrics = component_factory.create_metrics
      analyzers = component_factory.create_analyzers
      rails_enrichers = component_factory.create_rails_enrichers

      # Build pipeline with configured stages
      # Skip default pipeline since we're building a custom one
      @pipeline = Pipeline::EnrichmentPipeline.new(config.merge(skip_default_pipeline: true))

      # Add stages with their components
      pipeline.add_stage(Pipeline::MetricsStage, metrics: metrics) if config.fetch(:enable_metrics)
      pipeline.add_stage(Pipeline::AnalysisStage, analyzers: analyzers) if config.fetch(:enable_patterns)
      pipeline.add_stage(Pipeline::RailsStage, rails_enrichers: rails_enrichers) if config.fetch(:enable_rails)
      pipeline.add_stage(Pipeline::ScoringStage)
      pipeline.add_stage(Pipeline::IssueIdentificationStage)
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

    # Converts entities of a specific type using the appropriate converter.
    def convert_entities(entities, type)
      Converters::ConverterFactory.create_converter(type).convert(entities)
    end
  end
end
