# frozen_string_literal: true

require_relative "enrichment_stage"

module Rubymap
  class Enricher
    module Pipeline
      # Pipeline stage for applying metrics calculation.
      class MetricsStage < EnrichmentStage
        attr_reader :metrics

        def initialize(config = {}, next_stage = nil)
          super
          @metrics = config[:metrics] || []
        end

        protected

        def process(result)
          metrics.each do |metric|
            metric.calculate(result, config)
          end
        end

        def enabled?
          config[:enable_metrics] != false
        end
      end
    end
  end
end
