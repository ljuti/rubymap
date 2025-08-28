# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Normalizers
      # Handles name normalization following Strategy pattern
      class NameNormalizer
        def generate_fqname(name, namespace = nil)
          return name unless namespace && !namespace.empty?
          "#{namespace}::#{name}"
        end

        def extract_namespace_path(name)
          return [] unless name.include?("::")
          
          parts = name.split("::")
          parts[0...-1]
        end

        def to_snake_case(name)
          name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase
        end
      end
    end
  end
end