# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Service container for dependency injection - eliminates complex constructor wiring
    # Implements Service Locator pattern to manage component lifecycle
    class ServiceContainer
      def initialize
        @services = {}
        @factories = {}
        register_factories
      end

      def get(service_name)
        @services[service_name] ||= create_service(service_name)
      end

      def register(service_name, instance)
        @services[service_name] = instance
      end

      private

      def create_service(service_name)
        factory = @factories[service_name]
        raise ArgumentError, "Unknown service: #{service_name}" unless factory

        factory.call
      end

      def register_factories
        # Core services
        @factories[:symbol_id_generator] = -> { SymbolIdGenerator.new }
        @factories[:provenance_tracker] = -> { ProvenanceTracker.new }
        @factories[:symbol_index] = -> { SymbolIndex.new }
        @factories[:normalizer_registry] = -> { NormalizerRegistry.new }

        # Symbol finder service
        @factories[:symbol_finder] = -> { SymbolFinder.new(get(:symbol_index)) }

        # Processing services
        @factories[:processor_factory] = -> {
          ProcessorFactory.new(
            get(:symbol_id_generator),
            get(:provenance_tracker),
            get(:normalizer_registry)
          )
        }

        @factories[:resolver_factory] = -> {
          ResolverFactory.new(get(:symbol_finder))
        }

        # Deduplication services
        @factories[:merge_strategy] = -> {
          Deduplication::MergeStrategy.new(
            get(:provenance_tracker),
            get(:normalizer_registry).visibility_normalizer
          )
        }

        @factories[:deduplicator] = -> {
          Deduplication::Deduplicator.new(get(:merge_strategy))
        }

        # Output services
        @factories[:output_formatter] = -> { Output::DeterministicFormatter.new }
      end
    end
  end
end
