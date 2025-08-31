# frozen_string_literal: true

require_relative "enrichment_stage"
require_relative "../processors/issue_identifier"

module Rubymap
  class Enricher
    module Pipeline
      # Pipeline stage for identifying issues and hotspots.
      class IssueIdentificationStage < EnrichmentStage
        attr_reader :issue_identifier

        def initialize(config = {}, next_stage = nil)
          super
          @issue_identifier = Processors::IssueIdentifier.new(config)
        end

        protected

        def process(result)
          issue_identifier.identify_all_issues(result)
        end
      end
    end
  end
end
