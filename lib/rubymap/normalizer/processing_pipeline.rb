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
    # Single Responsibility: Adapt input to symbol data format
    class ExtractSymbolsStep < PipelineStep
      def call(context)
        adapter = context.container.get(:input_adapter)
        context.extracted_data = adapter.adapt(context.input)
      end
    end

    # Step 2: Process symbols through processors
    class ProcessSymbolsStep < PipelineStep
      # Define processors in order with their data keys
      PROCESSORS = [
        [:class_processor, :classes],
        [:module_processor, :modules],
        [:method_processor, :methods],
        [:method_call_processor, :method_calls]
      ].freeze

      def call(context)
        return unless context.extracted_data
        
        processor_factory = context.container.get(:processor_factory)
        
        # Process all symbol types
        PROCESSORS.each do |processor_type, data_key|
          processor = processor_factory.send("create_#{processor_type}")
          data = context.extracted_data[data_key] || []
          processor.process(data, context.result, context.errors)
        end
        
        # Index symbols
        index_symbols(context)
        
        # Process mixins after indexing
        processor = processor_factory.create_mixin_processor
        mixins = context.extracted_data[:mixins] || []
        processor.process(mixins, context.result, context.errors)
      end

      private

      def index_symbols(context)
        symbol_index = context.container.get(:symbol_index)
        
        (context.result.classes + context.result.modules).each do |symbol|
          symbol_index.add(symbol)
        end
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

