# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Calculators
      # Calculates confidence scores following SRP
      class ConfidenceCalculator
        def calculate(data)
          source = data[:source] || Normalizer::DATA_SOURCES[:inferred]
          base_confidence = case source
          when Normalizer::DATA_SOURCES[:rbs] then 0.95
          when Normalizer::DATA_SOURCES[:sorbet] then 0.90
          when Normalizer::DATA_SOURCES[:yard] then 0.80
          when Normalizer::DATA_SOURCES[:runtime] then 0.85
          when Normalizer::DATA_SOURCES[:static] then 0.75
          else 0.50 # inferred
          end

          # Boost confidence if location information is available
          base_confidence += 0.05 if data[:location]

          # Reduce confidence if key information is missing
          base_confidence -= 0.10 if data[:name].nil? || data[:name].empty?

          [base_confidence, 1.0].min
        end
      end
    end
  end
end
