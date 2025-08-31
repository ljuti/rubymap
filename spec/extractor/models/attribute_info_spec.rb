# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::AttributeInfo do
  describe "#to_h" do
    before do
      allow(Rubymap::Extractor::LocationConverter).to receive(:to_h).with(anything) do |arg|
        arg.nil? ? nil : {converted: arg}
      end
    end

    it "includes all fields when all are present" do
      info = described_class.new(
        name: "name",
        type: "reader",
        location: "file.rb:10",
        namespace: "MyClass"
      )

      result = info.to_h
      expect(result).to eq({
        name: "name",
        type: "reader",
        location: {converted: "file.rb:10"},
        namespace: "MyClass"
      })
    end

    it "excludes nil optional fields" do
      info = described_class.new(
        name: "name",
        type: "reader"
      )

      result = info.to_h
      expect(result).to eq({
        name: "name",
        type: "reader"
      })
    end

    it "preserves false values" do
      info = described_class.new(
        name: false,
        type: false,
        location: false,
        namespace: false
      )

      result = info.to_h
      expect(result).to eq({
        name: false,
        type: false,
        location: {converted: false},
        namespace: false
      })
    end
  end

  describe "#readable?" do
    it "returns true for reader" do
      info = described_class.new(name: "x", type: "reader")
      expect(info.readable?).to be true
    end

    it "returns true for accessor" do
      info = described_class.new(name: "x", type: "accessor")
      expect(info.readable?).to be true
    end

    it "returns false for writer" do
      info = described_class.new(name: "x", type: "writer")
      expect(info.readable?).to be false
    end

    it "returns false for other types" do
      info = described_class.new(name: "x", type: "other")
      expect(info.readable?).to be false
    end
  end

  describe "#writable?" do
    it "returns true for writer" do
      info = described_class.new(name: "x", type: "writer")
      expect(info.writable?).to be true
    end

    it "returns true for accessor" do
      info = described_class.new(name: "x", type: "accessor")
      expect(info.writable?).to be true
    end

    it "returns false for reader" do
      info = described_class.new(name: "x", type: "reader")
      expect(info.writable?).to be false
    end

    it "returns false for other types" do
      info = described_class.new(name: "x", type: "other")
      expect(info.writable?).to be false
    end
  end
end
