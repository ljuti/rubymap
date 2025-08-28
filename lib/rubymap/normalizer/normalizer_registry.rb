# frozen_string_literal: true

require_relative 'normalizers/name_normalizer'
require_relative 'normalizers/visibility_normalizer'
require_relative 'normalizers/location_normalizer'
require_relative 'normalizers/parameter_normalizer'
require_relative 'calculators/arity_calculator'
require_relative 'calculators/confidence_calculator'

module Rubymap
  class Normalizer
    # Registry for all normalization strategies - implements dependency injection
    class NormalizerRegistry
      attr_reader :name_normalizer, :visibility_normalizer, :location_normalizer,
                  :parameter_normalizer, :arity_calculator, :confidence_calculator

      def initialize
        @name_normalizer = Normalizers::NameNormalizer.new
        @visibility_normalizer = Normalizers::VisibilityNormalizer.new
        @location_normalizer = Normalizers::LocationNormalizer.new
        @parameter_normalizer = Normalizers::ParameterNormalizer.new
        @arity_calculator = Calculators::ArityCalculator.new
        @confidence_calculator = Calculators::ConfidenceCalculator.new
      end
    end
  end
end