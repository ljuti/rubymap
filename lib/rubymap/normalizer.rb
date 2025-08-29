# frozen_string_literal: true

require "digest"

# Load all components
require_relative "normalizer/domain_model"
require_relative "normalizer/service_container"
require_relative "normalizer/symbol_finder"
require_relative "normalizer/processor_factory"
require_relative "normalizer/resolver_factory"
require_relative "normalizer/processing_pipeline"
require_relative "normalizer/symbol_index"
require_relative "normalizer/normalizer_registry"

require_relative "normalizer/processors/base_processor"
require_relative "normalizer/processors/class_processor"
require_relative "normalizer/processors/module_processor"
require_relative "normalizer/processors/method_processor"
require_relative "normalizer/processors/method_call_processor"
require_relative "normalizer/processors/mixin_processor"

require_relative "normalizer/resolvers/namespace_resolver"
require_relative "normalizer/resolvers/inheritance_resolver"
require_relative "normalizer/resolvers/cross_reference_resolver"
require_relative "normalizer/resolvers/mixin_method_resolver"

require_relative "normalizer/deduplication/deduplicator"
require_relative "normalizer/deduplication/merge_strategy"

require_relative "normalizer/output/deterministic_formatter"

module Rubymap
  # Normalizes extracted Ruby symbols into a consistent format
  # Refactored to follow SOLID principles with clear separation of concerns
  class Normalizer
    # Schema version for normalized output
    SCHEMA_VERSION = 1

    # Normalizer version for tracking changes
    NORMALIZER_VERSION = "1.0.0"

    # Data source types for provenance tracking
    DATA_SOURCES = {
      static: "static",
      runtime: "runtime",
      yard: "yard",
      rbs: "rbs",
      sorbet: "sorbet",
      inferred: "inferred"
    }.freeze

    # Precedence order (higher number = higher precedence)
    SOURCE_PRECEDENCE = {
      DATA_SOURCES[:inferred] => 1,
      DATA_SOURCES[:yard] => 2,
      DATA_SOURCES[:sorbet] => 3,
      DATA_SOURCES[:rbs] => 4,
      DATA_SOURCES[:runtime] => 5,
      DATA_SOURCES[:static] => 6
    }.freeze

    def initialize(container = nil)
      @container = container || ServiceContainer.new
      @processing_pipeline = ProcessingPipeline.new(@container)
    end

    # Main normalization method - delegates to processing pipeline
    def normalize(raw_data)
      @container.get(:symbol_index).clear
      @processing_pipeline.execute(raw_data)
    end

    private

    attr_reader :container

    # Symbol ID generator using Strategy pattern (moved from original class)
    class SymbolIdGenerator
      def generate_class_id(fqname, kind = "class")
        generate_id("c", fqname, kind)
      end

      def generate_module_id(fqname)
        generate_id("m", fqname, "module")
      end

      def generate_method_id(fqname:, receiver:, arity:)
        generate_id("m", fqname, receiver, arity.to_s)
      end

      private

      def generate_id(*components)
        content = components.compact.join("/")
        Digest::SHA256.hexdigest(content)[0..15] # Use first 16 characters for shorter IDs
      end
    end

    # Provenance tracking for data sources and confidence (moved from original class)
    class ProvenanceTracker
      def create_provenance(sources:, confidence: 0.5)
        Provenance.new(
          sources: Array(sources),
          confidence: confidence,
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end

      def merge_provenance(existing, new_provenance)
        merged_sources = (existing.sources + new_provenance.sources).uniq
        highest_confidence = [existing.confidence, new_provenance.confidence].max

        Provenance.new(
          sources: merged_sources,
          confidence: highest_confidence,
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end
    end

    # Result object to hold normalized data
    class NormalizedResult
      attr_accessor :classes, :modules, :methods, :method_calls, :errors,
        :schema_version, :normalizer_version, :normalized_at

      def initialize(schema_version: nil, normalizer_version: nil, normalized_at: nil)
        @classes = []
        @modules = []
        @methods = []
        @method_calls = []
        @errors = []
        @schema_version = schema_version
        @normalizer_version = normalizer_version
        @normalized_at = normalized_at
      end
    end

    # Provenance information for tracking data sources
    Provenance = Struct.new(
      :sources, :confidence, :timestamp,
      keyword_init: true
    )

    # Error structure for validation
    NormalizedError = Struct.new(
      :type, :message, :data,
      keyword_init: true
    )

    # Normalized data structures with provenance and symbol IDs
    NormalizedClass = Struct.new(
      :symbol_id, :name, :fqname, :kind, :superclass, :location,
      :namespace_path, :children, :inheritance_chain,
      :instance_methods, :class_methods,
      :available_instance_methods, :available_class_methods,
      :mixins, :provenance,
      # Additional fields for testing and analysis (optional)
      :dependencies, :visibility, :git_commits, :last_modified,
      :age_in_days, :test_coverage, :documentation_coverage, :churn_score,
      :file, :implements,
      # Rails-specific fields (optional)
      :associations, :validations, :scopes,
      :actions, :filters, :rescue_handlers,
      # Test data fields
      :method_names,
      keyword_init: true
    )

    NormalizedModule = Struct.new(
      :symbol_id, :name, :fqname, :kind, :location,
      :namespace_path, :children, :provenance,
      # Additional fields for testing
      :instance_methods, :visibility,
      keyword_init: true
    )

    NormalizedMethod = Struct.new(
      :symbol_id, :name, :fqname, :visibility, :owner, :scope,
      :parameters, :arity, :canonical_name, :available_in,
      :inferred_visibility, :source, :provenance,
      # Additional analysis fields (optional, populated by extractors)
      :branches, :loops, :conditionals, :body_lines, :test_coverage,
      keyword_init: true
    )

    NormalizedMethodCall = Struct.new(
      :from, :to, :type,
      keyword_init: true
    )

    NormalizedLocation = Struct.new(
      :file, :line,
      keyword_init: true
    )
  end
end
