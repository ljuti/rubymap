# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Output
      # Ensures deterministic output ordering following SRP
      class DeterministicFormatter
        def format(result)
          ensure_deterministic_output(result)
        end

        private

        def ensure_deterministic_output(result)
          # Sort all collections by stable criteria
          result.classes.sort_by! { |c| [c.fqname, c.symbol_id] }
          result.modules.sort_by! { |m| [m.fqname, m.symbol_id] }
          result.methods.sort_by! { |m| [m.fqname, m.symbol_id] }
          result.method_calls.sort_by! { |mc| [mc.from, mc.to] }
          
          # Sort nested collections
          result.classes.each do |klass|
            klass.children.sort! if klass.children
            klass.instance_methods.sort! if klass.instance_methods
            klass.class_methods.sort! if klass.class_methods
            klass.available_instance_methods.sort! if klass.available_instance_methods
            klass.available_class_methods.sort! if klass.available_class_methods
          end
          
          result.modules.each do |mod|
            mod.children.sort! if mod.children
          end
          
          result.methods.each do |method|
            method.available_in.sort! if method.available_in
          end
        end
      end
    end
  end
end