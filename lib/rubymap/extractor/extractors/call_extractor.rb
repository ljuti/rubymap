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
        when :has_many, :has_one, :belongs_to, :has_and_belongs_to_many
          record_rails_dsl(node)
        when :before_action, :after_action, :around_action,
             :skip_before_action, :skip_after_action, :skip_around_action,
             :before_filter, :after_filter, :around_filter,
             :skip_before_filter, :skip_after_filter, :skip_around_filter
          record_rails_dsl(node)
        when :scope, :default_scope, :rescue_from, :delegate
          record_rails_dsl(node)
        end

        # Catch validates and validates_* variants that don't match explicit when clauses
        record_rails_dsl(node) if node.name.to_s.start_with?("validates")
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

      # Record a Rails DSL pattern (e.g., has_many, validates, before_action).
      # Only records when context.current_class is set (i.e., inside a class/module body).
      def record_rails_dsl(node)
        return unless context.current_class

        args = extract_rails_dsl_arguments(node)

        pattern = PatternInfo.new(
          type: "rails_dsl",
          method: node.name.to_s,
          target: context.current_class,
          location: node.location,
          indicators: args
        )

        result.patterns << pattern
      end

      # Extract argument values from a Rails DSL call for pattern indicators.
      def extract_rails_dsl_arguments(node)
        return [] unless node.arguments&.arguments

        node.arguments.arguments.map do |arg|
          case arg
          when Prism::SymbolNode then arg.unescaped
          when Prism::StringNode then arg.unescaped
          when Prism::KeywordHashNode
            arg.elements.map do |el|
              if el.key.respond_to?(:unescaped)
                el.key.unescaped
              elsif el.key.respond_to?(:name)
                el.key.name.to_s
              else
                el.key.to_s
              end
            end
          else
            arg.respond_to?(:slice) ? arg.slice : arg.class.name
          end
        end.flatten
      end

      # Resolve a constant path node to a "::"-joined string.
      def resolve_constant_path(node)
        extract_constant_name(node)
      end
    end
  end
end
