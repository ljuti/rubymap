# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates composite stability scores
      class StabilityMetric < BaseMetric
        def calculate(result, config)
          # Calculate stability for classes
          result.classes.each do |klass|
            # Stability score is calculated in main Enricher
            # but we can identify stable/unstable classes here
            categorize_stability(klass, result.stability_analysis)
          end
        end

        private

        def categorize_stability(klass, stability_analysis)
          return unless stability_analysis

          score = klass.stability_score || calculate_simple_stability(klass)

          if score >= 0.7
            stability_analysis.stable_classes << klass.name
          elsif score <= 0.4
            stability_analysis.unstable_classes << klass.name
          end

          stability_analysis.stability_scores[klass.name] = score
        end

        def calculate_simple_stability(klass)
          # Simple fallback calculation if not done elsewhere
          factors = []

          # Age factor
          if klass.age_in_days
            age_score = normalize(klass.age_in_days, 365)
            factors << age_score
          end

          # Coverage factor
          if klass.test_coverage
            coverage_score = klass.test_coverage / 100.0
            factors << coverage_score
          end

          # Churn factor (inverted - less churn = more stable)
          if klass.churn_score
            churn_score = 1.0 - normalize(klass.churn_score, 10)
            factors << churn_score
          end

          # Documentation factor
          if klass.documentation_coverage
            doc_score = klass.documentation_coverage / 100.0
            factors << doc_score
          end

          return 0.5 if factors.empty?

          (factors.sum / factors.size).round(2)
        end
      end
    end
  end
end
