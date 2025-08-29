# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Calculators
      # Calculates confidence scores following SRP
      class ConfidenceCalculator
        def calculate(data)
          # Don't guard against non-hash data to allow NoMethodError
          source = data[:source] || Normalizer::DATA_SOURCES[:inferred]
          base_confidence = case source
          when Normalizer::DATA_SOURCES[:rbs] then 0.95
          when Normalizer::DATA_SOURCES[:sorbet] then 0.90
          when Normalizer::DATA_SOURCES[:runtime] then 0.85
          when Normalizer::DATA_SOURCES[:yard] then 0.80
          when Normalizer::DATA_SOURCES[:static] then 0.75
          when Normalizer::DATA_SOURCES[:inferred] then 0.50
          else 0.50 # unknown source
          end

          # Boost confidence if location information is available
          if data[:location] && data[:location] != false && data[:location] != nil
            base_confidence += 0.05
          end

          # Reduce confidence if name is nil or empty string
          if data.key?(:name) && (data[:name].nil? || data[:name] == "")
            base_confidence -= 0.10
          end

          [base_confidence, 1.0].min
        end
      end
    end
  end
end
