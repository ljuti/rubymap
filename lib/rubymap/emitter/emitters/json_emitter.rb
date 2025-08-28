# frozen_string_literal: true

require "json"

module Rubymap
  module Emitter
    module Emitters
      class JSON < BaseEmitter
        def emit(indexed_data)
          filtered_data = filter_data(indexed_data)
          formatted_data = apply_deterministic_formatting(filtered_data)

          json_output = if @options[:pretty] || @options[:pretty_print]
            ::JSON.pretty_generate(formatted_data)
          else
            ::JSON.generate(formatted_data)
          end

          apply_redaction(json_output)
        end

        def emit_to_files(indexed_data, output_directory)
          ensure_directory_exists(output_directory)

          written_files = []

          # Main map file
          map_path = File.join(output_directory, "map.json")
          File.write(map_path, emit(indexed_data))
          written_files << {path: "map.json", size: File.size(map_path)}

          # Symbols directory
          if indexed_data[:classes] || indexed_data[:modules]
            symbols_dir = File.join(output_directory, "symbols")
            ensure_directory_exists(symbols_dir)

            # Classes file
            if indexed_data[:classes] && !indexed_data[:classes].empty?
              classes_data = {
                total: indexed_data[:classes].size,
                symbols: indexed_data[:classes]
              }
              classes_path = File.join(symbols_dir, "classes.json")
              File.write(classes_path, format_json(classes_data))
              written_files << {path: "symbols/classes.json", size: File.size(classes_path)}
            end

            # Modules file
            if indexed_data[:modules] && !indexed_data[:modules].empty?
              modules_data = {
                total: indexed_data[:modules].size,
                symbols: indexed_data[:modules]
              }
              modules_path = File.join(symbols_dir, "modules.json")
              File.write(modules_path, format_json(modules_data))
              written_files << {path: "symbols/modules.json", size: File.size(modules_path)}
            end
          end

          # Graphs directory
          if indexed_data[:graphs]
            graphs_dir = File.join(output_directory, "graphs")
            ensure_directory_exists(graphs_dir)

            indexed_data[:graphs].each do |graph_type, graph_data|
              next if graph_data.nil? || (graph_data.is_a?(Array) && graph_data.empty?)

              graph_path = File.join(graphs_dir, "#{graph_type}.json")
              File.write(graph_path, format_json(graph_data))
              written_files << {path: "graphs/#{graph_type}.json", size: File.size(graph_path)}
            end
          end

          generate_manifest(output_directory, written_files, indexed_data)
          written_files
        end

        protected

        def format_extension
          "json"
        end

        def default_filename
          "map.json"
        end

        def generate_files(indexed_data)
          files = []

          # Split into manageable files if data is large
          if should_partition?(indexed_data)
            files.concat(partition_data(indexed_data))
          else
            files << {
              path: "map.json",
              content: emit(indexed_data)
            }
          end

          files
        end

        private

        def format_json(data)
          formatted = apply_deterministic_formatting(data)

          output = if @options[:pretty] || @options[:pretty_print]
            ::JSON.pretty_generate(formatted)
          else
            ::JSON.generate(formatted)
          end

          apply_redaction(output)
        end

        def should_partition?(indexed_data)
          return false unless @options[:partition]

          # Partition if we have many classes/modules
          total_symbols = (indexed_data[:classes]&.size || 0) +
            (indexed_data[:modules]&.size || 0)
          total_symbols > (@options[:partition_threshold] || 100)
        end

        def partition_data(indexed_data)
          files = []

          # Metadata file
          files << {
            path: "metadata.json",
            content: format_json(indexed_data[:metadata] || {})
          }

          # Classes partitioned by namespace
          if indexed_data[:classes]
            partition_symbols(indexed_data[:classes], "classes").each do |file|
              files << file
            end
          end

          # Modules partitioned by namespace
          if indexed_data[:modules]
            partition_symbols(indexed_data[:modules], "modules").each do |file|
              files << file
            end
          end

          # Graphs as separate files
          if indexed_data[:graphs]
            indexed_data[:graphs].each do |graph_type, graph_data|
              files << {
                path: "graphs/#{graph_type}.json",
                content: format_json(graph_data)
              }
            end
          end

          # Index file listing all partitions
          files << {
            path: "index.json",
            content: format_json({
              metadata_file: "metadata.json",
              partitions: files.map { |f| f[:path] }
            })
          }

          files
        end

        def partition_symbols(symbols, type)
          return [] if symbols.empty?

          # Group by top-level namespace
          grouped = symbols.group_by do |symbol|
            fqname = symbol[:fqname] || symbol["fqname"]
            namespace = extract_top_namespace(fqname)
            namespace.empty? ? "global" : namespace
          end

          grouped.map do |namespace, namespace_symbols|
            {
              path: "#{type}/#{namespace.downcase.gsub("::", "_")}.json",
              content: format_json({
                namespace: namespace,
                count: namespace_symbols.size,
                symbols: namespace_symbols
              })
            }
          end
        end

        def extract_top_namespace(fqname)
          return "" unless fqname

          parts = fqname.to_s.split("::")
          return "" if parts.size <= 1

          parts.first
        end
      end
    end
  end
end
