# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts alias statements from AST nodes
    class AliasExtractor < BaseExtractor
      def extract(node)
        new_name = extract_method_name(node.new_name)
        old_name = extract_method_name(node.old_name)

        return unless new_name && old_name

        alias_info = AliasInfo.new(
          new_name: new_name,
          original_name: old_name,
          location: node.location,
          namespace: context.current_namespace
        )

        result.aliases << alias_info
      end

      private

      def extract_method_name(node)
        case node
        when Prism::SymbolNode
          node.unescaped
        when Prism::StringNode
          node.unescaped
        else
          node.slice if node.respond_to?(:slice)
        end
      end
    end
  end
end
