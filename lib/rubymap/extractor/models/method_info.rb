# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about a Ruby method definition
    class MethodInfo
      attr_accessor :name, :visibility, :receiver_type, :params, :location,
        :doc, :namespace, :owner

      def initialize(name:, visibility: "public", receiver_type: "instance",
        params: [], location: nil, doc: nil, namespace: nil, owner: nil)
        @name = name
        @visibility = visibility
        @receiver_type = receiver_type
        @params = params
        @location = location
        @doc = doc
        @namespace = namespace
        @owner = owner
      end

      def full_name
        prefix = namespace || owner
        return name unless prefix

        separator = (receiver_type == "instance") ? "#" : "."
        "#{prefix}#{separator}#{name}"
      end

      def scope
        (receiver_type == "class") ? "class" : "instance"
      end
    end
  end
end
