# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Normalizers
      # Handles parameter normalization following Strategy pattern
      class ParameterNormalizer
        def normalize(params)
          return [] unless params

          # Handle case where params is not an array (e.g., a malformed string)
          params = Array(params) unless params.is_a?(Array)

          params.map do |param|
            case param
            when String
              {name: param, type: "required"}
            when Hash
              param
            else
              {name: param.to_s, type: "required"}
            end
          end
        end
      end
    end
  end
end
