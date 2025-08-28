# frozen_string_literal: true

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
      attr_reader :context, :result

      def initialize(context, result)
        @context = context
        @result = result
        initialize_extractors
      end

      def visit(node)
        return unless node

        case node
        when Prism::ProgramNode
          visit(node.statements)
        when Prism::StatementsNode
          node.body&.each { |child| visit(child) }
        when Prism::ClassNode
          @class_extractor.extract(node) { visit_children(node) }
        when Prism::ModuleNode
          @module_extractor.extract(node) { visit_children(node) }
        when Prism::DefNode
          @method_extractor.extract(node)
          visit_children(node)
        when Prism::CallNode
          @call_extractor.extract(node)
          visit_children(node)
        when Prism::ConstantWriteNode, Prism::ConstantPathWriteNode
          @constant_extractor.extract(node)
          visit_children(node)
        when Prism::ClassVariableWriteNode
          @class_variable_extractor.extract(node)
          visit_children(node)
        when Prism::AliasNode
          @alias_extractor.extract(node)
          visit_children(node)
        else
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
