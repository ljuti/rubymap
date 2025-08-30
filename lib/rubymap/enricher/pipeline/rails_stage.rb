# frozen_string_literal: true

require_relative "enrichment_stage"
require_relative "../detectors/rails_detector"

module Rubymap
  class Enricher
    module Pipeline
      # Pipeline stage for Rails-specific enrichment.
      class RailsStage < EnrichmentStage
        attr_reader :rails_enrichers

        def initialize(config = {}, next_stage = nil)
          super(config, next_stage)
          @rails_enrichers = config[:rails_enrichers] || []
        end

        protected

        def process(result)
          return unless Detectors::RailsDetector.rails_project?(result)

          rails_enrichers.each do |enricher|
            enricher.enrich(result, config)
          end

          # Add Rails analysis to result
          result.rails_analysis = Detectors::RailsDetector.analyze_rails_project(result)
        end

        def enabled?
          config[:enable_rails] != false
        end
      end
    end
  end
end