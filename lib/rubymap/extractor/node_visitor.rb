# frozen_string_literal: true

require_relative "node_handler_registry"
require_relative "extractors/class_extractor"
require_relative "extractors/module_extractor"
require_relative "extractors/method_extractor"
require_relative "extractors/call_extractor"
require_relative "extractors/constant_extractor"
require_relative "extractors/class_variable_extractor"
require_relative "extractors/alias_extractor"

module Rubymap
  class Extractor
    # Visitor that traverses the AST and delegates to specific extractors
    class NodeVisitor
      attr_reader :context, :result, :registry

      def initialize(context, result)
        @context = context
        @result = result
        @registry = NodeHandlerRegistry.new
        initialize_extractors
      end

      def visit(node)
        return unless node

        handler_method = @registry.handler_for(node)

        if handler_method
          send(handler_method, node)
        else
          # Default behavior for unknown nodes
          visit_children(node)
        end
      rescue => e
        result.add_error(e, "Error processing #{node.class.name}")
      end

      private

      def initialize_extractors
        @extractors = {
          class: ClassExtractor.new(context, result),
          module: ModuleExtractor.new(context, result),
          method: MethodExtractor.new(context, result),
          call: CallExtractor.new(context, result),
          constant: ConstantExtractor.new(context, result),
          class_variable: ClassVariableExtractor.new(context, result),
          alias: AliasExtractor.new(context, result)
        }
      end

      # Handler methods for each node type
      def handle_program(node)
        visit(node.statements)
      end

      def handle_statements(node)
        node.body&.each { |child| visit(child) }
      end

      def handle_class(node)
        @extractors[:class].extract(node) { visit_children(node) }
      end

      def handle_module(node)
        @extractors[:module].extract(node) { visit_children(node) }
      end

      def handle_method(node)
        @extractors[:method].extract(node)
        visit_children(node)
      end

      def handle_call(node)
        @extractors[:call].extract(node)
        visit_children(node)
      end

      def handle_constant(node)
        @extractors[:constant].extract(node)
        visit_children(node)
      end

      def handle_class_variable(node)
        @extractors[:class_variable].extract(node)
        visit_children(node)
      end

      def handle_alias(node)
        @extractors[:alias].extract(node)
        visit_children(node)
      end

      def visit_children(node)
        if node.respond_to?(:child_nodes)
          node.child_nodes.compact.each { |child| visit(child) }
        elsif node.respond_to?(:body)
          visit(node.body)
        end
      end
    end
  end
end
