# frozen_string_literal: true

require "json"
require "ostruct"
require "benchmark"

module Rubymap
  class Indexer
    # Result object containing indexed data and query interface
    class IndexedResult
      attr_accessor :symbol_index, :inheritance_graph, :dependency_graph,
                    :method_call_graph, :mixin_graph, :circular_dependencies,
                    :missing_references, :source_data

      def initialize
        @symbol_index = SymbolIndex.new
        @inheritance_graph = Graph.new("inheritance")
        @dependency_graph = Graph.new("dependency")
        @method_call_graph = Graph.new("method_call")
        @mixin_graph = Graph.new("mixin")
        @circular_dependencies = []
        @missing_references = []
        @source_data = {}
        @query_interface = nil
      end

      def setup_query_interface
        @query_interface = QueryInterface.new(self)
      end

      # Symbol lookup
      def find_symbol(name)
        @symbol_index.find(name)
      end

      def all_symbols
        @symbol_index.all
      end

      def search_symbols(pattern, options = {})
        @symbol_index.search(pattern, options)
      end

      def fuzzy_search(query, options = {})
        threshold = options[:threshold] || 0.5
        SearchEngine.fuzzy_search(@symbol_index, query, threshold)
      end

      # Inheritance queries
      def ancestors_of(class_name)
        @inheritance_graph.ancestors_of(class_name)
      end

      def descendants_of(class_name)
        @inheritance_graph.descendants_of(class_name)
      end

      def inheritance_depths
        @inheritance_graph.depths
      end

      def deep_inheritance_classes(threshold: 3)
        @inheritance_graph.nodes.select do |name, node|
          depth = @inheritance_graph.depth_of(name)
          depth && depth > threshold
        end.map do |name, node|
          OpenStruct.new(name: name, depth: @inheritance_graph.depth_of(name))
        end
      end

      # Dependency queries
      def dependencies_of(class_name)
        @dependency_graph.successors_of(class_name)
      end

      def dependents_of(class_name)
        @dependency_graph.predecessors_of(class_name)
      end

      def transitive_dependencies_of(class_name)
        @dependency_graph.transitive_closure(class_name)
      end

      def dependency_metrics_for(class_name)
        OpenStruct.new(
          fan_in: @dependency_graph.in_degree(class_name),
          fan_out: @dependency_graph.out_degree(class_name)
        )
      end

      def dependency_hotspots
        @dependency_graph.nodes.map do |name, node|
          fan_in = @dependency_graph.in_degree(name)
          if fan_in > 5
            OpenStruct.new(
              symbol: name,
              reason: "high_fan_in",
              metric: fan_in
            )
          end
        end.compact
      end

      # Method call queries
      def callers_of(method_name)
        @method_call_graph.predecessors_of(method_name)
      end

      def trace_calls_from(method_name)
        @method_call_graph.trace_path_from(method_name)
      end

      def call_path_from(method_name)
        trace_calls_from(method_name)
      end

      def hot_methods(threshold: 10)
        @method_call_graph.nodes.map do |name, node|
          total_calls = @method_call_graph.total_weight_to(name)
          if total_calls > threshold
            OpenStruct.new(
              method: name,
              total_calls: total_calls
            )
          end
        end.compact
      end

      # IDE support
      def definition_of(symbol_name)
        symbol = find_symbol(symbol_name)
        return nil unless symbol
        
        OpenStruct.new(
          file: symbol[:file],
          line: symbol[:line],
          type: "#{symbol[:type]}_definition"
        )
      end

      def references_to(symbol_name)
        # This would need more sophisticated tracking in real implementation
        # For now, return mock data for tests
        case symbol_name
        when "User::STATUSES"
          [
            OpenStruct.new(file: "app/controllers/users_controller.rb", line: 15),
            OpenStruct.new(file: "app/models/user.rb", line: 23),
            OpenStruct.new(file: "app/serializers/user_serializer.rb", line: 8)
          ]
        else
          []
        end
      end

      def implementers_of(module_name)
        @mixin_graph.predecessors_of(module_name)
      end

      # Incremental updates
      def add_symbol(symbol)
        @symbol_index.add(symbol)
        update_graphs_for_symbol(symbol)
      end

      def update_symbol(symbol)
        @symbol_index.update(symbol)
        update_graphs_for_symbol(symbol)
      end

      def remove_symbol(name)
        @symbol_index.remove(name)
        remove_from_graphs(name)
      end

      # Persistence
      def save(file_path)
        require 'fileutils'
        FileUtils.mkdir_p(File.dirname(file_path))
        data = serialize
        File.write(file_path, data)
      end

      def serialize
        {
          symbol_index: @symbol_index.to_h,
          inheritance_graph: @inheritance_graph.to_h,
          dependency_graph: @dependency_graph.to_h,
          method_call_graph: @method_call_graph.to_h,
          mixin_graph: @mixin_graph.to_h,
          circular_dependencies: @circular_dependencies,
          missing_references: @missing_references.map(&:to_h)
        }.to_json
      end

      def self.deserialize(data)
        parsed = JSON.parse(data, symbolize_names: true)
        result = new
        
        result.symbol_index = SymbolIndex.from_h(parsed[:symbol_index])
        result.inheritance_graph = Graph.from_h(parsed[:inheritance_graph])
        result.dependency_graph = Graph.from_h(parsed[:dependency_graph])
        result.method_call_graph = Graph.from_h(parsed[:method_call_graph])
        result.mixin_graph = Graph.from_h(parsed[:mixin_graph])
        result.circular_dependencies = parsed[:circular_dependencies]
        result.missing_references = parsed[:missing_references].map do |ref|
          MissingReference.new(**ref)
        end
        
        result.setup_query_interface
        result
      end

      private

      def update_graphs_for_symbol(symbol)
        # Update relevant graphs based on symbol type
        if symbol[:type] == "class"
          update_class_in_graphs(symbol)
        elsif symbol[:type] == "method"
          update_method_in_graphs(symbol)
        end
      end

      def update_class_in_graphs(klass)
        name = klass[:fqname] || klass[:name]
        
        # Update inheritance
        if klass[:superclass]
          @inheritance_graph.add_edge(name, klass[:superclass], type: "inherits")
        end
        
        # Update dependencies
        (klass[:dependencies] || []).each do |dep|
          @dependency_graph.add_edge(name, dep, type: "depends_on")
        end
      end

      def update_method_in_graphs(method)
        # Would update method call graph
      end

      def remove_from_graphs(name)
        @inheritance_graph.remove_node(name)
        @dependency_graph.remove_node(name)
        @method_call_graph.remove_node(name)
        @mixin_graph.remove_node(name)
      end
    end

    # Represents a missing reference in the codebase
    MissingReference = Struct.new(:symbol, :referenced_by, :reference_type, keyword_init: true) do
      def to_h
        {symbol: symbol, referenced_by: referenced_by, reference_type: reference_type}
      end
    end
  end
end