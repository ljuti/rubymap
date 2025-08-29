# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Processes mixin relationships following SRP - handles only mixin logic
      class MixinProcessor < BaseProcessor
        def process(mixins, result, errors, collected_mixins = [])
          # Process module inclusions from raw data or accumulated mixins
          mixins_to_process = mixins + collected_mixins

          mixins_to_process.each do |mixin_data|
            target_class = find_symbol(mixin_data[:target], result)
            next unless target_class

            target_class.mixins ||= []
            new_mixin = {
              type: mixin_data[:type],
              module: mixin_data[:module]
            }

            # Only add if not already present (check both module name variations)
            module_name = mixin_data[:module]
            base_module_name = module_name.split("::").last

            unless target_class.mixins.any? { |m|
              m[:type] == new_mixin[:type] &&
                  (m[:module] == module_name || m[:module] == base_module_name ||
                   m[:module].split("::").last == base_module_name)
            }
              target_class.mixins << new_mixin
            end
          end
        end

        def validate(data, errors)
          # Mixins have different validation requirements
          true
        end

        private

        def find_symbol(name, result)
          result.classes.find { |c| c.fqname == name || c.name == name } ||
            result.modules.find { |m| m.fqname == name || m.name == name }
        end
      end
    end
  end
end
