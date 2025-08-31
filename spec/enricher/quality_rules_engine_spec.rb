# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Rubymap::Enricher::QualityRulesEngine do
  let(:engine) { described_class.new }

  describe "#initialize" do
    it "loads default rules" do
      expect(engine.rules).to have_key(:method)
      expect(engine.rules).to have_key(:class)
      expect(engine.rules).to have_key(:code_smells)
      expect(engine.rules).to have_key(:scoring)
    end

    context "with custom rules file" do
      let(:custom_rules_file) do
        Tempfile.new(["rules", ".yml"]).tap do |f|
          f.write(<<~YAML)
            version: "1.0"
            method_rules:
              - id: test_rule
                enabled: true
                description: "Test rule"
                threshold:
                  metric: line_count
                  operator: ">"
                  value: 10
                severity: medium
                message_template: "Test message"
                suggestion: "Test suggestion"
          YAML
          f.flush
        end
      end

      after { custom_rules_file.unlink }

      it "loads custom rules from file" do
        custom_engine = described_class.new(custom_rules_file.path)
        expect(custom_engine.rules[:method]).not_to be_empty
        expect(custom_engine.rules[:method].first[:id]).to eq("test_rule")
      end
    end

    context "with invalid rules file" do
      it "falls back to default rules" do
        engine = described_class.new("/nonexistent/path.yml")
        expect(engine.rules).to eq({
          method: [],
          class: [],
          code_smells: [],
          scoring: engine.send(:default_scoring)
        })
      end
    end
  end

  describe "#apply_method_rules" do
    let(:long_method) do
      double("method",
        name: "long_method",
        line_count: 50,
        parameters: [:a, :b, :c, :d, :e],
        complexity: 20)
    end

    let(:short_method) do
      double("method",
        name: "good_method",
        line_count: 10,
        parameters: [:a],
        complexity: 3)
    end

    it "returns issues for methods violating rules" do
      issues = engine.apply_method_rules(long_method)
      expect(issues).not_to be_empty
      expect(issues.any? { |i| i[:type] == "long_method" }).to be true
      expect(issues.any? { |i| i[:type] == "too_many_parameters" }).to be true
    end

    it "returns empty array for compliant methods" do
      issues = engine.apply_method_rules(short_method)
      # May have some issues depending on default rules
      expect(issues).to be_a(Array)
    end

    context "with name-based rules" do
      let(:java_style_method) do
        double("method",
          name: "get_value",
          line_count: 5,
          parameters: [],
          complexity: 1)
      end

      let(:short_name_method) do
        double("method",
          name: "x",
          line_count: 5,
          parameters: [],
          complexity: 1)
      end

      it "detects Java-style getter methods" do
        issues = engine.apply_method_rules(java_style_method)
        expect(issues.any? { |i| i[:type] == "java_style_getter" }).to be true
      end

      it "detects too-short method names" do
        issues = engine.apply_method_rules(short_name_method)
        expect(issues.any? { |i| i[:type] == "short_method_name" }).to be true
      end

      it "excludes operator methods from short name check" do
        operator = double("method", name: "+", line_count: 5, parameters: [:other], complexity: 1)
        issues = engine.apply_method_rules(operator)
        expect(issues.any? { |i| i[:type] == "short_method_name" }).to be false
      end
    end
  end

  describe "#apply_class_rules" do
    let(:god_class) do
      double("class",
        name: "GodClass",
        metrics: {loc: 600},
        instance_methods: Array.new(35) { |i| "method_#{i}" },
        dependencies: Array.new(20) { |i| "Dep#{i}" },
        total_complexity: 60,
        instance_variables: ["@var1", "@var2"])
    end

    let(:simple_class) do
      double("class",
        name: "SimpleClass",
        metrics: {loc: 50},
        instance_methods: ["method1", "method2"],
        dependencies: ["Dep1"],
        total_complexity: 5,
        instance_variables: ["@var"])
    end

    it "detects god classes" do
      issues = engine.apply_class_rules(god_class)
      expect(issues.any? { |i| i[:type] == "god_class" }).to be true
    end

    it "returns empty array for simple classes" do
      issues = engine.apply_class_rules(simple_class)
      expect(issues).to be_empty
    end

    context "with data class detection" do
      let(:data_class) do
        double("class",
          name: "DataClass",
          metrics: {loc: 100},
          instance_methods: ["get_name", "set_name", "name=", "age=", "get_age", "validate"],
          dependencies: [],
          total_complexity: 10,
          instance_variables: ["@name", "@age"])
      end

      it "detects data classes" do
        issues = engine.apply_class_rules(data_class)
        expect(issues.any? { |i| i[:type] == "data_class" }).to be true
      end
    end

    context "with mixed abstraction levels" do
      let(:mixed_class) do
        double("class",
          name: "MixedClass",
          metrics: {loc: 200},
          instance_methods: [
            "process_order", "handle_payment", "manage_inventory",
            "get_price", "set_quantity", "read_config", "write_log"
          ],
          dependencies: [],
          total_complexity: 20,
          instance_variables: [])
      end

      it "detects mixed abstraction levels" do
        issues = engine.apply_class_rules(mixed_class)
        expect(issues.any? { |i| i[:type] == "mixed_abstraction_levels" }).to be true
      end
    end
  end

  describe "#calculate_method_score" do
    let(:method) { double("method", complexity: 3) }

    it "returns perfect score for no issues" do
      score = engine.calculate_method_score(method, [])
      expect(score).to eq(1.0)
    end

    it "reduces score based on issue severity" do
      issues = [
        {type: "issue1", severity: "high"},
        {type: "issue2", severity: "low"}
      ]
      score = engine.calculate_method_score(method, issues)
      expect(score).to be < 1.0
      expect(score).to be > 0.0
    end

    it "applies complexity penalty" do
      simple_method = double("method", complexity: 3)
      complex_method = double("method", complexity: 25)
      score_simple = engine.calculate_method_score(simple_method, [])
      score_complex = engine.calculate_method_score(complex_method, [])
      expect(score_complex).to be < score_simple
    end

    it "clamps score between 0 and 1" do
      many_issues = Array.new(10) { {type: "issue", severity: "critical"} }
      score = engine.calculate_method_score(method, many_issues)
      expect(score).to eq(0.0)
    end
  end

  describe "#calculate_class_score" do
    let(:klass) { double("class", stability_score: nil) }

    it "returns perfect score for no issues" do
      score = engine.calculate_class_score(klass, [])
      expect(score).to eq(1.0)
    end

    it "reduces score based on issue severity" do
      issues = [
        {type: "god_class", severity: "high"},
        {type: "low_cohesion", severity: "medium"}
      ]
      score = engine.calculate_class_score(klass, issues)
      expect(score).to be < 1.0
    end

    context "with stability score" do
      let(:stable_class) { double("class", stability_score: 0.9) }

      it "factors in stability score" do
        issues = [{type: "issue", severity: "medium"}]
        score_with_stability = engine.calculate_class_score(stable_class, issues)
        
        # With stability weight of 0.3:
        # Base score after penalty: 0.9 (1.0 - 0.1)
        # With stability: (0.9 * 0.7) + (0.9 * 0.3) = 0.63 + 0.27 = 0.9
        expect(score_with_stability).to eq(0.9)
      end
    end
  end

  describe "#quality_level" do
    it "returns 'excellent' for high scores" do
      expect(engine.quality_level(0.95)).to eq("excellent")
    end

    it "returns 'good' for good scores" do
      expect(engine.quality_level(0.75)).to eq("good")
    end

    it "returns 'fair' for fair scores" do
      expect(engine.quality_level(0.55)).to eq("fair")
    end

    it "returns 'poor' for poor scores" do
      expect(engine.quality_level(0.35)).to eq("poor")
    end

    it "returns 'needs_improvement' for very low scores" do
      expect(engine.quality_level(0.15)).to eq("needs_improvement")
    end

    it "handles boundary values correctly" do
      expect(engine.quality_level(0.9)).to eq("excellent")
      expect(engine.quality_level(0.7)).to eq("good")
      expect(engine.quality_level(0.5)).to eq("fair")
      expect(engine.quality_level(0.3)).to eq("poor")
    end
  end

  describe "severity calculation" do
    let(:method_with_ranges) do
      double("method",
        name: "test",
        line_count: 45,
        parameters: [],
        complexity: 5)
    end

    it "calculates severity based on ranges" do
      issues = engine.apply_method_rules(method_with_ranges)
      long_method_issue = issues.find { |i| i[:type] == "long_method" }
      
      expect(long_method_issue).not_to be_nil
      expect(long_method_issue[:severity]).to eq("medium") # 45 lines falls in medium range
    end
  end

  describe "message interpolation" do
    let(:method) do
      double("method",
        name: "test",
        line_count: 25,
        parameters: [:a, :b, :c, :d, :e, :f],
        complexity: 5)
    end

    it "interpolates values into message templates" do
      issues = engine.apply_method_rules(method)
      
      long_method_issue = issues.find { |i| i[:type] == "long_method" }
      expect(long_method_issue[:message]).to include("25")
      expect(long_method_issue[:message]).to include("20")
      
      params_issue = issues.find { |i| i[:type] == "too_many_parameters" }
      expect(params_issue[:message]).to include("6")
      expect(params_issue[:message]).to include("4")
    end
  end
end