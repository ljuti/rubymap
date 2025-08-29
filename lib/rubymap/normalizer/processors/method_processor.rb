# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes method symbols using the new architecture
      class MethodProcessor < BaseProcessor
        def validate_specific(data, errors)
          if data[:owner].nil? && data[:class].nil?
            add_validation_error("Method must have an owner or class", data, errors)
            return false
          end
          true
        end

        def normalize_item(data)
          owner = data[:class] || data[:owner]  # Prefer class over owner
          name = data[:name].to_s  # Convert to string to handle symbols
          scope = determine_scope(data)
          fqname = build_fqname(owner, name, scope)

          # Calculate arity from parameters
          arity = calculate_arity(data[:parameters])

          symbol_id = symbol_id_generator.generate_method_id(
            fqname: fqname,
            receiver: owner,
            arity: arity
          )

          NormalizedMethod.new(
            symbol_id: symbol_id,
            name: name,
            fqname: fqname,
            visibility: (data[:visibility] || "public").to_s,
            owner: owner,
            scope: scope,
            parameters: normalize_parameters(data[:parameters]),
            arity: arity,
            canonical_name: snake_case(name),
            available_in: [],
            inferred_visibility: infer_visibility(name, data[:visibility]),
            source: data[:source] || "inferred",
            provenance: provenance_tracker.create_provenance(
              sources: data[:source] || Normalizer::DATA_SOURCES[:inferred],
              confidence: 0.8
            )
          )
        end

        def add_to_result(item, result)
          result.methods << item
        end

        private

        def determine_scope(data)
          return data[:scope] if data[:scope]

          case data[:receiver]
          when "self", "singleton", "class"
            "class"
          else
            "instance"
          end
        end

        def build_fqname(owner, name, scope)
          return name unless owner
          separator = (scope == "class") ? "." : "#"
          "#{owner}#{separator}#{name}"
        end

        def calculate_arity(parameters)
          return 0 if parameters.nil? || parameters.empty?

          required_count = 0
          optional_count = 0
          has_rest = false
          has_keywords = false

          parameters.each do |param|
            # Handle both :kind and :type fields
            param_type = param[:kind] || param[:type]
            case param_type
            when "req", "required"
              required_count += 1
            when "opt", "optional"
              optional_count += 1
            when "rest"
              has_rest = true
            when "keyreq", "key", "keyopt", "keyrest"
              has_keywords = true
            end
          end

          # Ruby arity convention:
          # - Fixed args only: return count
          # - With optional/rest: return -(required_count + 1)
          # - Keywords don't count towards arity in Ruby
          if optional_count > 0 || has_rest
            -(required_count + 1)
          elsif has_keywords && required_count == 0
            -1
          else
            required_count
          end
        end

        def normalize_parameters(parameters)
          return [] if parameters.nil?

          parameters.map do |param|
            {
              kind: normalize_param_kind(param[:kind]),
              name: param[:name],
              default: param[:default]
            }
          end
        end

        def normalize_param_kind(kind)
          case kind
          when "required" then "req"
          when "optional" then "opt"
          else kind
          end
        end

        def snake_case(name)
          name
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end

        def infer_visibility(name, explicit_visibility)
          return explicit_visibility if explicit_visibility

          # Names starting with _ are typically private
          if name.start_with?("_")
            "private"
          else
            "public"
          end
        end
      end
    end
  end
end
