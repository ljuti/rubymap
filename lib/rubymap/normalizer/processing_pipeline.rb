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
          AttachMetadataStep.new,
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

    # Step 3: Attach metadata (patterns, attributes, class_variables, aliases)
    # to already-normalized classes and modules by name lookup.
    class AttachMetadataStep < PipelineStep
      def call(context)
        return unless context.extracted_data

        attach_patterns(context)
        attach_attributes(context)
        attach_class_variables(context)
        attach_aliases(context)
      end

      private

      def attach_patterns(context)
        patterns = context.extracted_data[:patterns] || []
        return if patterns.empty?

        patterns.each do |pattern|
          target = pattern[:target]
          next unless target

          normalized = find_symbol(context.result, target)
          next unless normalized

          normalized.patterns ||= []
          normalized.patterns << pattern
        end
      end

      def attach_attributes(context)
        attrs = context.extracted_data[:attributes] || []
        return if attrs.empty?

        attrs.each do |attr_data|
          namespace = attr_data[:namespace]
          next unless namespace

          normalized = find_symbol(context.result, namespace)
          next unless normalized

          normalized.attributes ||= []
          normalized.attributes << attr_data
        end
      end

      def attach_class_variables(context)
        class_vars = context.extracted_data[:class_variables] || []
        return if class_vars.empty?

        class_vars.each do |cv|
          namespace = cv[:namespace]
          next unless namespace

          normalized = find_symbol(context.result, namespace)
          next unless normalized

          normalized.class_variables ||= []
          normalized.class_variables << cv
        end
      end

      def attach_aliases(context)
        aliases = context.extracted_data[:aliases] || []
        return if aliases.empty?

        aliases.each do |aliaz|
          namespace = aliaz[:namespace]
          next unless namespace

          normalized = find_symbol(context.result, namespace)
          next unless normalized

          normalized.aliases ||= []
          normalized.aliases << aliaz
        end
      end

      def find_symbol(result, name)
        result.classes.find { |c| c.name == name } || result.modules.find { |m| m.name == name }
      end
    end

    # Step 4: Resolve relationships
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

    # Step 5: Deduplicate symbols
    class DeduplicateSymbolsStep < PipelineStep
      def call(context)
        deduplicator = context.container.get(:deduplicator)
        deduplicator.deduplicate_symbols(context.result)
      end
    end

    # Step 6: Format output
    class FormatOutputStep < PipelineStep
      def call(context)
        formatter = context.container.get(:output_formatter)
        formatter.format(context.result)
        context.result.errors = context.errors
      end
    end
  end
end
