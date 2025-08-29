# frozen_string_literal: true

module Rubymap
  class Extractor
    # Manages the extraction context during AST traversal
    class ExtractionContext
      attr_reader :current_class
      attr_accessor :comments

      def initialize
        @namespace_stack = []
        @visibility_stack = [:public]
        @current_class = nil
        @comments = []
      end

      # Public API for namespace management
      def current_namespace
        @namespace_stack.join("::")
      end

      def push_namespace(name)
        @namespace_stack.push(name)
      end

      def pop_namespace
        @namespace_stack.pop
      end

      def namespace_depth
        @namespace_stack.size
      end

      def with_namespace(name)
        push_namespace(name)
        old_class = @current_class
        @current_class = name
        yield
      ensure
        pop_namespace
        @current_class = old_class
      end

      # Public API for visibility management
      def current_visibility
        @visibility_stack.last || :public
      end

      def push_visibility(visibility)
        @visibility_stack.push(visibility)
      end

      def pop_visibility
        @visibility_stack.pop
      end

      def visibility_depth
        @visibility_stack.size
      end

      def with_visibility(visibility)
        push_visibility(visibility)
        yield
      ensure
        pop_visibility
      end

      # Reset context to initial state
      def reset!
        @namespace_stack.clear
        @visibility_stack = [:public]
        @current_class = nil
        @comments = []
      end

      # Debugging helpers
      def namespace_stack
        @namespace_stack.dup.freeze
      end

      def visibility_stack
        @visibility_stack.dup.freeze
      end
    end
  end
end
