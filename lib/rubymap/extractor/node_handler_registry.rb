# frozen_string_literal: true

module Rubymap
  class Extractor
    # Registry for node handlers using the Strategy pattern
    # This allows adding new node types without modifying the visitor
    class NodeHandlerRegistry
      attr_reader :handlers

      def initialize
        @handlers = {}
        register_default_handlers
      end

      # Register a handler for a specific node type
      def register(node_class, handler)
        @handlers[node_class] = handler
      end

      # Get handler for a node, returns nil if not found
      def handler_for(node)
        @handlers[node.class]
      end

      # Check if a handler exists for a node type
      def handles?(node)
        @handlers.key?(node.class)
      end

      private

      def register_default_handlers
        # Register handlers for each node type
        # These will be initialized lazily when needed
        @handlers = {
          Prism::ProgramNode => :handle_program,
          Prism::StatementsNode => :handle_statements,
          Prism::ClassNode => :handle_class,
          Prism::ModuleNode => :handle_module,
          Prism::DefNode => :handle_method,
          Prism::CallNode => :handle_call,
          Prism::ConstantWriteNode => :handle_constant,
          Prism::ConstantPathWriteNode => :handle_constant,
          Prism::ClassVariableWriteNode => :handle_class_variable,
          Prism::AliasMethodNode => :handle_alias
        }
      end
    end
  end
end
