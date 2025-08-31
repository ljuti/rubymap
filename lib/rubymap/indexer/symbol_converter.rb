# frozen_string_literal: true

module Rubymap
  class Indexer
    # Utility class for converting various data types to normalized hash format.
    #
    # This class encapsulates the logic for converting objects that don't have
    # their own conversion methods, following the Tell, Don't Ask principle.
    # It serves as a fallback for backward compatibility.
    #
    # @example Converting a symbol object
    #   converter = SymbolConverter.new
    #   hash = converter.normalize_symbol(symbol_object)
    #
    class SymbolConverter
      # Convert a symbol object to normalized hash format
      #
      # @param symbol [Object] The object to convert
      # @return [Hash] Normalized hash representation, or empty hash if conversion fails
      def normalize_symbol(symbol)
        # Handle nil input
        return {} if symbol.nil?

        # If it's already a hash with the expected structure, return it
        if symbol.is_a?(Hash)
          # Only return if it has expected symbol keys
          if symbol[:name] || symbol[:fqname]
            return symbol
          else
            # This is not a symbol hash, return empty
            return {}
          end
        end

        # Convert struct to hash if possible
        if symbol.respond_to?(:to_h)
          begin
            hash = symbol.to_h
            # Only use to_h result if it has expected symbol keys
            if hash.is_a?(Hash) && (hash[:name] || hash[:fqname])
              return hash
            end
          rescue
            # Fall through if to_h fails
          end
        end

        # Extract fields manually from objects
        result = {}
        [:name, :fqname, :type, :superclass, :dependencies, :mixins, :file, :line, :owner].each do |field|
          if symbol.respond_to?(field)
            result[field] = symbol.send(field)
          end
        end

        # Only return if we actually got a name
        (result[:name] || result[:fqname]) ? result : {}
      end

      # Convert array of symbols, using Array() for safety
      #
      # @param data [Array, Object] Data to convert to array and normalize
      # @return [Array<Hash>] Array of normalized symbol hashes
      def normalize_symbol_array(data)
        Array(data).map { |item| normalize_symbol(item) }
      end
    end
  end
end
