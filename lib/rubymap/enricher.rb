# frozen_string_literal: true

require_relative "enricher/enricher_registry"
require_relative "enricher/enrichment_result"

module Rubymap
  # Enriches normalized Ruby symbols with metrics, patterns, and quality insights
  # Takes normalized data and adds calculated metrics, detected patterns, and quality analysis
  class Enricher
    def initialize(config = {})
      @config = default_config.merge(config)
      @registry = EnricherRegistry.new
      setup_components
    end

    # Main enrichment method - transforms normalized data into enriched data
    def enrich(normalized_data)
      # Convert to proper input format if needed
      input = ensure_normalized_result(normalized_data)

      # Create enriched result from normalized data
      result = EnrichmentResult.from_normalized(input)

      # Apply metrics calculation
      apply_metrics(result)

      # Apply pattern detection
      apply_analyzers(result)

      # Apply Rails-specific enrichment if applicable
      apply_rails_enrichment(result) if rails_project?(result)

      # Calculate composite scores
      calculate_composite_scores(result)

      # Identify issues and hotspots
      identify_issues(result)

      result
    end

    private

    def default_config
      {
        enable_metrics: true,
        enable_patterns: true,
        enable_rails: true,
        complexity_threshold: 10,
        api_size_threshold: 5,
        inheritance_depth_threshold: 4,
        fan_out_threshold: 3,
        churn_threshold: 10,
        coverage_threshold: 80
      }
    end

    def setup_components
      setup_metrics
      setup_analyzers
      setup_rails_enrichers
    end

    def setup_metrics
      @metrics = [
        @registry.get_metric(:complexity),
        @registry.get_metric(:dependency),
        @registry.get_metric(:inheritance),
        @registry.get_metric(:api_surface),
        @registry.get_metric(:coverage),
        @registry.get_metric(:churn),
        @registry.get_metric(:stability)
      ].compact
    end

    def setup_analyzers
      @analyzers = [
        @registry.get_analyzer(:pattern_detector),
        @registry.get_analyzer(:idiom_detector),
        @registry.get_analyzer(:hotspot_analyzer),
        @registry.get_analyzer(:quality_analyzer)
      ].compact
    end

    def setup_rails_enrichers
      @rails_enrichers = [
        @registry.get_rails_enricher(:model),
        @registry.get_rails_enricher(:controller),
        @registry.get_rails_enricher(:route)
      ].compact
    end

    def ensure_normalized_result(data)
      case data
      when Normalizer::NormalizedResult
        data
      when Hash
        convert_hash_to_normalized_result(data)
      else
        raise ArgumentError, "Expected NormalizedResult or Hash, got #{data.class}"
      end
    end

    def convert_hash_to_normalized_result(hash)
      result = Normalizer::NormalizedResult.new

      # Convert hash classes to NormalizedClass structs
      result.classes = (hash[:classes] || []).map do |klass_hash|
        if klass_hash.is_a?(Normalizer::NormalizedClass)
          klass_hash
        else
          Normalizer::NormalizedClass.new(
            symbol_id: klass_hash[:symbol_id] || "class_#{klass_hash[:name]}",
            name: klass_hash[:name],
            fqname: klass_hash[:fqname] || klass_hash[:name],
            kind: klass_hash[:kind] || "class",
            superclass: klass_hash[:superclass],
            location: klass_hash[:location],
            namespace_path: klass_hash[:namespace_path] || [],
            children: klass_hash[:children] || [],
            inheritance_chain: klass_hash[:inheritance_chain] || [],
            instance_methods: klass_hash[:instance_methods] || [],
            class_methods: klass_hash[:class_methods] || [],
            available_instance_methods: klass_hash[:available_instance_methods] || [],
            available_class_methods: klass_hash[:available_class_methods] || [],
            mixins: klass_hash[:mixins] || [],
            provenance: klass_hash[:provenance] || "test",
            # Additional test data fields
            dependencies: klass_hash[:dependencies],
            visibility: klass_hash[:visibility],
            git_commits: klass_hash[:git_commits],
            last_modified: klass_hash[:last_modified],
            age_in_days: klass_hash[:age_in_days],
            test_coverage: klass_hash[:test_coverage],
            documentation_coverage: klass_hash[:documentation_coverage],
            churn_score: klass_hash[:churn_score],
            file: klass_hash[:file],
            implements: klass_hash[:implements],
            # Rails-specific fields
            associations: klass_hash[:associations],
            validations: klass_hash[:validations],
            scopes: klass_hash[:scopes],
            actions: klass_hash[:actions],
            filters: klass_hash[:filters],
            rescue_handlers: klass_hash[:rescue_handlers],
            # Test data fields
            method_names: klass_hash[:methods]
          )
        end
      end

      # Convert hash modules to NormalizedModule structs
      result.modules = (hash[:modules] || []).map do |mod_hash|
        if mod_hash.is_a?(Normalizer::NormalizedModule)
          mod_hash
        else
          Normalizer::NormalizedModule.new(
            symbol_id: mod_hash[:symbol_id] || "module_#{mod_hash[:name]}",
            name: mod_hash[:name],
            fqname: mod_hash[:fqname] || mod_hash[:name],
            kind: mod_hash[:kind] || "module",
            location: mod_hash[:location],
            namespace_path: mod_hash[:namespace_path] || [],
            children: mod_hash[:children] || [],
            provenance: mod_hash[:provenance] || "test",
            # Additional test data fields
            instance_methods: mod_hash[:instance_methods],
            visibility: mod_hash[:visibility]
          )
        end
      end

      # Convert hash methods to NormalizedMethod structs
      result.methods = (hash[:methods] || []).map do |method_hash|
        if method_hash.is_a?(Normalizer::NormalizedMethod)
          method_hash
        else
          Normalizer::NormalizedMethod.new(
            symbol_id: method_hash[:symbol_id] || "method_#{method_hash[:name]}",
            name: method_hash[:name],
            fqname: method_hash[:fqname] || method_hash[:name],
            visibility: method_hash[:visibility] || "public",
            owner: method_hash[:owner],
            scope: method_hash[:scope] || "instance",
            parameters: method_hash[:parameters] || [],
            arity: method_hash[:arity] || -1,
            canonical_name: method_hash[:canonical_name] || method_hash[:name],
            available_in: method_hash[:available_in] || [],
            inferred_visibility: method_hash[:inferred_visibility],
            source: method_hash[:source],
            provenance: method_hash[:provenance] || "test",
            # Additional analysis fields
            branches: method_hash[:branches],
            loops: method_hash[:loops],
            conditionals: method_hash[:conditionals],
            body_lines: method_hash[:body_lines],
            test_coverage: method_hash[:test_coverage]
          )
        end
      end

      result.method_calls = hash[:method_calls] || []
      result
    end

    def apply_metrics(result)
      return unless @config[:enable_metrics]

      @metrics.each do |metric|
        metric.calculate(result, @config)
      end
    end

    def apply_analyzers(result)
      return unless @config[:enable_patterns]

      @analyzers.each do |analyzer|
        analyzer.analyze(result, @config)
      end
    end

    def apply_rails_enrichment(result)
      return unless @config[:enable_rails]

      @rails_enrichers.each do |enricher|
        enricher.enrich(result, @config)
      end
    end

    def calculate_composite_scores(result)
      result.classes.each do |klass|
        klass.stability_score = calculate_stability_score(klass)
        klass.complexity_score = calculate_complexity_score(klass)
        klass.maintainability_score = calculate_maintainability_score(klass)
      end
    end

    def calculate_stability_score(klass)
      age_factor = normalize_age(klass.age_in_days || 0)
      coverage_factor = (klass.test_coverage || 0) / 100.0
      churn_factor = 1.0 - normalize_churn(klass.churn_score || 0)
      doc_factor = (klass.documentation_coverage || 0) / 100.0

      (age_factor * 0.2 + coverage_factor * 0.3 + churn_factor * 0.3 + doc_factor * 0.2).round(2)
    end

    def calculate_complexity_score(klass)
      return 0.0 unless klass.respond_to?(:metrics)

      methods = klass.methods || []
      return 0.0 if methods.empty?

      avg_complexity = methods.sum { |m| m.cyclomatic_complexity || 1 } / methods.size.to_f
      (avg_complexity / 10.0).clamp(0.0, 1.0).round(2)
    end

    def calculate_maintainability_score(klass)
      stability = klass.stability_score || 0
      complexity = 1.0 - (klass.complexity_score || 0)
      coupling = 1.0 - normalize_coupling(klass.coupling_strength || 0)

      ((stability + complexity + coupling) / 3.0).round(2)
    end

    def identify_issues(result)
      identify_quality_issues(result)
      identify_design_issues(result)
      identify_hotspots(result)
    end

    def identify_quality_issues(result)
      result.quality_issues ||= []

      # Low test coverage
      result.methods.each do |method|
        if method.test_coverage && method.test_coverage < @config[:coverage_threshold]
          result.quality_issues << QualityIssue.new(
            type: "low_test_coverage",
            severity: coverage_severity(method.test_coverage),
            location: "#{method.owner}##{method.name}",
            method: method.name,
            suggestion: "Add test coverage for this method"
          )
        end
      end
    end

    def identify_design_issues(result)
      result.design_issues ||= []

      # Deep inheritance
      result.classes.each do |klass|
        if klass.inheritance_depth && klass.inheritance_depth > @config[:inheritance_depth_threshold]
          result.design_issues << DesignIssue.new(
            type: "deep_inheritance",
            severity: "warning",
            class: klass.name,
            depth: klass.inheritance_depth,
            suggestion: "Consider composition over inheritance"
          )
        end

        # Large public API
        if klass.public_api_surface && klass.public_api_surface >= @config[:api_size_threshold]
          result.design_issues << DesignIssue.new(
            type: "large_public_api",
            severity: "warning",
            class: klass.name,
            api_size: klass.public_api_surface,
            suggestion: "Consider splitting responsibilities"
          )
        end
      end
    end

    def identify_hotspots(result)
      result.hotspots ||= []
      result.coupling_hotspots ||= []

      # High churn hotspots
      result.classes.each do |klass|
        if klass.churn_score && klass.churn_score > @config[:churn_threshold]
          result.hotspots << Hotspot.new(
            type: "high_churn",
            class: klass.name,
            score: klass.churn_score,
            commits: klass.git_commits
          )
        end

        # High coupling hotspots
        if klass.fan_out && klass.fan_out > 5
          result.coupling_hotspots << CouplingHotspot.new(
            class: klass.name,
            reason: "high_fan_out",
            fan_out: klass.fan_out
          )
        end
      end
    end

    def rails_project?(result)
      result.classes.any? { |c| c.superclass&.include?("ApplicationRecord") || c.superclass&.include?("ApplicationController") }
    end

    def coverage_severity(coverage)
      case coverage
      when 0...30 then "high"
      when 30...60 then "medium"
      else "low"
      end
    end

    def normalize_age(days)
      (days / 365.0).clamp(0.0, 1.0)
    end

    def normalize_churn(score)
      (score / 100.0).clamp(0.0, 1.0)
    end

    def normalize_coupling(strength)
      (strength / 10.0).clamp(0.0, 1.0)
    end
  end
end
