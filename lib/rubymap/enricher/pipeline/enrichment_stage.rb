# frozen_string_literal: true

module Rubymap
  class Enricher
    module Pipeline
      # Base class for all enrichment pipeline stages.
      # Implements Template Method pattern to standardize stage execution.
      #
      # Each stage in the enrichment pipeline should inherit from this class
      # and implement the #process method to perform its specific enrichment logic.
      #
      # @abstract
      class EnrichmentStage
        attr_reader :config, :next_stage

        # Creates a new enrichment stage.
        #
        # @param config [Hash] Configuration options for the stage
        # @param next_stage [EnrichmentStage, nil] The next stage in the pipeline
        def initialize(config = {}, next_stage = nil)
          @config = config
          @next_stage = next_stage
        end

        # Executes this stage and passes result to the next stage.
        # Template method that ensures consistent execution pattern.
        #
        # @param result [EnrichmentResult] The result being enriched
        # @return [EnrichmentResult] The enriched result after all stages
        def execute(result)
          return result unless enabled?

          begin
            process(result)
          rescue StandardError => e
            handle_error(e, result)
          end

          # Pass to next stage in chain
          next_stage ? next_stage.execute(result) : result
        end

        # Sets the next stage in the pipeline.
        #
        # @param stage [EnrichmentStage] The next stage to execute
        # @return [EnrichmentStage] Returns self for chaining
        def chain(stage)
          @next_stage = stage
          self
        end

        protected

        # Process the enrichment for this stage.
        # Must be implemented by subclasses.
        #
        # @param result [EnrichmentResult] The result to enrich
        # @abstract
        def process(result)
          raise NotImplementedError, "#{self.class} must implement #process"
        end

        # Determines if this stage is enabled based on configuration.
        #
        # @return [Boolean] true if the stage should execute
        def enabled?
          true
        end

        # Handles errors that occur during processing.
        #
        # @param error [StandardError] The error that occurred
        # @param result [EnrichmentResult] The result being processed
        def handle_error(error, result)
          # Add to problem_areas instead of errors since EnrichmentResult doesn't have errors attribute
          result.problem_areas ||= []
          result.problem_areas << {
            stage: self.class.name,
            error: error.message,
            backtrace: error.backtrace&.first(5)
          }
          
          # Re-raise in development/test to catch issues
          raise error if ENV["RACK_ENV"] == "test" || ENV["RAILS_ENV"] == "test"
        end
      end
    end
  end
end