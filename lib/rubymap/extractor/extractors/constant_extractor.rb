# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts constant definitions from AST nodes
    class ConstantExtractor < BaseExtractor
      def extract(node)
        name = extract_constant_name_from_write(node)
        value = extract_constant_value(node.value) if node.respond_to?(:value)

        constant_info = ConstantInfo.new(
          name: name,
          value: value,
          location: node.location,
          namespace: context.current_namespace
        )

        result.constants << constant_info
      end

      private

      def extract_constant_name_from_write(node)
        case node
        when Prism::ConstantWriteNode
          node.name.to_s
        when Prism::ConstantPathWriteNode
          extract_constant_name(node.target)
        end
      end

      def extract_constant_value(value_node)
        return nil unless value_node

        case value_node
        when Prism::IntegerNode
          value_node.value.to_s
        when Prism::FloatNode
          value_node.value.to_s
        when Prism::StringNode
          "\"#{value_node.unescaped}\""
        when Prism::SymbolNode
          ":#{value_node.unescaped}"
        when Prism::TrueNode
          "true"
        when Prism::FalseNode
          "false"
        when Prism::NilNode
          "nil"
        when Prism::ArrayNode
          extract_array_value(value_node)
        when Prism::HashNode
          extract_hash_value(value_node)
        when Prism::ConstantReadNode
          value_node.name.to_s
        when Prism::CallNode
          extract_call_value(value_node)
        else
          value_node.slice if value_node.respond_to?(:slice)
        end
      end

      def extract_array_value(node)
        elements = node.elements.map { |el| extract_constant_value(el) }
        "[#{elements.compact.join(", ")}]"
      end

      def extract_hash_value(node)
        pairs = node.elements.map do |element|
          if element.is_a?(Prism::AssocNode)
            key = extract_constant_value(element.key)
            value = extract_constant_value(element.value)
            "#{key} => #{value}"
          end
        end
        "{#{pairs.compact.join(", ")}}"
      end

      def extract_call_value(node)
        if node.receiver
          receiver = extract_constant_value(node.receiver)
          "#{receiver}.#{node.name}"
        else
          node.name.to_s
        end
      end
    end
  end
end
