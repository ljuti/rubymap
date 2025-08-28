# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Resolvers
      # Resolves methods from included/extended modules following SRP
      class MixinMethodResolver
        def resolve(result)
          resolve_mixin_methods(result)
        end

        private

        def resolve_mixin_methods(result)
          # Resolve methods from included/extended modules
          result.classes.each do |klass|
            next unless klass.respond_to?(:mixins) && klass.mixins

            klass.mixins.each do |mixin|
              module_obj = find_symbol(mixin[:module], result)
              next unless module_obj

              # Find methods from the mixed-in module
              module_methods = result.methods.select { |m| m.owner == mixin[:module] }

              module_methods.each do |method|
                if mixin[:type] == "include"
                  handle_include_mixin(method, klass)
                elsif mixin[:type] == "extend"
                  handle_extend_mixin(method, klass)
                end
              end
            end
          end
        end

        def handle_include_mixin(method, klass)
          # Include adds instance methods from module
          # And class methods from module are also made available
          if method.scope == "instance"
            klass.available_instance_methods << method.name
            method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
          elsif method.scope == "class"
            # Module class methods become available as class methods on the including class
            klass.available_class_methods << method.name
            method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
          end
        end

        def handle_extend_mixin(method, klass)
          # Extend adds module's instance methods as class methods
          if method.scope == "instance"
            klass.available_class_methods << method.name
            method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
          elsif method.scope == "class"
            # Module's class methods also become class methods
            klass.available_class_methods << method.name
            method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
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
