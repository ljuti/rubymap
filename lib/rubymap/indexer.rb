# frozen_string_literal: true

require_relative "indexer/indexed_result"
require_relative "indexer/graph"
require_relative "indexer/symbol_index"
require_relative "indexer/search_engine"
require_relative "indexer/query_interface"
require_relative "indexer/symbol_converter"

module Rubymap
  # Builds searchable indexes and relationship graphs from normalized codebase data.
  #
  # The Indexer creates efficient data structures for fast symbol lookup, dependency
  # analysis, and relationship traversal. It builds multiple specialized graphs
  # (inheritance, dependencies, method calls, mixins) and provides a query interface
  # for searching and navigation.
  #
  # @rubymap Creates searchable indexes and relationship graphs from code data
  #
  # @example Building indexes from normalized data
  #   normalizer = Rubymap::Normalizer.new
  #   normalized_data = normalizer.normalize(extraction_result)
  #
  #   indexer = Rubymap::Indexer.new
  #   indexed = indexer.build(normalized_data)
  #
  #   # Access various graphs and indexes
  #   indexed.symbol_index      # Fast symbol lookup
  #   indexed.inheritance_graph # Class hierarchy
  #   indexed.dependency_graph  # Dependency relationships
  #
  # @example Querying the indexed data
  #   indexed = indexer.build(normalized_data)
  #
  #   # Find symbols by name
  #   user_class = indexed.query.find_class("User")
  #
  #   # Navigate relationships
  #   indexed.inheritance_graph.ancestors_of("User")   # => ["ApplicationRecord", "ActiveRecord::Base"]
  #   indexed.dependency_graph.dependencies_of("User") # => ["EmailService", "Validator"]
  #
  # @example Detecting issues
  #   indexed = indexer.build(normalized_data)
  #
  #   indexed.circular_dependencies # => Detected circular dependency chains
  #   indexed.missing_references    # => References to undefined symbols
  #
  class Indexer
    class InvalidDataError < StandardError; end

    # Creates a new Indexer instance.
    #
    # @param config [Hash] Configuration options
    # @option config [Boolean] :enable_caching (true) Enable caching for repeated queries
    # @option config [Integer] :max_search_results (100) Maximum results for searches
    # @option config [Float] :fuzzy_threshold (0.7) Threshold for fuzzy matching
    # @option config [Boolean] :performance_mode (false) Optimize for speed over memory
    #
    # @example Custom configuration
    #   indexer = Rubymap::Indexer.new(
    #     enable_caching: false,
    #     fuzzy_threshold: 0.8
    #   )
    def initialize(config = {})
      @config = default_config.merge(config)
      @symbol_converter = SymbolConverter.new
    end

    # Builds comprehensive indexes from normalized or enriched data.
    #
    # Creates multiple data structures:
    # - Symbol index for O(1) lookup by name or ID
    # - Inheritance graph tracking class hierarchies
    # - Dependency graph for require/load relationships
    # - Method call graph for runtime interactions
    # - Mixin graph for module inclusions
    #
    # @param enriched_data [Hash, NormalizedResult, EnrichmentResult] Input data to index
    # @return [IndexedResult] Complete indexed representation with query interface
    # @raise [InvalidDataError] if input data format is invalid
    #
    # @example
    #   data = normalizer.normalize(extracted_data)
    #   indexed = indexer.build(data)
    #
    #   indexed.symbol_index.count        # => 150
    #   indexed.inheritance_graph.nodes    # => All classes with inheritance
    #   indexed.query.search("User")      # => Fuzzy search results
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

    # Loads a previously saved index from disk.
    #
    # @param file_path [String] Path to the saved index file
    # @return [IndexedResult] Deserialized index data
    # @raise [StandardError] if file does not exist
    #
    # @example
    #   # Save an index
    #   indexed = indexer.build(data)
    #   indexed.save("project.rubymap_idx")
    #
    #   # Load it later
    #   loaded = Rubymap::Indexer.load("project.rubymap_idx")
    #   loaded.query.find_class("User")  # Works as before
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
      method_calls = if !data.is_a?(Hash) && data.respond_to?(:method_calls)
        data.method_calls || []
      else
        data[:method_calls] || []
      end

      method_calls.each do |call|
        from = call[:from]
        to = call[:to]
        frequency = call[:frequency] || 1

        result.method_call_graph.add_node(from, {type: "method"})
        result.method_call_graph.add_node(to, {type: "method"})
        result.method_call_graph.add_edge(from, to,
          type: "calls",
          weight: frequency)
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
      # If it's an object with a to_h method, convert it first
      if !data.is_a?(Hash) && data.respond_to?(:to_h)
        hash_data = data.to_h
        @symbol_converter.normalize_symbol_array(hash_data[:classes])
      # If it's an object with classes method, use that
      elsif !data.is_a?(Hash) && data.respond_to?(:classes)
        @symbol_converter.normalize_symbol_array(data.classes)
      else
        @symbol_converter.normalize_symbol_array(data[:classes])
      end
    end

    def extract_methods(data)
      # If it's an object with a to_h method, convert it first
      if !data.is_a?(Hash) && data.respond_to?(:to_h)
        hash_data = data.to_h
        @symbol_converter.normalize_symbol_array(hash_data[:methods])
      # If it's an object with methods method, use that
      elsif !data.is_a?(Hash) && data.respond_to?(:methods)
        @symbol_converter.normalize_symbol_array(data.methods)
      else
        @symbol_converter.normalize_symbol_array(data[:methods])
      end
    end

    def extract_modules(data)
      # If it's an object with a to_h method, convert it first
      if !data.is_a?(Hash) && data.respond_to?(:to_h)
        hash_data = data.to_h
        @symbol_converter.normalize_symbol_array(hash_data[:modules])
      # If it's an object with modules method, use that
      elsif !data.is_a?(Hash) && data.respond_to?(:modules)
        @symbol_converter.normalize_symbol_array(data.modules)
      else
        @symbol_converter.normalize_symbol_array(data[:modules])
      end
    end
  end
end
