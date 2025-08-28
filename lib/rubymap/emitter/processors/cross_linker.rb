# frozen_string_literal: true

module Rubymap
  module Emitter
    module Processors
      class CrossLinker
        def initialize
          @symbol_index = {}
          @chunk_index = {}
        end

        def link_chunks(chunks)
          # Build indices
          build_indices(chunks)

          # Add cross-references to each chunk
          chunks.map do |chunk|
            add_cross_references(chunk)
          end
        end

        def add_cross_references(chunk)
          content = chunk[:content]

          # Find symbol references in content
          references = find_symbol_references(content)

          # Add links section to chunk
          if references.any?
            links = generate_links_section(references)
            chunk[:content] = "#{content}\n\n#{links}"
            chunk[:references] = references
          end

          chunk
        end

        def link_documentation(content, symbol_map)
          linked_content = content.dup

          # Replace symbol references with links
          symbol_map.each do |symbol, info|
            pattern = /\b#{Regexp.escape(symbol)}\b/
            link = generate_link(symbol, info)
            linked_content.gsub!(pattern, link)
          end

          linked_content
        end

        private

        def build_indices(chunks)
          chunks.each_with_index do |chunk, idx|
            # Index by chunk ID
            @chunk_index[chunk[:chunk_id]] = {
              index: idx,
              symbol: chunk[:symbol_id],
              type: chunk[:type]
            }

            # Index by symbol
            if chunk[:symbol_id]
              @symbol_index[chunk[:symbol_id]] = chunk[:chunk_id]
            end
          end
        end

        def find_symbol_references(content)
          references = []

          # Look for class/module references
          class_pattern = /\b([A-Z][A-Za-z0-9]*(?:::[A-Z][A-Za-z0-9]*)*)\b/

          content.scan(class_pattern) do |match|
            symbol = match[0]
            if @symbol_index[symbol]
              references << {
                symbol: symbol,
                chunk_id: @symbol_index[symbol]
              }
            end
          end

          # Look for method references (e.g., User#save, User.find)
          method_pattern = /\b([A-Z][A-Za-z0-9]*(?:::[A-Z][A-Za-z0-9]*)*)([#.])\w+\b/

          content.scan(method_pattern) do |match|
            class_name = match[0]
            if @symbol_index[class_name]
              references << {
                symbol: class_name,
                chunk_id: @symbol_index[class_name]
              }
            end
          end

          references.uniq
        end

        def generate_links_section(references)
          lines = ["## Related Chunks", ""]

          references.each do |ref|
            chunk_info = @chunk_index[ref[:chunk_id]]
            lines << "- **#{ref[:symbol]}**: See chunk `#{ref[:chunk_id]}` (#{chunk_info[:type]})"
          end

          lines << ""
          lines << "See graph: `graphs/complete.dot` for visual relationships"

          lines.join("\n")
        end

        def generate_link(symbol, info)
          case info[:type]
          when :class, :module
            "[#{symbol}](chunks/#{info[:chunk_file]})"
          when :method
            "[#{symbol}](chunks/#{info[:chunk_file]}##{info[:anchor]})"
          else
            symbol
          end
        end
      end
    end
  end
end
