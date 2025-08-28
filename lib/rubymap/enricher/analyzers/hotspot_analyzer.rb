# frozen_string_literal: true

require_relative "base_analyzer"

module Rubymap
  class Enricher
    module Analyzers
      # Identifies hotspots and problem areas in the codebase
      class HotspotAnalyzer < BaseAnalyzer
        HOTSPOT_THRESHOLDS = {
          high_complexity: 10,
          high_churn: 5,
          high_coupling: 8,
          low_coverage: 30,
          high_loc: 200,
          too_many_dependencies: 10
        }.freeze

        def analyze(result, config)
          result.hotspots ||= []
          result.problem_areas ||= []

          # Analyze classes for hotspots
          result.classes.each do |klass|
            analyze_class_hotspots(klass, result)
          end

          # Analyze methods for hotspots
          result.methods.each do |method|
            analyze_method_hotspots(method, result)
          end

          # Identify top problem areas
          identify_top_problems(result)
        end

        private

        def analyze_class_hotspots(klass, result)
          hotspot_indicators = []

          # Check for high complexity
          if klass.total_complexity && klass.total_complexity > HOTSPOT_THRESHOLDS[:high_complexity]
            hotspot_indicators << {
              type: "high_complexity",
              value: klass.total_complexity,
              threshold: HOTSPOT_THRESHOLDS[:high_complexity],
              severity: calculate_severity(klass.total_complexity, HOTSPOT_THRESHOLDS[:high_complexity])
            }
          end

          # Check for high churn
          if klass.churn_score && klass.churn_score > HOTSPOT_THRESHOLDS[:high_churn]
            hotspot_indicators << {
              type: "high_churn",
              value: klass.churn_score,
              threshold: HOTSPOT_THRESHOLDS[:high_churn],
              severity: calculate_severity(klass.churn_score, HOTSPOT_THRESHOLDS[:high_churn])
            }
          end

          # Check for high coupling
          fan_out = klass.dependencies&.size || 0
          if fan_out > HOTSPOT_THRESHOLDS[:high_coupling]
            hotspot_indicators << {
              type: "high_coupling",
              value: fan_out,
              threshold: HOTSPOT_THRESHOLDS[:high_coupling],
              severity: calculate_severity(fan_out, HOTSPOT_THRESHOLDS[:high_coupling])
            }
          end

          # Check for low test coverage
          if klass.test_coverage && klass.test_coverage < HOTSPOT_THRESHOLDS[:low_coverage]
            hotspot_indicators << {
              type: "low_coverage",
              value: klass.test_coverage,
              threshold: HOTSPOT_THRESHOLDS[:low_coverage],
              severity: calculate_severity(HOTSPOT_THRESHOLDS[:low_coverage] - klass.test_coverage, HOTSPOT_THRESHOLDS[:low_coverage])
            }
          end

          # Check for high LOC
          loc = klass.metrics&.[](:loc) || 0
          if loc > HOTSPOT_THRESHOLDS[:high_loc]
            hotspot_indicators << {
              type: "high_loc",
              value: loc,
              threshold: HOTSPOT_THRESHOLDS[:high_loc],
              severity: calculate_severity(loc, HOTSPOT_THRESHOLDS[:high_loc])
            }
          end

          if hotspot_indicators.any?
            hotspot = Hotspot.new(
              type: "class",
              name: klass.name,
              indicators: hotspot_indicators,
              risk_score: calculate_risk_score(hotspot_indicators),
              recommendations: generate_recommendations(hotspot_indicators)
            )

            result.hotspots << hotspot

            # Add to problem areas if high risk
            if hotspot.risk_score > 0.7
              result.problem_areas << {
                type: "high_risk_class",
                class: klass.name,
                risk_score: hotspot.risk_score,
                primary_issues: hotspot_indicators.map { |i| i[:type] }
              }
            end
          end
        end

        def analyze_method_hotspots(method, result)
          hotspot_indicators = []

          # Check for high complexity
          if method.complexity && method.complexity > HOTSPOT_THRESHOLDS[:high_complexity]
            hotspot_indicators << {
              type: "high_complexity",
              value: method.complexity,
              threshold: HOTSPOT_THRESHOLDS[:high_complexity],
              severity: calculate_severity(method.complexity, HOTSPOT_THRESHOLDS[:high_complexity])
            }
          end

          # Check for too many dependencies
          dep_count = method.dependencies&.size || 0
          if dep_count > HOTSPOT_THRESHOLDS[:too_many_dependencies]
            hotspot_indicators << {
              type: "too_many_dependencies",
              value: dep_count,
              threshold: HOTSPOT_THRESHOLDS[:too_many_dependencies],
              severity: calculate_severity(dep_count, HOTSPOT_THRESHOLDS[:too_many_dependencies])
            }
          end

          # Check for low coverage in complex methods
          if method.complexity && method.complexity > 5 && method.test_coverage && method.test_coverage < 50
            hotspot_indicators << {
              type: "complex_untested",
              value: method.test_coverage,
              threshold: 50,
              severity: "high"
            }
          end

          if hotspot_indicators.any?
            hotspot = Hotspot.new(
              type: "method",
              name: "#{method.owner}##{method.name}",
              indicators: hotspot_indicators,
              risk_score: calculate_risk_score(hotspot_indicators),
              recommendations: generate_recommendations(hotspot_indicators)
            )

            result.hotspots << hotspot
          end
        end

        def identify_top_problems(result)
          # Sort hotspots by risk score
          critical_hotspots = result.hotspots.select { |h| h.risk_score > 0.8 }

          critical_hotspots.each do |hotspot|
            problem = {
              type: "critical_hotspot",
              name: hotspot.name,
              risk_score: hotspot.risk_score,
              immediate_action_required: true,
              recommendations: hotspot.recommendations
            }

            result.problem_areas << problem unless result.problem_areas.any? { |p| p[:name] == hotspot.name }
          end
        end

        def calculate_severity(value, threshold)
          ratio = value.to_f / threshold
          case ratio
          when 0..1.5
            "low"
          when 1.5..2.0
            "medium"
          when 2.0..3.0
            "high"
          else
            "critical"
          end
        end

        def calculate_risk_score(indicators)
          return 0.0 if indicators.empty?

          # Weight different indicator types
          weights = {
            "high_complexity" => 0.25,
            "high_churn" => 0.20,
            "high_coupling" => 0.20,
            "low_coverage" => 0.15,
            "high_loc" => 0.10,
            "too_many_dependencies" => 0.10,
            "complex_untested" => 0.30
          }

          weighted_score = 0.0
          total_weight = 0.0

          indicators.each do |indicator|
            weight = weights[indicator[:type]] || 0.1
            severity_score = case indicator[:severity]
            when "critical"
              1.0
            when "high"
              0.8
            when "medium"
              0.5
            when "low"
              0.3
            else
              0.5
            end

            weighted_score += severity_score * weight
            total_weight += weight
          end

          (weighted_score / total_weight).round(2)
        end

        def generate_recommendations(indicators)
          recommendations = []

          indicators.each do |indicator|
            case indicator[:type]
            when "high_complexity"
              recommendations << "Consider breaking down complex logic into smaller methods"
              recommendations << "Extract complex conditions into well-named methods"
            when "high_churn"
              recommendations << "Stabilize frequently changed code with better abstractions"
              recommendations << "Add comprehensive tests before making further changes"
            when "high_coupling"
              recommendations << "Reduce dependencies through dependency injection"
              recommendations << "Consider using interfaces or abstractions"
            when "low_coverage"
              recommendations << "Add unit tests to improve coverage"
              recommendations << "Focus on testing critical paths first"
            when "high_loc"
              recommendations << "Split large classes into smaller, focused components"
              recommendations << "Apply Single Responsibility Principle"
            when "too_many_dependencies"
              recommendations << "Reduce the number of direct dependencies"
              recommendations << "Consider using a facade or mediator pattern"
            when "complex_untested"
              recommendations << "Critical: Add tests for complex logic immediately"
              recommendations << "Complex untested code is a major risk"
            end
          end

          recommendations.uniq
        end
      end
    end
  end
end
