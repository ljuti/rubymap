# frozen_string_literal: true

require_relative "enrichment_stage"

module Rubymap
  class Enricher
    module Pipeline
      # Pipeline stage for applying pattern and quality analysis.
      class AnalysisStage < EnrichmentStage
        attr_reader :analyzers

        def initialize(config = {}, next_stage = nil)
          super(config, next_stage)
          @analyzers = config[:analyzers] || []
        end

        protected

        def process(result)
          analyzers.each do |analyzer|
            analyzer.analyze(result, config)
          end
        end

        def enabled?
          config[:enable_patterns] != false
        end
      end
    end
  end
end