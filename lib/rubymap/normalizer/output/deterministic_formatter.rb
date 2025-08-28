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
            klass.children&.sort!
            klass.instance_methods&.sort!
            klass.class_methods&.sort!
            klass.available_instance_methods&.sort!
            klass.available_class_methods&.sort!
          end

          result.modules.each do |mod|
            mod.children&.sort!
          end

          result.methods.each do |method|
            method.available_in&.sort!
          end
        end
      end
    end
  end
end
