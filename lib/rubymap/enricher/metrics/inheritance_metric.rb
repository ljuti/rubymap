# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates inheritance depth and hierarchy metrics
      class InheritanceMetric < BaseMetric
        def calculate(result, config)
          depth_threshold = config_value(config, :inheritance_depth_threshold, 5)

          result.classes.each do |klass|
            calculate_inheritance_depth(klass)
          end

          identify_deep_hierarchies(result, depth_threshold)
        end

        private

        def calculate_inheritance_depth(klass)
          # Use the inheritance chain if available
          klass.inheritance_depth = if klass.inheritance_chain && klass.inheritance_chain.is_a?(Array)
            # Inheritance depth is the number of ancestors excluding the class itself
            # For Object class, depth is 0
            # For classes inheriting directly from Object, depth is 1, etc.
            if klass.inheritance_chain.first == klass.name
              # Chain includes the class itself, so subtract 1
              klass.inheritance_chain.size - 1
            else
              # Chain doesn't include the class itself
              klass.inheritance_chain.size
            end
          elsif klass.superclass
            # If we don't have the full chain, count what we have
            1
          else
            # No inheritance
            0
          end
        end

        def identify_deep_hierarchies(result, threshold)
          result.design_issues ||= []

          result.classes.each do |klass|
            # Use threshold of 4 for deep inheritance (more than 3 levels is considered deep)
            actual_threshold = threshold || 4
            if klass.inheritance_depth && klass.inheritance_depth >= actual_threshold
              result.design_issues << DesignIssue.new(
                type: "deep_inheritance",
                class: klass.name,
                depth: klass.inheritance_depth
              )
            end
          end
        end
      end
    end
  end
end
