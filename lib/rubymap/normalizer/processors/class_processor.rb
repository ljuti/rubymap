# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes class symbols according to SRP - only handles class-specific logic
      class ClassProcessor < BaseProcessor
        def process(classes, result, errors)
          processed_classes = []
          
          classes.each do |class_data|
            next unless validate(class_data, errors)
            
            # Check if it's actually a module
            if class_data[:type] == "module" || class_data[:kind] == "module"
              normalized = normalize_as_module(class_data)
              result.modules << normalized
            else
              normalized = normalize_class(class_data)
              processed_classes << normalized
              result.classes << normalized
              
              # Handle mixins if present - assign directly
              assign_mixins(class_data, normalized)
            end
          end
          
          processed_classes
        end

        def validate(data, errors)
          if data[:name].nil?
            add_validation_error("missing required field: name", data, errors)
            return false
          end
          true
        end

        private

        def normalize_class(data)
          fqname = normalizers.name_normalizer.generate_fqname(data[:name], data[:namespace])
          symbol_id = symbol_id_generator.generate_class_id(fqname, data[:type] || "class")
          
          provenance = provenance_tracker.create_provenance(
            sources: [data[:source] || Normalizer::DATA_SOURCES[:inferred]],
            confidence: normalizers.confidence_calculator.calculate(data)
          )
          
          NormalizedClass.new(
            symbol_id: symbol_id,
            name: data[:name],
            fqname: fqname,
            kind: data[:type] || "class",
            superclass: data[:superclass],
            location: normalizers.location_normalizer.normalize(data[:location]),
            namespace_path: normalizers.name_normalizer.extract_namespace_path(data[:name]),
            children: [],
            inheritance_chain: [],
            instance_methods: [],
            class_methods: [],
            available_instance_methods: [],
            available_class_methods: [],
            mixins: [],
            provenance: provenance
          )
        end

        def normalize_as_module(data)
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

        def assign_mixins(class_data, normalized_class)
          return unless class_data[:mixins]
          
          class_data[:mixins].each do |mixin|
            normalized_class.mixins << {
              type: mixin[:type],
              module: mixin[:module]
            }
          end
        end
      end
    end
  end
end