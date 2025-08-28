# frozen_string_literal: true

require "ostruct"

module Rubymap
  class Indexer
    # Directed graph for representing relationships between symbols
    class Graph
      attr_reader :nodes, :edges, :type, :depths

      def initialize(type)
        @type = type
        @nodes = {}
        @edges = []
        @adjacency_list = Hash.new { |h, k| h[k] = [] }
        @reverse_adjacency = Hash.new { |h, k| h[k] = [] }
        @depths = {}
      end

      def add_node(name, data = {})
        @nodes[name] = data unless @nodes.key?(name)
      end

      def add_edge(from, to, attributes = {})
        add_node(from)
        add_node(to)

        edge = Edge.new(from, to, attributes)
        @edges << edge
        @adjacency_list[from] << to
        @reverse_adjacency[to] << from
        edge
      end

      def remove_node(name)
        @nodes.delete(name)
        @edges.reject! { |e| e.from == name || e.to == name }
        @adjacency_list.delete(name)
        @adjacency_list.each { |_, neighbors| neighbors.delete(name) }
        @reverse_adjacency.delete(name)
        @reverse_adjacency.each { |_, neighbors| neighbors.delete(name) }
      end

      def successors_of(node)
        @adjacency_list[node].uniq
      end

      def predecessors_of(node)
        @reverse_adjacency[node].uniq
      end

      def out_edges_of(node)
        @edges.select { |e| e.from == node }
      end

      def in_edges_of(node)
        @edges.select { |e| e.to == node }
      end

      def edge_between(from, to)
        @edges.find { |e| e.from == from && e.to == to }
      end

      def out_degree(node)
        @adjacency_list[node].size
      end

      def in_degree(node)
        @reverse_adjacency[node].size
      end

      def total_weight_to(node)
        in_edges_of(node).sum { |e| e.weight || 1 }
      end

      # Graph traversal
      def ancestors_of(node)
        visited = Set.new
        queue = [node]
        result = []

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)
          visited.add(current)

          # For inheritance, ancestors are found by following edges up (successors in our graph)
          # because child -> parent edges
          parents = successors_of(current)
          parents.each do |parent|
            result << parent unless result.include?(parent)
            queue << parent unless visited.include?(parent)
          end
        end

        result
      end

      def descendants_of(node)
        visited = Set.new
        queue = [node]
        result = []

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)
          visited.add(current)

          # For inheritance, descendants are found by following edges down (predecessors in our graph)
          # because child -> parent edges means parent has incoming edges from children
          children = predecessors_of(current)
          children.each do |child|
            result << child unless result.include?(child)
            queue << child unless visited.include?(child)
          end
        end

        result
      end

      def transitive_closure(node)
        visited = Set.new
        queue = [node]
        result = []

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)
          visited.add(current)

          successors_of(current).each do |succ|
            result << succ unless result.include?(succ)
            queue << succ unless visited.include?(succ)
          end
        end

        result
      end

      def trace_path_from(start_node)
        visited = Set.new
        path = []
        queue = [start_node]

        until queue.empty?
          node = queue.shift
          next if visited.include?(node)

          visited.add(node)
          path << node

          successors_of(node).each do |succ|
            queue << succ unless visited.include?(succ)
          end
        end

        path
      end

      # Cycle detection using DFS
      def find_cycles
        cycles = []
        visited = Set.new
        rec_stack = Set.new

        @nodes.keys.each do |node|
          if !visited.include?(node)
            detect_cycle(node, visited, rec_stack, [], cycles)
          end
        end

        cycles.map do |cycle|
          OpenStruct.new(cycle: cycle + [cycle.first])
        end
      end

      def calculate_depths
        return unless @type == "inheritance"

        # For inheritance, root nodes have no outgoing edges (no parent)
        # because edges go from child to parent
        roots = @nodes.keys.select { |n| out_degree(n) == 0 }

        @depths = {}
        visited = Set.new

        # Use iterative BFS to avoid stack overflow
        roots.each do |root|
          queue = [[root, 0]]

          until queue.empty?
            node, depth = queue.shift
            next if visited.include?(node)

            visited.add(node)
            @depths[node] = depth

            # Get children (nodes that have this node as parent)
            predecessors_of(node).each do |child|
              queue << [child, depth + 1] unless visited.include?(child)
            end
          end
        end
      end

      def depth_of(node)
        @depths[node]
      end

      def node_count
        @nodes.size
      end

      def edge_count
        @edges.size
      end

      def is_acyclic
        find_cycles.empty?
      end

      def to_h
        {
          type: @type,
          nodes: @nodes,
          edges: @edges.map(&:to_h),
          depths: @depths
        }
      end

      def self.from_h(data)
        graph = new(data[:type])

        data[:nodes].each { |name, node_data| graph.add_node(name, node_data) }
        data[:edges].each do |edge|
          attributes = edge.dup
          attributes.delete(:from)
          attributes.delete(:to)
          graph.add_edge(edge[:from], edge[:to], attributes)
        end
        graph.instance_variable_set(:@depths, data[:depths] || {})

        graph
      end

      private

      def detect_cycle(node, visited, rec_stack, path, cycles)
        visited.add(node)
        rec_stack.add(node)
        path.push(node)

        successors_of(node).each do |neighbor|
          if !visited.include?(neighbor)
            detect_cycle(neighbor, visited, rec_stack, path.dup, cycles)
          elsif rec_stack.include?(neighbor)
            # Found a cycle
            cycle_start = path.index(neighbor)
            cycles << path[cycle_start..-1] if cycle_start
          end
        end

        path.pop
        rec_stack.delete(node)
      end

      # Edge representation
      class Edge
        attr_reader :from, :to, :type, :weight

        def initialize(from, to, attributes = {})
          @from = from
          @to = to
          @type = attributes[:type]
          @weight = attributes[:weight]
          @attributes = attributes
        end

        def to_h
          {from: @from, to: @to}.merge(@attributes)
        end
      end
    end
  end
end
