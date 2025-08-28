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
        end
        
        private
        
        def calculate_inheritance_depth(klass)
          # Use the inheritance chain if available
          if klass.inheritance_chain && klass.inheritance_chain.is_a?(Array)
            # Depth is chain length minus 1 (excluding the class itself)
            # But we often want to exclude Object/BasicObject
            chain = klass.inheritance_chain.reject { |c| %w[Object BasicObject].include?(c) }
            klass.inheritance_depth = [chain.size - 1, 0].max
          elsif klass.superclass
            # If we don't have the full chain, count what we have
            klass.inheritance_depth = 1
          else
            # No inheritance
            klass.inheritance_depth = 0
          end
        end
      end
    end
  end
end