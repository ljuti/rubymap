# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts method definitions from AST nodes
    class MethodExtractor < BaseExtractor
      def extract(node)
        name = node.name.to_s
        receiver_type = determine_receiver_type(node)
        params = extract_parameters(node.parameters)
        doc = extract_method_documentation(node, params)
        
        # Extract YARD tags including @rubymap
        tags = extract_yard_tags(doc)
        rubymap = tags[:rubymap] if tags

        method_info = MethodInfo.new(
          name: name,
          visibility: context.current_visibility.to_s,
          receiver_type: receiver_type,
          params: params,
          location: node.location,
          doc: doc,
          namespace: context.current_namespace,
          owner: context.current_class,
          rubymap: rubymap
        )

        result.methods << method_info
      end

      private

      def determine_receiver_type(node)
        if node.receiver
          "class"
        else
          "instance"
        end
      end

      def extract_parameters(params_node)
        return [] unless params_node

        params = []

        # Required parameters
        params_node.requireds&.each do |param|
          params << {name: param.name.to_s, type: "required"}
        end

        # Optional parameters
        params_node.optionals&.each do |param|
          default = param.value ? extract_default_value(param.value) : nil
          params << {name: param.name.to_s, type: "optional", default: default}
        end

        # Rest parameters (*args)
        if params_node.rest
          params << {name: params_node.rest.name.to_s, type: "rest"}
        end

        # Keyword parameters
        params_node.keywords&.each do |param|
          default = param.value ? extract_default_value(param.value) : nil
          params << {name: param.name.to_s, type: "keyword", default: default}
        end

        # Keyword rest parameters (**kwargs)
        if params_node.keyword_rest
          params << {name: params_node.keyword_rest.name.to_s, type: "keyword_rest"}
        end

        # Block parameter
        if params_node.block
          params << {name: params_node.block.name.to_s, type: "block"}
        end

        params
      end

      def extract_default_value(node)
        case node
        when Prism::IntegerNode then node.value.to_s
        when Prism::FloatNode then node.value.to_s
        when Prism::StringNode then "\"#{node.unescaped}\""
        when Prism::SymbolNode then ":#{node.unescaped}"
        when Prism::TrueNode then "true"
        when Prism::FalseNode then "false"
        when Prism::NilNode then "nil"
        when Prism::ArrayNode then "[]"
        when Prism::HashNode then "{}"
        else node.slice if node.respond_to?(:slice)
        end
      end

      def extract_method_documentation(node, params)
        doc = extract_documentation(node)
        return doc unless doc

        # Extract @param type hints from documentation
        params.each do |param|
          if (match = doc.match(/@param\s+#{Regexp.escape(param[:name])}\s+\[([^\]]+)\]/))
            param[:type_hint] = match[1]
          end
        end

        doc
      end
    end
  end
end
