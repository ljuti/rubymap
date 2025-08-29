# frozen_string_literal: true

require "spec_helper"

# This spec file is specifically designed to kill mutations in the Normalizer classes
# by testing edge cases and ensuring all code paths are exercised

RSpec.describe "Normalizer Mutation Killing" do
  describe Rubymap::Normalizer do
    let(:normalizer) { described_class.new }
    
    describe "#normalize" do
      it "returns empty result for nil input" do
        result = normalizer.normalize(nil)
        expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
        expect(result.classes).to eq([])
        expect(result.modules).to eq([])
        expect(result.methods).to eq([])
        expect(result.errors).to eq([])
      end

      it "returns empty result for empty hash input" do
        result = normalizer.normalize({})
        expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
        expect(result.classes).to eq([])
      end

      it "processes input with all symbol types" do
        data = {
          classes: [{ name: "User", location: { file: "user.rb", line: 1 } }],
          modules: [{ name: "Helpers", location: { file: "helpers.rb", line: 1 } }],
          methods: [{ name: "save", owner: "User", location: { file: "user.rb", line: 10 } }],
          method_calls: [{ method: "save", caller: "UserController" }]
        }
        
        result = normalizer.normalize(data)
        expect(result.classes.size).to eq(1)
        expect(result.modules.size).to eq(1)
        expect(result.methods.size).to eq(1)
        expect(result.method_calls.size).to eq(1)
      end

      it "includes all metadata in result" do
        result = normalizer.normalize({})
        expect(result.schema_version).to eq(1)
        expect(result.normalizer_version).to eq("1.0.0")
        expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "processes and validates all input data" do
        data = {
          classes: [
            { name: "", location: { file: "bad.rb", line: 1 } },  # Invalid name
            { name: "Good", location: { file: "good.rb", line: 1 } }
          ]
        }
        
        result = normalizer.normalize(data)
        expect(result.classes.size).to eq(1)  # Only valid class
        expect(result.errors.size).to be >= 1  # Error for invalid class
      end
    end

    describe "private methods" do
      describe "#create_result" do
        it "creates result with proper metadata" do
          result = normalizer.send(:create_result)
          expect(result.schema_version).to eq(1)
          expect(result.normalizer_version).to eq("1.0.0")
          
          # Verify UTC time format
          time = Time.parse(result.normalized_at)
          expect(time.utc?).to be true
          expect(result.normalized_at).to match(/\.\d{3}Z$/)  # Milliseconds included
        end
      end

      describe "#index_symbols" do
        it "indexes all classes and modules" do
          result = normalizer.send(:create_result)
          result.classes << double("class", symbol_id: "c1", fqname: "User")
          result.modules << double("module", symbol_id: "m1", fqname: "Helpers")
          
          index = normalizer.instance_variable_get(:@symbol_index)
          expect(index).to receive(:add).twice
          
          normalizer.send(:index_symbols, result)
        end

        it "handles empty result" do
          result = normalizer.send(:create_result)
          expect { normalizer.send(:index_symbols, result) }.not_to raise_error
        end
      end

      describe "#validate_data" do
        it "adds errors for invalid data" do
          data = { classes: [{ name: nil }] }
          errors = []
          
          normalizer.send(:validate_data, data, errors)
          expect(errors).not_to be_empty
        end

        it "passes valid data without errors" do
          data = { classes: [{ name: "User", location: { file: "user.rb", line: 1 } }] }
          errors = []
          
          normalizer.send(:validate_data, data, errors)
          expect(errors).to be_empty
        end
      end
    end
  end

  describe Rubymap::Normalizer::SymbolIndex do
    let(:index) { described_class.new }

    describe "#add" do
      it "adds symbol by id and fqname" do
        symbol = double("symbol", symbol_id: "123", fqname: "MyApp::User")
        index.add(symbol)
        
        expect(index.get_by_id("123")).to eq(symbol)
        expect(index.get_by_fqname("MyApp::User")).to eq(symbol)
      end

      it "handles symbols without fqname" do
        symbol = double("symbol", symbol_id: "123", fqname: nil)
        index.add(symbol)
        
        expect(index.get_by_id("123")).to eq(symbol)
        expect(index.get_by_fqname(nil)).to be_nil
      end

      it "overwrites existing symbols with same id" do
        symbol1 = double("symbol1", symbol_id: "123", fqname: "User")
        symbol2 = double("symbol2", symbol_id: "123", fqname: "User")
        
        index.add(symbol1)
        index.add(symbol2)
        
        expect(index.get_by_id("123")).to eq(symbol2)
      end
    end

    describe "#get_by_id" do
      it "returns nil for non-existent id" do
        expect(index.get_by_id("nonexistent")).to be_nil
      end

      it "returns correct symbol for existing id" do
        symbol = double("symbol", symbol_id: "123", fqname: "User")
        index.add(symbol)
        expect(index.get_by_id("123")).to eq(symbol)
      end
    end

    describe "#get_by_fqname" do
      it "returns nil for non-existent fqname" do
        expect(index.get_by_fqname("NonExistent")).to be_nil
      end

      it "returns correct symbol for existing fqname" do
        symbol = double("symbol", symbol_id: "123", fqname: "User")
        index.add(symbol)
        expect(index.get_by_fqname("User")).to eq(symbol)
      end
    end

    describe "#exists?" do
      it "returns false for non-existent id" do
        expect(index.exists?("nonexistent")).to be false
      end

      it "returns true for existing id" do
        symbol = double("symbol", symbol_id: "123", fqname: "User")
        index.add(symbol)
        expect(index.exists?("123")).to be true
      end
    end

    describe "#clear" do
      it "removes all symbols" do
        symbol1 = double("symbol1", symbol_id: "1", fqname: "User")
        symbol2 = double("symbol2", symbol_id: "2", fqname: "Post")
        
        index.add(symbol1)
        index.add(symbol2)
        index.clear
        
        expect(index.get_by_id("1")).to be_nil
        expect(index.get_by_id("2")).to be_nil
        expect(index.get_by_fqname("User")).to be_nil
        expect(index.get_by_fqname("Post")).to be_nil
      end
    end

    describe "#all_symbols" do
      it "returns empty array when no symbols" do
        expect(index.all_symbols).to eq([])
      end

      it "returns all added symbols" do
        symbol1 = double("symbol1", symbol_id: "1", fqname: "User")
        symbol2 = double("symbol2", symbol_id: "2", fqname: "Post")
        
        index.add(symbol1)
        index.add(symbol2)
        
        all = index.all_symbols
        expect(all).to include(symbol1, symbol2)
        expect(all.size).to eq(2)
      end
    end

    describe "#size" do
      it "returns 0 when empty" do
        expect(index.size).to eq(0)
      end

      it "returns correct count" do
        index.add(double(symbol_id: "1", fqname: "A"))
        index.add(double(symbol_id: "2", fqname: "B"))
        expect(index.size).to eq(2)
      end

      it "doesn't double count same id" do
        index.add(double(symbol_id: "1", fqname: "A"))
        index.add(double(symbol_id: "1", fqname: "B"))
        expect(index.size).to eq(1)
      end
    end
  end

  describe Rubymap::Normalizer::NormalizerRegistry do
    let(:registry) { described_class.new }

    describe "#register_processor" do
      it "registers processor for symbol type" do
        processor = double("processor")
        registry.register_processor(:custom, processor)
        expect(registry.get_processor(:custom)).to eq(processor)
      end

      it "overwrites existing processor" do
        processor1 = double("processor1")
        processor2 = double("processor2")
        
        registry.register_processor(:class, processor1)
        registry.register_processor(:class, processor2)
        
        expect(registry.get_processor(:class)).to eq(processor2)
      end
    end

    describe "#get_processor" do
      it "returns nil for unregistered type" do
        expect(registry.get_processor(:unknown)).to be_nil
      end

      it "returns default processors" do
        expect(registry.get_processor(:class)).to be_a(Rubymap::Normalizer::Processors::ClassProcessor)
        expect(registry.get_processor(:module)).to be_a(Rubymap::Normalizer::Processors::ModuleProcessor)
        expect(registry.get_processor(:method)).to be_a(Rubymap::Normalizer::Processors::MethodProcessor)
        expect(registry.get_processor(:method_call)).to be_a(Rubymap::Normalizer::Processors::MethodCallProcessor)
      end
    end

    describe "#register_resolver" do
      it "registers resolver" do
        resolver = double("resolver")
        registry.register_resolver(:custom, resolver)
        expect(registry.resolvers).to include(custom: resolver)
      end
    end

    describe "#register_normalizer" do
      it "registers normalizer" do
        normalizer = double("normalizer")
        registry.register_normalizer(:custom, normalizer)
        expect(registry.get_normalizer(:custom)).to eq(normalizer)
      end
    end

    describe "#get_normalizer" do
      it "returns nil for unregistered type" do
        expect(registry.get_normalizer(:unknown)).to be_nil
      end

      it "returns default normalizers" do
        expect(registry.get_normalizer(:name)).to be_a(Rubymap::Normalizer::Normalizers::NameNormalizer)
        expect(registry.get_normalizer(:visibility)).to be_a(Rubymap::Normalizer::Normalizers::VisibilityNormalizer)
        expect(registry.get_normalizer(:location)).to be_a(Rubymap::Normalizer::Normalizers::LocationNormalizer)
        expect(registry.get_normalizer(:parameter)).to be_a(Rubymap::Normalizer::Normalizers::ParameterNormalizer)
      end
    end
  end

  describe Rubymap::Normalizer::Calculators::ArityCalculator do
    let(:calculator) { described_class.new }

    describe "#calculate" do
      it "returns 0 for no parameters" do
        expect(calculator.calculate([])).to eq(0)
      end

      it "counts required parameters" do
        params = [
          { kind: "req", name: "a" },
          { kind: "req", name: "b" }
        ]
        expect(calculator.calculate(params)).to eq(2)
      end

      it "counts optional parameters as negative" do
        params = [
          { kind: "req", name: "a" },
          { kind: "opt", name: "b" }
        ]
        expect(calculator.calculate(params)).to eq(-2)
      end

      it "handles rest parameters" do
        params = [
          { kind: "req", name: "a" },
          { kind: "rest", name: "args" }
        ]
        expect(calculator.calculate(params)).to eq(-2)
      end

      it "handles keyword parameters" do
        params = [
          { kind: "keyreq", name: "a" },
          { kind: "keyopt", name: "b" }
        ]
        expect(calculator.calculate(params)).to eq(-1)
      end

      it "handles block parameters" do
        params = [
          { kind: "req", name: "a" },
          { kind: "block", name: "blk" }
        ]
        expect(calculator.calculate(params)).to eq(1)
      end

      it "handles complex parameter combinations" do
        params = [
          { kind: "req", name: "a" },
          { kind: "opt", name: "b" },
          { kind: "rest", name: "args" },
          { kind: "keyreq", name: "c" },
          { kind: "keyopt", name: "d" },
          { kind: "keyrest", name: "kwargs" },
          { kind: "block", name: "blk" }
        ]
        expect(calculator.calculate(params)).to eq(-2)
      end
    end
  end

  describe Rubymap::Normalizer::Calculators::ConfidenceCalculator do
    let(:calculator) { described_class.new }

    describe "#calculate" do
      it "returns 1.0 for complete data from reliable source" do
        symbol = {
          sources: ["rbs"],
          name: "User",
          location: { file: "user.rb", line: 1 },
          doc: "Documentation",
          visibility: "public"
        }
        expect(calculator.calculate(symbol)).to be_within(0.01).of(1.0)
      end

      it "returns lower confidence for missing fields" do
        symbol = {
          sources: ["static"],
          name: "User"
        }
        expect(calculator.calculate(symbol)).to be < 0.5
      end

      it "adjusts confidence based on source reliability" do
        symbol1 = { sources: ["rbs"], name: "User" }
        symbol2 = { sources: ["inferred"], name: "User" }
        
        expect(calculator.calculate(symbol1)).to be > calculator.calculate(symbol2)
      end

      it "considers multiple sources" do
        symbol1 = { sources: ["static"], name: "User" }
        symbol2 = { sources: ["static", "runtime"], name: "User" }
        
        expect(calculator.calculate(symbol2)).to be > calculator.calculate(symbol1)
      end

      it "handles nil sources" do
        symbol = { name: "User" }
        expect(calculator.calculate(symbol)).to be >= 0.0
        expect(calculator.calculate(symbol)).to be <= 1.0
      end

      it "handles empty sources" do
        symbol = { sources: [], name: "User" }
        expect(calculator.calculate(symbol)).to be >= 0.0
        expect(calculator.calculate(symbol)).to be <= 1.0
      end
    end
  end
end