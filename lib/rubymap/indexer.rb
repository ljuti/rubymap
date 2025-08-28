# frozen_string_literal: true

require "set"
require_relative "indexer/indexed_result"
require_relative "indexer/graph"
require_relative "indexer/symbol_index"
require_relative "indexer/search_engine"
require_relative "indexer/query_interface"

module Rubymap
  # Builds searchable indexes and relationship graphs from enriched Ruby codebase data
  # Enables fast symbol lookup, dependency tracking, and code navigation
  class Indexer
    class InvalidDataError < StandardError; end

    def initialize(config = {})
      @config = default_config.merge(config)
    end

    # Main entry point - builds indexes from enriched data
    def build(enriched_data)
      validate_input!(enriched_data)
      
      result = IndexedResult.new
      result.source_data = enriched_data
      
      # Build symbol index for fast lookups
      build_symbol_index(result, enriched_data)
      
      # Build relationship graphs
      build_inheritance_graph(result, enriched_data)
      build_dependency_graph(result, enriched_data)
      build_method_call_graph(result, enriched_data)
      build_mixin_graph(result, enriched_data)
      
      # Detect issues
      detect_circular_dependencies(result)
      detect_missing_references(result, enriched_data)
      
      # Set up query interface
      result.setup_query_interface
      
      result
    end

    # Load a previously saved index
    def self.load(file_path)
      raise "File not found: #{file_path}" unless File.exist?(file_path)
      
      data = File.read(file_path)
      IndexedResult.deserialize(data)
    end

    private

    def default_config
      {
        enable_caching: true,
        max_search_results: 100,
        fuzzy_threshold: 0.7,
        performance_mode: false
      }
    end

    def validate_input!(data)
      unless data.is_a?(Hash) || data.respond_to?(:classes)
        raise InvalidDataError, "Expected Hash or enriched result, got #{data.class}"
      end

      # Allow enriched result objects (but not plain hashes that happen to have these methods)
      if !data.is_a?(Hash) && data.respond_to?(:classes)
        return true
      end

      # For hashes, require at least one of the expected keys
      if data.is_a?(Hash)
        valid_keys = [:classes, :methods, :modules, :method_calls]
        has_valid_key = valid_keys.any? { |key| data.key?(key) }
        
        unless has_valid_key
          raise InvalidDataError, "Missing required keys: must have at least one of classes, methods, modules, or method_calls"
        end
      end

      true
    end

    def build_symbol_index(result, data)
      classes = extract_classes(data)
      methods = extract_methods(data) 
      modules = extract_modules(data)
      
      # Index all symbols for fast lookup
      (classes + methods + modules).each do |symbol|
        # Only add symbols that have a name and are not empty hashes
        if symbol.is_a?(Hash) && !symbol.empty? && (symbol[:name] || symbol[:fqname])
          result.symbol_index.add(symbol)
        end
      end
    end

    def build_inheritance_graph(result, data)
      classes = extract_classes(data)
      
      classes.each do |klass|
        name = klass[:fqname] || klass[:name]
        result.inheritance_graph.add_node(name, klass)
        
        if klass[:superclass]
          # Note: In Ruby inheritance, child inherits from parent
          # So edge goes from child to parent
          result.inheritance_graph.add_edge(
            name,
            klass[:superclass],
            type: "inherits"
          )
        end
      end
      
      # Calculate depths
      result.inheritance_graph.calculate_depths
    end

    def build_dependency_graph(result, data)
      classes = extract_classes(data)
      
      classes.each do |klass|
        name = klass[:fqname] || klass[:name]
        result.dependency_graph.add_node(name, klass)
        
        dependencies = klass[:dependencies] || []
        dependencies.each do |dep|
          result.dependency_graph.add_edge(name, dep, type: "depends_on")
        end
      end
    end

    def build_method_call_graph(result, data)
      method_calls = data[:method_calls] || []
      
      method_calls.each do |call|
        from = call[:from]
        to = call[:to]
        frequency = call[:frequency] || 1
        
        result.method_call_graph.add_node(from, {type: "method"})
        result.method_call_graph.add_node(to, {type: "method"})
        result.method_call_graph.add_edge(from, to, 
          type: "calls",
          weight: frequency
        )
      end
    end

    def build_mixin_graph(result, data)
      classes = extract_classes(data)
      
      classes.each do |klass|
        name = klass[:fqname] || klass[:name]
        mixins = klass[:mixins] || []
        
        mixins.each do |mixin|
          module_name = mixin[:module] || mixin["module"]
          mixin_type = mixin[:type] || mixin["type"] || "include"
          
          edge_type = case mixin_type
                      when "include" then "includes"
                      when "extend" then "extends"
                      when "prepend" then "prepends"
                      else mixin_type
                      end
          
          result.mixin_graph.add_edge(name, module_name, type: edge_type)
        end
      end
    end

    def detect_circular_dependencies(result)
      result.circular_dependencies = result.dependency_graph.find_cycles
    end

    def detect_missing_references(result, data)
      all_symbols = result.symbol_index.all_names
      
      # Check superclasses
      extract_classes(data).each do |klass|
        if klass[:superclass] && !all_symbols.include?(klass[:superclass])
          result.missing_references << MissingReference.new(
            symbol: klass[:superclass],
            referenced_by: klass[:fqname] || klass[:name],
            reference_type: "superclass"
          )
        end
        
        # Check dependencies
        (klass[:dependencies] || []).each do |dep|
          unless all_symbols.include?(dep)
            result.missing_references << MissingReference.new(
              symbol: dep,
              referenced_by: klass[:fqname] || klass[:name],
              reference_type: "dependency"
            )
          end
        end
      end
    end

    def extract_classes(data)
      # Check if it's an enriched result object (not a hash)
      if !data.is_a?(Hash) && data.respond_to?(:classes)
        # Convert enriched objects to hashes if needed
        Array(data.classes).map { |c| normalize_symbol(c) }
      else
        Array(data[:classes]).map { |c| normalize_symbol(c) }
      end
    end

    def extract_methods(data)
      # Check if it's an enriched result object (not a hash)
      if !data.is_a?(Hash) && data.respond_to?(:methods)
        Array(data.methods).map { |m| normalize_symbol(m) }
      else
        Array(data[:methods]).map { |m| normalize_symbol(m) }
      end
    end

    def extract_modules(data)
      # Check if it's an enriched result object (not a hash)
      if !data.is_a?(Hash) && data.respond_to?(:modules)
        Array(data.modules).map { |m| normalize_symbol(m) }
      else
        Array(data[:modules]).map { |m| normalize_symbol(m) }
      end
    end

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
      result[:name] || result[:fqname] ? result : {}
    end
  end
end