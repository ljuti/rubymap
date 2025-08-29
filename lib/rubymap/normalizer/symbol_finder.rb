# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Centralized symbol finding logic - eliminates duplication across components
    # Implements Strategy pattern for different lookup strategies
    class SymbolFinder
      def initialize(symbol_index)
        @symbol_index = symbol_index
      end

      def find_symbol(name, result = nil)
        # Try index first for fast lookup
        symbol = @symbol_index.find(name)
        return symbol if symbol

        # Fallback to linear search if result provided
        return nil unless result

        find_in_collections(name, result)
      end

      def find_class(name, result)
        result.classes.find { |c| matches?(c, name) }
      end

      def find_module(name, result)
        result.modules.find { |m| matches?(m, name) }
      end

      def find_class_or_module(name, result)
        find_class(name, result) || find_module(name, result)
      end

      private

      attr_reader :symbol_index

      def find_in_collections(name, result)
        result.classes.find { |c| matches?(c, name) } ||
          result.modules.find { |m| matches?(m, name) }
      end

      def matches?(symbol, name)
        symbol.fqname == name || symbol.name == name
      end
    end
  end
end
