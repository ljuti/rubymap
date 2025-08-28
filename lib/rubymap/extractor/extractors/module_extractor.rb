# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts module definitions from AST nodes
    class ModuleExtractor < BaseExtractor
      def extract(node, &block)
        name = extract_constant_name(node.constant_path)
        doc = extract_documentation(node)

        # Build fully qualified name if within a namespace
        full_name = context.current_namespace && !context.current_namespace.empty? ? "#{context.current_namespace}::#{name}" : name

        module_info = ModuleInfo.new(
          name: full_name,
          location: node.location,
          doc: doc,
          namespace: context.current_namespace,
          is_concern: false # Will be detected later by pattern detection
        )

        result.modules << module_info

        # Process module body with updated context
        # Use the full_name for nested namespace
        context.with_namespace(full_name) do
          context.with_visibility(:public) do
            yield if block_given?
          end
        end
      end
    end
  end
end
