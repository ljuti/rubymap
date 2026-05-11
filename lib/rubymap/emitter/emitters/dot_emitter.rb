# frozen_string_literal: true

module Rubymap
  module Emitter
    module Emitters
      # Emits a GraphViz DOT visualization of class relationships.
      #
      # Generates a directed graph from the inheritance and dependency data
      # in the indexed output. Inheritance edges use solid arrows; dependency
      # edges use dashed arrows.
      class GraphViz < BaseEmitter
        def emit(indexed_data)
          graphs = indexed_data[:graphs] || {}

          lines = []
          lines << "digraph Rubymap {"
          lines << "  rankdir=TB;"
          lines << "  node [shape=box, style=rounded];"
          lines << ""

          nodes = {}

          # Collect all nodes from both inheritance and dependency edges
          (graphs[:inheritance] || []).each do |edge|
            nodes[edge[:from]] = true
            nodes[edge[:to]] = true
          end
          (graphs[:dependencies] || []).each do |edge|
            nodes[edge[:from]] = true
            nodes[edge[:to]] = true
          end

          # Declare nodes
          nodes.each_key do |name|
            escaped = name.to_s.gsub('"', '\"')
            lines << "  \"#{escaped}\";"
          end
          lines << ""

          # Inheritance edges (solid)
          (graphs[:inheritance] || []).each do |edge|
            from = edge[:from].to_s.gsub('"', '\"')
            to = edge[:to].to_s.gsub('"', '\"')
            lines << "  \"#{from}\" -> \"#{to}\" [style=solid, color=blue];"
          end

          # Dependency edges (dashed)
          (graphs[:dependencies] || []).each do |edge|
            from = edge[:from].to_s.gsub('"', '\"')
            to = edge[:to].to_s.gsub('"', '\"')
            lines << "  \"#{from}\" -> \"#{to}\" [style=dashed, color=red];"
          end

          lines << "}"
          lines.join("\n") + "\n"
        end

        protected

        def format_extension
          "dot"
        end

        def default_filename
          "rubymap.dot"
        end
      end
    end
  end
end
