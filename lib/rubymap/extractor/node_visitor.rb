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
        @class_extractor = ClassExtractor.new(context, result)
        @module_extractor = ModuleExtractor.new(context, result)
        @method_extractor = MethodExtractor.new(context, result)
        @call_extractor = CallExtractor.new(context, result)
        @constant_extractor = ConstantExtractor.new(context, result)
        @class_variable_extractor = ClassVariableExtractor.new(context, result)
        @alias_extractor = AliasExtractor.new(context, result)
      end

      # Handler methods for each node type
      def handle_program(node)
        visit(node.statements)
      end

      def handle_statements(node)
        node.body&.each { |child| visit(child) }
      end

      def handle_class(node)
        @class_extractor.extract(node) { visit_children(node) }
      end

      def handle_module(node)
        @module_extractor.extract(node) { visit_children(node) }
      end

      def handle_method(node)
        @method_extractor.extract(node)
        visit_children(node)
      end

      def handle_call(node)
        @call_extractor.extract(node)
        visit_children(node)
      end

      def handle_constant(node)
        @constant_extractor.extract(node)
        visit_children(node)
      end

      def handle_class_variable(node)
        @class_variable_extractor.extract(node)
        visit_children(node)
      end

      def handle_alias(node)
        @alias_extractor.extract(node)
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
