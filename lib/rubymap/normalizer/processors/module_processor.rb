# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes module symbols following SRP - handles only module-specific logic
      class ModuleProcessor < BaseProcessor
        def process(modules, result, errors)
          modules.each do |module_data|
            next unless validate(module_data, errors)

            normalized = normalize_module(module_data)
            result.modules << normalized
          end
        end

        def validate(data, errors)
          if data[:name].nil?
            add_validation_error("missing required field: name", data, errors)
            return false
          end
          true
        end

        private

        def normalize_module(data)
          fqname = normalizers.name_normalizer.generate_fqname(data[:name], data[:namespace])
          symbol_id = symbol_id_generator.generate_module_id(fqname)

          provenance = provenance_tracker.create_provenance(
            sources: [data[:source] || Normalizer::DATA_SOURCES[:inferred]],
            confidence: normalizers.confidence_calculator.calculate(data)
          )

          NormalizedModule.new(
            symbol_id: symbol_id,
            name: data[:name],
            fqname: fqname,
            kind: "module",
            location: normalizers.location_normalizer.normalize(data[:location]),
            namespace_path: normalizers.name_normalizer.extract_namespace_path(data[:name]),
            children: [],
            provenance: provenance
          )
        end
      end
    end
  end
end
