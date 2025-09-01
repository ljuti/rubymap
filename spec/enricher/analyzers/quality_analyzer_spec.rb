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
    it "creates a rules engine with default path when nil is passed" do
      analyzer = described_class.new(nil)
      expect(analyzer.rules_engine).to be_a(Rubymap::Enricher::QualityRulesEngine)
    end

    it "creates a rules engine with default path when no argument" do
      expect(analyzer.rules_engine).to be_a(Rubymap::Enricher::QualityRulesEngine)
    end

    it "passes custom rules path to rules engine" do
      custom_path = "/custom/path/rules.yml"
      expect(Rubymap::Enricher::QualityRulesEngine).to receive(:new).with(custom_path).and_call_original
      custom_analyzer = described_class.new(custom_path)
      expect(custom_analyzer.rules_engine).to be_a(Rubymap::Enricher::QualityRulesEngine)
    end

    it "differentiates between nil and no argument" do
      # This tests that rules_path argument is actually passed through
      expect(Rubymap::Enricher::QualityRulesEngine).to receive(:new).with(nil).and_call_original
      described_class.new(nil)

      expect(Rubymap::Enricher::QualityRulesEngine).to receive(:new).with(nil).and_call_original
      described_class.new
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

      context "when quality_issues already exists" do
        it "preserves existing quality_issues array" do
          existing_issues = [
            Rubymap::Enricher::Analyzers::QualityIssue.new(
              type: "method",
              name: "existing",
              issues: [{severity: "low"}]
            )
          ]
          allow(result).to receive(:quality_issues).and_return(existing_issues)
          allow(result).to receive(:quality_issues=)

          analyzer.analyze(result, config)
          expect(result.quality_issues).to equal(existing_issues)
        end
      end

      context "when quality_issues is nil" do
        it "initializes to empty array" do
          allow(result).to receive(:quality_issues).and_return(nil, [])
          allow(result).to receive(:quality_issues=).with([])

          analyzer.analyze(result, config)
          expect(result).to have_received(:quality_issues=).with([])
        end
      end

      it "preserves existing quality issues if already set" do
        existing_issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
          type: "method",
          name: "existing",
          issues: [{severity: "low"}]
        )
        existing_issues = [existing_issue]
        allow(result).to receive(:quality_issues).and_return(existing_issues)
        analyzer.analyze(result, config)
        expect(result.quality_issues).to eq(existing_issues)
      end
    end

    context "with empty arrays for methods and classes" do
      before do
        allow(result).to receive(:methods).and_return([])
        allow(result).to receive(:classes).and_return([])
      end

      it "processes empty collections without error" do
        expect { analyzer.analyze(result, config) }.not_to raise_error
      end

      it "sets empty issues_by_severity" do
        analyzer.analyze(result, config)
        expect(result.quality_metrics.issues_by_severity).to eq({
          critical: 0,
          high: 0,
          medium: 0,
          low: 0
        })
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

      let(:method_without_owner) do
        double("method",
          name: "orphan_method",
          owner: nil,
          line_count: 10,
          parameters: [],
          complexity: 3,
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

      it "sets has_quality_issues to true for methods with issues" do
        analyzer.analyze(result, config)
        expect(method1).to have_received(:has_quality_issues=).with(true)
      end

      it "sets has_quality_issues to false for clean methods" do
        analyzer.analyze(result, config)
        expect(method2).to have_received(:has_quality_issues=).with(false)
      end

      it "handles methods without owner" do
        allow(result).to receive(:methods).and_return([method_without_owner])
        allow(method_without_owner).to receive(:quality_score=)
        allow(method_without_owner).to receive(:has_quality_issues=)

        analyzer.analyze(result, config)

        # Should be handled gracefully
        expect(method_without_owner).to have_received(:quality_score=)
      end

      it "always sets quality_score even for clean methods" do
        clean_method = double("method",
          name: "clean",
          owner: "TestClass",
          line_count: 5,
          parameters: [],
          complexity: 1,
          quality_score: nil,
          has_quality_issues: nil)

        allow(result).to receive(:methods).and_return([clean_method])
        allow(clean_method).to receive(:quality_score=)
        allow(clean_method).to receive(:has_quality_issues=)

        analyzer.analyze(result, config)

        expect(clean_method).to have_received(:quality_score=).with(kind_of(Float))
        expect(clean_method).to have_received(:has_quality_issues=).with(false)
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

  describe "#analyze_methods_quality" do
    it "creates QualityIssue object with correct structure" do
      method = double("method",
        name: "test_method",
        owner: "TestClass",
        line_count: 100,
        parameters: [:a, :b, :c, :d, :e],
        complexity: 25,
        quality_score: nil,
        has_quality_issues: nil)

      allow(result).to receive(:methods).and_return([method])
      allow(result).to receive(:classes).and_return(nil)
      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)

      analyzer.analyze(result, config)

      issue = result.quality_issues.first
      expect(issue).to be_a(Rubymap::Enricher::Analyzers::QualityIssue)
      expect(issue.type).to eq("method")
      expect(issue.name).to eq("TestClass#test_method")
      expect(issue.issues).not_to be_empty
      expect(issue.quality_score).to be_a(Float)
    end

    it "adds issues to result.quality_issues array" do
      method = double("method",
        name: "bad_method",
        owner: "BadClass",
        line_count: 150,
        parameters: [],
        complexity: 30,
        quality_score: nil,
        has_quality_issues: nil)

      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)

      # Manually call analyze_methods_quality
      analyzer.send(:analyze_methods_quality, [method], result)

      expect(result.quality_issues.size).to be >= 1
    end

    it "sets has_quality_issues to true when issues exist" do
      method = double("method",
        name: "problematic",
        owner: nil,
        line_count: 100,
        parameters: [:a, :b, :c, :d, :e, :f],
        complexity: 20)

      allow(method).to receive(:quality_score=)
      expect(method).to receive(:has_quality_issues=).with(true)

      analyzer.send(:analyze_methods_quality, [method], result)
    end

    it "sets has_quality_issues to false when no issues" do
      method = double("method",
        name: "good_method",
        owner: nil,
        line_count: 10,
        parameters: [:a],
        complexity: 2)

      allow(method).to receive(:quality_score=)
      expect(method).to receive(:has_quality_issues=).with(false)

      analyzer.send(:analyze_methods_quality, [method], result)
    end

    it "does not add QualityIssue when no issues found" do
      method = double("method",
        name: "clean_method",
        owner: nil,
        line_count: 5,
        parameters: [],
        complexity: 1)

      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)

      analyzer.send(:analyze_methods_quality, [method], result)
      expect(result.quality_issues).to be_empty
    end

    it "only adds issue when issues.any? returns true" do
      method = double("method", name: "test", owner: nil)
      issues_mock = double("issues")

      allow(analyzer.rules_engine).to receive(:apply_method_rules).and_return(issues_mock)
      allow(analyzer.rules_engine).to receive(:calculate_method_score).and_return(0.8)
      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)

      # Test both paths
      allow(issues_mock).to receive(:any?).and_return(false)
      analyzer.send(:analyze_methods_quality, [method], result)
      expect(result.quality_issues).to be_empty

      allow(issues_mock).to receive(:any?).and_return(true)
      analyzer.send(:analyze_methods_quality, [method], result)
      expect(result.quality_issues.size).to eq(1)
    end

    it "creates QualityIssue with exact parameters" do
      method = double("method", name: "my_method", owner: "MyClass")
      issues = [{type: "long_method", severity: "high"}]
      score = 0.65

      allow(analyzer.rules_engine).to receive(:apply_method_rules).with(method).and_return(issues)
      allow(analyzer.rules_engine).to receive(:calculate_method_score).with(method, issues).and_return(score)
      allow(method).to receive(:quality_score=).with(score)
      allow(method).to receive(:has_quality_issues=).with(true)

      expect(analyzer).to receive(:format_method_name).with(method).and_return("MyClass#my_method")

      analyzer.send(:analyze_methods_quality, [method], result)

      issue = result.quality_issues.first
      expect(issue.type).to eq("method")
      expect(issue.name).to eq("MyClass#my_method")
      expect(issue.issues).to equal(issues) # Same object reference
      expect(issue.quality_score).to eq(score)
    end

    it "calculates quality_score twice with same parameters" do
      method = double("method", name: "test", owner: nil)
      issues = [{type: "issue"}]

      # Ensure calculate_method_score is called twice with same parameters
      expect(analyzer.rules_engine).to receive(:apply_method_rules).and_return(issues)
      expect(analyzer.rules_engine).to receive(:calculate_method_score).with(method, issues).twice.and_return(0.7)
      allow(method).to receive(:quality_score=)
      allow(method).to receive(:has_quality_issues=)

      analyzer.send(:analyze_methods_quality, [method], result)
    end
  end

  describe "#analyze_classes_quality" do
    it "creates QualityIssue object for problematic classes" do
      klass = double("class",
        name: "ProblematicClass",
        metrics: {loc: 1000},
        instance_methods: Array.new(50) { |i| "method_#{i}" },
        dependencies: Array.new(30) { |i| "Dep#{i}" },
        total_complexity: 100,
        instance_variables: ["@var1", "@var2"],
        quality_score: nil,
        stability_score: nil)

      allow(klass).to receive(:quality_score=)

      analyzer.send(:analyze_classes_quality, [klass], result)

      issue = result.quality_issues.first
      expect(issue).to be_a(Rubymap::Enricher::Analyzers::QualityIssue)
      expect(issue.type).to eq("class")
      expect(issue.name).to eq("ProblematicClass")
    end

    it "always sets quality_score on class" do
      klass = double("class",
        name: "SimpleClass",
        metrics: {loc: 50},
        instance_methods: ["method1"],
        dependencies: [],
        total_complexity: 5,
        instance_variables: [],
        quality_score: nil,
        stability_score: nil)

      allow(klass).to receive(:quality_score=)

      analyzer.send(:analyze_classes_quality, [klass], result)

      expect(klass).to have_received(:quality_score=).with(kind_of(Float))
    end

    it "only creates issue when issues.any? is true not just truthy" do
      klass = double("class", name: "TestClass")
      issues = []

      allow(analyzer.rules_engine).to receive(:apply_class_rules).and_return(issues)
      allow(analyzer.rules_engine).to receive(:calculate_class_score).and_return(0.8)
      allow(klass).to receive(:quality_score=)

      # Verify that we check issues.any? not just truthiness
      expect(issues).to receive(:any?).and_return(false)

      analyzer.send(:analyze_classes_quality, [klass], result)
      expect(result.quality_issues).to be_empty
    end

    it "creates issue with all required fields including issues array" do
      klass = double("class", name: "TestClass")
      issues = [{type: "god_class", severity: "high"}]
      score = 0.6

      allow(analyzer.rules_engine).to receive(:apply_class_rules).and_return(issues)
      allow(analyzer.rules_engine).to receive(:calculate_class_score).with(klass, issues).and_return(score)
      allow(klass).to receive(:quality_score=)

      analyzer.send(:analyze_classes_quality, [klass], result)

      issue = result.quality_issues.first
      expect(issue.type).to eq("class")
      expect(issue.name).to eq("TestClass")
      expect(issue.issues).to eq(issues)
      expect(issue.quality_score).to eq(score)
    end

    it "does not create issue when issues array is empty" do
      klass = double("class", name: "TestClass")
      issues = []

      allow(analyzer.rules_engine).to receive(:apply_class_rules).and_return(issues)
      allow(analyzer.rules_engine).to receive(:calculate_class_score).and_return(1.0)
      allow(klass).to receive(:quality_score=)

      analyzer.send(:analyze_classes_quality, [klass], result)
      expect(result.quality_issues).to be_empty
    end

    it "processes multiple classes independently" do
      klass1 = double("class", name: "Class1")
      klass2 = double("class", name: "Class2")

      allow(analyzer.rules_engine).to receive(:apply_class_rules).with(klass1).and_return([])
      allow(analyzer.rules_engine).to receive(:apply_class_rules).with(klass2).and_return([{type: "issue"}])
      allow(analyzer.rules_engine).to receive(:calculate_class_score).and_return(0.8)
      allow(klass1).to receive(:quality_score=)
      allow(klass2).to receive(:quality_score=)

      analyzer.send(:analyze_classes_quality, [klass1, klass2], result)

      expect(result.quality_issues.size).to eq(1)
      expect(result.quality_issues.first.name).to eq("Class2")
    end
  end

  describe "#format_method_name" do
    it "formats method name with owner" do
      method = double("method", name: "test", owner: "MyClass")
      formatted = analyzer.send(:format_method_name, method)
      expect(formatted).to eq("MyClass#test")
    end

    it "returns just name when owner is nil" do
      method = double("method", name: "test", owner: nil)
      formatted = analyzer.send(:format_method_name, method)
      expect(formatted).to eq("test")
    end

    it "handles symbols as method names" do
      method = double("method", name: :test_method, owner: "MyClass")
      formatted = analyzer.send(:format_method_name, method)
      expect(formatted).to eq("MyClass#test_method")
    end

    it "converts name to string when owner is nil" do
      # Test that to_s is necessary for non-string names
      method = double("method", name: :symbol_name, owner: nil)
      formatted = analyzer.send(:format_method_name, method)
      expect(formatted).to eq("symbol_name")
      expect(formatted).to be_a(String)
    end

    it "handles falsy but non-nil owner" do
      method = double("method", name: "test", owner: false)
      formatted = analyzer.send(:format_method_name, method)
      expect(formatted).to eq("test")
    end
  end

  describe "#calculate_overall_quality" do
    it "calculates average score and sets quality level" do
      method1 = double("method", quality_score: 0.8)
      method2 = double("method", quality_score: 0.6)

      allow(result).to receive(:methods).and_return([method1, method2])
      allow(result).to receive(:classes).and_return(nil)
      allow(result).to receive(:quality_issues).and_return([])

      # Ensure quality_metrics is initialized
      metrics = Rubymap::Enricher::Analyzers::QualityMetrics.new
      allow(result).to receive(:quality_metrics).and_return(metrics)

      analyzer.send(:calculate_overall_quality, result)

      expect(result.quality_metrics.overall_score).to eq(0.7)
      expect(result.quality_metrics.quality_level).to eq("good")
    end

    it "sets issues_by_severity" do
      allow(result).to receive(:methods).and_return(nil)
      allow(result).to receive(:classes).and_return(nil)
      allow(result).to receive(:quality_issues).and_return([])

      # Ensure quality_metrics is initialized
      metrics = Rubymap::Enricher::Analyzers::QualityMetrics.new
      allow(result).to receive(:quality_metrics).and_return(metrics)

      analyzer.send(:calculate_overall_quality, result)

      expect(result.quality_metrics.issues_by_severity).to eq({
        critical: 0,
        high: 0,
        medium: 0,
        low: 0
      })
    end

    it "handles empty scores array" do
      allow(result).to receive(:methods).and_return(nil)
      allow(result).to receive(:classes).and_return(nil)
      allow(result).to receive(:quality_issues).and_return([])

      # Ensure quality_metrics is initialized
      metrics = Rubymap::Enricher::Analyzers::QualityMetrics.new
      allow(result).to receive(:quality_metrics).and_return(metrics)

      analyzer.send(:calculate_overall_quality, result)

      # When no scores, overall_score should not be set
      expect(result.quality_metrics.overall_score).to eq(0.0)
    end
  end

  describe "#collect_quality_scores" do
    it "collects scores from methods" do
      method1 = double("method", quality_score: 0.8)
      method2 = double("method", quality_score: 0.9)
      allow(result).to receive(:methods).and_return([method1, method2])
      allow(result).to receive(:classes).and_return(nil)

      scores = analyzer.send(:collect_quality_scores, result)
      expect(scores).to eq([0.8, 0.9])
    end

    it "collects scores from classes" do
      class1 = double("class", quality_score: 0.7)
      class2 = double("class", quality_score: 0.85)
      allow(result).to receive(:methods).and_return(nil)
      allow(result).to receive(:classes).and_return([class1, class2])

      scores = analyzer.send(:collect_quality_scores, result)
      expect(scores).to eq([0.7, 0.85])
    end

    it "skips nil scores" do
      method1 = double("method", quality_score: 0.8)
      method2 = double("method", quality_score: nil)
      allow(result).to receive(:methods).and_return([method1, method2])
      allow(result).to receive(:classes).and_return(nil)

      scores = analyzer.send(:collect_quality_scores, result)
      expect(scores).to eq([0.8])
    end

    it "returns empty array when no scores available" do
      allow(result).to receive(:methods).and_return(nil)
      allow(result).to receive(:classes).and_return(nil)

      scores = analyzer.send(:collect_quality_scores, result)
      expect(scores).to eq([])
    end

    it "collects from both methods and classes" do
      method = double("method", quality_score: 0.8)
      klass = double("class", quality_score: 0.7)
      allow(result).to receive(:methods).and_return([method])
      allow(result).to receive(:classes).and_return([klass])

      scores = analyzer.send(:collect_quality_scores, result)
      expect(scores).to eq([0.8, 0.7])
    end

    it "uses safe navigation for methods and classes" do
      # Test that nil doesn't cause errors
      allow(result).to receive(:methods).and_return(nil)
      allow(result).to receive(:classes).and_return(nil)

      expect { analyzer.send(:collect_quality_scores, result) }.not_to raise_error
    end

    it "only adds score if quality_score is truthy" do
      method1 = double("method", quality_score: 0.0) # 0.0 is truthy in Ruby
      method2 = double("method", quality_score: false)
      method3 = double("method", quality_score: nil)
      method4 = double("method", quality_score: 0.5)

      allow(result).to receive(:methods).and_return([method1, method2, method3, method4])
      allow(result).to receive(:classes).and_return(nil)

      scores = analyzer.send(:collect_quality_scores, result)
      # 0.0 is truthy in Ruby and should be included
      # false and nil should be excluded
      expect(scores).to eq([0.0, 0.5])
    end

    it "iterates through each method and class with safe navigation" do
      methods = [double("method", quality_score: 0.8)]
      classes = [double("class", quality_score: 0.7)]

      allow(result).to receive(:methods).and_return(methods)
      allow(result).to receive(:classes).and_return(classes)

      # Verify safe navigation is used
      expect(methods).to receive(:each).and_yield(methods.first)
      expect(classes).to receive(:each).and_yield(classes.first)

      analyzer.send(:collect_quality_scores, result)
    end
  end

  describe "#count_issues_by_severity" do
    it "counts issues correctly" do
      issue1 = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test1",
        issues: [
          {severity: "high"},
          {severity: "low"}
        ]
      )
      issue2 = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test2",
        issues: [
          {severity: "low"},
          {severity: "critical"}
        ]
      )

      allow(result).to receive(:quality_issues).and_return([issue1, issue2])

      counts = analyzer.send(:count_issues_by_severity, result)
      expect(counts).to eq({
        critical: 1,
        high: 1,
        medium: 0,
        low: 2
      })
    end

    it "handles empty issues array" do
      allow(result).to receive(:quality_issues).and_return([])

      counts = analyzer.send(:count_issues_by_severity, result)
      expect(counts).to eq({
        critical: 0,
        high: 0,
        medium: 0,
        low: 0
      })
    end

    it "handles unknown severity levels" do
      issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test",
        issues: [{severity: "unknown"}]
      )

      allow(result).to receive(:quality_issues).and_return([issue])

      counts = analyzer.send(:count_issues_by_severity, result)
      expect(counts[:unknown]).to eq(1)
    end

    it "skips issues with nil severity" do
      issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test",
        issues: [
          {severity: nil},
          {severity: "high"},
          {severity: nil}
        ]
      )

      allow(result).to receive(:quality_issues).and_return([issue])

      counts = analyzer.send(:count_issues_by_severity, result)
      expect(counts[:high]).to eq(1)
      expect(counts[:critical]).to eq(0)
    end

    it "converts string severities to symbols" do
      issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test",
        issues: [
          {severity: "critical"},
          {severity: :high}
        ]
      )

      allow(result).to receive(:quality_issues).and_return([issue])

      counts = analyzer.send(:count_issues_by_severity, result)
      expect(counts[:critical]).to eq(1)
      expect(counts[:high]).to eq(1)
    end

    it "iterates through all quality issues and their nested issues" do
      issue1 = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test1",
        issues: [{severity: "high"}]
      )
      issue2 = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test2",
        issues: [{severity: "low"}]
      )

      quality_issues = [issue1, issue2]
      allow(result).to receive(:quality_issues).and_return(quality_issues)

      # Verify iteration happens
      expect(quality_issues).to receive(:each).and_call_original

      analyzer.send(:count_issues_by_severity, result)
    end

    it "accesses severity with hash syntax" do
      issue = Rubymap::Enricher::Analyzers::QualityIssue.new(
        type: "method",
        name: "test",
        issues: [{severity: "high"}]
      )

      allow(result).to receive(:quality_issues).and_return([issue])

      # Test that we use hash access [:severity]
      expect(issue.issues.first).to receive(:[]).with(:severity).and_return("high")

      analyzer.send(:count_issues_by_severity, result)
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

