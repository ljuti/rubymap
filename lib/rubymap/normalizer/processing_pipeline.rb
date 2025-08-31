# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Improved processing pipeline with better testability and reduced coupling
    # Uses Strategy pattern and dependency injection for flexibility
    class ProcessingPipeline
      attr_reader :steps

      def initialize(container)
        @container = container
        @steps = build_default_steps
      end

      def execute(raw_data)
        context = build_context(raw_data)
        
        steps.each do |step|
          step.call(context)
        end
        
        context.result
      end

      # Allow customization of pipeline steps for testing and flexibility
      def with_steps(custom_steps)
        @steps = custom_steps
        self
      end

      private

      attr_reader :container

      def build_context(raw_data)
        PipelineContext.new(
          input: raw_data,
          result: create_result,
          container: container
        )
      end

      def create_result
        NormalizedResult.new(
          schema_version: SCHEMA_VERSION,
          normalizer_version: NORMALIZER_VERSION,
          normalized_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end

      def build_default_steps
        [
          ExtractSymbolsStep.new,
          ProcessSymbolsStep.new,
          ResolveRelationshipsStep.new,
          DeduplicateSymbolsStep.new,
          FormatOutputStep.new
        ]
      end
    end

    # Context object that flows through the pipeline
    class PipelineContext
      attr_accessor :input, :result, :errors, :container, :extracted_data

      def initialize(input:, result:, container:)
        @input = input
        @result = result
        @container = container
        @errors = []
      end
    end

    # Base class for pipeline steps
    class PipelineStep
      def call(context)
        raise NotImplementedError
      end
    end

    # Step 1: Extract symbols from input
    class ExtractSymbolsStep < PipelineStep
      def call(context)
        context.extracted_data = extract_symbol_data(context.input)
      end

      private

      def extract_symbol_data(raw_data)
        return empty_symbol_data unless raw_data
        return extract_from_hash(raw_data) if raw_data.is_a?(Hash)
        return extract_from_result(raw_data) if extractor_result?(raw_data)
        empty_symbol_data
      end

      def extract_from_hash(raw_data)
        {
          classes: raw_data[:classes] || [],
          modules: raw_data[:modules] || [],
          methods: raw_data[:methods] || [],
          method_calls: raw_data[:method_calls] || [],
          mixins: raw_data[:mixins] || []
        }
      end

      def extract_from_result(raw_data)
        {
          classes: convert_to_hashes(raw_data.classes || []),
          modules: convert_to_hashes(raw_data.modules || []),
          methods: convert_to_hashes(raw_data.methods || []),
          method_calls: [],
          mixins: convert_to_hashes(raw_data.mixins || [])
        }
      end

      def empty_symbol_data
        {
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        }
      end

      def extractor_result?(raw_data)
        raw_data.respond_to?(:classes) && raw_data.respond_to?(:modules)
      end

      def convert_to_hashes(items)
        return items if items.empty?
        return items if items.first.is_a?(Hash)
        items.map(&:to_h)
      end
    end

    # Step 2: Process symbols through processors
    class ProcessSymbolsStep < PipelineStep
      def call(context)
        return unless context.extracted_data
        
        processor_factory = context.container.get(:processor_factory)
        
        # Process main symbols
        process_main_symbols(processor_factory, context)
        
        # Index symbols
        index_symbols(context)
        
        # Process mixins (after indexing)
        process_mixins(processor_factory, context)
      end

      private

      def process_main_symbols(factory, context)
        data = context.extracted_data
        
        factory.create_class_processor.process(data[:classes], context.result, context.errors)
        factory.create_module_processor.process(data[:modules], context.result, context.errors)
        factory.create_method_processor.process(data[:methods], context.result, context.errors)
        factory.create_method_call_processor.process(data[:method_calls], context.result, context.errors)
      end

      def index_symbols(context)
        symbol_index = context.container.get(:symbol_index)
        
        (context.result.classes + context.result.modules).each do |symbol|
          symbol_index.add(symbol)
        end
      end

      def process_mixins(factory, context)
        mixins = context.extracted_data[:mixins] || []
        factory.create_mixin_processor.process(mixins, context.result, context.errors, [])
      end
    end

    # Step 3: Resolve relationships
    class ResolveRelationshipsStep < PipelineStep
      # Make resolvers configurable for better testability
      RESOLVER_TYPES = [
        :namespace_resolver,
        :inheritance_resolver,
        :cross_reference_resolver,
        :mixin_method_resolver
      ].freeze

      def call(context)
        resolver_factory = context.container.get(:resolver_factory)
        
        RESOLVER_TYPES.each do |resolver_type|
          resolver = resolver_factory.send("create_#{resolver_type}")
          resolver.resolve(context.result)
        end
      end
    end

    # Step 4: Deduplicate symbols
    class DeduplicateSymbolsStep < PipelineStep
      def call(context)
        deduplicator = context.container.get(:deduplicator)
        deduplicator.deduplicate_symbols(context.result)
      end
    end

    # Step 5: Format output
    class FormatOutputStep < PipelineStep
      def call(context)
        formatter = context.container.get(:output_formatter)
        formatter.format(context.result)
        context.result.errors = context.errors
      end
    end
  end
end

