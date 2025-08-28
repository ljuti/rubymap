# frozen_string_literal: true

require 'digest'
require 'set'

# Load all components
require_relative 'normalizer/symbol_index'
require_relative 'normalizer/normalizer_registry'

require_relative 'normalizer/processors/base_processor'
require_relative 'normalizer/processors/class_processor'
require_relative 'normalizer/processors/module_processor'
require_relative 'normalizer/processors/method_processor'
require_relative 'normalizer/processors/method_call_processor'
require_relative 'normalizer/processors/mixin_processor'

require_relative 'normalizer/resolvers/namespace_resolver'
require_relative 'normalizer/resolvers/inheritance_resolver'
require_relative 'normalizer/resolvers/cross_reference_resolver'
require_relative 'normalizer/resolvers/mixin_method_resolver'

require_relative 'normalizer/deduplication/deduplicator'
require_relative 'normalizer/deduplication/merge_strategy'

require_relative 'normalizer/output/deterministic_formatter'

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

    def initialize
      @symbol_id_generator = SymbolIdGenerator.new
      @provenance_tracker = ProvenanceTracker.new
      @normalizers = NormalizerRegistry.new
      @symbol_index = SymbolIndex.new
      
      # Initialize processors with dependency injection
      @class_processor = Processors::ClassProcessor.new(
        symbol_id_generator: @symbol_id_generator,
        provenance_tracker: @provenance_tracker,
        normalizers: @normalizers
      )
      
      @module_processor = Processors::ModuleProcessor.new(
        symbol_id_generator: @symbol_id_generator,
        provenance_tracker: @provenance_tracker,
        normalizers: @normalizers
      )
      
      @method_processor = Processors::MethodProcessor.new(
        symbol_id_generator: @symbol_id_generator,
        provenance_tracker: @provenance_tracker,
        normalizers: @normalizers
      )
      
      @method_call_processor = Processors::MethodCallProcessor.new(
        symbol_id_generator: @symbol_id_generator,
        provenance_tracker: @provenance_tracker,
        normalizers: @normalizers
      )
      
      @mixin_processor = Processors::MixinProcessor.new(
        symbol_id_generator: @symbol_id_generator,
        provenance_tracker: @provenance_tracker,
        normalizers: @normalizers
      )
      
      # Initialize resolvers
      @namespace_resolver = Resolvers::NamespaceResolver.new
      @inheritance_resolver = Resolvers::InheritanceResolver.new
      @cross_reference_resolver = Resolvers::CrossReferenceResolver.new(@symbol_index)
      @mixin_method_resolver = Resolvers::MixinMethodResolver.new
      
      # Initialize deduplication strategy
      merge_strategy = Deduplication::MergeStrategy.new(
        @provenance_tracker, 
        @normalizers.visibility_normalizer
      )
      @deduplicator = Deduplication::Deduplicator.new(merge_strategy)
      
      # Initialize output formatter
      @output_formatter = Output::DeterministicFormatter.new
    end

    # Main normalization method - now serves as orchestrator following Open/Closed Principle
    def normalize(raw_data)
      @errors = []
      @symbol_index.clear
      
      result = create_result
      
      # Process each type of symbol using dedicated processors
      process_symbols(raw_data, result)
      
      # Build relationships and resolve references using dedicated resolvers
      resolve_relationships(result)
      
      # Deduplicate symbols using dedicated strategy
      @deduplicator.deduplicate_symbols(result)
      
      # Ensure deterministic output ordering using dedicated formatter
      @output_formatter.format(result)
      
      # Add errors and return
      result.errors = @errors
      result
    end
    
    private
    
    attr_reader :class_processor, :module_processor, :method_processor,
                :method_call_processor, :mixin_processor,
                :namespace_resolver, :inheritance_resolver,
                :cross_reference_resolver, :mixin_method_resolver

    def create_result
      NormalizedResult.new(
        schema_version: SCHEMA_VERSION,
        normalizer_version: NORMALIZER_VERSION,
        normalized_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
      )
    end

    def process_symbols(raw_data, result)
      # Handle nil or non-hash input
      return if raw_data.nil? || !raw_data.is_a?(Hash)
      
      # Process in deterministic order using Strategy pattern
      class_processor.process(raw_data[:classes] || [], result, @errors)
      module_processor.process(raw_data[:modules] || [], result, @errors)
      method_processor.process(raw_data[:methods] || [], result, @errors)
      method_call_processor.process(raw_data[:method_calls] || [], result, @errors)
      
      # Index processed symbols for fast lookups
      index_symbols(result)
      
      # Process mixins (raw data only since class mixins are handled directly)
      mixin_processor.process(raw_data[:mixins] || [], result, @errors, [])
    end

    def resolve_relationships(result)
      # Use dedicated resolvers following Single Responsibility Principle
      namespace_resolver.resolve(result)
      inheritance_resolver.resolve(result)
      cross_reference_resolver.resolve(result)
      mixin_method_resolver.resolve(result)
    end

    def index_symbols(result)
      (result.classes + result.modules).each do |symbol|
        @symbol_index.add(symbol)
      end
    end
    
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
      keyword_init: true
    )
    
    NormalizedModule = Struct.new(
      :symbol_id, :name, :fqname, :kind, :location, 
      :namespace_path, :children, :provenance,
      keyword_init: true
    )
    
    NormalizedMethod = Struct.new(
      :symbol_id, :name, :fqname, :visibility, :owner, :scope,
      :parameters, :arity, :canonical_name, :available_in,
      :inferred_visibility, :source, :provenance,
      # Additional analysis fields (optional, populated by extractors)
      :branches, :loops, :conditionals, :body_lines,
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