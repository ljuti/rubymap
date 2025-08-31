# frozen_string_literal: true

require_relative "base_converter"
require_relative "normalized_class_builder"

module Rubymap
  class Enricher
    module Converters
      # Converter for transforming hash data into NormalizedClass objects.
      #
      # This converter implements the Strategy pattern for class-specific conversion,
      # utilizing the Builder pattern for complex object construction. It handles
      # all the nuances of class data including inheritance, mixins, Rails-specific
      # attributes, and quality metrics.
      class ClassConverter < BaseConverter
        protected

        # Checks if item is already a NormalizedClass
        def already_normalized?(item)
          item.is_a?(Normalizer::NormalizedClass)
        end

        # Converts a single hash to NormalizedClass using builder pattern
        def convert_single(hash)
          NormalizedClassBuilder.new
            .symbol_id(ensure_symbol_id(hash, "class"))
            .name(safe_extract(hash, :name))
            .fqname(safe_extract(hash, :fqname) || safe_extract(hash, :name))
            .kind(safe_extract(hash, :kind, "class"))
            .superclass(safe_extract(hash, :superclass))
            .location(safe_extract(hash, :location))
            .namespace_path(safe_extract(hash, :namespace_path, []))
            .children(safe_extract(hash, :children, []))
            .inheritance_chain(safe_extract(hash, :inheritance_chain, []))
            .instance_methods(safe_extract(hash, :instance_methods, []))
            .class_methods(safe_extract(hash, :class_methods, []))
            .available_instance_methods(safe_extract(hash, :available_instance_methods, []))
            .available_class_methods(safe_extract(hash, :available_class_methods, []))
            .mixins(safe_extract(hash, :mixins, []))
            .provenance(safe_extract(hash, :provenance, "test"))
            .apply_analysis_fields(hash)
            .apply_quality_metrics(hash)
            .apply_rails_fields(hash)
            .build
        end
      end
    end
  end
end

# Extension to NormalizedClassBuilder for complex field groups
class Rubymap::Enricher::Converters::NormalizedClassBuilder
  # Applies analysis-related fields
  def apply_analysis_fields(hash)
    dependencies(safe_extract(hash, :dependencies))
      .visibility(safe_extract(hash, :visibility))
      .git_commits(safe_extract(hash, :git_commits))
      .last_modified(safe_extract(hash, :last_modified))
      .age_in_days(safe_extract(hash, :age_in_days))
      .file(safe_extract(hash, :file))
      .implements(safe_extract(hash, :implements))
      .method_names(safe_extract(hash, :methods)) # Legacy test data support
  end

  # Applies quality metrics fields
  def apply_quality_metrics(hash)
    test_coverage(safe_extract(hash, :test_coverage))
      .documentation_coverage(safe_extract(hash, :documentation_coverage))
      .churn_score(safe_extract(hash, :churn_score))
  end

  # Applies Rails-specific fields
  def apply_rails_fields(hash)
    associations(safe_extract(hash, :associations))
      .validations(safe_extract(hash, :validations))
      .scopes(safe_extract(hash, :scopes))
      .actions(safe_extract(hash, :actions))
      .filters(safe_extract(hash, :filters))
      .rescue_handlers(safe_extract(hash, :rescue_handlers))
  end

  private

  # Helper method for safe extraction with inheritance from converter
  def safe_extract(hash, key, default = nil)
    hash[key] || hash[key.to_s] || default
  end
end
