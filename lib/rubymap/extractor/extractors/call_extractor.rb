# frozen_string_literal: true

require_relative "base_extractor"

module Rubymap
  class Extractor
    # Extracts information from method calls (attr_*, include, require, etc.)
    class CallExtractor < BaseExtractor
      def extract(node)
        return unless node.name

        case node.name
        when :attr_reader, :attr_writer, :attr_accessor
          extract_attributes(node)
        when :include, :extend, :prepend
          extract_mixin(node)
        when :private, :protected, :public
          handle_visibility_change(node)
        when :require, :require_relative
          extract_dependency(node)
        when :autoload
          extract_autoload(node)
        when :alias_method
          extract_alias(node)
        end
      end

      private

      def extract_attributes(node)
        type = node.name.to_s.sub("attr_", "")

        node.arguments&.arguments&.each do |arg|
          next unless arg.is_a?(Prism::SymbolNode)

          attribute_info = AttributeInfo.new(
            name: arg.unescaped,
            type: type,
            location: arg.location,
            namespace: context.current_namespace
          )

          result.attributes << attribute_info
        end
      end

      def extract_mixin(node)
        return unless node.arguments&.arguments&.first

        module_name = extract_constant_name(node.arguments.arguments.first)

        mixin_info = MixinInfo.new(
          type: node.name.to_s,
          module_name: module_name,
          target: context.current_namespace,
          location: node.location
        )

        result.mixins << mixin_info

        # Detect ActiveSupport::Concern pattern
        if module_name == "ActiveSupport::Concern" && node.name == :extend
          pattern = PatternInfo.new(
            type: "concern",
            target: context.current_namespace,
            location: node.location,
            indicators: ["ActiveSupport::Concern"]
          )
          result.patterns << pattern

          # Mark the current module as a concern
          if (current_module = result.modules.last) && current_module.namespace == context.current_namespace
            current_module.is_concern = true
          end
        end
      end

      def handle_visibility_change(node)
        # Change the current visibility in the context
        context.pop_visibility
        context.push_visibility(node.name)
      end

      def extract_dependency(node)
        return unless node.arguments&.arguments&.first

        arg = node.arguments.arguments.first
        path = case arg
        when Prism::StringNode then arg.unescaped
        when Prism::InterpolatedStringNode then arg.parts.map(&:unescaped).join
        else return
        end

        dependency_info = DependencyInfo.new(
          type: node.name.to_s,
          path: path,
          location: node.location
        )

        result.dependencies << dependency_info
      end

      def extract_autoload(node)
        return unless node.arguments&.arguments&.size == 2

        constant = node.arguments.arguments[0]
        path = node.arguments.arguments[1]

        return unless constant.is_a?(Prism::SymbolNode) && path.is_a?(Prism::StringNode)

        dependency_info = DependencyInfo.new(
          type: "autoload",
          path: path.unescaped,
          constant: constant.unescaped,
          location: node.location
        )

        result.dependencies << dependency_info
      end

      def extract_alias(node)
        return unless node.arguments&.arguments&.size == 2

        new_name = extract_symbol_or_string(node.arguments.arguments[0])
        original_name = extract_symbol_or_string(node.arguments.arguments[1])

        return unless new_name && original_name

        alias_info = AliasInfo.new(
          new_name: new_name,
          original_name: original_name,
          location: node.location,
          namespace: context.current_namespace
        )

        result.aliases << alias_info
      end

      def extract_symbol_or_string(node)
        case node
        when Prism::SymbolNode then node.unescaped
        when Prism::StringNode then node.unescaped
        end
      end
    end
  end
end
