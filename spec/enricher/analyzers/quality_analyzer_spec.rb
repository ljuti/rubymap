# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Rubymap::Enricher::Analyzers::QualityAnalyzer do
  let(:analyzer) { described_class.new }
  let(:result) { double("result", quality_issues: [], quality_metrics: nil) }
  let(:config) { {} }
  let(:quality_metrics) { Rubymap::Enricher::Analyzers::QualityMetrics.new }

  before do
    allow(result).to receive(:quality_issues=)
    allow(result).to receive(:quality_metrics=) do |value|
      allow(result).to receive(:quality_metrics).and_return(value)
    end
  end

  describe "#initialize" do
    it "creates a rules engine with default path" do
      expect(analyzer.rules_engine).to be_a(Rubymap::Enricher::QualityRulesEngine)
    end

    it "accepts a custom rules path" do
      custom_path = "/custom/path/rules.yml"
      custom_analyzer = described_class.new(custom_path)
      expect(custom_analyzer.rules_engine).to be_a(Rubymap::Enricher::QualityRulesEngine)
    end
  end

  describe "#analyze" do
    context "with no methods or classes" do
      before do
        allow(result).to receive(:methods).and_return(nil)
        allow(result).to receive(:classes).and_return(nil)
      end

      it "initializes quality metrics" do
        analyzer.analyze(result, config)
        expect(result.quality_metrics).to be_a(Rubymap::Enricher::Analyzers::QualityMetrics)
      end

      it "initializes empty quality issues" do
        analyzer.analyze(result, config)
        expect(result.quality_issues).to eq([])
      end
    end

    context "with methods" do
      let(:method1) do
        double("method",
          name: "long_method",
          owner: "TestClass",
          line_count: 50,
          parameters: [:a, :b],
          complexity: 15,
          quality_score: nil,
          has_quality_issues: nil)
      end

      let(:method2) do
        double("method",
          name: "short_method",
          owner: "TestClass",
          line_count: 5,
          parameters: [:a],
          complexity: 2,
          quality_score: nil,
          has_quality_issues: nil)
      end

      before do
        allow(result).to receive(:methods).and_return([method1, method2])
        allow(result).to receive(:classes).and_return(nil)
        allow(method1).to receive(:quality_score=)
        allow(method1).to receive(:has_quality_issues=)
        allow(method2).to receive(:quality_score=)
        allow(method2).to receive(:has_quality_issues=)
      end

      it "analyzes each method" do
        analyzer.analyze(result, config)
        expect(method1).to have_received(:quality_score=)
        expect(method1).to have_received(:has_quality_issues=)
        expect(method2).to have_received(:quality_score=)
        expect(method2).to have_received(:has_quality_issues=)
      end

      it "creates quality issues for problematic methods" do
        analyzer.analyze(result, config)
        expect(result.quality_issues).not_to be_empty
        
        issue = result.quality_issues.find { |i| i.name == "TestClass#long_method" }
        expect(issue).not_to be_nil
        expect(issue.type).to eq("method")
      end

      it "calculates quality scores" do
        analyzer.analyze(result, config)
        expect(result.quality_metrics.overall_score).to be_a(Float)
        expect(result.quality_metrics.overall_score).to be_between(0, 1)
      end
    end

    context "with classes" do
      let(:class1) do
        double("class",
          name: "GodClass",
          metrics: {loc: 600},
          instance_methods: Array.new(35) { |i| "method_#{i}" },
          dependencies: Array.new(20) { |i| "Dep#{i}" },
          total_complexity: 60,
          instance_variables: ["@var1", "@var2"],
          quality_score: nil,
          stability_score: nil)
      end

      let(:class2) do
        double("class",
          name: "SimpleClass",
          metrics: {loc: 50},
          instance_methods: ["method1", "method2"],
          dependencies: ["Dep1"],
          total_complexity: 5,
          instance_variables: ["@var1"],
          quality_score: nil,
          stability_score: nil)
      end

      before do
        allow(result).to receive(:methods).and_return(nil)
        allow(result).to receive(:classes).and_return([class1, class2])
        allow(class1).to receive(:quality_score=)
        allow(class2).to receive(:quality_score=)
      end

      it "analyzes each class" do
        analyzer.analyze(result, config)
        expect(class1).to have_received(:quality_score=)
        expect(class2).to have_received(:quality_score=)
      end

      it "creates quality issues for problematic classes" do
        analyzer.analyze(result, config)
        
        issue = result.quality_issues.find { |i| i.name == "GodClass" }
        expect(issue).not_to be_nil
        expect(issue.type).to eq("class")
        expect(issue.issues).not_to be_empty
      end

      it "does not create issues for simple classes" do
        analyzer.analyze(result, config)
        
        issue = result.quality_issues.find { |i| i.name == "SimpleClass" }
        expect(issue).to be_nil
      end
    end

    context "with both methods and classes" do
      let(:method) do
        double("method",
          name: "test_method",
          owner: "TestClass",
          line_count: 10,
          parameters: [:a],
          complexity: 3,
          quality_score: 0.8,
          has_quality_issues: nil)
      end

      let(:klass) do
        double("class",
          name: "TestClass",
          metrics: {loc: 100},
          instance_methods: ["method1"],
          dependencies: [],
          total_complexity: 10,
          instance_variables: ["@var"],
          quality_score: 0.9,
          stability_score: nil)
      end

      before do
        allow(result).to receive(:methods).and_return([method])
        allow(result).to receive(:classes).and_return([klass])
        allow(method).to receive(:quality_score=)
        allow(method).to receive(:has_quality_issues=)
        allow(klass).to receive(:quality_score=)
      end

      it "calculates overall quality from both" do
        analyzer.analyze(result, config)
        
        expect(result.quality_metrics.overall_score).to eq(0.85) # (0.8 + 0.9) / 2
        expect(result.quality_metrics.quality_level).to eq("good")
      end
    end

    context "with various severity issues" do
      let(:methods) { [] }
      
      before do
        allow(result).to receive(:methods).and_return(methods)
        allow(result).to receive(:classes).and_return(nil)
        
        # Stub quality issues with different severities
        allow(result).to receive(:quality_issues).and_return([
          Rubymap::Enricher::Analyzers::QualityIssue.new(
            type: "method",
            name: "test1",
            issues: [
              {severity: "critical", type: "issue1"},
              {severity: "high", type: "issue2"}
            ]
          ),
          Rubymap::Enricher::Analyzers::QualityIssue.new(
            type: "method",
            name: "test2",
            issues: [
              {severity: "medium", type: "issue3"},
              {severity: "low", type: "issue4"},
              {severity: "low", type: "issue5"}
            ]
          )
        ])
      end

      it "counts issues by severity" do
        analyzer.analyze(result, config)
        
        expect(result.quality_metrics.issues_by_severity).to eq({
          critical: 1,
          high: 1,
          medium: 1,
          low: 2
        })
      end
    end
  end

  describe "QualityMetrics" do
    let(:metrics) { Rubymap::Enricher::Analyzers::QualityMetrics.new }

    it "initializes with default values" do
      expect(metrics.overall_score).to eq(0.0)
      expect(metrics.quality_level).to eq("unknown")
      expect(metrics.issues_by_severity).to eq({})
    end

    it "converts to hash" do
      metrics.overall_score = 0.75
      metrics.quality_level = "good"
      metrics.issues_by_severity = {low: 2}
      
      expect(metrics.to_h).to eq({
        overall_score: 0.75,
        quality_level: "good",
        issues_by_severity: {low: 2}
      })
    end
  end

  describe "QualityIssue" do
    let(:issue) do
      Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "TestClass#method",
        issues: [{type: "long_method", severity: "high"}],
        quality_score: 0.6
      )
    end

    it "initializes with provided values" do
      expect(issue.type).to eq("method")
      expect(issue.name).to eq("TestClass#method")
      expect(issue.issues).to eq([{type: "long_method", severity: "high"}])
      expect(issue.quality_score).to eq(0.6)
    end

    it "has default values" do
      minimal_issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "class",
        name: "TestClass"
      )
      
      expect(minimal_issue.issues).to eq([])
      expect(minimal_issue.quality_score).to eq(1.0)
    end

    it "converts to hash" do
      expect(issue.to_h).to eq({
        type: "method",
        name: "TestClass#method",
        issues: [{type: "long_method", severity: "high"}],
        quality_score: 0.6
      })
    end
  end

  describe "Integration with custom rules" do
    let(:custom_rules) do
      Tempfile.new(["custom_rules", ".yml"]).tap do |f|
        f.write(<<~YAML)
          version: "1.0"
          method_rules:
            - id: custom_rule
              enabled: true
              description: "Custom test rule"
              threshold:
                metric: line_count
                operator: ">"
                value: 3
              severity: high
              message_template: "Method exceeds custom threshold"
              suggestion: "Fix it"
        YAML
        f.flush
      end
    end

    let(:custom_analyzer) { described_class.new(custom_rules.path) }

    let(:method) do
      double("method",
        name: "test",
        owner: "TestClass",
        line_count: 5,
        parameters: [],
        complexity: 1,
        quality_score: nil,
        has_quality_issues: nil)
    end

    before do
      allow(result).to receive(:methods).and_return([method])
      allow(result).to receive(:classes).and_return(nil)
      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)
    end

    after do
      custom_rules.unlink
    end

    it "applies custom rules from file" do
      custom_analyzer.analyze(result, config)
      
      issue = result.quality_issues.first
      expect(issue).not_to be_nil
      expect(issue.issues.first[:type]).to eq("custom_rule")
      expect(issue.issues.first[:message]).to eq("Method exceeds custom threshold")
    end
  end
end