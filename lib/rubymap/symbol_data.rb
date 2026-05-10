# frozen_string_literal: true

module Rubymap
  # Typed value object wrapping symbol hash data from the pipeline.
  #
  # Provides named accessors for common symbol fields while maintaining
  # backward compatibility with hash-style access ([] and dig).
  # This gives the LLM emitter ecosystem a typed contract instead of
  # arbitrary hash key access.
  #
  # @example
  #   data = SymbolData.new(fqname: "User", type: "class", superclass: "AR")
  #   data.fqname        # => "User"
  #   data[:fqname]      # => "User"  (backward compat)
  #   data.instance_methods  # => []  (nil-safe)
  class SymbolData
    def initialize(hash = {})
      @data = hash || {}
    end

    # Named accessors with nil-safety for collection fields
    def fqname = @data[:fqname]

    def type = @data[:type]

    def superclass = @data[:superclass]

    def file = @data[:file]

    def line = @data[:line]

    def documentation = @data[:documentation]

    def namespace = @data[:namespace]

    def instance_methods = @data[:instance_methods] || []

    def class_methods = @data[:class_methods] || []

    def dependencies = @data[:dependencies] || []

    def mixins = @data[:mixins] || []

    # Metrics accessors
    def metrics = @data[:metrics] || {}

    def complexity_score = metrics[:complexity_score]

    def cyclomatic_complexity = @data[:cyclomatic_complexity] || metrics[:cyclomatic_complexity]

    def total_complexity = @data[:total_complexity] || metrics[:total_complexity]

    def quality_score = @data[:quality_score]

    def maintainability_score = @data[:maintainability_score]

    def public_api_surface = @data[:public_api_surface] || metrics[:public_api_surface]

    def test_coverage = @data[:test_coverage] || metrics[:test_coverage]

    def fan_in = @data[:fan_in]

    def fan_out = @data[:fan_out]

    def coupling_strength = @data[:coupling_strength]

    # Nested data access (for chunk metadata, etc.)
    def [](key) = @data[key]

    def dig(*keys) = @data.dig(*keys)

    def to_h = @data

    def empty? = @data.empty?

    def nil? = @data.nil?

    def any? = @data.any?

    # Array-like interface for iteration over multiple symbols
    def each(&) = @data.each(&) if @data.is_a?(Hash)
  end
end
