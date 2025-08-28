# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Resolvers
      # Resolves inheritance chains following SRP - handles only inheritance relationships
      class InheritanceResolver
        def resolve(result)
          resolve_inheritance_chains(result)
        end

        private

        def resolve_inheritance_chains(result)
          result.classes.each do |klass|
            chain = build_inheritance_chain(klass, result.classes)
            klass.inheritance_chain = chain
          end
        end

        def build_inheritance_chain(klass, all_classes)
          chain = [klass.fqname]
          current = klass
          
          while current.superclass
            chain << current.superclass
            current = all_classes.find { |c| c.fqname == current.superclass }
            break unless current
          end
          
          chain
        end
      end
    end
  end
end