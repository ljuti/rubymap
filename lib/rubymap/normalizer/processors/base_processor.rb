# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Base class implementing Template Method pattern for symbol processing
      # Provides common processing pipeline with hooks for customization
      class BaseProcessor
        def initialize(symbol_id_generator:, provenance_tracker:, normalizers:)
          @symbol_id_generator = symbol_id_generator
          @provenance_tracker = provenance_tracker
          @normalizers = normalizers
        end

        # Template method - defines processing pipeline
        def process(raw_data, result, errors)
          processed_items = []

          raw_data.each do |item_data|
            next unless validate_item(item_data, errors)

            begin
              processed_item = normalize_item(item_data)
              processed_items << processed_item
              add_to_result(processed_item, result)
              post_process_item(processed_item, item_data, result)
            rescue => e
              add_processing_error(e.message, item_data, errors)
            end
          end

          processed_items
        end

        protected

        attr_reader :symbol_id_generator, :provenance_tracker, :normalizers

        # Hook methods for subclasses to implement
        def validate_item(data, errors)
          if data[:name].nil?
            add_validation_error("missing required field: name", data, errors)
            return false
          end
          validate_specific(data, errors)
        end

        def validate_specific(data, errors)
          true # Override in subclasses for specific validation
        end

        def normalize_item(data)
          raise NotImplementedError, "Subclasses must implement #normalize_item"
        end

        def add_to_result(item, result)
          raise NotImplementedError, "Subclasses must implement #add_to_result"
        end

        def post_process_item(item, raw_data, result)
          # Override in subclasses if needed
        end

        # Common helper methods
        def create_provenance(data)
          provenance_tracker.create_provenance(
            sources: [data[:source] || DATA_SOURCES[:inferred]],
            confidence: normalizers.confidence_calculator.calculate(data)
          )
        end

        def add_validation_error(message, data, errors)
          errors << NormalizedError.new(
            type: "validation",
            message: message,
            data: data
          )
        end

        def add_processing_error(message, data, errors)
          errors << NormalizedError.new(
            type: "processing",
            message: message,
            data: data
          )
        end
      end
    end
  end
end
