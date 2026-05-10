# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::MethodBodyResult do
  describe "#initialize" do
    it "initializes with default empty values" do
      result = described_class.new
      expect(result.calls).to eq([])
      expect(result.branches).to eq(0)
      expect(result.loops).to eq(0)
      expect(result.conditionals).to eq(0)
      expect(result.body_lines).to eq(0)
    end

    it "accepts custom values" do
      calls = [{receiver: nil, method: "puts", arguments: [], has_block: false}]
      result = described_class.new(
        calls: calls,
        branches: 3,
        loops: 2,
        conditionals: 4,
        body_lines: 10
      )
      expect(result.calls).to eq(calls)
      expect(result.branches).to eq(3)
      expect(result.loops).to eq(2)
      expect(result.conditionals).to eq(4)
      expect(result.body_lines).to eq(10)
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields" do
      result = described_class.new
      hash = result.to_h
      expect(hash).to be_a(Hash)
      expect(hash.keys).to match_array(%i[calls branches loops conditionals body_lines])
    end

    it "includes populated calls" do
      calls = [{receiver: ["Rails", "logger"], method: "info", arguments: [], has_block: false}]
      result = described_class.new(calls: calls, body_lines: 5)
      hash = result.to_h
      expect(hash[:calls]).to eq(calls)
      expect(hash[:body_lines]).to eq(5)
    end
  end
end
