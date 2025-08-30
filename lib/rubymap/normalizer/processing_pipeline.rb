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
        return if raw_data.nil?

        processor_factory = container.get(:processor_factory)

        # Handle both Hash and Extractor::Result objects
        if raw_data.is_a?(Hash)
          classes = raw_data[:classes] || []
          modules = raw_data[:modules] || []
          methods = raw_data[:methods] || []
          method_calls = raw_data[:method_calls] || []
        elsif raw_data.respond_to?(:classes) && raw_data.respond_to?(:modules) && raw_data.respond_to?(:methods)
          # For Extractor::Result objects - convert to hashes
          classes = convert_to_hashes(raw_data.classes || [])
          modules = convert_to_hashes(raw_data.modules || [])
          methods = convert_to_hashes(raw_data.methods || [])
          method_calls = [] # Result doesn't have method_calls
        else
          # Handle invalid input types gracefully - return empty collections
          classes = []
          modules = []
          methods = []
          method_calls = []
        end

        # Process in deterministic order
        processor_factory.create_class_processor.process(classes, result, errors)
        processor_factory.create_module_processor.process(modules, result, errors)
        processor_factory.create_method_processor.process(methods, result, errors)
        processor_factory.create_method_call_processor.process(method_calls, result, errors)

        # Index processed symbols
        index_symbols(result)

        # Process mixins last
        if raw_data.is_a?(Hash)
          mixins = raw_data[:mixins] || []
        elsif raw_data.respond_to?(:mixins)
          mixins = convert_to_hashes(raw_data.mixins || [])
        else
          mixins = []
        end
        processor_factory.create_mixin_processor.process(mixins, result, errors, [])
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

      def convert_to_hashes(items)
        return items if items.empty? || items.first.is_a?(Hash)
        
        items.map do |item|
          # Convert objects to hashes by extracting their attributes
          hash = {}
          
          # Common attributes
          [:name, :type, :kind, :namespace, :superclass, :doc, :rubymap,
           :visibility, :receiver_type, :params, :parameters, :owner,
           :module_name, :target, :path, :constant, :value].each do |attr|
            if item.respond_to?(attr)
              value = item.send(attr)
              # Convert location objects to hashes
              if attr == :location && value && !value.is_a?(Hash)
                value = convert_location_to_hash(value)
              end
              # MixinProcessor expects :module, not :module_name
              key = attr == :module_name ? :module : attr
              hash[key] = value unless value.nil?
            end
          end
          
          hash
        end
      end

      def convert_location_to_hash(location)
        return nil unless location
        
        # Handle Prism::Location objects
        if location.respond_to?(:start_line)
          {
            line: location.start_line,
            column: location.respond_to?(:start_column) ? location.start_column : nil,
            end_line: location.respond_to?(:end_line) ? location.end_line : nil,
            end_column: location.respond_to?(:end_column) ? location.end_column : nil
          }.compact
        else
          location
        end
      end
    end
  end
end
