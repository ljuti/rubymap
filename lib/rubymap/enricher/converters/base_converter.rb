# frozen_string_literal: true

module Rubymap
  class Enricher
    module Converters
      # Base converter defining the interface for hash-to-struct conversion.
      #
      # This abstract base class implements the Strategy pattern, allowing different
      # conversion strategies for different entity types while maintaining a consistent
      # interface. Each converter is responsible for transforming hash data into
      # properly structured normalized objects.
      #
      # @abstract Subclass must implement #convert_single
      class BaseConverter
        # Converts an array of hash objects to normalized structs.
        #
        # @param hash_array [Array<Hash>] Array of hash objects to convert
        # @return [Array] Array of converted normalized structs
        def convert(hash_array)
          return [] if hash_array.nil? || hash_array.empty?

          hash_array.map do |hash_item|
            convert_item(hash_item)
          end
        end

        private

        # Converts a single hash or returns existing normalized object.
        #
        # @param item [Hash, Object] Hash to convert or existing normalized object
        # @return [Object] Normalized struct object
        def convert_item(item)
          return item if already_normalized?(item)

          convert_single(item)
        end

        # Checks if the item is already a normalized object of the expected type.
        #
        # @param item [Object] Object to check
        # @return [Boolean] True if already normalized
        # @abstract Subclass must implement this method
        def already_normalized?(item)
          raise NotImplementedError, "#{self.class} must implement #already_normalized?"
        end

        # Converts a single hash to a normalized struct.
        #
        # @param hash [Hash] Hash data to convert
        # @return [Object] Normalized struct object
        # @abstract Subclass must implement this method
        def convert_single(hash)
          raise NotImplementedError, "#{self.class} must implement #convert_single"
        end

        # Safely extracts a value from hash with default fallback.
        #
        # @param hash [Hash] Source hash
        # @param key [Symbol] Key to extract
        # @param default [Object] Default value if key doesn't exist
        # @return [Object] Value from hash or default
        def safe_extract(hash, key, default = nil)
          hash[key] || hash[key.to_s] || default
        end

        # Generates a symbol ID if not provided.
        #
        # @param hash [Hash] Source hash
        # @param prefix [String] Prefix for generated ID
        # @return [String] Symbol ID
        def ensure_symbol_id(hash, prefix)
          safe_extract(hash, :symbol_id) || "#{prefix}_#{safe_extract(hash, :name)}"
        end
      end
    end
  end
end
