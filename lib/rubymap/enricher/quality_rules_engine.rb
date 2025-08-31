# frozen_string_literal: true

require "yaml"

module Rubymap
  class Enricher
    # Engine for loading and applying quality rules from configuration
    class QualityRulesEngine
      DEFAULT_RULES_PATH = File.expand_path("../../../../config/quality_rules.yml", __FILE__)

      attr_reader :rules, :config

      def initialize(rules_path = nil)
        @rules_path = rules_path || DEFAULT_RULES_PATH
        load_rules
      end

      def load_rules
        @config = YAML.load_file(@rules_path)
        @rules = {
          method: parse_method_rules,
          class: parse_class_rules,
          code_smells: parse_code_smell_rules,
          scoring: @config["scoring"] || {}
        }
      rescue => e
        # Fallback to minimal rules if config fails to load
        @rules = default_rules
        @config = {"version" => "1.0"}
      end

      def apply_method_rules(method)
        issues = []
        
        @rules[:method].each do |rule|
          next unless rule[:enabled]
          
          issue = evaluate_method_rule(method, rule)
          issues << issue if issue
        end
        
        issues
      end

      def apply_class_rules(klass)
        issues = []
        
        @rules[:class].each do |rule|
          next unless rule[:enabled]
          
          issue = evaluate_class_rule(klass, rule)
          issues << issue if issue
        end
        
        issues
      end

      def calculate_method_score(method, issues)
        scoring = @rules[:scoring]["method"] || default_method_scoring
        base_score = scoring["base_score"] || 1.0
        
        issues.each do |issue|
          penalty = scoring["penalties"][issue[:severity]] || 0
          base_score -= penalty
        end
        
        # Apply complexity penalty if applicable
        if method.respond_to?(:complexity) && method.complexity
          complexity_factor = scoring["complexity_factor"] || {}
          threshold = complexity_factor["threshold"] || 5
          
          if method.complexity > threshold
            max_penalty = complexity_factor["max_penalty"] || 0.3
            scale = complexity_factor["scale"] || 20
            penalty = [(method.complexity - threshold).to_f / scale * max_penalty, max_penalty].min
            base_score -= penalty
          end
        end
        
        base_score.clamp(0.0, 1.0).round(2)
      end

      def calculate_class_score(klass, issues)
        scoring = @rules[:scoring]["class"] || default_class_scoring
        base_score = scoring["base_score"] || 1.0
        
        issues.each do |issue|
          penalty = scoring["penalties"][issue[:severity]] || 0
          base_score -= penalty
        end
        
        # Factor in stability if available
        if klass.respond_to?(:stability_score) && klass.stability_score
          stability_weight = scoring["stability_weight"] || 0.3
          base_score = (base_score * (1 - stability_weight) + klass.stability_score * stability_weight)
        end
        
        base_score.clamp(0.0, 1.0).round(2)
      end

      def quality_level(score)
        levels = @rules[:scoring]["overall"]["quality_levels"] || default_quality_levels
        
        levels.each do |level, range|
          min = range["min"] || 0
          max = range["max"] || 1
          return level.to_s if score >= min && score <= max
        end
        
        "unknown"
      end

      private

      def parse_method_rules
        rules = []
        
        (@config["method_rules"] || []).each do |rule_config|
          rules << {
            id: rule_config["id"],
            enabled: rule_config.fetch("enabled", true),
            description: rule_config["description"],
            threshold: rule_config["threshold"],
            condition: rule_config["condition"],
            severity: parse_severity(rule_config["severity"]),
            message_template: rule_config["message_template"],
            suggestion: rule_config["suggestion"]
          }
        end
        
        rules
      end

      def parse_class_rules
        rules = []
        
        (@config["class_rules"] || []).each do |rule_config|
          rules << {
            id: rule_config["id"],
            enabled: rule_config.fetch("enabled", true),
            description: rule_config["description"],
            threshold: rule_config["threshold"],
            indicators: rule_config["indicators"],
            min_indicators: rule_config["min_indicators"],
            conditions: rule_config["conditions"],
            patterns: rule_config["patterns"],
            pattern_threshold: rule_config["pattern_threshold"],
            severity: rule_config["severity"],
            message_template: rule_config["message_template"],
            suggestion: rule_config["suggestion"]
          }
        end
        
        rules
      end

      def parse_code_smell_rules
        (@config["code_smells"] || []).map do |rule_config|
          {
            id: rule_config["id"],
            enabled: rule_config.fetch("enabled", true),
            description: rule_config["description"],
            threshold: rule_config["threshold"],
            severity: rule_config["severity"],
            message_template: rule_config["message_template"],
            suggestion: rule_config["suggestion"]
          }
        end
      end

      def parse_severity(severity_config)
        return severity_config if severity_config.is_a?(String)
        
        # Handle range-based severity
        if severity_config.is_a?(Hash) && severity_config["ranges"]
          return severity_config
        end
        
        "medium"
      end

      def evaluate_method_rule(method, rule)
        # Check threshold-based rules
        if rule[:threshold]
          value = get_metric_value(method, rule[:threshold]["metric"])
          return nil unless value
          
          if compare_value(value, rule[:threshold]["operator"], rule[:threshold]["value"])
            severity = calculate_severity(value, rule[:severity])
            return format_issue(rule, severity, value: value, threshold: rule[:threshold]["value"])
          end
        end
        
        # Check condition-based rules
        if rule[:condition]
          if matches_condition?(method.name, rule[:condition])
            return format_issue(rule, rule[:severity], name: method.name)
          end
        end
        
        nil
      end

      def evaluate_class_rule(klass, rule)
        # Handle multi-indicator rules (like god_class)
        if rule[:indicators]
          matched_indicators = 0
          
          rule[:indicators].each do |indicator|
            value = get_class_metric_value(klass, indicator["metric"])
            if value && compare_value(value, indicator["operator"], indicator["value"])
              matched_indicators += 1
            end
          end
          
          if matched_indicators >= (rule[:min_indicators] || 1)
            return format_issue(rule, rule[:severity])
          end
        end
        
        # Handle threshold-based rules
        if rule[:threshold]
          value = get_class_metric_value(klass, rule[:threshold]["metric"])
          return nil unless value
          
          if compare_value(value, rule[:threshold]["operator"], rule[:threshold]["value"])
            formatted_value = rule[:threshold]["metric"] == "cohesion" ? "#{(value * 100).round}%" : value
            return format_issue(rule, rule[:severity], value: formatted_value)
          end
        end
        
        # Handle condition-based rules (like data_class)
        if rule[:conditions]
          if evaluate_class_conditions(klass, rule[:conditions])
            return format_issue(rule, rule[:severity])
          end
        end
        
        # Handle pattern-based rules (like mixed_abstraction_levels)
        if rule[:patterns]
          if has_mixed_patterns?(klass, rule[:patterns], rule[:pattern_threshold])
            return format_issue(rule, rule[:severity])
          end
        end
        
        nil
      end

      def get_metric_value(method, metric)
        case metric
        when "line_count"
          method.line_count
        when "parameter_count"
          method.parameters&.size || 0
        when "complexity"
          method.complexity
        else
          nil
        end
      end

      def get_class_metric_value(klass, metric)
        case metric
        when "loc"
          klass.metrics&.dig(:loc)
        when "method_count"
          klass.instance_methods&.size || 0
        when "dependency_count"
          klass.dependencies&.size || 0
        when "total_complexity"
          klass.total_complexity
        when "cohesion"
          calculate_cohesion(klass)
        when "external_call_ratio"
          calculate_external_call_ratio(klass)
        else
          nil
        end
      end

      def compare_value(value, operator, threshold)
        case operator
        when ">"
          value > threshold
        when ">="
          value >= threshold
        when "<"
          value < threshold
        when "<="
          value <= threshold
        when "=="
          value == threshold
        else
          false
        end
      end

      def matches_condition?(name, condition)
        return false unless condition["type"] == "regex"
        
        pattern = Regexp.new(condition["pattern"])
        exclude = condition["exclude"] || []
        
        return false if exclude.any? { |ex| name == ex }
        
        pattern.match?(name)
      end

      def calculate_severity(value, severity_config)
        return severity_config if severity_config.is_a?(String)
        
        if severity_config.is_a?(Hash) && severity_config["ranges"]
          severity_config["ranges"].each do |range|
            return range["level"] if range["max"] && value <= range["max"]
          end
          
          # Find default range
          default_range = severity_config["ranges"].find { |r| r["default"] }
          return default_range["level"] if default_range
        end
        
        "medium"
      end

      def format_issue(rule, severity, interpolations = {})
        message = rule[:message_template]
        
        # Interpolate values into message
        interpolations.each do |key, value|
          message = message.gsub("{#{key}}", value.to_s)
        end
        
        {
          type: rule[:id],
          severity: severity,
          message: message,
          suggestion: rule[:suggestion]
        }
      end

      def evaluate_class_conditions(klass, conditions)
        methods = klass.instance_methods || []
        return false if methods.size < (conditions["min_method_count"] || 0)
        
        if conditions["accessor_ratio"]
          accessor_methods = methods.count { |m| m =~ /^(get_|set_)|=$/ }
          accessor_ratio = accessor_methods.to_f / methods.size
          
          return false unless compare_value(accessor_ratio, conditions["accessor_ratio"]["operator"], conditions["accessor_ratio"]["value"])
        end
        
        if conditions["behavior_method_count"]
          behavior_methods = methods.count { |m| m !~ /^(get_|set_)|=$/ && !m.end_with?("?") }
          return false unless compare_value(behavior_methods, conditions["behavior_method_count"]["operator"], conditions["behavior_method_count"]["value"])
        end
        
        true
      end

      def has_mixed_patterns?(klass, patterns, threshold)
        methods = klass.instance_methods || []
        
        # Check both string and symbol keys for compatibility
        high_patterns = patterns["high_level"] || patterns[:high_level]
        low_patterns = patterns["low_level"] || patterns[:low_level]
        
        return false unless high_patterns && low_patterns
        
        high_level_pattern = Regexp.union(high_patterns.map { |p| Regexp.new(p) })
        low_level_pattern = Regexp.union(low_patterns.map { |p| Regexp.new(p) })
        
        high_level_count = methods.count { |m| high_level_pattern.match?(m) }
        low_level_count = methods.count { |m| low_level_pattern.match?(m) }
        
        return false if high_level_count == 0 || low_level_count == 0
        
        ratio = [high_level_count, low_level_count].min.to_f / [high_level_count, low_level_count].max
        ratio > (threshold&.dig("min_ratio") || 0.3)
      end

      def calculate_cohesion(klass)
        # Simplified cohesion calculation
        return 1.0 unless klass.instance_methods && klass.instance_variables
        
        methods = klass.instance_methods
        variables = klass.instance_variables
        
        return 1.0 if methods.empty? || variables.empty?
        
        # This is a simplified heuristic
        0.5
      end

      def calculate_external_call_ratio(klass)
        # Simplified external call ratio
        0.5
      end

      def default_rules
        {
          method: [],
          class: [],
          code_smells: [],
          scoring: default_scoring
        }
      end

      def default_scoring
        {
          "method" => default_method_scoring,
          "class" => default_class_scoring,
          "overall" => {"quality_levels" => default_quality_levels}
        }
      end

      def default_method_scoring
        {
          "base_score" => 1.0,
          "penalties" => {
            "critical" => 0.4,
            "high" => 0.25,
            "medium" => 0.15,
            "low" => 0.05
          }
        }
      end

      def default_class_scoring
        {
          "base_score" => 1.0,
          "penalties" => {
            "critical" => 0.3,
            "high" => 0.2,
            "medium" => 0.1,
            "low" => 0.05
          }
        }
      end

      def default_quality_levels
        {
          "excellent" => {"min" => 0.9, "max" => 1.0},
          "good" => {"min" => 0.7, "max" => 0.9},
          "fair" => {"min" => 0.5, "max" => 0.7},
          "poor" => {"min" => 0.3, "max" => 0.5},
          "needs_improvement" => {"min" => 0.0, "max" => 0.3}
        }
      end
    end
  end
end