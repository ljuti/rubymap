# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates public API surface area metrics
      class ApiSurfaceMetric < BaseMetric
        def calculate(result, config)
          config_value(config, :api_size_threshold, 20)

          # Calculate for classes
          result.classes.each do |klass|
            calculate_class_api_surface(klass, result.methods)
          end

          # Calculate for modules
          result.modules.each do |mod|
            calculate_module_api_surface(mod, result.methods)
          end
        end

        private

        def calculate_class_api_surface(klass, all_methods)
          public_instance_count = 0
          public_class_count = 0

          # If we have visibility information, use it
          if klass.respond_to?(:visibility) && klass.visibility
            # Count public instance methods
            if klass.instance_methods
              public_instance_count = klass.instance_methods.count do |method_name|
                klass.visibility[method_name] == "public"
              end
            end

            # Class methods are typically all public unless specified otherwise
            if klass.class_methods
              public_class_count = klass.class_methods.count do |method_name|
                # If no visibility info for class methods, assume public
                visibility = klass.visibility[method_name]
                visibility.nil? || visibility == "public"
              end
            end
          else
            # Fall back to checking methods in the result
            class_methods = all_methods.select { |m| m.owner == klass.name }

            class_methods.each do |method|
              next unless method.visibility == "public"

              if method.scope == "instance"
                public_instance_count += 1
              elsif method.scope == "class"
                public_class_count += 1
              end
            end
          end

          klass.public_api_surface = public_instance_count + public_class_count
        end

        def calculate_module_api_surface(mod, all_methods)
          return unless mod.respond_to?(:public_api_surface=)

          public_count = 0

          # Find methods belonging to this module
          module_methods = all_methods.select { |m| m.owner == mod.name }

          # Count public methods
          module_methods.each do |method|
            public_count += 1 if method.visibility == "public"
          end

          # Alternative: use the method lists if available
          if mod.respond_to?(:visibility) && mod.visibility && mod.instance_methods
            public_count = count_public_methods(mod.instance_methods, mod.visibility)
          end

          mod.public_api_surface = public_count
        end

        def count_public_methods(methods, visibility_hash)
          return 0 unless methods && visibility_hash

          methods.count { |method_name| visibility_hash[method_name] == "public" }
        end
      end
    end
  end
end
