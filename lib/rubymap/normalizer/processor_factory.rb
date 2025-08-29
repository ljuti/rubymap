# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Factory for creating processors with shared dependencies
    # Implements Factory Method pattern to eliminate processor creation complexity
    class ProcessorFactory
      def initialize(symbol_id_generator, provenance_tracker, normalizer_registry)
        @symbol_id_generator = symbol_id_generator
        @provenance_tracker = provenance_tracker
        @normalizer_registry = normalizer_registry
      end

      def create_class_processor
        Processors::ClassProcessor.new(
          symbol_id_generator: @symbol_id_generator,
          provenance_tracker: @provenance_tracker,
          normalizers: @normalizer_registry
        )
      end

      def create_module_processor
        Processors::ModuleProcessor.new(
          symbol_id_generator: @symbol_id_generator,
          provenance_tracker: @provenance_tracker,
          normalizers: @normalizer_registry
        )
      end

      def create_method_processor
        Processors::MethodProcessor.new(
          symbol_id_generator: @symbol_id_generator,
          provenance_tracker: @provenance_tracker,
          normalizers: @normalizer_registry
        )
      end

      def create_method_call_processor
        Processors::MethodCallProcessor.new(
          symbol_id_generator: @symbol_id_generator,
          provenance_tracker: @provenance_tracker,
          normalizers: @normalizer_registry
        )
      end

      def create_mixin_processor
        Processors::MixinProcessor.new(
          symbol_id_generator: @symbol_id_generator,
          provenance_tracker: @provenance_tracker,
          normalizers: @normalizer_registry
        )
      end
    end
  end
end
