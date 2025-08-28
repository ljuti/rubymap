# frozen_string_literal: true

require_relative "metrics/complexity_metric"
require_relative "metrics/dependency_metric"
require_relative "metrics/inheritance_metric"
require_relative "metrics/api_surface_metric"
require_relative "metrics/coverage_metric"
require_relative "metrics/churn_metric"
require_relative "metrics/stability_metric"

require_relative "analyzers/pattern_detector"
require_relative "analyzers/idiom_detector"
require_relative "analyzers/hotspot_analyzer"
require_relative "analyzers/quality_analyzer"

require_relative "rails/model_enricher"
require_relative "rails/controller_enricher"

module Rubymap
  class Enricher
    # Registry for managing enricher components via dependency injection
    class EnricherRegistry
      def initialize
        @metrics = {}
        @analyzers = {}
        @rails_enrichers = {}

        register_default_components
      end

      # Register a metric calculator
      def register_metric(name, metric)
        @metrics[name] = metric
      end

      # Register an analyzer
      def register_analyzer(name, analyzer)
        @analyzers[name] = analyzer
      end

      # Register a Rails-specific enricher
      def register_rails_enricher(name, enricher)
        @rails_enrichers[name] = enricher
      end

      # Get a registered metric
      def get_metric(name)
        @metrics[name]
      end

      # Get a registered analyzer
      def get_analyzer(name)
        @analyzers[name]
      end

      # Get a registered Rails enricher
      def get_rails_enricher(name)
        @rails_enrichers[name]
      end

      private

      def register_default_components
        register_default_metrics
        register_default_analyzers
        register_default_rails_enrichers
      end

      def register_default_metrics
        register_metric(:complexity, Metrics::ComplexityMetric.new)
        register_metric(:dependency, Metrics::DependencyMetric.new)
        register_metric(:inheritance, Metrics::InheritanceMetric.new)
        register_metric(:api_surface, Metrics::ApiSurfaceMetric.new)
        register_metric(:coverage, Metrics::CoverageMetric.new)
        register_metric(:churn, Metrics::ChurnMetric.new)
        register_metric(:stability, Metrics::StabilityMetric.new)
      end

      def register_default_analyzers
        register_analyzer(:pattern_detector, Analyzers::PatternDetector.new)
        register_analyzer(:idiom_detector, Analyzers::IdiomDetector.new)
        register_analyzer(:hotspot_analyzer, Analyzers::HotspotAnalyzer.new)
        register_analyzer(:quality_analyzer, Analyzers::QualityAnalyzer.new)
      end

      def register_default_rails_enrichers
        register_rails_enricher(:model, Rails::ModelEnricher.new)
        register_rails_enricher(:controller, Rails::ControllerEnricher.new)
      end
    end
  end
end