RSpec.describe Rubymap::Enricher::Analyzers::QualityMetrics do
  describe "#initialize" do
    it "initializes with default values" do
      metrics = described_class.new
      expect(metrics.overall_score).to eq(0.0)
      expect(metrics.quality_level).to eq("unknown")
      expect(metrics.issues_by_severity).to eq({})
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      metrics = described_class.new
      metrics.overall_score = 0.85
      metrics.quality_level = "good"
      metrics.issues_by_severity = {critical: 1, high: 2}

      expect(metrics.to_h).to eq({
        overall_score: 0.85,
        quality_level: "good",
        issues_by_severity: {critical: 1, high: 2}
      })
    end
  end
end

RSpec.describe Rubymap::Enricher::Analyzers::QualityIssue do
  describe "#initialize" do
    it "creates with required parameters" do
      issue = described_class.new(type: "method", name: "test_method")
      expect(issue.type).to eq("method")
      expect(issue.name).to eq("test_method")
      expect(issue.issues).to eq([])
      expect(issue.quality_score).to eq(1.0)
    end

    it "accepts optional parameters" do
      issues = [{type: "long_method"}]
      issue = described_class.new(
        type: "method",
        name: "test",
        issues: issues,
        quality_score: 0.7
      )
      expect(issue.issues).to eq(issues)
      expect(issue.quality_score).to eq(0.7)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      issue = described_class.new(
        type: "class",
        name: "TestClass",
        issues: [{severity: "high"}],
        quality_score: 0.6
      )

      expect(issue.to_h).to eq({
        type: "class",
        name: "TestClass",
        issues: [{severity: "high"}],
        quality_score: 0.6
      })
    end
  end
end
