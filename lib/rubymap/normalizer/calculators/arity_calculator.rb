# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Calculators
      # Calculates method arity following SRP
      class ArityCalculator
        def calculate(parameters)
          return 0 unless parameters

          required = parameters.count { |p| p[:type] == "required" || p[:type] == "req" }
          optional = parameters.count { |p| p[:type] == "optional" || p[:type] == "opt" }
          rest = parameters.any? { |p| p[:type] == "rest" }

          rest ? -required - 1 : required + optional
        end
      end
    end
  end
end
