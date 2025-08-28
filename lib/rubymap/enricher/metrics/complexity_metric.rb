# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates cyclomatic complexity and related metrics
      class ComplexityMetric < BaseMetric
        COMPLEXITY_THRESHOLDS = {
          simple: 5,
          moderate: 10,
          complex: 20
        }.freeze

        def calculate(result, config)
          config_value(config, :complexity_threshold, 10)

          # Calculate complexity for methods
          result.methods.each do |method|
            calculate_method_complexity(method)
            assign_complexity_category(method)
          end

          # Aggregate complexity for classes
          result.classes.each do |klass|
            calculate_class_complexity(klass, result.methods)
          end
        end

        private

        def calculate_method_complexity(method)
          # Base complexity is 1
          complexity = 1

          # Add complexity for branches (if, unless, case, etc.)
          complexity += method.branches || 0

          # Add complexity for loops (while, for, each, etc.)
          complexity += method.loops || 0

          # Add complexity for conditionals
          if method.conditionals
            if method.conditionals.is_a?(Array)
              complexity += method.conditionals.size
            elsif method.conditionals.is_a?(Integer)
              complexity += method.conditionals
            end
          end

          # Add complexity based on method length (simple heuristic)
          if method.body_lines
            complexity += (method.body_lines / 10).to_i
          end

          method.cyclomatic_complexity = complexity
          method.lines_of_code = method.body_lines || 0
        end

        def assign_complexity_category(method)
          complexity = method.cyclomatic_complexity || 1

          method.complexity_category = if complexity <= COMPLEXITY_THRESHOLDS[:simple]
            "simple"
          elsif complexity <= COMPLEXITY_THRESHOLDS[:moderate]
            "moderate"
          elsif complexity <= COMPLEXITY_THRESHOLDS[:complex]
            "complex"
          else
            "very_complex"
          end
        end

        def calculate_class_complexity(klass, all_methods)
          # Find methods belonging to this class
          class_methods = all_methods.select { |m| m.owner == klass.name }
          klass.methods = class_methods

          return if class_methods.empty?

          # Calculate average complexity
          total_complexity = class_methods.sum { |m| m.cyclomatic_complexity || 1 }
          klass.cyclomatic_complexity = (total_complexity.to_f / class_methods.size).round(2)

          # Determine overall complexity category
          klass.complexity_category = if klass.cyclomatic_complexity <= COMPLEXITY_THRESHOLDS[:simple]
            "simple"
          elsif klass.cyclomatic_complexity <= COMPLEXITY_THRESHOLDS[:moderate]
            "moderate"
          else
            "complex"
          end
        end
      end
    end
  end
end
