# frozen_string_literal: true

module Rubymap
  class Enricher
    module Factories
      # Factory for creating enricher components.
      # Centralizes component creation and dependency injection.
      class ComponentFactory
        attr_reader :registry, :config

        def initialize(registry, config = {})
          @registry = registry
          @config = config
        end

        # Creates metrics components.
        #
        # @return [Array<BaseMetric>] Array of metric calculators
        def create_metrics
          [
            registry.get_metric(:complexity),
            registry.get_metric(:dependency),
            registry.get_metric(:inheritance),
            registry.get_metric(:api_surface),
            registry.get_metric(:coverage),
            registry.get_metric(:churn),
            registry.get_metric(:stability)
          ].compact
        end

        # Creates analyzer components.
        #
        # @return [Array<BaseAnalyzer>] Array of analyzers
        def create_analyzers
          [
            registry.get_analyzer(:pattern_detector),
            registry.get_analyzer(:idiom_detector),
            registry.get_analyzer(:hotspot_analyzer),
            registry.get_analyzer(:quality_analyzer)
          ].compact
        end

        # Creates Rails enricher components.
        #
        # @return [Array<BaseEnricher>] Array of Rails enrichers
        def create_rails_enrichers
          [
            registry.get_rails_enricher(:model),
            registry.get_rails_enricher(:controller),
            registry.get_rails_enricher(:route)
          ].compact
        end

        # Creates the issue identifier.
        #
        # @return [IssueIdentifier] Issue identifier instance
        def create_issue_identifier
          Processors::IssueIdentifier.new(config)
        end

        # Creates the score calculator.
        #
        # @return [CompositeScoreCalculator] Score calculator instance
        def create_score_calculator
          Processors::CompositeScoreCalculator
        end

        # Creates the enrichment pipeline.
        #
        # @return [EnrichmentPipeline] Pipeline instance
        def create_pipeline
          Pipeline::EnrichmentPipeline.new(config)
        end
      end
    end
  end
end