# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes method symbols following SRP - handles only method-specific logic
      class MethodProcessor < BaseProcessor
        def process(methods, result, errors)
          methods.each do |method_data|
            next unless validate(method_data, errors)
            
            normalized = normalize_method(method_data, errors)
            result.methods << normalized
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

        def normalize_method(data, errors)
          owner = data[:class] || data[:owner]
          scope = determine_method_scope(data)
          fqname = generate_method_fqname(data[:name], owner, scope)
          
          normalized_params = normalizers.parameter_normalizer.normalize(data[:parameters])
          arity = normalizers.arity_calculator.calculate(normalized_params)
          
          symbol_id = symbol_id_generator.generate_method_id(
            fqname: fqname,
            receiver: scope == "class" ? "class" : "instance", 
            arity: arity
          )
          
          visibility = normalizers.visibility_normalizer.normalize(data[:visibility], errors)
          inferred_visibility = normalizers.visibility_normalizer.infer_from_name(data[:name])
          
          provenance = provenance_tracker.create_provenance(
            sources: [data[:source] || Normalizer::DATA_SOURCES[:inferred]],
            confidence: normalizers.confidence_calculator.calculate(data)
          )
          
          NormalizedMethod.new(
            symbol_id: symbol_id,
            name: data[:name],
            fqname: fqname,
            visibility: visibility,
            owner: owner,
            scope: scope,
            parameters: normalized_params,
            arity: arity,
            canonical_name: normalizers.name_normalizer.to_snake_case(data[:name]),
            available_in: [],
            inferred_visibility: inferred_visibility,
            source: data[:source] || owner,
            provenance: provenance
          )
        end

        def determine_method_scope(data)
          return data[:scope] if data[:scope]
          "instance" # Default fallback
        end

        def generate_method_fqname(method_name, owner, scope)
          return method_name unless owner
          
          separator = scope == "class" ? "." : "#"
          "#{owner}#{separator}#{method_name}"
        end
      end
    end
  end
end