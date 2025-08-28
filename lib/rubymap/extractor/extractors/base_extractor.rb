# frozen_string_literal: true

module Rubymap
  class Extractor
    # Base class for all specific extractors
    class BaseExtractor
      attr_reader :context, :result

      def initialize(context, result)
        @context = context
        @result = result
      end

      protected

      def extract_constant_name(node)
        return nil unless node

        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          parts = []
          current = node
          while current.is_a?(Prism::ConstantPathNode)
            parts.unshift(current.name.to_s)
            current = current.parent
          end
          parts.unshift(extract_constant_name(current)) if current
          parts.compact.join("::")
        else
          node.to_s
        end
      end

      def extract_documentation(node)
        return nil unless node.respond_to?(:location)
        return nil if context.comments.nil? || context.comments.empty?

        # Find comments that appear immediately before this node
        node_line = node.location.start_line
        
        # Get all comments that are before this node
        preceding_comments = context.comments.select do |comment|
          comment.location.start_line < node_line
        end
        
        return nil if preceding_comments.empty?
        
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

        return nil if doc_comments.empty?

        # Extract text from comments, removing the # and optional space
        doc_comments
          .map { |c| c.slice.sub(/^#\s?/, "") }
          .join("\n")
      end
    end
  end
end
