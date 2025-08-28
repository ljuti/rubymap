# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Symbol index for fast lookups following SRP
    class SymbolIndex
      def initialize
        @index = {}
      end

      def add(symbol)
        @index[symbol.fqname] = symbol
        @index[symbol.name] = symbol unless symbol.fqname == symbol.name
      end

      def find(name)
        @index[name]
      end

      def clear
        @index.clear
      end

      def find_parent_class(class_name)
        symbol = find(class_name)
        return nil unless symbol&.respond_to?(:superclass)

        symbol.superclass
      end

      private

      attr_reader :index
    end
  end
end
