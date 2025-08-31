# frozen_string_literal: true

require_relative "enrichment_stage"
require_relative "../processors/composite_score_calculator"

module Rubymap
  class Enricher
    module Pipeline
      # Pipeline stage for calculating composite scores.
      class ScoringStage < EnrichmentStage
        protected

        def process(result)
          result.classes.each do |klass|
            Processors::CompositeScoreCalculator.calculate_all_scores(klass)
          end
        end
      end
    end
  end
end
