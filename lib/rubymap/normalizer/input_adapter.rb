# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Adapts various input formats into a consistent symbol data structure
    # Single Responsibility: Convert input to normalized symbol collections
    class InputAdapter
      SYMBOL_TYPES = [:classes, :modules, :methods, :method_calls, :mixins, :attributes, :dependencies, :patterns, :class_variables, :aliases].freeze
      def adapt(input)
        case input
        when Hash
          normalize_hash(input)
        when ExtractorResult
          normalize_extractor_result(input)
        else
          empty_data
        end
      end

      private

      def normalize_hash(hash)
        result = SYMBOL_TYPES.each_with_object({}) do |type, data_result|
          value = hash[type]
          data_result[type] = case value
          when nil then []
          when Array then value
          else [value]
          end
        end
        # Merge method_calls from hash with those derived from methods' calls_made
        derived = derive_method_calls(result[:methods])
        result[:method_calls] = (result[:method_calls] + derived).uniq
        result
      end

      def normalize_extractor_result(result)
        # Use the ExtractorResult's built-in conversion method
        data = result.to_h
        methods = data[:methods] || []
        {
          classes: data[:classes] || [],
          modules: data[:modules] || [],
          methods: methods,
          method_calls: derive_method_calls(methods),
          mixins: data[:mixins] || [],
          attributes: data[:attributes] || [],
          dependencies: data[:dependencies] || [],
          patterns: data[:patterns] || [],
          class_variables: data[:class_variables] || [],
          aliases: data[:aliases] || []
        }
      end

      def empty_data
        SYMBOL_TYPES.each_with_object({}) do |type, result|
          result[type] = []
        end
      end

      def derive_method_calls(methods)
        return [] unless methods.is_a?(Array) && !methods.empty?

        methods.flat_map do |method|
          calls = method[:calls_made] || method["calls_made"] || []
          next [] if calls.empty?

          owner = method[:owner] || method["owner"]
          name = method[:name] || method["name"]
          scope = method[:scope] || method["scope"] || "instance"

          separator = (scope == "class") ? "." : "#"
          from = "#{owner}#{separator}#{name}"

          calls.map do |call|
            {from: from, to: build_to(call), type: "method_call"}
          end
        end
      end

      def build_to(call)
        receiver = call[:receiver] || call["receiver"]
        method = call[:method] || call["method"]
        if receiver.is_a?(Array) && !receiver.empty?
          "#{receiver.join(".")}.#{method}"
        elsif method
          method.to_s
        else
          "unknown"
        end
      end

      # Duck typing check for Extractor::Result
      class ExtractorResult
        def self.===(obj)
          obj.respond_to?(:classes) && obj.respond_to?(:modules)
        end
      end
    end
  end
end
