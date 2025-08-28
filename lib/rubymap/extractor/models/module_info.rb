# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about a Ruby module definition
    class ModuleInfo
      attr_accessor :name, :location, :doc, :namespace, :is_concern

      def initialize(name:, location: nil, doc: nil, namespace: nil, is_concern: false)
        @name = name
        @location = location
        @doc = doc
        @namespace = namespace
        @is_concern = is_concern
      end

      def full_name
        namespace ? "#{namespace}::#{name}" : name
      end

      # For backward compatibility with tests
      def type
        "module"
      end
    end
  end
end
