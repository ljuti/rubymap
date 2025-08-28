# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Calculators::ArityCalculator do
  subject(:arity_calculator) { described_class.new }

  describe "behavior when calculating method arity" do
    context "when parameters contain required arguments" do
      it "calculates arity for methods with only required parameters" do
        parameters = [
          { type: "required", name: "first" },
          { type: "required", name: "second" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "handles alternative 'req' type designation" do
        parameters = [
          { type: "req", name: "first" },
          { type: "req", name: "second" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "calculates arity for single required parameter" do
        parameters = [
          { type: "required", name: "arg" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(1)
      end
    end

    context "when parameters contain optional arguments" do
      it "calculates arity for methods with only optional parameters" do
        parameters = [
          { type: "optional", name: "first" },
          { type: "optional", name: "second" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "handles alternative 'opt' type designation" do
        parameters = [
          { type: "opt", name: "first" },
          { type: "opt", name: "second" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "calculates arity for single optional parameter" do
        parameters = [
          { type: "optional", name: "arg" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(1)
      end
    end

    context "when parameters contain mixed required and optional arguments" do
      it "sums required and optional parameters" do
        parameters = [
          { type: "required", name: "first" },
          { type: "optional", name: "second" },
          { type: "required", name: "third" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(3)
      end

      it "handles mixed req and opt type designations" do
        parameters = [
          { type: "req", name: "first" },
          { type: "opt", name: "second" },
          { type: "req", name: "third" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(3)
      end

      it "handles large numbers of mixed parameters" do
        parameters = (1..10).map do |i|
          { type: i.even? ? "required" : "optional", name: "param#{i}" }
        end
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(10)  # 5 required + 5 optional
      end
    end

    context "when parameters contain rest arguments (splat)" do
      it "calculates negative arity for methods with rest parameters" do
        parameters = [
          { type: "required", name: "first" },
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-2)  # -(1 required + 1) = -2
      end

      it "ignores optional parameters when rest parameter is present" do
        parameters = [
          { type: "required", name: "first" },
          { type: "optional", name: "second" },
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-2)  # -(1 required + 1) = -2, optional ignored
      end

      it "calculates arity with only rest parameter" do
        parameters = [
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-1)  # -(0 required + 1) = -1
      end

      it "calculates arity with multiple required parameters and rest" do
        parameters = [
          { type: "required", name: "first" },
          { type: "required", name: "second" },
          { type: "required", name: "third" },
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-4)  # -(3 required + 1) = -4
      end

      it "handles multiple rest parameters (though unusual)" do
        parameters = [
          { type: "required", name: "first" },
          { type: "rest", name: "args1" },
          { type: "rest", name: "args2" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-2)  # -(1 required + 1) = -2, any rest param triggers negative
      end
    end

    context "when parameters contain unknown or invalid types" do
      it "ignores parameters with unknown types" do
        parameters = [
          { type: "required", name: "valid" },
          { type: "unknown", name: "invalid" },
          { type: "optional", name: "also_valid" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)  # Only counts valid required and optional
      end

      it "handles parameters with nil types" do
        parameters = [
          { type: "required", name: "valid" },
          { type: nil, name: "invalid" },
          { type: "optional", name: "also_valid" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "handles parameters with missing type field" do
        parameters = [
          { type: "required", name: "valid" },
          { name: "no_type" },
          { type: "optional", name: "also_valid" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "handles mixed valid and invalid parameters with rest" do
        parameters = [
          { type: "required", name: "valid" },
          { type: "invalid", name: "invalid" },
          { type: "rest", name: "splat" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-2)  # -(1 required + 1) = -2
      end
    end

    context "when handling edge case inputs" do
      it "returns 0 for nil parameters" do
        arity = arity_calculator.calculate(nil)
        
        expect(arity).to eq(0)
      end

      it "returns 0 for empty parameters array" do
        arity = arity_calculator.calculate([])
        
        expect(arity).to eq(0)
      end

      it "handles parameters with empty hashes" do
        parameters = [
          {},
          { type: "required", name: "valid" },
          {}
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(1)
      end

      it "handles parameters with string keys instead of symbol keys" do
        parameters = [
          { "type" => "required", "name" => "first" },
          { "type" => "optional", "name" => "second" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(0)  # String keys not recognized, so no valid parameters
      end

      it "handles mixed symbol and string keys" do
        parameters = [
          { type: "required", name: "first" },      # symbol keys
          { "type" => "optional", "name" => "second" }  # string keys
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(1)  # Only symbol key parameter counted
      end
    end

    context "when processing complex parameter scenarios" do
      it "handles realistic method signature with all parameter types" do
        parameters = [
          { type: "required", name: "name" },
          { type: "optional", name: "age" },
          { type: "required", name: "email" },
          { type: "rest", name: "options" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        # 2 required parameters, rest present: -(2 + 1) = -3
        expect(arity).to eq(-3)
      end

      it "handles method with only optional parameters (common in Ruby)" do
        parameters = [
          { type: "optional", name: "host" },
          { type: "optional", name: "port" },
          { type: "optional", name: "ssl" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(3)
      end

      it "handles zero-arity methods (no parameters)" do
        parameters = []
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(0)
      end

      it "correctly distinguishes between methods with same number but different types" do
        all_required = [
          { type: "required", name: "first" },
          { type: "required", name: "second" }
        ]
        
        all_optional = [
          { type: "optional", name: "first" },
          { type: "optional", name: "second" }
        ]
        
        required_with_rest = [
          { type: "required", name: "first" },
          { type: "rest", name: "args" }
        ]
        
        expect(arity_calculator.calculate(all_required)).to eq(2)
        expect(arity_calculator.calculate(all_optional)).to eq(2)
        expect(arity_calculator.calculate(required_with_rest)).to eq(-2)
      end
    end

    context "when validating Ruby arity semantics" do
      it "matches Ruby's arity for simple required parameters" do
        # def method(a, b) -> arity 2
        parameters = [
          { type: "required", name: "a" },
          { type: "required", name: "b" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "matches Ruby's arity for optional parameters" do
        # def method(a = nil, b = nil) -> arity 2
        parameters = [
          { type: "optional", name: "a" },
          { type: "optional", name: "b" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(2)
      end

      it "matches Ruby's arity for splat parameters" do
        # def method(*args) -> arity -1
        parameters = [
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-1)
      end

      it "matches Ruby's arity for required + splat" do
        # def method(a, *args) -> arity -2
        parameters = [
          { type: "required", name: "a" },
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        expect(arity).to eq(-2)
      end

      it "matches Ruby's arity for complex signatures" do
        # def method(a, b = nil, c, *args) -> arity -3 (ignores optional when splat present)
        parameters = [
          { type: "required", name: "a" },
          { type: "optional", name: "b" },
          { type: "required", name: "c" },
          { type: "rest", name: "args" }
        ]
        
        arity = arity_calculator.calculate(parameters)
        
        # 2 required parameters, rest present: -(2 + 1) = -3
        expect(arity).to eq(-3)
      end
    end
  end

  describe "parameter type recognition behavior" do
    context "when recognizing required parameter types" do
      it "recognizes 'required' as required type" do
        parameters = [{ type: "required", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(1)
      end

      it "recognizes 'req' as required type" do
        parameters = [{ type: "req", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(1)
      end

      it "does not recognize 'REQUIRED' (case sensitive)" do
        parameters = [{ type: "REQUIRED", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end

      it "does not recognize 'require' (exact match required)" do
        parameters = [{ type: "require", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end
    end

    context "when recognizing optional parameter types" do
      it "recognizes 'optional' as optional type" do
        parameters = [{ type: "optional", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(1)
      end

      it "recognizes 'opt' as optional type" do
        parameters = [{ type: "opt", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(1)
      end

      it "does not recognize 'OPTIONAL' (case sensitive)" do
        parameters = [{ type: "OPTIONAL", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end

      it "does not recognize 'option' (exact match required)" do
        parameters = [{ type: "option", name: "arg" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end
    end

    context "when recognizing rest parameter types" do
      it "recognizes 'rest' as rest type" do
        parameters = [{ type: "rest", name: "args" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(-1)
      end

      it "does not recognize 'REST' (case sensitive)" do
        parameters = [{ type: "REST", name: "args" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end

      it "does not recognize 'splat' (exact match required)" do
        parameters = [{ type: "splat", name: "args" }]
        arity = arity_calculator.calculate(parameters)
        expect(arity).to eq(0)
      end
    end
  end
end