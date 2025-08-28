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
          coverage_threshold = config_value(config, :coverage_threshold, 80)
          
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
          
          method.coverage_category = COVERAGE_CATEGORIES.find do |category, threshold|
            coverage >= threshold
          end&.first || "untested"
        end
        
        def calculate_class_coverage(klass, all_methods)
          # Find methods belonging to this class
          class_methods = all_methods.select { |m| m.owner == klass.name }
          
          return if class_methods.empty?
          
          # Calculate average coverage
          total_coverage = class_methods.sum { |m| m.test_coverage || 0.0 }
          klass.test_coverage = (total_coverage / class_methods.size).round(2)
          
          # Categorize class coverage
          klass.coverage_category = COVERAGE_CATEGORIES.find do |category, threshold|
            klass.test_coverage >= threshold
          end&.first || "untested"
        end
      end
    end
  end
end