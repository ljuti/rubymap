# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts class definitions from AST nodes
    class ClassExtractor < BaseExtractor
      def extract(node)
        name = extract_constant_name(node.constant_path)
        superclass = extract_superclass(node)
        doc = extract_documentation(node)

        # Note: We don't need the full_name anymore since we're only pushing the simple name
        # namespace_service.resolve_in_namespace(name, context.current_namespace)

        class_info = ClassInfo.new(
          name: name,  # Use simple name, namespace is separate
          superclass: superclass,
          location: node.location,
          doc: doc,
          namespace: context.current_namespace
        )

        result.classes << class_info

        # Process class body with updated context
        # Only push the simple name, not the full name to avoid duplication
        context.with_namespace(name) do
          context.with_visibility(:public) do
            yield if block_given?
          end
        end
      end

      private

      def extract_superclass(node)
        return nil unless node.superclass

        # Check if it's a Struct.new call
        if node.superclass.is_a?(Prism::CallNode)
          receiver = node.superclass.receiver
          if receiver && extract_constant_name(receiver) == "Struct" && node.superclass.name == :new
            return "Struct"
          end
        end

        extract_constant_name(node.superclass)
      end
    end
  end
end
