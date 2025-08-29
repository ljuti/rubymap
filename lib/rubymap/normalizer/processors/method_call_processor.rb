# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes method call symbols following SRP - handles only method call logic
      class MethodCallProcessor < BaseProcessor
        def process(method_calls, result, errors)
          method_calls.each do |call_data|
            normalized = normalize_method_call(call_data)
            result.method_calls << normalized if normalized
          end
        end

        def validate(data, errors)
          # Method calls have different validation requirements
          true
        end

        private

        def normalize_method_call(data)
          # Support both formats: {:caller, :calls} and {:from, :to}
          from = data[:caller] || data[:from]
          to = data[:calls] || data[:to]
          
          return nil unless from && to

          # If we already have the correct format, use it directly
          if data[:from] && data[:to]
            return NormalizedMethodCall.new(
              from: from,
              to: to,
              type: data[:type] || "method_call"
            )
          end

          target = resolve_method_call_target(to, from)
          call_type = determine_call_type(to, target)

          NormalizedMethodCall.new(
            from: from,
            to: target,
            type: call_type
          )
        end

        def determine_call_type(call_target, resolved_target = nil)
          case call_target
          when "super"
            "super_call"
          when /^[A-Z]/
            "class_method_call"
          when /^@/
            "instance_variable_access"
          else
            # Check if it's calling a private method
            if resolved_target && resolved_target =~ /#(validate_|_)/
              "private_method_call"
            else
              "instance_method_call"
            end
          end
        end

        def resolve_method_call_target(target, caller_context)
          if target == "super"
            # For super calls, resolve to parent method
            if caller_context =~ /^(.+)(#|\.)(.+)$/
              class_name = $1
              method_name = $3

              # Find parent class and construct target
              parent = find_parent_class(class_name)
              return "#{parent}##{method_name}" if parent
            end
            target
          elsif !/#|\./.match?(target)
            # If it's just a method name, append it to the caller's class
            if caller_context =~ /^(.+)(#|\.)/
              class_name = $1
              "#{class_name}##{target}"
            else
              target
            end
          else
            target
          end
        end

        def find_parent_class(class_name)
          # This would need access to symbol index - will be handled by resolver
          nil
        end
      end
    end
  end
end
