# frozen_string_literal: true

module Rubymap
  class Extractor
    # Value object holding the results of analyzing a method body.
    #
    # Collected by MethodBodyVisitor during recursive AST traversal and
    # attached to MethodInfo after extraction completes.
    class MethodBodyResult
      # @return [Array<Hash>] Recorded call hashes with keys:
      #   :receiver, :method, :arguments, :has_block
      attr_accessor :calls

      # @return [Integer] Number of branch points (if/elsif/unless/case/rescue)
      attr_accessor :branches

      # @return [Integer] Number of loops (while/until/for + block iterators)
      attr_accessor :loops

      # @return [Integer] Number of conditionals (if/unless with if_keyword_loc)
      attr_accessor :conditionals

      # @return [Integer] Line count of the method body
      attr_accessor :body_lines

      def initialize(calls: [], branches: 0, loops: 0, conditionals: 0, body_lines: 0)
        @calls = calls
        @branches = branches
        @loops = loops
        @conditionals = conditionals
        @body_lines = body_lines
      end

      # Convert to a hash suitable for serialization.
      # @return [Hash]
      def to_h
        {
          calls: @calls,
          branches: @branches,
          loops: @loops,
          conditionals: @conditionals,
          body_lines: @body_lines
        }
      end
    end
  end
end
