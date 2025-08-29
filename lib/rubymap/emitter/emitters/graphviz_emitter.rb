# frozen_string_literal: true

module Rubymap
  module Emitter
    module Emitters
      class GraphViz < BaseEmitter
        THEMES = {
          default: {
            bgcolor: "white",
            fontcolor: "black",
            class_color: "lightblue",
            module_color: "lightgreen",
            edge_color: "gray"
          },
          dark: {
            bgcolor: "black",
            fontcolor: "white",
            class_color: "darkblue",
            module_color: "darkgreen",
            edge_color: "lightgray"
          }
        }.freeze

        def initialize(**options)
          super
          @theme = THEMES[options[:theme] || :default]
          @max_depth = options[:max_depth]
          @rankdir = options[:rankdir] || "TB"  # Top-Bottom by default
          @node_shape = options[:node_shape] || "box"
          @font_size = options[:font_size] || 10
        end

        def emit(indexed_data)
          generate_complete_graph(indexed_data)
        end

        def emit_inheritance_graph(indexed_data)
          generate_inheritance_graph(indexed_data)
        end

        def emit_dependency_graph(indexed_data)
          generate_dependency_graph(indexed_data)
        end

        def emit_module_graph(indexed_data)
          generate_module_graph(indexed_data)
        end

        def emit_call_graph(indexed_data)
          generate_call_graph(indexed_data)
        end

        def emit_complexity_graph(indexed_data)
          generate_complexity_graph(indexed_data)
        end

        def emit_rails_graph(indexed_data)
          generate_rails_graph(indexed_data)
        end

        def emit_to_directory(indexed_data, output_dir, include_makefile: false, include_readme: false)
          ensure_directory_exists(output_dir)
          written_files = []

          # Generate different graph types
          graphs = {
            "inheritance.dot" => emit_inheritance_graph(indexed_data),
            "dependencies.dot" => emit_dependency_graph(indexed_data),
            "modules.dot" => emit_module_graph(indexed_data),
            "complete.dot" => emit(indexed_data)
          }

          graphs.each do |filename, content|
            file_path = File.join(output_dir, filename)
            File.write(file_path, content)
            written_files << create_file_info(filename, file_path)
          end

          # Generate Makefile if requested
          if include_makefile
            makefile_path = File.join(output_dir, "Makefile")
            File.write(makefile_path, generate_makefile)
            written_files << create_file_info("Makefile", makefile_path)
          end

          # Generate README if requested
          if include_readme
            readme_path = File.join(output_dir, "README.md")
            File.write(readme_path, generate_graphviz_readme)
            written_files << create_file_info("README.md", readme_path)
          end

          generate_manifest(output_dir, written_files, indexed_data)
          written_files
        end

        protected

        def format_extension
          "dot"
        end

        def default_filename
          "graph.dot"
        end

        private

        def generate_complete_graph(indexed_data)
          dot = []

          dot << "digraph CodeStructure {"
          dot << apply_graph_attributes
          dot << ""

          # Add nodes
          add_class_nodes(dot, indexed_data[:classes]) if indexed_data[:classes]
          add_module_nodes(dot, indexed_data[:modules]) if indexed_data[:modules]

          dot << ""

          # Add edges
          add_inheritance_edges(dot, indexed_data.dig(:graphs, :inheritance))
          add_dependency_edges(dot, indexed_data.dig(:graphs, :dependencies))
          add_module_edges(dot, indexed_data.dig(:graphs, :modules))

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_inheritance_graph(indexed_data)
          dot = []

          dot << "digraph Inheritance {"
          dot << apply_graph_attributes
          dot << '  rankdir="BT";  // Bottom-Top for inheritance'
          dot << ""

          inheritance_data = indexed_data.dig(:graphs, :inheritance) || []

          # Collect all nodes involved in inheritance
          nodes = Set.new
          inheritance_data.each do |rel|
            nodes << rel[:from]
            nodes << rel[:to]
          end

          # Add nodes with appropriate styling
          nodes.each do |node|
            klass = find_class(indexed_data, node)
            dot << if klass
              format_class_node(node, klass)
            else
              "  \"#{escape_name(node)}\" [shape=#{@node_shape}, color=gray];"
            end
          end

          dot << ""

          # Add inheritance edges
          inheritance_data.each do |rel|
            dot << "  \"#{escape_name(rel[:from])}\" -> \"#{escape_name(rel[:to])}\" [label=\"inherits\", color=blue];"
          end

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_dependency_graph(indexed_data)
          dot = []

          dot << "digraph Dependencies {"
          dot << apply_graph_attributes
          dot << ""

          dependencies = indexed_data.dig(:graphs, :dependencies) || []

          # Add dependency edges with different styles
          dependencies.each do |dep|
            style = (dep[:type] == "hard") ? "solid" : "dashed"
            dot << "  \"#{escape_name(dep[:from])}\" -> \"#{escape_name(dep[:to])}\" [label=\"depends_on\", style=#{style}];"
          end

          # Handle circular dependencies
          if @options[:show_circular]
            add_circular_dependency_detection(dot, dependencies)
          end

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_module_graph(indexed_data)
          dot = []

          dot << "digraph Modules {"
          dot << apply_graph_attributes
          dot << ""

          # Different edge colors for different mixin types
          includes_data = indexed_data.dig(:graphs, :includes) || []
          extends_data = indexed_data.dig(:graphs, :extends) || []
          prepends_data = indexed_data.dig(:graphs, :prepends) || []

          # Add module nodes
          indexed_data[:modules]&.each do |mod|
            dot << "  \"#{escape_name(mod[:fqname])}\" [shape=ellipse, color=green, label=\"#{mod[:fqname]}\"];"
          end

          dot << ""

          # Add different mixin relationships
          includes_data.each do |rel|
            dot << "  \"#{escape_name(rel[:from])}\" -> \"#{escape_name(rel[:to])}\" [label=\"includes\", color=green];"
          end

          extends_data.each do |rel|
            dot << "  \"#{escape_name(rel[:from])}\" -> \"#{escape_name(rel[:to])}\" [label=\"extends\", color=red];"
          end

          prepends_data.each do |rel|
            dot << "  \"#{escape_name(rel[:from])}\" -> \"#{escape_name(rel[:to])}\" [label=\"prepends\", color=blue];"
          end

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_call_graph(indexed_data)
          dot = []

          dot << "digraph CallGraph {"
          dot << apply_graph_attributes
          dot << ""

          # Method call relationships
          calls = indexed_data.dig(:graphs, :calls) || []

          calls.each do |call|
            from_method = "#{call[:from_class]}##{call[:from_method]}"
            to_method = "#{call[:to_class]}##{call[:to_method]}"
            dot << "  \"#{escape_name(from_method)}\" -> \"#{escape_name(to_method)}\" [label=\"calls\"];"
          end

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_complexity_graph(indexed_data)
          dot = []

          dot << "digraph Complexity {"
          dot << apply_graph_attributes
          dot << ""

          # Use color gradients for complexity
          indexed_data[:classes]&.each do |klass|
            complexity = klass.dig(:metrics, :complexity_score) || 0
            color = complexity_to_color(complexity)

            dot << "  \"#{escape_name(klass[:fqname])}\" [shape=#{@node_shape}, style=filled, fillcolor=\"#{color}\", label=\"#{klass[:fqname]}\\ncomplexity: #{complexity}\"];"
          end

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def generate_rails_graph(indexed_data)
          dot = []

          dot << "digraph RailsStructure {"
          dot << apply_graph_attributes
          dot << ""

          # Create clusters for MVC
          dot << "  subgraph cluster_models {"
          dot << "    label=\"Models\";"
          dot << "    color=blue;"
          add_rails_nodes(dot, indexed_data[:classes], "app/models")
          dot << "  }"

          dot << ""
          dot << "  subgraph cluster_controllers {"
          dot << "    label=\"Controllers\";"
          dot << "    color=green;"
          add_rails_nodes(dot, indexed_data[:classes], "app/controllers")
          dot << "  }"

          dot << ""
          dot << "  subgraph cluster_views {"
          dot << "    label=\"Views\";"
          dot << "    color=red;"
          # Views would be handled differently
          dot << "  }"

          dot << ""

          # Highlight Rails base classes
          dot << "  \"ApplicationRecord\" [style=bold, color=blue];"
          dot << "  \"ApplicationController\" [style=bold, color=green];"

          # Add relationships
          add_inheritance_edges(dot, indexed_data.dig(:graphs, :inheritance))

          dot << "}"

          apply_redaction(dot.join("\n"))
        end

        def apply_graph_attributes
          attrs = []
          attrs << "  bgcolor=\"#{@theme[:bgcolor]}\";"
          attrs << "  fontcolor=\"#{@theme[:fontcolor]}\";"
          attrs << "  fontsize=#{@font_size};"
          attrs << "  rankdir=\"#{@rankdir}\";"
          attrs << "  concentrate=true;" if @options[:concentrate]
          attrs << "  rank=same;" if @options[:same_rank]
          attrs.join("\n")
        end

        def add_class_nodes(dot, classes)
          classes.each do |klass|
            dot << format_class_node(klass[:fqname], klass)
          end
        end

        def add_module_nodes(dot, modules)
          modules.each do |mod|
            dot << format_module_node(mod[:fqname], mod)
          end
        end

        def format_class_node(name, klass)
          "  \"#{escape_name(name)}\" [shape=#{@node_shape}, color=#{@theme[:class_color]}];"
        end

        def format_module_node(name, mod)
          "  \"#{escape_name(name)}\" [shape=ellipse, color=#{@theme[:module_color]}];"
        end

        def add_inheritance_edges(dot, inheritance_data)
          return unless inheritance_data

          inheritance_data.each do |rel|
            dot << "  \"#{escape_name(rel[:from])}\" -> \"#{escape_name(rel[:to])}\" [label=\"inherits\"];"
          end
        end

        def add_dependency_edges(dot, dependencies)
          return unless dependencies

          dependencies.each do |dep|
            style = (dep[:type] == "hard") ? "solid" : "dashed"
            dot << "  \"#{escape_name(dep[:from])}\" -> \"#{escape_name(dep[:to])}\" [label=\"depends_on\", style=#{style}];"
          end
        end

        def add_module_edges(dot, module_data)
          # Would add module relationship edges here
        end

        def add_rails_nodes(dot, classes, path_prefix)
          return unless classes

          classes.select { |c| c[:file]&.start_with?(path_prefix) }.each do |klass|
            dot << "    \"#{escape_name(klass[:fqname])}\";"
          end
        end

        def add_circular_dependency_detection(dot, dependencies)
          # Simple circular dependency detection
          graph = Hash.new { |h, k| h[k] = [] }

          dependencies.each do |dep|
            graph[dep[:from]] << dep[:to]
          end

          # Find cycles (simplified)
          graph.each do |node, deps|
            deps.each do |dep|
              if graph[dep]&.include?(node)
                dot << "  \"#{escape_name(node)}\" -> \"#{escape_name(dep)}\" [color=red, style=bold, label=\"circular\"];"
              end
            end
          end
        end

        def find_class(indexed_data, name)
          indexed_data[:classes]&.find { |c| c[:fqname] == name }
        end

        def escape_name(name)
          name.to_s.gsub(/[<>"]/, "_")
        end

        def complexity_to_color(complexity)
          # Map complexity score to color gradient
          case complexity
          when 0..3 then "#90EE90"    # Light green
          when 4..7 then "#FFD700"    # Gold
          when 8..10 then "#FFA500"   # Orange
          else "#FF6347"              # Tomato red
          end
        end

        def generate_makefile
          <<~MAKEFILE
            # Makefile for generating graph images from DOT files
            
            DOT_FILES := $(wildcard *.dot)
            SVG_FILES := $(DOT_FILES:.dot=.svg)
            PNG_FILES := $(DOT_FILES:.dot=.png)
            
            .PHONY: all svg png clean
            
            all: svg png
            
            svg: $(SVG_FILES)
            
            png: $(PNG_FILES)
            
            %.svg: %.dot
            	dot -Tsvg $< -o $@
            
            %.png: %.dot
            	dot -Tpng $< -o $@
            
            clean:
            	rm -f *.svg *.png
            
            view: svg
            	open *.svg
          MAKEFILE
        end

        def generate_graphviz_readme
          <<~README
            # GraphViz Diagrams
            
            This directory contains GraphViz DOT files representing your codebase structure.
            
            ## Files
            
            - `inheritance.dot` - Class inheritance hierarchy
            - `dependencies.dot` - Dependency relationships
            - `modules.dot` - Module inclusions and extensions
            - `complete.dot` - Complete code structure graph
            
            ## Rendering Graphs
            
            ### Using GraphViz directly:
            
            ```bash
            # Generate SVG
            dot -Tsvg inheritance.dot -o inheritance.svg
            
            # Generate PNG
            dot -Tpng inheritance.dot -o inheritance.png
            
            # Generate PDF
            dot -Tpdf inheritance.dot -o inheritance.pdf
            ```
            
            ### Using the Makefile:
            
            ```bash
            # Generate all SVG and PNG files
            make all
            
            # Generate only SVG files
            make svg
            
            # Generate only PNG files
            make png
            
            # View SVG files (macOS)
            make view
            
            # Clean generated files
            make clean
            ```
            
            ## Requirements
            
            You need GraphViz installed:
            
            - macOS: `brew install graphviz`
            - Ubuntu/Debian: `apt-get install graphviz`
            - Windows: Download from https://graphviz.org/download/
            
            ## Online Viewers
            
            You can also view DOT files online at:
            - https://dreampuf.github.io/GraphvizOnline/
            - http://www.webgraphviz.com/
          README
        end

        def create_file_info(relative_path, full_path)
          {
            path: full_path,
            relative_path: relative_path,
            size: File.size(full_path),
            checksum: Digest::SHA256.hexdigest(File.read(full_path))
          }
        end
      end
    end
  end
end
