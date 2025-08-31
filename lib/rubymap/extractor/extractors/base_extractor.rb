# frozen_string_literal: true

require "forwardable"
require_relative "../services/documentation_service"
require_relative "../services/namespace_service"

module Rubymap
  class Extractor
    # Base class for all specific extractors
    class BaseExtractor
      extend Forwardable
      
      attr_reader :context, :result, :documentation_service, :namespace_service

      def initialize(context, result)
        @context = context
        @result = result
        @documentation_service = Services::DocumentationService.new
        @namespace_service = Services::NamespaceService.new
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

      # Delegation methods for documentation extraction
      # These pass through to the documentation service with proper context
      def extract_documentation(node)
        documentation_service.extract_documentation(node, context.comments)
      end

      def extract_inline_comment(node)
        documentation_service.extract_inline_comment(node, context.comments)
      end

      def extract_yard_tags(documentation)
        documentation_service.extract_yard_tags(documentation)
      end
    end
  end
end
