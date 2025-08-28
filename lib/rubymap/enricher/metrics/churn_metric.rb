# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates git churn metrics
      class ChurnMetric < BaseMetric
        def calculate(result, config)
          config_value(config, :churn_threshold, 10)

          result.classes.each do |klass|
            calculate_churn_score(klass)
          end
        end

        private

        def calculate_churn_score(klass)
          commits = klass.git_commits || 0
          last_modified = klass.last_modified

          # Calculate age if last_modified is available
          if last_modified
            age_in_days = calculate_age_in_days(last_modified)
            klass.age_in_days = age_in_days
          end

          # Calculate churn score based on commits and recency
          # Higher score = more churn (more problematic)
          base_score = commits.to_f

          # Adjust based on recency (recent changes = higher score)
          if klass.age_in_days
            recency_factor = if klass.age_in_days < 7
              2.0  # Very recent changes
            elsif klass.age_in_days < 30
              1.5  # Recent changes
            elsif klass.age_in_days < 90
              1.2  # Somewhat recent
            else
              0.5  # Older changes (reduce churn score)
            end

            klass.churn_score = (base_score * recency_factor).round(2)
          else
            # Simple normalization without time factor
            klass.churn_score = base_score.round(2)
          end
        end

        def calculate_age_in_days(last_modified)
          return 0 unless last_modified

          if last_modified.is_a?(Time)
            ((Time.now - last_modified) / 86400).to_i
          elsif last_modified.respond_to?(:to_time)
            ((Time.now - last_modified.to_time) / 86400).to_i
          else
            # Assume it's already in days or can't be converted
            365
          end
        end
      end
    end
  end
end
