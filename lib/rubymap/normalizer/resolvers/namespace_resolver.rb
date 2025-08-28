# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Resolvers
      # Resolves namespace hierarchies following SRP - handles only namespace relationships
      class NamespaceResolver
        def resolve(result)
          build_namespace_hierarchies(result)
        end

        private

        def build_namespace_hierarchies(result)
          # Group by namespace levels
          all_symbols = result.classes + result.modules

          all_symbols.each do |symbol|
            next unless symbol.fqname.include?("::")

            parent_name = symbol.namespace_path.join("::")
            parent = all_symbols.find { |s| s.fqname == parent_name }

            if parent
              parent.children << symbol.fqname
            end
          end
        end
      end
    end
  end
end
