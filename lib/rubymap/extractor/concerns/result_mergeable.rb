# frozen_string_literal: true

module Rubymap
  class Extractor
    module Concerns
      # Provides result merging functionality to avoid duplication
      module ResultMergeable
        # List of collections that can be merged between results
        MERGEABLE_COLLECTIONS = %i[
          classes modules methods constants attributes
          mixins dependencies class_variables aliases patterns errors
        ].freeze

        # Merge source result into target result
        def merge_results!(target, source)
          MERGEABLE_COLLECTIONS.each do |collection|
            if target.respond_to?(collection) && source.respond_to?(collection)
              target.send(collection).concat(source.send(collection))
            end
          end
          target
        end

        # Merge source result into self (if included in Result class)
        def merge!(source)
          MERGEABLE_COLLECTIONS.each do |collection|
            if respond_to?(collection) && source.respond_to?(collection)
              send(collection).concat(source.send(collection))
            end
          end
          self
        end
      end
    end
  end
end
