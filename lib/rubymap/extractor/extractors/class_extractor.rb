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

        # Build fully qualified name if within a namespace
        full_name = (context.current_namespace && !context.current_namespace.empty?) ? "#{context.current_namespace}::#{name}" : name

        class_info = ClassInfo.new(
          name: name,  # Use simple name, namespace is separate
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
