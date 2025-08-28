# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Analyzes test coverage metrics
      class CoverageMetric < BaseMetric
        COVERAGE_CATEGORIES = {
          "well_covered" => 80,
          "adequately_covered" => 60,
          "partially_covered" => 30,
          "poorly_covered" => 1,
          "untested" => 0
        }.freeze

        def calculate(result, config)
          config_value(config, :coverage_threshold, 80)

          # Process method coverage
          result.methods.each do |method|
            categorize_method_coverage(method)
          end

          # Aggregate coverage for classes
          result.classes.each do |klass|
            calculate_class_coverage(klass, result.methods)
          end
        end

        private

        def categorize_method_coverage(method)
          coverage = method.test_coverage || 0.0

          method.coverage_category = if coverage >= 80
            "well_covered"
          elsif coverage >= 60
            "adequately_covered"
          elsif coverage >= 30
            "partially_covered"
          elsif coverage > 0
            "poorly_covered"
          else
            "untested"
          end
        end

        def calculate_class_coverage(klass, all_methods)
          # Find methods belonging to this class
          class_methods = all_methods.select { |m| m.owner == klass.name }

          return if class_methods.empty?

          # Calculate average coverage
          total_coverage = class_methods.sum { |m| m.test_coverage || 0.0 }
          klass.test_coverage = (total_coverage / class_methods.size).round(2)

          # Categorize class coverage
          klass.coverage_category = if klass.test_coverage >= 80
            "well_covered"
          elsif klass.test_coverage >= 60
            "adequately_covered"
          elsif klass.test_coverage >= 30
            "partially_covered"
          elsif klass.test_coverage > 0
            "poorly_covered"
          else
            "untested"
          end
        end
      end
    end
  end
end
