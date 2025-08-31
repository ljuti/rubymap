# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Processing pipeline that orchestrates the normalization process
    # Implements Chain of Responsibility pattern for processing steps
    class ProcessingPipeline
      def initialize(container)
        @container = container
      end

      def execute(raw_data)
        errors = []
        result = create_result

        # Execute processing steps in order
        process_symbols(raw_data, result, errors)
        resolve_relationships(result)
        deduplicate_symbols(result)
        format_output(result)

        result.errors = errors
        result
      end

      private

      attr_reader :container

      def create_result
        NormalizedResult.new(
          schema_version: SCHEMA_VERSION,
          normalizer_version: NORMALIZER_VERSION,
          normalized_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end

      def process_symbols(raw_data, result, errors)
        extracted_data = extract_symbol_data(raw_data)
        execute_processors(extracted_data, result, errors)
      end

      def resolve_relationships(result)
        resolver_factory = container.get(:resolver_factory)

        # Execute resolvers in dependency order
        resolver_factory.create_namespace_resolver.resolve(result)
        resolver_factory.create_inheritance_resolver.resolve(result)
        resolver_factory.create_cross_reference_resolver.resolve(result)
        resolver_factory.create_mixin_method_resolver.resolve(result)
      end

      def deduplicate_symbols(result)
        container.get(:deduplicator).deduplicate_symbols(result)
      end

      def format_output(result)
        container.get(:output_formatter).format(result)
      end

      def index_symbols(result)
        symbol_index = container.get(:symbol_index)

        (result.classes + result.modules).each do |symbol|
          symbol_index.add(symbol)
        end
      end

      # Extract symbol data from raw input, handling different input types
      def extract_symbol_data(raw_data)
        return create_empty_symbol_data unless raw_data
        return extract_from_hash(raw_data) if raw_data.is_a?(Hash)
        return extract_from_result(raw_data) if extractor_result?(raw_data)
        create_empty_symbol_data
      end

      # Extract symbol data from hash format
      def extract_from_hash(raw_data)
        {
          classes: raw_data[:classes] || [],
          modules: raw_data[:modules] || [],
          methods: raw_data[:methods] || [],
          method_calls: raw_data[:method_calls] || [],
          mixins: raw_data[:mixins] || []
        }
      end

      # Extract symbol data from Extractor::Result object
      def extract_from_result(raw_data)
        {
          classes: convert_to_hashes(raw_data.classes || []),
          modules: convert_to_hashes(raw_data.modules || []),
          methods: convert_to_hashes(raw_data.methods || []),
          method_calls: [], # Result doesn't have method_calls
          mixins: convert_to_hashes(raw_data.mixins || [])
        }
      end

      # Create empty symbol data for invalid input types
      def create_empty_symbol_data
        {
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        }
      end

      # Check if raw_data is an Extractor::Result object
      def extractor_result?(raw_data)
        raw_data.respond_to?(:classes) && raw_data.respond_to?(:modules)
      end

      # Execute all processors in the correct order
      def execute_processors(extracted_data, result, errors)
        processor_factory = container.get(:processor_factory)

        # Process main symbol types in deterministic order
        process_main_symbols(processor_factory, extracted_data, result, errors)
        
        # Index processed symbols
        index_symbols(result)
        
        # Process mixins last (they depend on other symbols being processed first)
        process_mixins(processor_factory, extracted_data[:mixins], result, errors)
      end

      # Process the main symbol types (classes, modules, methods, method_calls)
      def process_main_symbols(processor_factory, extracted_data, result, errors)
        processor_factory.create_class_processor.process(extracted_data[:classes], result, errors)
        processor_factory.create_module_processor.process(extracted_data[:modules], result, errors)
        processor_factory.create_method_processor.process(extracted_data[:methods], result, errors)
        processor_factory.create_method_call_processor.process(extracted_data[:method_calls], result, errors)
      end

      # Process mixins separately as they have special requirements
      def process_mixins(processor_factory, mixins, result, errors)
        processor_factory.create_mixin_processor.process(mixins, result, errors, [])
      end

      # Convert items to hashes using their to_h method if available
      def convert_to_hashes(items)
        return items if items.empty?
        return items if items.first.is_a?(Hash)
        items.map(&:to_h)
      end
    end
  end
end
