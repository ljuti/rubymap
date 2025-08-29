# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Factory for creating resolvers with shared dependencies
    # Implements Factory Method pattern for resolver creation
    class ResolverFactory
      def initialize(symbol_finder)
        @symbol_finder = symbol_finder
      end

      def create_namespace_resolver
        Resolvers::NamespaceResolver.new
      end

      def create_inheritance_resolver
        Resolvers::InheritanceResolver.new
      end

      def create_cross_reference_resolver
        Resolvers::CrossReferenceResolver.new(@symbol_finder)
      end

      def create_mixin_method_resolver
        Resolvers::MixinMethodResolver.new(@symbol_finder)
      end
    end
  end
end
