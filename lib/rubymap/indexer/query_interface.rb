# frozen_string_literal: true

require "ostruct"

module Rubymap
  class Indexer
    # Clean query interface for indexed data
    class QueryInterface
      def initialize(indexed_result)
        @result = indexed_result
      end

      # Symbol queries
      def find_symbol(name)
        @result.find_symbol(name)
      end

      def search(query, options = {})
        @result.search_symbols(query, options)
      end

      def fuzzy_search(query, threshold = 0.7)
        @result.fuzzy_search(query, threshold: threshold)
      end

      # Inheritance queries
      def ancestors_of(class_name)
        @result.ancestors_of(class_name)
      end

      def descendants_of(class_name)
        @result.descendants_of(class_name)
      end

      def inheritance_depth(class_name)
        @result.inheritance_depths[class_name]
      end

      # Dependency queries
      def dependencies_of(class_name)
        @result.dependencies_of(class_name)
      end

      def dependents_of(class_name)
        @result.dependents_of(class_name)
      end

      # Method call queries
      def callers_of(method_name)
        @result.callers_of(method_name)
      end

      def trace_calls_from(method_name)
        @result.trace_calls_from(method_name)
      end

      # Mixin queries
      def implementers_of(module_name)
        @result.implementers_of(module_name)
      end

      def available_methods(class_name)
        # Get methods available in a class including inherited and mixed-in
        methods = OpenStruct.new(
          included_methods: [],
          extended_methods: []
        )

        symbol = find_symbol(class_name)
        return methods unless symbol

        # Get mixins
        mixins = symbol.mixins || []
        mixins.each do |mixin|
          module_name = mixin[:module] || mixin["module"]
          mixin_type = mixin[:type] || mixin["type"]

          case mixin_type
          when "include"
            methods.included_methods << module_name
          when "extend"
            methods.extended_methods << module_name
          end
        end

        methods
      end

      def effective_mixins(class_name)
        mixins = []

        # Get direct mixins
        symbol = find_symbol(class_name)
        if symbol && symbol.mixins
          mixins.concat(symbol.mixins.map { |m| m[:module] || m["module"] })
        end

        # Get inherited mixins
        ancestors_of(class_name).each do |ancestor|
          ancestor_symbol = find_symbol(ancestor)
          if ancestor_symbol && ancestor_symbol.mixins
            mixins.concat(ancestor_symbol.mixins.map { |m| m[:module] || m["module"] })
          end
        end

        mixins.uniq
      end

      # File-based queries
      def symbols_in_file(file_path)
        @result.search_symbols("", file_pattern: Regexp.new(Regexp.escape(file_path)))
      end

      # Graph traversal
      def traverse_bfs(start, direction)
        case direction
        when :descendants
          bfs_descendants(start)
        when :ancestors
          bfs_ancestors(start)
        else
          []
        end
      end

      def traverse_dfs(start, direction)
        case direction
        when :descendants
          dfs_descendants(start)
        when :ancestors
          dfs_ancestors(start)
        else
          []
        end
      end

      def shortest_path(from, to)
        # Simple BFS shortest path
        visited = Set.new
        queue = [[from]]

        until queue.empty?
          path = queue.shift
          node = path.last

          next if visited.include?(node)
          visited.add(node)

          return path if node == to

          # Check all types of connections
          neighbors = []

          # Check inheritance
          neighbors.concat(@result.inheritance_graph.successors_of(node))
          neighbors.concat(@result.inheritance_graph.predecessors_of(node))

          # Check mixins
          neighbors.concat(@result.mixin_graph.successors_of(node))

          neighbors.each do |neighbor|
            queue << (path + [neighbor]) unless visited.include?(neighbor)
          end
        end

        nil
      end

      # Documentation search
      def search_documentation(query)
        # Would search in documentation fields
        # For now, return symbols matching the query
        @result.search_symbols(query, case_sensitive: false)
      end

      def search_methods(query)
        @result.search_symbols(query, type: :method)
      end

      private

      def bfs_descendants(start)
        visited = Set.new
        queue = [start]
        result = []

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)

          visited.add(current)
          result << current

          descendants = @result.inheritance_graph.successors_of(current)
          queue.concat(descendants)
        end

        result
      end

      def bfs_ancestors(start)
        visited = Set.new
        queue = [start]
        result = []

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)

          visited.add(current)
          result << current

          ancestors = @result.inheritance_graph.predecessors_of(current)
          queue.concat(ancestors)
        end

        result
      end

      def dfs_descendants(start)
        visited = Set.new
        result = []

        dfs_helper(start, visited, result, :successors)
        result
      end

      def dfs_ancestors(start)
        visited = Set.new
        result = []

        dfs_helper(start, visited, result, :predecessors)
        result
      end

      def dfs_helper(node, visited, result, direction)
        return if visited.include?(node)

        visited.add(node)
        result << node

        neighbors = if direction == :successors
          @result.inheritance_graph.successors_of(node)
        else
          @result.inheritance_graph.predecessors_of(node)
        end

        neighbors.each do |neighbor|
          dfs_helper(neighbor, visited, result, direction)
        end
      end
    end
  end
end
