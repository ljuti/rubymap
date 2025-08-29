# frozen_string_literal: true

module Rubymap
  class Extractor
    module Services
      # Service for extracting and processing documentation from comments
      class DocumentationService
        # Extract documentation for a node from preceding comments
        def extract_documentation(node, comments)
          return nil unless node.respond_to?(:location)
          return nil if comments.nil? || comments.empty?

          node_line = node.location.start_line
          doc_comments = find_documentation_comments(comments, node_line)

          return nil if doc_comments.empty?

          format_documentation(doc_comments)
        end

        # Extract inline comment for a node (on the same line)
        def extract_inline_comment(node, comments)
          return nil unless node.respond_to?(:location)
          return nil if comments.nil? || comments.empty?

          node_line = node.location.start_line

          inline_comment = comments.find do |comment|
            comment.location.start_line == node_line &&
              comment.location.start_column > node.location.end_column
          end

          return nil unless inline_comment

          clean_comment_text(inline_comment.slice)
        end

        # Check if a comment is a documentation comment (starts with ##)
        def documentation_comment?(comment)
          comment.slice.start_with?("##")
        end

        # Extract YARD tags from documentation
        def extract_yard_tags(documentation)
          return {} unless documentation

          tags = {}
          documentation.lines.each do |line|
            if (match = line.match(/@(\w+)\s+(.*)/))
              tag_name = match[1].to_sym
              tag_value = match[2].strip

              tags[tag_name] = if tags[tag_name]
                # Handle multiple tags of the same type
                Array(tags[tag_name]) << tag_value
              else
                tag_value
              end
            end
          end
          tags
        end

        private

        def find_documentation_comments(comments, node_line)
          # Find comments that appear immediately before this node
          preceding_comments = comments.select do |comment|
            comment.location.start_line < node_line
          end

          return [] if preceding_comments.empty?

          # Sort by line number and find the block of comments immediately before the node
          preceding_comments = preceding_comments.sort_by { |c| c.location.start_line }

          # Take the last consecutive block of comments
          doc_comments = []
          expected_line = node_line - 1

          preceding_comments.reverse_each do |comment|
            comment_line = comment.location.start_line
            if comment_line == expected_line
              doc_comments.unshift(comment)
              expected_line = comment_line - 1
            elsif comment_line < expected_line - 1
              # Gap in comments, stop collecting
              break
            end
          end

          doc_comments
        end

        def format_documentation(doc_comments)
          doc_comments
            .map { |c| clean_comment_text(c.slice) }
            .join("\n")
        end

        def clean_comment_text(text)
          # Remove the # and optional space, handling ## for doc comments
          text.sub(/^##?\s?/, "")
        end
      end
    end
  end
end
