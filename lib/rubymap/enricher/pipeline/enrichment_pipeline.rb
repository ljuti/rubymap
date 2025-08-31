# frozen_string_literal: true

module Rubymap
  class Enricher
    module Pipeline
      # Orchestrates the enrichment pipeline using Chain of Responsibility pattern.
      # Manages the sequence of enrichment stages and ensures proper execution order.
      class EnrichmentPipeline
        attr_reader :stages, :config

        # Creates a new enrichment pipeline.
        #
        # @param config [Hash] Configuration for the pipeline
        def initialize(config = {})
          @config = config
          @stages = []
          build_pipeline unless config[:skip_default_pipeline]
        end

        # Executes the entire enrichment pipeline.
        #
        # @param result [EnrichmentResult] The result to enrich
        # @return [EnrichmentResult] The fully enriched result
        def execute(result)
          return result if stages.empty?

          # Start the chain of responsibility
          stages.first.execute(result)
        end

        # Adds a stage to the pipeline.
        #
        # @param stage_class [Class] The stage class to instantiate
        # @param stage_config [Hash] Configuration for the stage
        # @return [self] Returns self for chaining
        def add_stage(stage_class, stage_config = {})
          stage = stage_class.new(stage_config.merge(config))

          if stages.any?
            stages.last.chain(stage)
          end

          stages << stage
          self
        end

        private

        # Builds the default pipeline with all stages in order.
        def build_pipeline
          add_stage(MetricsStage) if config[:enable_metrics]
          add_stage(AnalysisStage) if config[:enable_patterns]
          add_stage(RailsStage) if config[:enable_rails]
          add_stage(ScoringStage)
          add_stage(IssueIdentificationStage)
        end
      end
    end
  end
end
