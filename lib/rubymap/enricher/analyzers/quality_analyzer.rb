# frozen_string_literal: true

require_relative "base_analyzer"
require_relative "../quality_rules_engine"

module Rubymap
  class Enricher
    module Analyzers
      # Analyzes overall code quality indicators using external rules
      class QualityAnalyzer < BaseAnalyzer
        attr_reader :rules_engine

        def initialize(rules_path = nil)
          @rules_engine = QualityRulesEngine.new(rules_path)
        end

        def analyze(result, config)
          result.quality_issues ||= []
          result.quality_metrics = QualityMetrics.new

          # Analyze method quality
          analyze_methods_quality(result.methods, result) if result.methods

          # Analyze class quality
          analyze_classes_quality(result.classes, result) if result.classes

          # Calculate overall quality score
          calculate_overall_quality(result)
        end

        private

        def analyze_methods_quality(methods, result)
          methods.each do |method|
            issues = rules_engine.apply_method_rules(method)
            
            if issues.any?
              result.quality_issues << QualityIssue.new(
                type: "method",
                name: format_method_name(method),
                issues: issues,
                quality_score: rules_engine.calculate_method_score(method, issues)
              )
            end

            # Add to method metadata
            method.quality_score = rules_engine.calculate_method_score(method, issues)
            method.has_quality_issues = issues.any?
          end
        end

        def analyze_classes_quality(classes, result)
          classes.each do |klass|
            issues = rules_engine.apply_class_rules(klass)
            
            if issues.any?
              result.quality_issues << QualityIssue.new(
                type: "class",
                name: klass.name,
                issues: issues,
                quality_score: rules_engine.calculate_class_score(klass, issues)
              )
            end

            # Add to class metadata
            klass.quality_score = rules_engine.calculate_class_score(klass, issues)
          end
        end

        def calculate_overall_quality(result)
          scores = collect_quality_scores(result)
          
          if scores.any?
            overall_score = (scores.sum / scores.size).round(2)
            result.quality_metrics.overall_score = overall_score
            result.quality_metrics.quality_level = rules_engine.quality_level(overall_score)
          end

          # Count issues by severity
          result.quality_metrics.issues_by_severity = count_issues_by_severity(result)
        end

        def format_method_name(method)
          if method.owner
            "#{method.owner}##{method.name}"
          else
            method.name.to_s
          end
        end

        def collect_quality_scores(result)
          scores = []
          
          result.methods&.each do |method|
            scores << method.quality_score if method.quality_score
          end
          
          result.classes&.each do |klass|
            scores << klass.quality_score if klass.quality_score
          end
          
          scores
        end

        def count_issues_by_severity(result)
          severities = {
            critical: 0,
            high: 0,
            medium: 0,
            low: 0
          }
          
          result.quality_issues.each do |quality_issue|
            quality_issue.issues.each do |issue|
              severity = issue[:severity]
              next unless severity
              severity = severity.to_sym
              severities[severity] = (severities[severity] || 0) + 1
            end
          end
          
          severities
        end
      end

      # Value objects for quality analysis results
      class QualityMetrics
        attr_accessor :overall_score, :quality_level, :issues_by_severity

        def initialize
          @overall_score = 0.0
          @quality_level = "unknown"
          @issues_by_severity = {}
        end

        def to_h
          {
            overall_score: overall_score,
            quality_level: quality_level,
            issues_by_severity: issues_by_severity
          }
        end
      end

      class QualityIssue
        attr_accessor :type, :name, :issues, :quality_score

        def initialize(type:, name:, issues: [], quality_score: 1.0)
          @type = type
          @name = name
          @issues = issues
          @quality_score = quality_score
        end

        def to_h
          {
            type: type,
            name: name,
            issues: issues,
            quality_score: quality_score
          }
        end
      end
    end
  end
end