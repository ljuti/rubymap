# frozen_string_literal: true

module Rubymap
  class Enricher
    # Enhanced result that extends normalized data with metrics and analysis
    class EnrichmentResult
      attr_accessor :classes, :modules, :methods, :method_calls,
                    :metrics, :design_patterns, :quality_issues, :design_issues,
                    :hotspots, :problem_areas, :coupling_hotspots, :stability_analysis, 
                    :ruby_idioms, :rails_insights, :rails_models, :rails_controllers,
                    :quality_metrics,
                    :schema_version, :normalizer_version, :enricher_version,
                    :normalized_at, :enriched_at
      
      def initialize
        @classes = []
        @modules = []
        @methods = []
        @method_calls = []
        @metrics = {}
        @design_patterns = []
        @quality_issues = []
        @design_issues = []
        @hotspots = []
        @problem_areas = []
        @coupling_hotspots = []
        @ruby_idioms = []
        @stability_analysis = StabilityAnalysis.new
        @rails_insights = {}
        @rails_models = []
        @rails_controllers = []
        @quality_metrics = QualityMetrics.new
        @enriched_at = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        @enricher_version = "1.0.0"
      end
      
      # Create enriched result from normalized result
      def self.from_normalized(normalized_result)
        enriched = new
        
        # Copy normalized data
        enriched.classes = wrap_classes(normalized_result.classes || [])
        enriched.modules = wrap_modules(normalized_result.modules || [])
        enriched.methods = wrap_methods(normalized_result.methods || [])
        enriched.method_calls = normalized_result.method_calls || []
        
        # Copy metadata
        enriched.schema_version = normalized_result.schema_version
        enriched.normalizer_version = normalized_result.normalizer_version
        enriched.normalized_at = normalized_result.normalized_at
        
        enriched
      end
      
      private
      
      def self.wrap_classes(classes)
        classes.map { |klass| EnrichedClass.from_normalized(klass) }
      end
      
      def self.wrap_modules(modules)
        modules.map { |mod| EnrichedModule.from_normalized(mod) }
      end
      
      def self.wrap_methods(methods)
        methods.map { |method| EnrichedMethod.from_normalized(method) }
      end
    end
    
    # Enhanced class with metrics and analysis
    class EnrichedClass < Struct.new(
      # Original normalized fields
      :symbol_id, :name, :fqname, :kind, :superclass, :location,
      :namespace_path, :children, :inheritance_chain,
      :instance_methods, :class_methods,
      :available_instance_methods, :available_class_methods,
      :mixins, :provenance,
      # Basic enriched fields
      :cyclomatic_complexity, :complexity_category, :total_complexity,
      :fan_in, :fan_out, :coupling_strength,
      :inheritance_depth, :public_api_surface,
      :test_coverage, :coverage_category,
      :git_commits, :churn_score, :last_modified,
      :age_in_days, :documentation_coverage,
      :stability_score, :complexity_score, :maintainability_score,
      :quality_score, :cohesion_score,
      # Rails-specific fields
      :model_complexity_score, :activerecord_metrics, :controller_metrics,
      :associations, :validations, :scopes,
      :actions, :filters, :rescue_handlers,
      :is_rails_model, :rails_model_info,
      :is_rails_controller, :rails_controller_info,
      # Other enrichment fields
      :dependencies, :methods, :metrics, :parent_class, :ancestors, :instance_variables,
      keyword_init: true
    )
      def self.from_normalized(normalized_class)
        new(
          symbol_id: normalized_class.symbol_id,
          name: normalized_class.name,
          fqname: normalized_class.fqname,
          kind: normalized_class.kind,
          superclass: normalized_class.superclass,
          location: normalized_class.location,
          namespace_path: normalized_class.namespace_path,
          children: normalized_class.children,
          inheritance_chain: normalized_class.inheritance_chain,
          instance_methods: normalized_class.instance_methods,
          class_methods: normalized_class.class_methods,
          available_instance_methods: normalized_class.available_instance_methods,
          available_class_methods: normalized_class.available_class_methods,
          mixins: normalized_class.mixins,
          provenance: normalized_class.provenance,
          methods: []
        )
      end
    end
    
    # Enhanced module with metrics
    class EnrichedModule < Struct.new(
      # Original normalized fields
      :symbol_id, :name, :fqname, :kind, :location,
      :namespace_path, :children, :provenance,
      # Enriched fields
      :public_api_surface, :instance_methods, :visibility,
      keyword_init: true
    )
      def self.from_normalized(normalized_module)
        new(
          symbol_id: normalized_module.symbol_id,
          name: normalized_module.name,
          fqname: normalized_module.fqname,
          kind: normalized_module.kind,
          location: normalized_module.location,
          namespace_path: normalized_module.namespace_path,
          children: normalized_module.children,
          provenance: normalized_module.provenance
        )
      end
    end
    
    # Enhanced method with metrics
    class EnrichedMethod < Struct.new(
      # Original normalized fields
      :symbol_id, :name, :fqname, :visibility, :owner, :scope,
      :parameters, :arity, :canonical_name, :available_in,
      :inferred_visibility, :source, :provenance,
      # Enriched fields
      :cyclomatic_complexity, :complexity_category, :complexity,
      :lines_of_code, :body_lines, :branches, :loops, :conditionals, :line_count,
      :test_coverage, :coverage_category,
      :implements_protocol, :yields,
      :dependencies, :calls_made, :owner_type,
      :quality_score, :has_quality_issues,
      :uses_instance_variables, :has_commented_code,
      keyword_init: true
    )
      def self.from_normalized(normalized_method)
        new(
          symbol_id: normalized_method.symbol_id,
          name: normalized_method.name,
          fqname: normalized_method.fqname,
          visibility: normalized_method.visibility,
          owner: normalized_method.owner,
          scope: normalized_method.scope,
          parameters: normalized_method.parameters,
          arity: normalized_method.arity,
          canonical_name: normalized_method.canonical_name,
          available_in: normalized_method.available_in,
          inferred_visibility: normalized_method.inferred_visibility,
          source: normalized_method.source,
          provenance: normalized_method.provenance,
          # Copy any existing analysis data
          branches: normalized_method.respond_to?(:branches) ? normalized_method.branches : nil,
          loops: normalized_method.respond_to?(:loops) ? normalized_method.loops : nil,
          conditionals: normalized_method.respond_to?(:conditionals) ? normalized_method.conditionals : nil,
          body_lines: normalized_method.respond_to?(:body_lines) ? normalized_method.body_lines : nil
        )
      end
    end
    
    # Value objects for enrichment results
    QualityIssue = Struct.new(:type, :name, :issues, :quality_score, keyword_init: true)
    DesignIssue = Struct.new(:type, :severity, :class, :depth, :api_size, :suggestion, keyword_init: true)
    Hotspot = Struct.new(:type, :name, :indicators, :risk_score, :recommendations, keyword_init: true)
    CouplingHotspot = Struct.new(:class, :reason, :fan_out, keyword_init: true)
    PatternMatch = Struct.new(:pattern, :class, :confidence, :evidence, keyword_init: true)
    RubyIdiom = Struct.new(:idiom, :class, :method, keyword_init: true)
    
    # Quality metrics container
    class QualityMetrics
      attr_accessor :overall_score, :quality_level, :issues_by_severity
      
      def initialize
        @overall_score = 0.0
        @quality_level = "unknown"
        @issues_by_severity = { critical: 0, high: 0, medium: 0, low: 0 }
      end
    end
    
    # Rails-specific data structures
    RailsModelInfo = Struct.new(
      :name, :table_name, :associations, :validations, :callbacks,
      :scopes, :attributes, :database_indexes, :concerns, :model_type,
      :association_count, :validation_count, :callback_count, :scope_count,
      :complexity_score, :issues,
      keyword_init: true
    )
    
    RailsControllerInfo = Struct.new(
      :name, :resource_name, :actions, :filters, :strong_parameters,
      :rescue_handlers, :concerns, :api_controller, :authentication, :routes,
      :action_count, :filter_count, :rest_compliance, :complexity_score, :issues,
      keyword_init: true
    )
    
    # Stability analysis container
    class StabilityAnalysis
      attr_accessor :stable_classes, :unstable_classes, :stability_scores
      
      def initialize
        @stable_classes = []
        @unstable_classes = []
        @stability_scores = {}
      end
    end
  end
end