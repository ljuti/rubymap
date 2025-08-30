# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about a Ruby class definition
    class ClassInfo
      attr_accessor :name, :type, :superclass, :location, :doc, :namespace, :rubymap

      def initialize(name:, type: "class", superclass: nil, location: nil, doc: nil, namespace: nil, rubymap: nil)
        @name = name
        @type = type
        @superclass = superclass
        @location = location
        @doc = doc
        @namespace = namespace
        @rubymap = rubymap
      end

      def full_name
        namespace ? "#{namespace}::#{name}" : name
      end
    end
  end
end
