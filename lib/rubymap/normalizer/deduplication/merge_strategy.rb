# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Deduplication
      # Handles merging strategies for duplicate symbols following Strategy pattern
      class MergeStrategy
        def initialize(provenance_tracker, visibility_normalizer)
          @provenance_tracker = provenance_tracker
          @visibility_normalizer = visibility_normalizer
        end

        def merge_methods(methods)
          # Sort by precedence (highest first)
          sorted_methods = methods.sort_by { |m| -get_highest_source_precedence(m.provenance) }
          primary = sorted_methods.first

          # Merge provenance from all sources
          merged_provenance = methods.reduce(primary.provenance) do |acc, method|
            provenance_tracker.merge_provenance(acc, method.provenance)
          end

          # Use primary method as base, but update with merged provenance
          primary.dup.tap do |merged|
            merged.provenance = merged_provenance
            # Take most restrictive visibility if explicitly set
            merged.visibility = get_most_restrictive_visibility(methods)
          end
        end

        def merge_classes(classes)
          # Sort by precedence (highest first)
          sorted_classes = classes.sort_by { |c| -get_highest_source_precedence(c.provenance) }
          primary = sorted_classes.first

          # Merge provenance from all sources
          merged_provenance = classes.reduce(primary.provenance) do |acc, klass|
            provenance_tracker.merge_provenance(acc, klass.provenance)
          end

          # Use primary class as base, but update with merged provenance
          primary.dup.tap do |merged|
            merged.provenance = merged_provenance
            # Merge superclass information (prefer explicit over inferred)
            merged.superclass = get_most_reliable_superclass(classes)
          end
        end

        def merge_modules(modules)
          # Sort by precedence (highest first)
          sorted_modules = modules.sort_by { |m| -get_highest_source_precedence(m.provenance) }
          primary = sorted_modules.first

          # Merge provenance from all sources
          merged_provenance = modules.reduce(primary.provenance) do |acc, mod|
            provenance_tracker.merge_provenance(acc, mod.provenance)
          end

          # Use primary module as base, but update with merged provenance
          primary.dup.tap do |merged|
            merged.provenance = merged_provenance
          end
        end

        private

        attr_reader :provenance_tracker, :visibility_normalizer

        def get_highest_source_precedence(provenance)
          return 0 unless provenance&.sources

          provenance.sources.map { |source| Normalizer::SOURCE_PRECEDENCE[source] || 0 }.max
        end

        def get_most_restrictive_visibility(methods)
          visibilities = methods.map(&:visibility).compact.uniq
          visibility_normalizer.get_most_restrictive(visibilities)
        end

        def get_most_reliable_superclass(classes)
          superclasses = classes.map(&:superclass).compact.uniq
          return nil if superclasses.empty?

          # Prefer superclass from highest precedence source
          classes.sort_by { |c| -get_highest_source_precedence(c.provenance) }
            .find(&:superclass)&.superclass
        end
      end
    end
  end
end
