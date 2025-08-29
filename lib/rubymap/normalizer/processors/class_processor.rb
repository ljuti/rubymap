# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Processors
      # Simplified class processor using Template Method pattern
      # Focuses on core class normalization with reduced complexity
      class ClassProcessor < BaseProcessor
        def validate_specific(data, errors)
          # Check for empty name (nil is already handled in base class)
          if data[:name].empty?
            add_validation_error("Class/module name cannot be empty", data, errors)
            return false
          end

          # For now, don't require location as it's optional
          true
        end

        def normalize_item(data)
          # Determine if this is actually a module
          if module_type?(data)
            normalize_as_module(data)
          else
            normalize_as_class(data)
          end
        end

        def add_to_result(item, result)
          if item.kind == "module"
            result.modules << item
          else
            result.classes << item
          end
        end

        def post_process_item(item, raw_data, result)
          # Only process mixins for classes
          process_mixins(raw_data, item) if item.kind == "class"
        end

        private

        def module_type?(data)
          data[:type] == "module" || data[:kind] == "module"
        end

        def normalize_as_class(data)
          fqname = build_fqname(data)
          symbol_id = symbol_id_generator.generate_class_id(fqname, data[:type] || "class")

          # Use core domain model - cleaner and more focused
          CoreNormalizedClass.new(
            symbol_id: symbol_id,
            name: data[:name],
            fqname: fqname,
            kind: data[:type] || "class",
            superclass: data[:superclass],
            location: normalize_location(data[:location]),
            namespace_path: extract_namespace_path(fqname),
            provenance: create_provenance(data)
          )
        end

        def normalize_as_module(data)
          fqname = build_fqname(data)
          symbol_id = symbol_id_generator.generate_module_id(fqname)

          CoreNormalizedModule.new(
            symbol_id: symbol_id,
            name: data[:name],
            fqname: fqname,
            location: normalize_location(data[:location]),
            namespace_path: extract_namespace_path(fqname),
            provenance: create_provenance(data)
          )
        end

        def build_fqname(data)
          normalizers.name_normalizer.generate_fqname(data[:name], data[:namespace])
        end

        def normalize_location(location_data)
          return nil unless location_data

          Location.new(
            file: location_data[:file],
            line: location_data[:line]
          )
        end

        def extract_namespace_path(fqname)
          normalizers.name_normalizer.extract_namespace_path(fqname)
        end

        def process_mixins(raw_data, normalized_class)
          mixin_list = []

          # Handle included modules
          raw_data[:included_modules]&.each do |mod|
            mixin_list << {type: "include", module: mod}
          end

          # Handle extended modules
          raw_data[:extended_modules]&.each do |mod|
            mixin_list << {type: "extend", module: mod}
          end

          # Handle prepended modules
          raw_data[:prepended_modules]&.each do |mod|
            mixin_list << {type: "prepend", module: mod}
          end

          # Also handle direct mixins format
          raw_data[:mixins]&.each do |mixin|
            mixin_list << {
              type: mixin[:type],
              module: mixin[:module]
            }
          end

          # Update mixins if any were found
          normalized_class.mixins = mixin_list unless mixin_list.empty?
        end
      end
    end
  end
end
