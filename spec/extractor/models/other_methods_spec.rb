# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Model other methods" do
  describe Rubymap::Extractor::ConstantInfo do
    describe "#type (inferred)" do
      it "infers 'unknown' when value is nil" do
        info = described_class.new(name: "X", value: nil)
        expect(info.type).to eq("unknown")
      end

      it "infers 'integer' for integer values" do
        info = described_class.new(name: "X", value: "42")
        expect(info.type).to eq("integer")
      end

      it "infers 'integer' for zero" do
        info = described_class.new(name: "X", value: "0")
        expect(info.type).to eq("integer")
      end

      it "infers 'float' for decimal values" do
        info = described_class.new(name: "X", value: "3.14")
        expect(info.type).to eq("float")
      end

      it "infers 'float' for zero float" do
        info = described_class.new(name: "X", value: "0.0")
        expect(info.type).to eq("float")
      end

      it "infers 'string' for double-quoted strings" do
        info = described_class.new(name: "X", value: '"hello"')
        expect(info.type).to eq("string")
      end

      it "infers 'string' for single-quoted strings" do
        info = described_class.new(name: "X", value: "'hello'")
        expect(info.type).to eq("string")
      end

      it "infers 'symbol' for symbols" do
        info = described_class.new(name: "X", value: ":symbol")
        expect(info.type).to eq("symbol")
      end

      it "infers 'array' for array literals" do
        info = described_class.new(name: "X", value: "[1, 2, 3]")
        expect(info.type).to eq("array")
      end

      it "infers 'array' for empty arrays" do
        info = described_class.new(name: "X", value: "[]")
        expect(info.type).to eq("array")
      end

      it "infers 'hash' for hash literals" do
        info = described_class.new(name: "X", value: "{a: 1}")
        expect(info.type).to eq("hash")
      end

      it "infers 'hash' for empty hashes" do
        info = described_class.new(name: "X", value: "{}")
        expect(info.type).to eq("hash")
      end

      it "infers 'boolean' for true" do
        info = described_class.new(name: "X", value: "true")
        expect(info.type).to eq("boolean")
      end

      it "infers 'boolean' for false" do
        info = described_class.new(name: "X", value: "false")
        expect(info.type).to eq("boolean")
      end

      it "infers 'constant_ref' for constant references" do
        info = described_class.new(name: "X", value: "ANOTHER_CONST")
        expect(info.type).to eq("constant_ref")
      end

      it "infers 'constant_ref' for capitalized names" do
        info = described_class.new(name: "X", value: "File.read('file')")
        expect(info.type).to eq("constant_ref")
      end

      it "infers 'expression' for complex expressions" do
        info = described_class.new(name: "X", value: "1 + 2")
        expect(info.type).to eq("expression")
      end

      it "infers 'expression' for empty string value" do
        info = described_class.new(name: "X", value: "")
        expect(info.type).to eq("expression")
      end

      it "infers 'expression' for partial patterns" do
        info = described_class.new(name: "X", value: "42.not_a_float")
        expect(info.type).to eq("expression")
      end

      it "infers 'integer' even with leading zeros" do
        info = described_class.new(name: "X", value: "042")
        expect(info.type).to eq("integer")
      end

      it "infers 'nil' for nil value" do
        info = described_class.new(name: "X", value: "nil")
        expect(info.type).to eq("nil")
      end
    end
  end

  describe Rubymap::Extractor::DependencyInfo do
    describe "#internal?" do
      it "returns true for relative paths" do
        info = described_class.new(type: "require_relative", path: "./lib/foo")
        expect(info.internal?).to be true
      end

      it "returns false for external gems" do
        info = described_class.new(type: "require", path: "json")
        expect(info.internal?).to be false
      end

      it "returns false for absolute paths with require" do
        info = described_class.new(type: "require", path: "/app/lib/foo")
        expect(info.internal?).to be false
      end
    end

    describe "#external?" do
      it "returns false for relative paths by default" do
        info = described_class.new(type: "require_relative", path: "../lib/foo")
        expect(info.external?).to be false
      end

      it "returns true for simple module names" do
        info = described_class.new(type: "require", path: "json")
        expect(info.external?).to be true
      end

      it "returns true for gems with nested paths" do
        info = described_class.new(type: "require", path: "rails/all")
        expect(info.external?).to be true
      end

      it "returns false for relative paths with require" do
        info = described_class.new(type: "require", path: "./lib/foo")
        expect(info.external?).to be false
      end
    end
  end
end
