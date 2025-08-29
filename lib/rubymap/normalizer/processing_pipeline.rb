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
        return if raw_data.nil? || !raw_data.is_a?(Hash)

        processor_factory = container.get(:processor_factory)

        # Process in deterministic order
        processor_factory.create_class_processor.process(raw_data[:classes] || [], result, errors)
        processor_factory.create_module_processor.process(raw_data[:modules] || [], result, errors)
        processor_factory.create_method_processor.process(raw_data[:methods] || [], result, errors)
        processor_factory.create_method_call_processor.process(raw_data[:method_calls] || [], result, errors)

        # Index processed symbols
        index_symbols(result)

        # Process mixins last
        processor_factory.create_mixin_processor.process(raw_data[:mixins] || [], result, errors, [])
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
    end
  end
end
