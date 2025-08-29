# frozen_string_literal: true

module Rubymap
  class Extractor
    module Services
      # Service for handling namespace-related operations
      class NamespaceService
        # Build a fully qualified name from parts
        def build_fqname(*parts)
          parts.flatten.compact.reject(&:empty?).join("::")
        end

        # Extract namespace path from a fully qualified name
        def extract_namespace_path(fqname)
          return [] unless fqname

          parts = fqname.to_s.split("::")
          return [] if parts.size <= 1

          parts[0...-1]
        end

        # Get the simple name from a fully qualified name
        def extract_simple_name(fqname)
          return nil unless fqname

          fqname.to_s.split("::").last
        end

        # Get the parent namespace from a fully qualified name
        def extract_parent_namespace(fqname)
          return nil unless fqname

          parts = fqname.to_s.split("::")
          return nil if parts.size <= 1

          parts[0...-1].join("::")
        end

        # Check if a name is fully qualified
        def fully_qualified?(name)
          name.to_s.start_with?("::")
        end

        # Normalize a name (remove leading :: if present)
        def normalize_name(name)
          return nil unless name

          name.to_s.gsub(/^::/, "")
        end

        # Resolve a name within a given namespace context
        def resolve_in_namespace(name, namespace)
          return name if fully_qualified?(name)
          return name if namespace.nil? || namespace.empty?

          "#{namespace}::#{name}"
        end

        # Check if a namespace is nested within another
        def nested_in?(child_namespace, parent_namespace)
          return false if child_namespace.nil? || parent_namespace.nil?

          child_namespace.to_s.start_with?("#{parent_namespace}::")
        end

        # Calculate the nesting level of a namespace
        def nesting_level(namespace)
          return 0 if namespace.nil? || namespace.empty?

          namespace.to_s.split("::").size
        end

        # Find the common namespace between two fully qualified names
        def common_namespace(fqname1, fqname2)
          return nil if fqname1.nil? || fqname2.nil?

          parts1 = fqname1.to_s.split("::")
          parts2 = fqname2.to_s.split("::")

          common_parts = []
          parts1.zip(parts2).each do |p1, p2|
            break unless p1 == p2
            common_parts << p1
          end

          common_parts.empty? ? nil : common_parts.join("::")
        end
      end
    end
  end
end
