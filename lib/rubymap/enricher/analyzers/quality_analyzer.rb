# frozen_string_literal: true

require_relative "base_analyzer"

module Rubymap
  class Enricher
    module Analyzers
      # Analyzes overall code quality indicators
      class QualityAnalyzer < BaseAnalyzer
        QUALITY_THRESHOLDS = {
          method_length: 20,
          parameter_count: 4,
          return_statements: 3,
          nesting_depth: 3,
          abc_score: 15,
          coupling_threshold: 5
        }.freeze

        def analyze(result, config)
          result.quality_issues ||= []
          result.quality_metrics ||= QualityMetrics.new

          # Analyze method quality
          analyze_methods_quality(result.methods, result)

          # Analyze class quality
          analyze_classes_quality(result.classes, result)

          # Calculate overall quality score
          calculate_overall_quality(result)
        end

        private

        def analyze_methods_quality(methods, result)
          methods.each do |method|
            issues = []

            # Check method length
            if method.line_count && method.line_count > QUALITY_THRESHOLDS[:method_length]
              issues << {
                type: "long_method",
                severity: calculate_length_severity(method.line_count),
                message: "Method is #{method.line_count} lines (threshold: #{QUALITY_THRESHOLDS[:method_length]})",
                suggestion: "Consider extracting logic into smaller methods"
              }
            end

            # Check parameter count
            param_count = method.parameters&.size || 0
            if param_count > QUALITY_THRESHOLDS[:parameter_count]
              issues << {
                type: "too_many_parameters",
                severity: "medium",
                message: "Method has #{param_count} parameters (threshold: #{QUALITY_THRESHOLDS[:parameter_count]})",
                suggestion: "Consider using a parameter object or configuration hash"
              }
            end

            # Check for code smells
            detect_code_smells(method, issues)

            # Check naming conventions
            check_naming_conventions(method, issues)

            if issues.any?
              result.quality_issues << QualityIssue.new(
                type: "method",
                name: "#{method.owner}##{method.name}",
                issues: issues,
                quality_score: calculate_method_quality_score(method, issues)
              )
            end

            # Add to method metadata
            method.quality_score = calculate_method_quality_score(method, issues)
            method.has_quality_issues = issues.any?
          end
        end

        def analyze_classes_quality(classes, result)
          classes.each do |klass|
            issues = []

            # Check class cohesion
            cohesion = calculate_cohesion(klass)
            if cohesion < 0.5
              issues << {
                type: "low_cohesion",
                severity: "medium",
                message: "Class has low cohesion (#{(cohesion * 100).round}%)",
                suggestion: "Consider splitting into multiple focused classes"
              }
            end

            # Check for god class
            if is_god_class?(klass)
              issues << {
                type: "god_class",
                severity: "high",
                message: "Class has too many responsibilities",
                suggestion: "Apply Single Responsibility Principle"
              }
            end

            # Check for data class
            if is_data_class?(klass)
              issues << {
                type: "data_class",
                severity: "low",
                message: "Class is primarily a data container with little behavior",
                suggestion: "Consider moving behavior from other classes"
              }
            end

            # Check for feature envy
            if has_feature_envy?(klass)
              issues << {
                type: "feature_envy",
                severity: "medium",
                message: "Class uses other classes' data more than its own",
                suggestion: "Consider moving methods to the classes whose data they use"
              }
            end

            # Check abstraction level
            check_abstraction_level(klass, issues)

            if issues.any?
              result.quality_issues << QualityIssue.new(
                type: "class",
                name: klass.name,
                issues: issues,
                quality_score: calculate_class_quality_score(klass, issues)
              )
            end

            # Add to class metadata
            klass.quality_score = calculate_class_quality_score(klass, issues)
            klass.cohesion_score = cohesion
          end
        end

        def calculate_overall_quality(result)
          scores = []

          # Collect all quality scores
          result.methods.each do |method|
            scores << method.quality_score if method.quality_score
          end

          result.classes.each do |klass|
            scores << klass.quality_score if klass.quality_score
          end

          if scores.any?
            result.quality_metrics.overall_score = (scores.sum / scores.size).round(2)

            # Categorize quality level
            result.quality_metrics.quality_level = case result.quality_metrics.overall_score
            when 0.9..1.0
              "excellent"
            when 0.7..0.9
              "good"
            when 0.5..0.7
              "fair"
            when 0.3..0.5
              "poor"
            else
              "needs_improvement"
            end
          end

          # Count issues by severity
          result.quality_metrics.issues_by_severity = {
            critical: count_issues_by_severity(result, "critical"),
            high: count_issues_by_severity(result, "high"),
            medium: count_issues_by_severity(result, "medium"),
            low: count_issues_by_severity(result, "low")
          }
        end

        def detect_code_smells(method, issues)
          # Check for long parameter lists in method calls
          if method.calls_made&.any? { |call| call[:arguments]&.size.to_i > 5 }
            issues << {
              type: "long_parameter_list",
              severity: "low",
              message: "Method makes calls with many arguments",
              suggestion: "Consider using builder pattern or parameter objects"
            }
          end

          # Check for duplicate code indicators
          if /(_copy|_duplicate|_2|_old|_new|_temp|_backup)$/.match?(method.name)
            issues << {
              type: "possible_duplication",
              severity: "medium",
              message: "Method name suggests code duplication",
              suggestion: "Remove duplication and use proper abstractions"
            }
          end

          # Check for commented code
          if method.has_commented_code
            issues << {
              type: "commented_code",
              severity: "low",
              message: "Method contains commented code",
              suggestion: "Remove commented code or move to version control"
            }
          end
        end

        def check_naming_conventions(method, issues)
          # Check for meaningful names
          if method.name.length < 3 && !%w[+ - * / == != < > <= >= [] []= << >> & | ^].include?(method.name)
            issues << {
              type: "unclear_naming",
              severity: "low",
              message: "Method name is too short to be meaningful",
              suggestion: "Use descriptive method names"
            }
          end

          # Check for consistency
          if method.name =~ /^get_/ && method.owner_type == "class"
            issues << {
              type: "java_style_getter",
              severity: "low",
              message: "Method uses 'get_' prefix which is not idiomatic Ruby",
              suggestion: "Use Ruby attribute readers instead"
            }
          end
        end

        def check_abstraction_level(klass, issues)
          # Check for mixing abstraction levels
          methods = klass.instance_methods || []

          high_level_methods = methods.count { |m| m =~ /^(process|handle|manage|coordinate)/ }
          low_level_methods = methods.count { |m| m =~ /^(get|set|read|write|fetch)/ }

          if high_level_methods > 0 && low_level_methods > 0
            ratio = [high_level_methods, low_level_methods].min.to_f / [high_level_methods, low_level_methods].max

            if ratio > 0.3
              issues << {
                type: "mixed_abstraction_levels",
                severity: "medium",
                message: "Class mixes high-level orchestration with low-level operations",
                suggestion: "Separate concerns into different classes"
              }
            end
          end
        end

        def calculate_cohesion(klass)
          return 1.0 unless klass.instance_methods && klass.instance_variables

          methods = klass.instance_methods
          variables = klass.instance_variables

          return 1.0 if methods.empty? || variables.empty?

          # Calculate how many methods use each instance variable
          # This is simplified - real implementation would analyze method bodies
          used_count = 0
          total_possible = methods.size * variables.size

          # Estimate based on method names and variable names
          methods.each do |method|
            variables.each do |var|
              var_name = var.gsub(/^@/, "")
              if method.include?(var_name) || var_name.include?(method.split("_").first)
                used_count += 1
              end
            end
          end

          return 1.0 if total_possible == 0

          (used_count.to_f / total_possible).round(2)
        end

        def is_god_class?(klass)
          return false unless klass.metrics

          # Check multiple indicators
          indicators = 0
          indicators += 1 if (klass.metrics[:loc] || 0) > 500
          indicators += 1 if (klass.instance_methods&.size || 0) > 30
          indicators += 1 if (klass.dependencies&.size || 0) > 15
          indicators += 1 if (klass.total_complexity || 0) > 50

          indicators >= 2
        end

        def is_data_class?(klass)
          methods = klass.instance_methods || []

          # Count getters/setters vs behavior methods
          accessor_methods = methods.count { |m| m =~ /^(get_|set_)|=$/ }
          behavior_methods = methods.count { |m| m !~ /^(get_|set_)|=$/ && !m.end_with?("?") }

          return false if methods.size < 5

          # Data class if mostly accessors and few behaviors
          accessor_ratio = accessor_methods.to_f / methods.size
          accessor_ratio > 0.7 && behavior_methods < 3
        end

        def has_feature_envy?(klass)
          # Check if class methods use external classes more than own data
          # This is simplified - real implementation would analyze method bodies
          external_calls = 0
          internal_refs = 0

          methods = klass.methods || []
          methods.each do |method|
            if method.calls_made
              external_calls += method.calls_made.count { |call| call[:receiver] && call[:receiver] != "self" }
            end
            internal_refs += 1 if method.uses_instance_variables
          end

          return false if external_calls == 0 && internal_refs == 0

          external_ratio = external_calls.to_f / (external_calls + internal_refs)
          external_ratio > 0.7
        end

        def calculate_method_quality_score(method, issues)
          base_score = 1.0

          issues.each do |issue|
            case issue[:severity]
            when "critical"
              base_score -= 0.4
            when "high"
              base_score -= 0.25
            when "medium"
              base_score -= 0.15
            when "low"
              base_score -= 0.05
            end
          end

          # Factor in complexity
          if method.complexity
            complexity_penalty = (method.complexity - 5).to_f / 20
            base_score -= complexity_penalty if complexity_penalty > 0
          end

          base_score.clamp(0.0, 1.0).round(2)
        end

        def calculate_class_quality_score(klass, issues)
          base_score = 1.0

          issues.each do |issue|
            case issue[:severity]
            when "critical"
              base_score -= 0.3
            when "high"
              base_score -= 0.2
            when "medium"
              base_score -= 0.1
            when "low"
              base_score -= 0.05
            end
          end

          # Factor in stability
          if klass.stability_score
            base_score = (base_score * 0.7 + klass.stability_score * 0.3)
          end

          base_score.clamp(0.0, 1.0).round(2)
        end

        def calculate_length_severity(line_count)
          case line_count
          when 0..30
            "low"
          when 31..50
            "medium"
          when 51..100
            "high"
          else
            "critical"
          end
        end

        def count_issues_by_severity(result, severity)
          result.quality_issues.sum do |issue|
            issue.issues.count { |i| i[:severity] == severity }
          end
        end
      end
    end
  end
end
