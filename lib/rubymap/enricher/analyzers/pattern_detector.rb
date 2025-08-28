# frozen_string_literal: true

require_relative "base_analyzer"

module Rubymap
  class Enricher
    module Analyzers
      # Detects common design patterns in the codebase
      class PatternDetector < BaseAnalyzer
        PATTERNS = {
          factory: {
            name_pattern: /Factory$/,
            required_methods: %w[create build],
            optional_methods: %w[create_with_defaults build_with_defaults]
          },
          singleton: {
            name_pattern: /Singleton$|Connection$/,
            required_methods: %w[instance],
            private_methods: %w[new],
            class_methods: %w[instance]
          },
          observer: {
            name_pattern: /Observer$|Listener$/,
            required_methods: %w[update],
            optional_methods: %w[notify]
          },
          strategy: {
            name_pattern: /Strategy$|Policy$/,
            required_methods: %w[execute],
            optional_methods: %w[perform apply]
          },
          adapter: {
            name_pattern: /Adapter$/,
            optional_methods: %w[adapt convert translate]
          },
          decorator: {
            name_pattern: /Decorator$/,
            optional_methods: %w[decorate wrap]
          }
        }.freeze

        def analyze(result, config)
          result.design_patterns ||= []

          result.classes.each do |klass|
            detect_patterns_for_class(klass, result)
          end
        end

        private

        def detect_patterns_for_class(klass, result)
          evidence = extract_evidence(klass)

          PATTERNS.each do |pattern_type, pattern_config|
            if matches_pattern?(klass, evidence, pattern_config)
              confidence = calculate_pattern_confidence(klass, evidence, pattern_config)

              # Only include evidence that matches the pattern
              pattern_evidence = evidence.select do |e|
                (pattern_config[:required_methods] || []).include?(e) ||
                  (pattern_config[:optional_methods] || []).include?(e)
              end

              result.design_patterns << PatternMatch.new(
                pattern: pattern_type.to_s.capitalize,
                class: klass.name,
                confidence: confidence,
                evidence: pattern_evidence
              )
            end
          end
        end

        def matches_pattern?(klass, evidence, pattern_config)
          # Check name pattern
          name_match = if pattern_config[:name_pattern]
            klass.name =~ pattern_config[:name_pattern]
          else
            false
          end

          # Check required methods
          methods_match = if pattern_config[:required_methods]
            pattern_config[:required_methods].all? { |m| evidence.include?(m) }
          else
            false
          end

          # Check for private constructor (singleton pattern)
          private_new = if pattern_config[:private_methods]
            # Check if 'new' is private
            klass.respond_to?(:visibility) &&
              klass.visibility &&
              klass.visibility["new"] == "private"
          else
            true
          end

          name_match || (methods_match && private_new)
        end

        def calculate_pattern_confidence(klass, evidence, pattern_config)
          scores = []

          # Name pattern match (higher weight for strong naming conventions)
          if pattern_config[:name_pattern] && klass.name =~ pattern_config[:name_pattern]
            scores << 0.4
          end

          # Required methods match (higher weight for required patterns)
          if pattern_config[:required_methods]
            required_count = pattern_config[:required_methods].count { |m| evidence.include?(m) }
            required_score = required_count.to_f / pattern_config[:required_methods].size
            scores << (required_score * 0.4)
          end

          # Optional methods match (bonus for having optional methods)
          if pattern_config[:optional_methods]
            optional_count = pattern_config[:optional_methods].count { |m| evidence.include?(m) }
            if optional_count > 0
              optional_score = optional_count.to_f / pattern_config[:optional_methods].size
              scores << (optional_score * 0.4)
            end
          end

          # Special case for Singleton - check for private new
          if pattern_config[:private_methods]&.include?("new")
            if klass.respond_to?(:visibility) && klass.visibility && klass.visibility["new"] == "private"
              scores << 0.3
            end
          end

          scores.sum.clamp(0.0, 1.0).round(2)
        end

        def extract_evidence(klass)
          evidence = []

          # Add methods from test data format (method_names field)
          if klass.respond_to?(:method_names) && klass.method_names
            evidence.concat(Array(klass.method_names))
          end

          # Add instance method names
          evidence.concat(klass.instance_methods) if klass.instance_methods

          # Add class method names
          evidence.concat(klass.class_methods) if klass.class_methods

          # Add interface implementations
          if klass.respond_to?(:implements)
            evidence.concat(Array(klass.implements))
          end

          evidence
        end
      end
    end
  end
end
