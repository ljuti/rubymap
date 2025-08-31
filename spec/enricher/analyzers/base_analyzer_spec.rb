# frozen_string_literal: true

require "spec_helper"

# Create a test subclass to test protected methods
class TestAnalyzer < Rubymap::Enricher::Analyzers::BaseAnalyzer
  def analyze(result, config)
    # Implementation for testing
  end

  # Expose protected methods for testing
  def test_pattern_matches?(evidence, required_evidence, confidence_threshold = 0.7)
    pattern_matches?(evidence, required_evidence, confidence_threshold)
  end

  def test_calculate_confidence(evidence, required_evidence, optional_evidence = [])
    calculate_confidence(evidence, required_evidence, optional_evidence)
  end

  def test_matches_naming_pattern?(name, pattern)
    matches_naming_pattern?(name, pattern)
  end

  def test_extract_evidence(symbol)
    extract_evidence(symbol)
  end
end

RSpec.describe Rubymap::Enricher::Analyzers::BaseAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#analyze" do
    it "raises NotImplementedError" do
      expect { analyzer.analyze({}, {}) }.to raise_error(NotImplementedError, "Subclasses must implement #analyze")
    end

    it "raises with the correct message" do
      expect { analyzer.analyze(nil, nil) }.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "protected methods" do
    let(:test_analyzer) { TestAnalyzer.new }

    describe "#pattern_matches?" do
      it "returns true when confidence meets threshold" do
        evidence = [:method1, :method2, :method3]
        required = [:method1, :method2]
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be true
      end

      it "returns false when confidence is below threshold" do
        evidence = [:method1]
        required = [:method1, :method2, :method3]
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be false
      end

      it "returns true when exactly at threshold" do
        evidence = [:method1, :method2]
        required = [:method1, :method2, :method3]
        threshold = 0.666666
        expect(test_analyzer.test_pattern_matches?(evidence, required, threshold)).to be true
      end

      it "uses custom threshold when provided" do
        evidence = [:method1]
        required = [:method1, :method2]
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.5)).to be true
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.51)).to be false
      end

      it "uses 0.7 as default threshold" do
        evidence = [:method1, :method2]
        required = [:method1, :method2, :method3]
        # 2/3 = 0.667
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be false
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.66)).to be true
      end

      it "handles edge case thresholds" do
        evidence = [:method1]
        required = [:method1, :method2]
        # 0.5 confidence
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.0)).to be true
        expect(test_analyzer.test_pattern_matches?(evidence, required, 1.0)).to be false
        expect(test_analyzer.test_pattern_matches?(evidence, required, Float::INFINITY)).to be false
      end

      it "requires threshold parameter when called with 3 arguments" do
        evidence = [:method1]
        required = [:method1, :method2]
        # Can't pass nil - it will cause ArgumentError in comparison
        expect { test_analyzer.test_pattern_matches?(evidence, required, nil) }.to raise_error(ArgumentError)
      end

      it "differentiates 0.0 threshold from default 0.7" do
        evidence = [:method1]
        required = [:method1, :method2, :method3]
        # 1/3 = 0.333
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.0)).to be true # 0.333 >= 0.0
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be false # 0.333 < 0.7
        # Also test that removing default would break
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.7)).to be false # explicit 0.7
      end

      it "tests exact boundary at 0.7 threshold" do
        # Create evidence that gives exactly 0.7 confidence
        evidence = [:a, :b, :c, :d, :e, :f, :g]
        required = [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j]
        # 7/10 = 0.7 exactly
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be true # default 0.7
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.7)).to be true
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.71)).to be false
      end

      it "differentiates 1.0 threshold from default 0.7" do
        evidence = [:method1, :method2]
        required = [:method1, :method2, :method3]
        # 2/3 = 0.667
        expect(test_analyzer.test_pattern_matches?(evidence, required, 1.0)).to be false # 0.667 < 1.0
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be false # 0.667 < 0.7 (close but not >=)
      end

      it "works with 2 arguments using default threshold" do
        evidence = [:method1, :method2, :method3]
        required = [:method1, :method2, :method3]
        # 100% match should pass with default 0.7 threshold
        expect(test_analyzer.test_pattern_matches?(evidence, required)).to be true
      end

      it "requires default parameter to handle 2-arg calls" do
        # This test verifies the method signature supports optional parameter
        method = test_analyzer.method(:test_pattern_matches?)
        expect(method.arity).to eq(-3) # -3 means 2 required, 1 optional
        expect(method.parameters).to include([:opt, :confidence_threshold])
      end

      it "rejects NaN threshold" do
        evidence = [:method1]
        required = [:method1, :method2]
        # NaN threshold always returns false in comparison
        expect(test_analyzer.test_pattern_matches?(evidence, required, 0.0 / 0.0)).to be false
      end

      it "rejects negative infinity threshold" do
        evidence = [:method1]
        required = [:method1, :method2]
        # -Infinity threshold means everything passes
        expect(test_analyzer.test_pattern_matches?(evidence, required, -Float::INFINITY)).to be true
      end

      it "returns false for empty evidence" do
        expect(test_analyzer.test_pattern_matches?([], [:method1])).to be false
      end

      it "returns false for empty required evidence" do
        # 0/0 results in NaN (no matches found / no requirements), which is not >= threshold
        expect(test_analyzer.test_pattern_matches?([:method1], [])).to be false
      end

      it "returns false when required is empty" do
        # 0/0 case - NaN is not >= threshold
        expect(test_analyzer.test_pattern_matches?([], [])).to be false
      end
    end

    describe "#calculate_confidence" do
      it "calculates confidence with required evidence only" do
        evidence = [:method1, :method2]
        required = [:method1, :method2, :method3]
        # 2/3 * 0.7 + 0 * 0.3 = 0.467
        expect(test_analyzer.test_calculate_confidence(evidence, required)).to eq(0.47)
      end

      it "calculates confidence with both required and optional evidence" do
        evidence = [:method1, :method2, :optional1]
        required = [:method1, :method2]
        optional = [:optional1, :optional2]
        # (2/2 * 0.7) + (1/2 * 0.3) = 0.7 + 0.15 = 0.85
        expect(test_analyzer.test_calculate_confidence(evidence, required, optional)).to eq(0.85)
      end

      it "returns 0 when no evidence matches required" do
        evidence = [:other]
        required = [:method1, :method2]
        expect(test_analyzer.test_calculate_confidence(evidence, required)).to eq(0.0)
      end

      it "returns 0.7 when all required met but no optional" do
        evidence = [:method1, :method2]
        required = [:method1, :method2]
        optional = [:optional1]
        expect(test_analyzer.test_calculate_confidence(evidence, required, optional)).to eq(0.7)
      end

      it "handles empty optional evidence array" do
        evidence = [:method1]
        required = [:method1]
        expect(test_analyzer.test_calculate_confidence(evidence, required, [])).to eq(0.7)
      end

      it "uses empty array as default for optional_evidence" do
        evidence = [:method1]
        required = [:method1]
        # Calling without optional_evidence parameter (using default)
        expect(test_analyzer.test_calculate_confidence(evidence, required)).to eq(0.7)
      end

      it "treats nil optional_evidence differently than empty array" do
        evidence = [:method1]
        required = [:method1]
        # nil should cause an error when trying to check if it's empty
        expect { test_analyzer.test_calculate_confidence(evidence, required, nil) }.to raise_error(NoMethodError)
      end

      it "requires default parameter to handle 2-arg calls" do
        # This test verifies the method signature supports optional parameter
        method = test_analyzer.method(:test_calculate_confidence)
        expect(method.arity).to eq(-3) # -3 means 2 required, 1 optional
        expect(method.parameters).to include([:opt, :optional_evidence])
      end

      it "works with 2 arguments using default empty array" do
        evidence = [:method1, :method2]
        required = [:method1, :method2]
        # No optional evidence, should get 0.7 (100% of required * 0.7)
        expect(test_analyzer.test_calculate_confidence(evidence, required)).to eq(0.7)
      end

      it "handles empty required evidence" do
        # Edge case: division by zero when required is empty results in NaN
        evidence = [:method1]
        required = []
        optional = [:method1]
        # NaN * 0.7 + 0.3 = NaN
        result = test_analyzer.test_calculate_confidence(evidence, required, optional)
        expect(result).to be_nan
      end

      it "rounds to 2 decimal places" do
        evidence = [:method1]
        required = [:method1, :method2, :method3]
        # 1/3 * 0.7 = 0.233333... should round to 0.23
        expect(test_analyzer.test_calculate_confidence(evidence, required)).to eq(0.23)
      end

      it "calculates correct weighted score" do
        evidence = [:req1, :req2, :opt1]
        required = [:req1, :req2, :req3, :req4]
        optional = [:opt1, :opt2, :opt3, :opt4]
        # (2/4 * 0.7) + (1/4 * 0.3) = 0.35 + 0.075 = 0.425 rounds to 0.43
        expect(test_analyzer.test_calculate_confidence(evidence, required, optional)).to eq(0.43)
      end

      it "weights required at 0.7 and optional at 0.3" do
        evidence = [:req1, :opt1]
        required = [:req1]
        optional = [:opt1]
        # (1/1 * 0.7) + (1/1 * 0.3) = 0.7 + 0.3 = 1.0
        expect(test_analyzer.test_calculate_confidence(evidence, required, optional)).to eq(1.0)
      end

      it "handles when all optional evidence matches but no required" do
        evidence = [:opt1, :opt2]
        required = [:req1]
        optional = [:opt1, :opt2]
        # (0/1 * 0.7) + (2/2 * 0.3) = 0 + 0.3 = 0.3
        expect(test_analyzer.test_calculate_confidence(evidence, required, optional)).to eq(0.3)
      end
    end

    describe "#matches_naming_pattern?" do
      context "with Regexp pattern" do
        it "returns true for matching regex" do
          expect(test_analyzer.test_matches_naming_pattern?("UserFactory", /Factory$/)).to be_truthy
        end

        it "returns false for non-matching regex" do
          expect(test_analyzer.test_matches_naming_pattern?("UserService", /Factory$/)).to be_falsey
        end

        it "matches case-sensitive regex" do
          expect(test_analyzer.test_matches_naming_pattern?("factory", /Factory$/)).to be_falsey
        end

        it "returns match position for successful match" do
          # =~ returns position, match? returns boolean
          result = test_analyzer.test_matches_naming_pattern?("UserFactory", /Factory/)
          expect(result).to eq(4) # Position where "Factory" starts
        end

        it "returns nil for non-match" do
          result = test_analyzer.test_matches_naming_pattern?("User", /Factory/)
          expect(result).to be_nil
        end
      end

      context "with String pattern" do
        it "returns true for case-insensitive string match" do
          expect(test_analyzer.test_matches_naming_pattern?("UserFactory", "factory")).to be true
        end

        it "returns true for partial string match" do
          expect(test_analyzer.test_matches_naming_pattern?("MyObserverClass", "observer")).to be true
        end

        it "returns false for non-matching string" do
          expect(test_analyzer.test_matches_naming_pattern?("UserService", "factory")).to be false
        end

        it "handles case differences correctly" do
          expect(test_analyzer.test_matches_naming_pattern?("FACTORY", "factory")).to be true
        end

        it "requires case-insensitive comparison" do
          # Both name and pattern must be downcased
          expect(test_analyzer.test_matches_naming_pattern?("UserFactory", "FACTORY")).to be true
          expect(test_analyzer.test_matches_naming_pattern?("USERFACTORY", "factory")).to be true
        end

        it "checks inclusion not equality" do
          # Must use include?, not ==
          expect(test_analyzer.test_matches_naming_pattern?("UserFactoryBuilder", "Factory")).to be true
        end
      end

      context "with other pattern types" do
        it "returns false for nil pattern" do
          expect(test_analyzer.test_matches_naming_pattern?("anything", nil)).to be false
        end

        it "returns false for numeric pattern" do
          expect(test_analyzer.test_matches_naming_pattern?("anything", 123)).to be false
        end

        it "returns false for array pattern" do
          expect(test_analyzer.test_matches_naming_pattern?("anything", [])).to be false
        end

        it "returns false for hash pattern" do
          expect(test_analyzer.test_matches_naming_pattern?("anything", {})).to be false
        end
      end
    end

    describe "#extract_evidence" do
      it "extracts instance methods from symbol" do
        symbol = double("symbol",
          name: "TestClass",
          instance_methods: [:method1, :method2],
          class_methods: nil)
        allow(symbol).to receive(:respond_to?).with(:instance_methods).and_return(true)
        allow(symbol).to receive(:respond_to?).with(:class_methods).and_return(false)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to include(:method1, :method2)
      end

      it "extracts class methods from symbol" do
        symbol = double("symbol",
          name: "TestClass",
          instance_methods: nil,
          class_methods: [:class_method1])
        allow(symbol).to receive(:respond_to?).with(:instance_methods).and_return(false)
        allow(symbol).to receive(:respond_to?).with(:class_methods).and_return(true)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to include(:class_method1)
      end

      it "extracts both instance and class methods" do
        symbol = double("symbol",
          name: "TestClass",
          instance_methods: [:instance1],
          class_methods: [:class1])
        allow(symbol).to receive(:respond_to?).with(:instance_methods).and_return(true)
        allow(symbol).to receive(:respond_to?).with(:class_methods).and_return(true)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to include(:instance1, :class1)
      end

      it "handles nil instance_methods gracefully" do
        symbol = double("symbol",
          name: "TestClass",
          instance_methods: nil,
          class_methods: [:class1])
        allow(symbol).to receive(:respond_to?).with(:instance_methods).and_return(true)
        allow(symbol).to receive(:respond_to?).with(:class_methods).and_return(true)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to eq([:class1])
      end

      it "handles nil class_methods gracefully" do
        symbol = double("symbol",
          name: "TestClass",
          instance_methods: [:instance1],
          class_methods: nil)
        allow(symbol).to receive(:respond_to?).with(:instance_methods).and_return(true)
        allow(symbol).to receive(:respond_to?).with(:class_methods).and_return(true)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to eq([:instance1])
      end

      context "with naming patterns" do
        it "adds factory_name evidence for Factory suffix" do
          symbol = double("symbol", name: "UserFactory")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).to include("factory_name")
        end

        it "rejects Factory pattern with newline after" do
          symbol = double("symbol", name: "UserFactory\n")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).not_to include("factory_name")
        end

        it "adds singleton_name evidence for Singleton suffix" do
          symbol = double("symbol", name: "ConfigSingleton")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).to include("singleton_name")
        end

        it "rejects Singleton pattern with newline after" do
          symbol = double("symbol", name: "ConfigSingleton\n")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).not_to include("singleton_name")
        end

        it "adds observer_name evidence for Observer suffix" do
          symbol = double("symbol", name: "UserObserver")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).to include("observer_name")
        end

        it "rejects Observer pattern with newline after" do
          symbol = double("symbol", name: "UserObserver\nExtra")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).not_to include("observer_name")
        end

        it "adds strategy_name evidence for Strategy suffix" do
          symbol = double("symbol", name: "PricingStrategy")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).to include("strategy_name")
        end

        it "rejects Strategy pattern with newline after" do
          symbol = double("symbol", name: "PricingStrategy\n")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).not_to include("strategy_name")
        end

        it "does not add pattern evidence for non-matching names" do
          symbol = double("symbol", name: "UserService")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          expect(evidence).not_to include("factory_name", "singleton_name", "observer_name", "strategy_name")
        end

        it "handles all patterns for complex names" do
          symbol = double("symbol", name: "FactorySingletonObserverStrategy")
          allow(symbol).to receive(:respond_to?).and_return(false)

          evidence = test_analyzer.test_extract_evidence(symbol)
          # Only matches Strategy suffix (last one)
          expect(evidence).to include("strategy_name")
          expect(evidence).not_to include("factory_name", "singleton_name", "observer_name")
        end
      end

      it "returns empty array for symbol without methods" do
        symbol = double("symbol", name: "EmptyClass")
        allow(symbol).to receive(:respond_to?).and_return(false)

        evidence = test_analyzer.test_extract_evidence(symbol)
        expect(evidence).to eq([])
      end
    end
  end
end
