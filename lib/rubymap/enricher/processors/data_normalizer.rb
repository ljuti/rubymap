# frozen_string_literal: true

module Rubymap
  class Enricher
    module Processors
      # Provides data normalization utilities for enrichment calculations.
      # Centralizes all normalization logic to ensure consistency and testability.
      class DataNormalizer
        # Normalizes age in days to a 0.0-1.0 scale.
        # One year (365 days) maps to 1.0.
        #
        # @param days [Numeric] Age in days
        # @return [Float] Normalized age between 0.0 and 1.0
        def self.normalize_age(days)
          return 0.0 if days.nil? || days < 0

          (days / 365.0).clamp(0.0, 1.0)
        end

        # Normalizes churn score to a 0.0-1.0 scale.
        # Score of 100 maps to 1.0.
        #
        # @param score [Numeric] Churn score
        # @return [Float] Normalized churn between 0.0 and 1.0
        def self.normalize_churn(score)
          return 0.0 if score.nil? || score < 0

          (score / 100.0).clamp(0.0, 1.0)
        end

        # Normalizes coupling strength to a 0.0-1.0 scale.
        # Strength of 10 maps to 1.0.
        #
        # @param strength [Numeric] Coupling strength
        # @return [Float] Normalized coupling between 0.0 and 1.0
        def self.normalize_coupling(strength)
          return 0.0 if strength.nil? || strength < 0

          (strength / 10.0).clamp(0.0, 1.0)
        end

        # Normalizes coverage percentage to a 0.0-1.0 scale.
        #
        # @param coverage [Numeric] Coverage percentage (0-100)
        # @return [Float] Normalized coverage between 0.0 and 1.0
        def self.normalize_coverage(coverage)
          return 0.0 if coverage.nil? || coverage < 0

          (coverage / 100.0).clamp(0.0, 1.0)
        end

        # Categorizes coverage severity based on percentage.
        #
        # @param coverage [Numeric] Coverage percentage
        # @return [String] Severity level: "high", "medium", or "low"
        def self.coverage_severity(coverage)
          return "high" if coverage.nil?

          case coverage
          when 0...30 then "high"
          when 30...60 then "medium"
          else "low"
          end
        end

        # Normalizes complexity score to a 0.0-1.0 scale.
        # Complexity of 10 maps to 1.0.
        #
        # @param complexity [Numeric] Cyclomatic complexity
        # @return [Float] Normalized complexity between 0.0 and 1.0
        def self.normalize_complexity(complexity)
          return 0.0 if complexity.nil? || complexity < 0

          (complexity / 10.0).clamp(0.0, 1.0)
        end
      end
    end
  end
end
