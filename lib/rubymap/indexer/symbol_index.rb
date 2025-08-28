# frozen_string_literal: true

require "ostruct"

module Rubymap
  class Indexer
    # Fast symbol lookup index with various search capabilities
    class SymbolIndex
      def initialize
        @symbols = {}
        @by_type = Hash.new { |h, k| h[k] = [] }
        @by_namespace = Hash.new { |h, k| h[k] = [] }
        @by_file = Hash.new { |h, k| h[k] = [] }
      end

      def add(symbol_data)
        name = symbol_data[:fqname] || symbol_data[:name]
        return unless name

        symbol = create_symbol(symbol_data)

        @symbols[name] = symbol
        @by_type[symbol.type] << symbol

        if symbol.namespace && !symbol.namespace.empty?
          namespace_key = Array(symbol.namespace).join("::")
          @by_namespace[namespace_key] << symbol
        end

        if symbol.file
          @by_file[symbol.file] << symbol
        end
      end

      def update(symbol_data)
        name = symbol_data[:fqname] || symbol_data[:name]
        remove(name) if @symbols[name]
        add(symbol_data)
      end

      def remove(name)
        symbol = @symbols.delete(name)
        return unless symbol

        @by_type[symbol.type].delete(symbol)

        if symbol.namespace
          namespace_key = Array(symbol.namespace).join("::")
          @by_namespace[namespace_key].delete(symbol)
        end

        if symbol.file
          @by_file[symbol.file].delete(symbol)
        end
      end

      def find(name)
        @symbols[name]
      end

      def all
        @symbols.values
      end

      def all_names
        @symbols.keys
      end

      def search(pattern, options = {})
        results = case pattern
        when Regexp
          search_by_regexp(pattern)
        when String
          if options[:case_sensitive] == false
            search_case_insensitive(pattern)
          else
            search_by_string(pattern)
          end
        else
          all
        end

        # Apply filters
        results = filter_by_type(results, options[:type]) if options[:type]
        results = filter_by_namespace(results, options[:namespace]) if options[:namespace]
        results = filter_by_file_pattern(results, options[:file_pattern]) if options[:file_pattern]

        results
      end

      def to_h
        {
          symbols: @symbols.transform_values(&:to_h),
          by_type: @by_type.transform_values { |v| v.map(&:name) },
          by_namespace: @by_namespace.transform_values { |v| v.map(&:name) },
          by_file: @by_file.transform_values { |v| v.map(&:name) }
        }
      end

      def self.from_h(data)
        index = new

        data[:symbols].each do |name, symbol_hash|
          index.add(symbol_hash)
        end

        index
      end

      private

      def create_symbol(data)
        name = data[:fqname] || data[:name]

        # Extract namespace from fully qualified name
        namespace = if data[:namespace]
          data[:namespace]
        elsif name&.include?("::")
          parts = name.split("::")
          parts[0...-1]
        else
          []
        end

        OpenStruct.new(
          name: data[:name] || name&.split("::")&.last || name,
          fully_qualified_name: name,
          type: data[:type] || "unknown",
          namespace: namespace,
          file: data[:file],
          line: data[:line],
          location: data[:file] ? "#{data[:file]}:#{data[:line]}" : nil,
          superclass: data[:superclass],
          dependencies: data[:dependencies] || [],
          mixins: data[:mixins] || [],
          owner: data[:owner],
          raw_data: data
        )
      end

      def search_by_regexp(pattern)
        @symbols.values.select { |s| s.name =~ pattern || s.fully_qualified_name =~ pattern }
      end

      def search_by_string(str)
        return all if str.empty?

        @symbols.values.select do |s|
          s.name&.include?(str) || s.fully_qualified_name&.include?(str)
        end
      end

      def search_case_insensitive(str)
        return all if str.empty?

        lower_str = str.downcase
        @symbols.values.select do |s|
          s.name&.downcase&.include?(lower_str) ||
            s.fully_qualified_name&.downcase&.include?(lower_str)
        end
      end

      def filter_by_type(symbols, type)
        type_str = type.to_s
        symbols.select { |s| s.type == type_str }
      end

      def filter_by_namespace(symbols, namespace)
        symbols.select do |s|
          s.namespace == namespace ||
            Array(s.namespace).join("::") == namespace
        end
      end

      def filter_by_file_pattern(symbols, pattern)
        symbols.select { |s| s.file && s.file =~ pattern }
      end
    end
  end
end
