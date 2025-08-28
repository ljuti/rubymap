# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Resolvers
      # Resolves cross-references between methods and classes following SRP
      class CrossReferenceResolver
        def initialize(symbol_index)
          @symbol_index = symbol_index
        end

        def resolve(result)
          resolve_cross_references(result)
        end

        private

        attr_reader :symbol_index

        def resolve_cross_references(result)
          # Associate methods with their owner classes
          result.methods.each do |method|
            owner = find_symbol(method.owner, result)
            next unless owner
            
            if method.scope == "class"
              owner.class_methods << method.name if owner.respond_to?(:class_methods)
            else
              owner.instance_methods << method.name if owner.respond_to?(:instance_methods)
            end
            
            # Track availability through inheritance
            track_method_availability(method, owner, result)
          end
        end

        def track_method_availability(method, owner, result)
          # Add to available_in for the owner and all descendants
          method.available_in << owner.fqname
          
          # Find all classes that inherit from owner
          result.classes.each do |klass|
            if klass.inheritance_chain.include?(owner.fqname)
              if method.scope == "class"
                klass.available_class_methods << method.name
              else
                klass.available_instance_methods << method.name
              end
              
              method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
            end
          end
        end

        def find_symbol(name, result)
          result.classes.find { |c| c.fqname == name || c.name == name } ||
          result.modules.find { |m| m.fqname == name || m.name == name }
        end
      end
    end
  end
end