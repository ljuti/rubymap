# frozen_string_literal: true

require_relative "../method_body_result"

module Rubymap
  class Extractor
    # Recursively walks a method body AST and records:
    #   - Every CallNode with receiver chain, method name, typed arguments
    #   - Loop counts from block iteration calls (each, map, etc.)
    #
    # @example
    #   visitor = MethodBodyVisitor.new
    #   result = visitor.visit(def_node.body)
    #   result.calls  # => [{receiver: [...], method: "save", arguments: [], has_block: false}, ...]
    class MethodBodyVisitor
      # Methods that indicate block-based iteration (increment loops counter).
      LOOP_METHODS = %i[
        each map collect select reject find detect
        reduce inject times upto downto step
        each_with_index each_with_object group_by partition sort_by flat_map
      ].freeze

      # Node types that have a meaningful :body accessor (DefNode, ClassNode, etc.)
      # but where we should not descend into nested definitions for call recording.
      # We still descend because inner method calls are important, but we track nesting.
      #
      # For safety we visit all child nodes regardless of type.

      # Visit a method body node and return a MethodBodyResult.
      #
      # @param body_node [Prism::Node, nil] The body of a DefNode (node.body)
      # @param def_node [Prism::DefNode, nil] The DefNode itself (for computing body_lines)
      # @return [MethodBodyResult]
      def visit(body_node, def_node = nil)
        result = MethodBodyResult.new

        # Compute body lines from the def node
        if def_node&.location
          result.body_lines = def_node.location.end_line - def_node.location.start_line
        end

        # Traverse the body
        traverse(body_node, result) if body_node

        result
      end

      private

      # Recursively traverse an AST node, dispatching by type.
      def traverse(node, result)
        return unless node

        case node
        when Prism::CallNode
          handle_call(node, result)
        when Prism::StatementsNode
          traverse_statements(node, result)
        when Prism::ProgramNode
          traverse(node.statements, result)
        # ── control-flow nodes ────────────────────────────────────────
        when Prism::IfNode
          result.branches += 1
          # Only count as conditional when if_keyword is "if" (not ternary ?: or elsif)
          result.conditionals += 1 if node.if_keyword == 'if'
          # An ElseNode consequent is an extra branch for if/elsif chains.
          # For ternaries (if_keyword_loc == nil), the ElseNode is the else-side
          # of ?: and already accounted for in the single ternary branch above.
          if node.consequent.is_a?(Prism::ElseNode) && node.if_keyword_loc
            result.branches += 1
          end
          traverse_children(node, result)
        when Prism::UnlessNode
          result.branches += 1
          result.conditionals += 1
          traverse_children(node, result)
        when Prism::WhileNode, Prism::UntilNode, Prism::ForNode
          result.branches += 1
          result.loops += 1
          traverse_children(node, result)
        when Prism::CaseNode
          result.branches += 1               # the case itself
          node.conditions&.each { |_| result.branches += 1 } # each when clause
          result.branches += 1 if node.consequent # else clause
          traverse_children(node, result)
        when Prism::AndNode, Prism::OrNode
          result.branches += 1
          traverse_children(node, result)
        when Prism::RescueModifierNode
          result.branches += 1
          traverse_children(node, result)
        when Prism::BeginNode
          traverse_children(node, result)
        else
          # For all other node types, recurse into children
          traverse_children(node, result)
        end
      end

      # Handle a CallNode: record the call and check for loop patterns.
      def handle_call(node, result)
        return unless node.name

        method_name = node.name.to_s
        receiver_chain = resolve_chain(node.receiver)
        args = extract_arguments(node.arguments)
        has_block = !node.block.nil?

        # Record the call
        result.calls << {
          receiver: receiver_chain,
          method: method_name,
          arguments: args,
          has_block: has_block
        }

        # If this is a block iteration call, count it as a loop
        if has_block && LOOP_METHODS.include?(node.name)
          result.loops += 1
        end

        # Recurse into arguments and block for nested calls
        traverse_arguments(node.arguments, result)
        traverse(node.block, result) if node.block
      end

      # Traverse a StatementsNode body.
      def traverse_statements(node, result)
        node.body&.each { |child| traverse(child, result) }
      end

      # Traverse all children of an arbitrary node.
      def traverse_children(node, result)
        if node.respond_to?(:child_nodes)
          node.child_nodes.compact.each { |child| traverse(child, result) }
        elsif node.respond_to?(:body)
          traverse(node.body, result)
        end
      rescue StandardError
        # Gracefully handle nodes that don't support child traversal
        # (some Prism nodes may not have either interface)
      end

      # Traverse the arguments of a call (they may contain nested calls).
      def traverse_arguments(arguments_node, result)
        return unless arguments_node
        return unless arguments_node.respond_to?(:arguments)

        arguments_node.arguments&.each do |arg|
          traverse(arg, result)
        end
      end

      # ── receiver resolution ────────────────────────────────────────────

      # Resolve a receiver node into an array of string components.
      #
      # nil → nil (self-call / no explicit receiver)
      # SelfNode → nil (self.foo treated as implicit receiver)
      # ConstantReadNode → [name]
      # ConstantPathNode → resolve_chain(parent) + [name]
      # CallNode → resolve_chain(receiver) + [name]
      def resolve_chain(receiver)
        return nil if receiver.nil?

        case receiver
        when Prism::SelfNode
          # self.foo is treated as an implicit receiver
          nil
        when Prism::ConstantReadNode
          [receiver.name.to_s]
        when Prism::ConstantPathNode
          parent_chain = resolve_chain(receiver.parent)
          name = receiver.name.to_s
          if parent_chain
            parent_chain + [name]
          else
            [name]
          end
        when Prism::CallNode
          parent_chain = resolve_chain(receiver.receiver)
          name = receiver.name.to_s
          if parent_chain
            parent_chain + [name]
          else
            [name]
          end
        else
          # For other receiver types (local variables, instance variables, etc.),
          # return a single-element array with a string representation.
          [receiver.slice]
        end
      rescue StandardError
        # If resolution fails, return what we can
        [receiver.respond_to?(:slice) ? receiver.slice : receiver.class.name]
      end
      # ── argument extraction ─────────────────────────────────────────────

      # Extract arguments from an ArgumentsNode into an array of typed hashes.
      #
      # Each element is {type: symbol, value: ...} with type-specific keys:
      #   :hash → also has :pairs
      #   :block → also has :source
      def extract_arguments(arguments_node)
        return [] unless arguments_node
        return [] unless arguments_node.respond_to?(:arguments)

        arguments_node.arguments.map { |arg| encode_argument(arg) }
      end

      # Encode a single argument node into its typed hash representation.
      def encode_argument(node)
        case node
        when Prism::SymbolNode
          {type: :symbol, value: node.unescaped}
        when Prism::StringNode
          {type: :string, value: node.unescaped}
        when Prism::InterpolatedStringNode
          {type: :string, value: reconstruct_interpolated(node)}
        when Prism::IntegerNode
          {type: :integer, value: node.value}
        when Prism::FloatNode
          {type: :float, value: node.value}
        when Prism::TrueNode
          {type: :boolean, value: true}
        when Prism::FalseNode
          {type: :boolean, value: false}
        when Prism::NilNode
          {type: :nil, value: nil}
        when Prism::KeywordHashNode
          pairs = extract_keyword_pairs(node)
          {type: :hash, pairs: pairs}
        when Prism::HashNode
          pairs = extract_hash_pairs(node)
          {type: :hash, pairs: pairs}
        when Prism::LambdaNode
          source = extract_source(node)
          {type: :block, source: source}
        when Prism::ArrayNode
          elements = node.elements.map { |el| encode_argument(el) }
          {type: :array, elements: elements}
        when Prism::ConstantReadNode
          {type: :constant, value: node.name.to_s}
        when Prism::ConstantPathNode
          {type: :constant, value: resolve_constant_path(node)}
        when Prism::CallNode
          # Nested call as argument (e.g., foo(bar()))
          encode_call_as_value(node)
        when Prism::LocalVariableReadNode
          {type: :local_variable, value: node.name.to_s}
        when Prism::InstanceVariableReadNode
          {type: :instance_variable, value: node.name.to_s}
        when Prism::ClassVariableReadNode
          {type: :class_variable, value: node.name.to_s}
        when Prism::GlobalVariableReadNode
          {type: :global_variable, value: node.name.to_s}
        when Prism::SelfNode
          {type: :self, value: 'self'}
        when Prism::RangeNode
          {type: :range, value: node.slice}
        when Prism::RegularExpressionNode
          {type: :regexp, value: node.slice}
        when Prism::SourceEncodingNode
          {type: :keyword, value: '__ENCODING__'}
        when Prism::SourceFileNode
          {type: :keyword, value: '__FILE__'}
        when Prism::SourceLineNode
          {type: :keyword, value: '__LINE__'}
        when Prism::SplatNode
          if node.expression
            inner = encode_argument(node.expression)
            {type: :splat, value: inner}
          else
            {type: :splat, value: nil}
          end
        when Prism::BlockArgumentNode
          if node.expression
            {type: :block_pass, value: encode_argument(node.expression)}
          else
            {type: :block_pass, value: nil}
          end
        when Prism::AssocSplatNode
          if node.value
            {type: :hash_splat, value: encode_argument(node.value)}
          else
            {type: :hash_splat, value: nil}
          end
        when Prism::AssocNode
          {type: :pair, key: encode_argument(node.key), value: encode_argument(node.value)}
        when Prism::ParenthesesNode
          if node.body
            # Parenthesized expression — encode its inner content
            encode_argument(node.body)
          else
            {type: :nil, value: nil}
          end
        else
          # Fallback: use source slice
          {type: :unknown, value: node.respond_to?(:slice) ? node.slice : node.class.name}
        end
      rescue StandardError
        {type: :error, value: node.respond_to?(:slice) ? node.slice : node.class.name}
      end

      # Extract keyword hash pairs (KeywordHashNode elements are AssocNodes).
      def extract_keyword_pairs(node)
        node.elements.map do |element|
          {
            key: element.key.respond_to?(:unescaped) ? element.key.unescaped : element.key.name.to_s,
            value: encode_argument(element.value)
          }
        end
      end

      # Extract hash pairs from a HashNode.
      def extract_hash_pairs(node)
        node.elements.map { |element| encode_argument(element) }
      end

      # Reconstruct an interpolated string from its parts.
      def reconstruct_interpolated(node)
        node.parts.map { |part|
          part.respond_to?(:unescaped) ? part.unescaped : part.slice
        }.join
      end

      # Encode a CallNode that appears as an argument value.
      def encode_call_as_value(node)
        {
          type: :call,
          receiver: resolve_chain(node.receiver),
          method: node.name.to_s,
          arguments: extract_arguments(node.arguments),
          has_block: !node.block.nil?
        }
      end

      # Extract source text from a node (for lambda blocks, etc.).
      def extract_source(node)
        node.respond_to?(:slice) ? node.slice : ''
      end

      # Resolve a constant path node to a "::"-joined string.
      def resolve_constant_path(node)
        parts = resolve_chain(node)
        parts&.join("::") || node.name.to_s
      end
    end
  end
end
