# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts module definitions from AST nodes
    class ModuleExtractor < BaseExtractor
      def extract(node, &block)
        name = extract_constant_name(node.constant_path)
        doc = extract_documentation(node)

        # Note: We don't need the full_name anymore since we're only pushing the simple name
        # (context.current_namespace && !context.current_namespace.empty?) ? "#{context.current_namespace}::#{name}" : name

        module_info = ModuleInfo.new(
          name: name,  # Use simple name, namespace is separate
          location: node.location,
          doc: doc,
          namespace: context.current_namespace,
          is_concern: false # Will be detected later by pattern detection
        )

        result.modules << module_info

        # Process module body with updated context
        # Only push the simple name, not the full name to avoid duplication
        context.with_namespace(name) do
          context.with_visibility(:public) do
            yield if block_given?
          end
        end
      end
    end
  end
end
