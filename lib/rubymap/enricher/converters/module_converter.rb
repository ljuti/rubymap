# frozen_string_literal: true

require_relative "base_converter"

module Rubymap
  class Enricher
    module Converters
      # Converter for transforming hash data into NormalizedModule objects.
      #
      # This converter handles module-specific conversion with a simpler structure
      # compared to classes, focusing on core module attributes and metadata.
      class ModuleConverter < BaseConverter
        protected

        # Checks if item is already a NormalizedModule
        def already_normalized?(item)
          item.is_a?(Normalizer::NormalizedModule)
        end

        # Converts a single hash to NormalizedModule
        def convert_single(hash)
          Normalizer::NormalizedModule.new(
            symbol_id: ensure_symbol_id(hash, "module"),
            name: safe_extract(hash, :name),
            fqname: safe_extract(hash, :fqname) || safe_extract(hash, :name),
            kind: safe_extract(hash, :kind, "module"),
            location: safe_extract(hash, :location),
            namespace_path: safe_extract(hash, :namespace_path, []),
            children: safe_extract(hash, :children, []),
            provenance: safe_extract(hash, :provenance, "test"),
            # Additional test data fields
            instance_methods: safe_extract(hash, :instance_methods),
            visibility: safe_extract(hash, :visibility)
          )
        end
      end
    end
  end
end