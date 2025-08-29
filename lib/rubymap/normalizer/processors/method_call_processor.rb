# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes method call symbols using the new architecture
      class MethodCallProcessor < BaseProcessor
        # Override the base validation since method calls don't have a 'name' field
        def validate_item(data, errors)
          # Method calls are valid as long as they have some identifying data
          data[:method] || data[:from] || data[:caller]
        end

        def validate_specific(data, errors)
          # Method calls are optional data, minimal validation
          true
        end

        def normalize_item(data)
          # Handle multiple formats:
          # 1. { method: "save", receiver: "user" }
          # 2. { from: "UserController#create", to: "User#save" }
          # 3. { caller: "UserController", calls: "save" }

          if data[:method]
            # Format 1: method and receiver
            build_from_method_receiver(data)
          elsif data[:from] && data[:to]
            # Format 2: from and to
            CoreNormalizedMethodCall.new(
              from: data[:from],
              to: data[:to],
              type: data[:type] || "method_call"
            )
          elsif data[:caller] && data[:calls]
            # Format 3: caller and calls
            CoreNormalizedMethodCall.new(
              from: data[:caller],
              to: data[:calls],
              type: data[:type] || "method_call"
            )
          else
            nil
          end
        end

        def add_to_result(item, result)
          result.method_calls << item if item
        end

        private

        def build_from_method_receiver(data)
          # Build method call from method/receiver format
          to = data[:method]
          from = build_caller_context(data)

          CoreNormalizedMethodCall.new(
            from: from,
            to: to,
            type: determine_call_type(data[:receiver], to)
          )
        end

        def build_caller_context(data)
          # Try to build caller context from available data
          if data[:caller_method] && data[:caller_class]
            "#{data[:caller_class]}##{data[:caller_method]}"
          elsif data[:caller_class]
            data[:caller_class]
          elsif data[:caller_method]
            data[:caller_method]
          end
        end

        def determine_call_type(receiver, method_name)
          return "super" if method_name == "super"
          return "self" if receiver == "self"
          "method_call"
        end
      end
    end
  end
end
