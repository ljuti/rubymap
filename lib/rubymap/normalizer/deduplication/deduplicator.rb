# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Deduplication
      # Handles symbol deduplication following SRP - only deduplication logic
      class Deduplicator
        def initialize(merge_strategy)
          @merge_strategy = merge_strategy
        end

        def deduplicate_symbols(result)
          # Merge duplicate methods with precedence rules
          result.methods = deduplicate_and_merge_methods(result.methods)

          # Merge duplicate classes/modules with precedence rules
          result.classes = deduplicate_and_merge_classes(result.classes)
          result.modules = deduplicate_and_merge_modules(result.modules)
        end

        private

        attr_reader :merge_strategy

        def deduplicate_and_merge_methods(methods)
          grouped = methods.group_by(&:symbol_id)

          grouped.map do |symbol_id, method_group|
            if method_group.size == 1
              method_group.first
            else
              merge_strategy.merge_methods(method_group)
            end
          end
        end

        def deduplicate_and_merge_classes(classes)
          grouped = classes.group_by(&:symbol_id)

          grouped.map do |symbol_id, class_group|
            if class_group.size == 1
              class_group.first
            else
              merge_strategy.merge_classes(class_group)
            end
          end
        end

        def deduplicate_and_merge_modules(modules)
          grouped = modules.group_by(&:symbol_id)

          grouped.map do |symbol_id, module_group|
            if module_group.size == 1
              module_group.first
            else
              merge_strategy.merge_modules(module_group)
            end
          end
        end
      end
    end
  end
end
