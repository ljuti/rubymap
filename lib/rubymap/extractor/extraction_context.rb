# frozen_string_literal: true

module Rubymap
  class Extractor
    # Manages the extraction context during AST traversal
    class ExtractionContext
      attr_reader :namespace_stack, :visibility_stack, :current_class
      attr_accessor :comments

      def initialize
        @namespace_stack = []
        @visibility_stack = [:public]
        @current_class = nil
        @comments = []
      end

      def current_namespace
        @namespace_stack.join("::")
      end

      def current_visibility
        @visibility_stack.last || :public
      end

      def with_namespace(name)
        @namespace_stack.push(name)
        old_class = @current_class
        @current_class = name
        yield
      ensure
        @namespace_stack.pop
        @current_class = old_class
      end

      def with_visibility(visibility)
        @visibility_stack.push(visibility)
        yield
      ensure
        @visibility_stack.pop
      end
    end
  end
end
