# frozen_string_literal: true

module Rubymap
  module Emitter
    module Formatters
      class DeterministicFormatter
        def format(data)
          case data
          when Hash
            format_hash(data)
          when Array
            format_array(data)
          else
            data
          end
        end

        private

        def format_hash(hash)
          # Sort keys deterministically
          sorted = hash.sort_by { |k, _v| k.to_s }.to_h
          
          # Recursively format values
          sorted.transform_values do |value|
            format(value)
          end.tap do |formatted|
            # Normalize timestamps if present
            normalize_timestamps!(formatted)
            
            # Sort arrays within hash
            sort_nested_arrays!(formatted)
          end
        end

        def format_array(array)
          # Format each element
          formatted = array.map { |item| format(item) }
          
          # Sort if array contains comparable elements
          if should_sort_array?(formatted)
            sort_array(formatted)
          else
            formatted
          end
        end

        def should_sort_array?(array)
          return false if array.empty?
          
          # Only sort arrays of hashes with consistent structure
          if array.all? { |item| item.is_a?(Hash) }
            # Check if all hashes have a sortable key
            sortable_keys = [:fqname, :name, :id, "fqname", "name", "id"]
            sortable_keys.any? { |key| array.all? { |item| item.key?(key) } }
          else
            false
          end
        end

        def sort_array(array)
          return array unless array.all? { |item| item.is_a?(Hash) }
          
          # Find the best key to sort by
          sort_key = find_sort_key(array)
          return array unless sort_key
          
          array.sort_by { |item| item[sort_key].to_s }
        end

        def find_sort_key(array)
          return nil if array.empty?
          
          # Priority order for sorting keys
          priority_keys = [:fqname, :name, :id, :chunk_id, :path,
                          "fqname", "name", "id", "chunk_id", "path"]
          
          first_item = array.first
          priority_keys.find { |key| first_item.key?(key) }
        end

        def normalize_timestamps!(hash)
          timestamp_keys = [:created_at, :updated_at, :generated_at, :mapping_date,
                           "created_at", "updated_at", "generated_at", "mapping_date"]
          
          timestamp_keys.each do |key|
            if hash.key?(key)
              hash[key] = normalize_timestamp(hash[key])
            end
          end
        end

        def normalize_timestamp(timestamp)
          return nil if timestamp.nil?
          
          # Convert to ISO8601 format for consistency
          case timestamp
          when Time
            timestamp.utc.iso8601
          when Date, DateTime
            timestamp.to_time.utc.iso8601
          when String
            # Already a string, ensure it's in ISO format
            begin
              Time.parse(timestamp).utc.iso8601
            rescue
              timestamp
            end
          else
            timestamp
          end
        end

        def sort_nested_arrays!(hash)
          hash.each do |key, value|
            case value
            when Array
              hash[key] = format_array(value)
            when Hash
              sort_nested_arrays!(value)
            end
          end
        end
      end
    end
  end
end