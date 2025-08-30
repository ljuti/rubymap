# frozen_string_literal: true

require_relative "base_converter"

module Rubymap
  class Enricher
    module Converters
      # Converter for transforming hash data into NormalizedMethod objects.
      #
      # This converter handles method-specific conversion including parameters,
      # visibility, scope, and analysis metrics for method complexity.
      class MethodConverter < BaseConverter
        protected

        # Checks if item is already a NormalizedMethod
        def already_normalized?(item)
          item.is_a?(Normalizer::NormalizedMethod)
        end

        # Converts a single hash to NormalizedMethod
        def convert_single(hash)
          Normalizer::NormalizedMethod.new(
            symbol_id: ensure_symbol_id(hash, "method"),
            name: safe_extract(hash, :name),
            fqname: safe_extract(hash, :fqname) || safe_extract(hash, :name),
            visibility: safe_extract(hash, :visibility, "public"),
            owner: safe_extract(hash, :owner),
            scope: safe_extract(hash, :scope, "instance"),
            parameters: safe_extract(hash, :parameters, []),
            arity: safe_extract(hash, :arity, -1),
            canonical_name: safe_extract(hash, :canonical_name) || safe_extract(hash, :name),
            available_in: safe_extract(hash, :available_in, []),
            inferred_visibility: safe_extract(hash, :inferred_visibility),
            source: safe_extract(hash, :source),
            provenance: safe_extract(hash, :provenance, "test"),
            # Analysis fields for complexity metrics
            branches: safe_extract(hash, :branches),
            loops: safe_extract(hash, :loops),
            conditionals: safe_extract(hash, :conditionals),
            body_lines: safe_extract(hash, :body_lines),
            test_coverage: safe_extract(hash, :test_coverage)
          )
        end
      end
    end
  end
end