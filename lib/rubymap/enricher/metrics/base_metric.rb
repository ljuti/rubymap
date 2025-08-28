# frozen_string_literal: true

module Rubymap
  class Enricher
    module Metrics
      # Abstract base class for all metric calculators
      class BaseMetric
        # Calculate metrics for the enriched result
        def calculate(result, config)
          raise NotImplementedError, "Subclasses must implement #calculate"
        end

        protected

        # Helper to safely get a config value with a default
        def config_value(config, key, default)
          config.fetch(key, default)
        end

        # Helper to calculate average of a collection
        def average(collection, &block)
          return 0.0 if collection.empty?

          values = block_given? ? collection.map(&block) : collection
          values.sum.to_f / values.size
        end

        # Helper to categorize a numeric value
        def categorize_value(value, thresholds)
          thresholds.each do |category, threshold|
            return category if value <= threshold
          end
          :unknown
        end

        # Helper to normalize a value to 0.0-1.0 range
        def normalize(value, max_value)
          return 0.0 if max_value <= 0
          (value.to_f / max_value).clamp(0.0, 1.0)
        end
      end
    end
  end
end
