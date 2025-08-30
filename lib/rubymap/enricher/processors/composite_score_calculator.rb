# frozen_string_literal: true

require_relative "data_normalizer"

module Rubymap
  class Enricher
    module Processors
      # Calculates composite scores for classes including stability, complexity, and maintainability.
      # Separates score calculation logic for better testability and maintainability.
      class CompositeScoreCalculator
        # Weight constants for score calculations
        STABILITY_WEIGHTS = {
          age: 0.2,
          coverage: 0.3,
          churn: 0.3,
          documentation: 0.2
        }.freeze

        MAINTAINABILITY_WEIGHT = 1.0 / 3.0

        # Calculates stability score for a class.
        #
        # @param klass [Object] Class object with metrics
        # @return [Float] Stability score between 0.0 and 1.0
        def self.calculate_stability_score(klass)
          age_factor = DataNormalizer.normalize_age(klass.age_in_days || 0)
          coverage_factor = DataNormalizer.normalize_coverage(klass.test_coverage || 0)
          churn_factor = 1.0 - DataNormalizer.normalize_churn(klass.churn_score || 0)
          doc_factor = DataNormalizer.normalize_coverage(klass.documentation_coverage || 0)

          weighted_sum = (age_factor * STABILITY_WEIGHTS[:age]) +
                        (coverage_factor * STABILITY_WEIGHTS[:coverage]) +
                        (churn_factor * STABILITY_WEIGHTS[:churn]) +
                        (doc_factor * STABILITY_WEIGHTS[:documentation])
          
          weighted_sum.round(2)
        end

        # Calculates complexity score for a class.
        #
        # @param klass [Object] Class object with methods
        # @return [Float] Complexity score between 0.0 and 1.0
        def self.calculate_complexity_score(klass)
          return 0.0 unless klass.respond_to?(:methods)

          methods = klass.methods || []
          return 0.0 if methods.empty?

          total_complexity = methods.sum { |m| m.cyclomatic_complexity || 1 }
          avg_complexity = total_complexity.to_f / methods.size
          
          DataNormalizer.normalize_complexity(avg_complexity).round(2)
        end

        # Calculates maintainability score for a class.
        #
        # @param klass [Object] Class object with scores
        # @return [Float] Maintainability score between 0.0 and 1.0
        def self.calculate_maintainability_score(klass)
          stability = klass.stability_score || 0.0
          complexity = 1.0 - (klass.complexity_score || 0.0)
          coupling = 1.0 - DataNormalizer.normalize_coupling(klass.coupling_strength || 0.0)

          ((stability + complexity + coupling) * MAINTAINABILITY_WEIGHT).round(2)
        end

        # Calculates all composite scores for a class.
        #
        # @param klass [Object] Class object to score
        # @return [Hash] Hash with all calculated scores
        def self.calculate_all_scores(klass)
          klass.stability_score = calculate_stability_score(klass)
          klass.complexity_score = calculate_complexity_score(klass)
          klass.maintainability_score = calculate_maintainability_score(klass)
          
          {
            stability: klass.stability_score,
            complexity: klass.complexity_score,
            maintainability: klass.maintainability_score
          }
        end
      end
    end
  end
end