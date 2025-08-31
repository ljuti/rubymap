# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Adapts various input formats into a consistent symbol data structure
    # Single Responsibility: Convert input to normalized symbol collections
    class InputAdapter
      SYMBOL_TYPES = [:classes, :modules, :methods, :method_calls, :mixins].freeze
      
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
        SYMBOL_TYPES.each_with_object({}) do |type, result|
          value = hash[type]
          result[type] = case value
                         when nil then []
                         when Array then value
                         else [value]
                         end
        end
      end
      
      def normalize_extractor_result(result)
        # ExtractorResult should provide its data in the correct format
        # We just need to ensure all required keys are present
        {
          classes: result.classes || [],
          modules: result.modules || [],
          methods: result.methods || [],
          method_calls: [], # Extractor doesn't provide method_calls
          mixins: result.mixins || []
        }
      end
      
      def empty_data
        SYMBOL_TYPES.each_with_object({}) do |type, result|
          result[type] = []
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