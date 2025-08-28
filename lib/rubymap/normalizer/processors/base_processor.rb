# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Base class for all symbol processors following Strategy pattern
      # Defines common interface and shared behavior for processing different symbol types
      class BaseProcessor
        def initialize(symbol_id_generator:, provenance_tracker:, normalizers:)
          @symbol_id_generator = symbol_id_generator
          @provenance_tracker = provenance_tracker
          @normalizers = normalizers
        end

        # Template method - subclasses must implement this
        def process(raw_data, result)
          raise NotImplementedError, "Subclasses must implement #process"
        end

        # Template method - subclasses must implement validation
        def validate(data)
          raise NotImplementedError, "Subclasses must implement #validate"
        end

        protected

        attr_reader :symbol_id_generator, :provenance_tracker, :normalizers

        def add_validation_error(message, data, errors)
          error = NormalizedError.new(
            type: "validation",
            message: message,
            data: data
          )
          errors << error
        end
      end
    end
  end
end
