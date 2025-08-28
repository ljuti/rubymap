# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts class definitions from AST nodes
    class ClassExtractor < BaseExtractor
      def extract(node)
        name = extract_constant_name(node.constant_path)
        superclass = node.superclass ? extract_constant_name(node.superclass) : nil
        doc = extract_documentation(node)

        # Build fully qualified name if within a namespace
        full_name = context.current_namespace && !context.current_namespace.empty? ? "#{context.current_namespace}::#{name}" : name

        class_info = ClassInfo.new(
          name: full_name,
          superclass: superclass,
          location: node.location,
          doc: doc,
          namespace: context.current_namespace
        )

        result.classes << class_info

        # Process class body with updated context
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
