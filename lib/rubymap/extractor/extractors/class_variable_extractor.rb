# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts class variable definitions from AST nodes
    class ClassVariableExtractor < BaseExtractor
      def extract(node)
        name = node.name.to_s
        
        # Extract the initial value if present
        initial_value = if node.value
          # Get the source code for the value node
          node.value.slice
        end

        class_var_info = ClassVariableInfo.new(
          name: name,
          location: node.location,
          namespace: context.current_namespace,
          initial_value: initial_value
        )

        result.class_variables << class_var_info
      end
    end
  end
end
