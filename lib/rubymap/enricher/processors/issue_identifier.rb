# frozen_string_literal: true

require_relative "data_normalizer"

module Rubymap
  class Enricher
    module Processors
      # Identifies quality issues, design issues, and hotspots in the codebase.
      # Separates issue detection logic for better testability.
      class IssueIdentifier
        attr_reader :config

        def initialize(config = {})
          @config = default_config.merge(config)
        end

        # Identifies all types of issues in the result.
        #
        # @param result [EnrichmentResult] The result to analyze
        def identify_all_issues(result)
          identify_quality_issues(result)
          identify_design_issues(result)
          identify_hotspots(result)
        end

        # Identifies quality issues like low test coverage.
        #
        # @param result [EnrichmentResult] The result to analyze
        def identify_quality_issues(result)
          result.quality_issues ||= []

          result.methods.each do |method|
            next unless method.test_coverage
            next if method.test_coverage >= config[:coverage_threshold]

            result.quality_issues << QualityIssue.new(
              type: "low_test_coverage",
              severity: DataNormalizer.coverage_severity(method.test_coverage),
              location: "#{method.owner}##{method.name}",
              method: method.name,
              suggestion: "Add test coverage for this method"
            )
          end
        end

        # Identifies design issues like deep inheritance and large APIs.
        #
        # @param result [EnrichmentResult] The result to analyze
        def identify_design_issues(result)
          result.design_issues ||= []

          result.classes.each do |klass|
            check_inheritance_depth(klass, result)
            check_api_surface(klass, result)
          end
        end

        # Identifies hotspots like high churn areas.
        #
        # @param result [EnrichmentResult] The result to analyze
        def identify_hotspots(result)
          result.hotspots ||= []
          result.coupling_hotspots ||= []

          result.classes.each do |klass|
            check_churn_hotspot(klass, result)
          end
        end

        private

        def default_config
          {
            coverage_threshold: 80,
            inheritance_depth_threshold: 4,
            api_size_threshold: 5,
            churn_threshold: 10
          }
        end

        def check_inheritance_depth(klass, result)
          return unless klass.inheritance_depth
          return if klass.inheritance_depth <= config[:inheritance_depth_threshold]

          result.design_issues << DesignIssue.new(
            type: "deep_inheritance",
            severity: "warning",
            class: klass.name,
            depth: klass.inheritance_depth,
            suggestion: "Consider composition over inheritance"
          )
        end

        def check_api_surface(klass, result)
          return unless klass.public_api_surface
          return if klass.public_api_surface < config[:api_size_threshold]

          result.design_issues << DesignIssue.new(
            type: "large_public_api",
            severity: "warning",
            class: klass.name,
            api_size: klass.public_api_surface,
            suggestion: "Consider splitting responsibilities"
          )
        end

        def check_churn_hotspot(klass, result)
          return unless klass.churn_score
          return if klass.churn_score <= config[:churn_threshold]

          result.hotspots << Hotspot.new(
            type: "high_churn",
            class: klass.name,
            score: klass.churn_score,
            commits: klass.git_commits
          )
        end
      end
    end
  end
end