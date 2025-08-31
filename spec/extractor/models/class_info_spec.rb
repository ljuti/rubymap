# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::ClassInfo do
  describe "#to_h" do
    let(:location) { double("location") }

    before do
      allow(Rubymap::Extractor::LocationConverter).to receive(:to_h).with(location).and_return({line: 10})
    end

    it "includes all fields when all are present" do
      info = described_class.new(
        name: "User",
        type: "class",
        superclass: "ApplicationRecord",
        location: location,
        doc: "User model",
        namespace: "Models",
        rubymap: {custom: "data"}
      )

      result = info.to_h
      expect(result).to eq({
        name: "User",
        type: "class",
        superclass: "ApplicationRecord",
        location: {line: 10},
        doc: "User model",
        namespace: "Models",
        rubymap: {custom: "data"}
      })
    end

    it "excludes nil optional fields" do
      info = described_class.new(name: "User")

      allow(Rubymap::Extractor::LocationConverter).to receive(:to_h).with(nil).and_return(nil)

      result = info.to_h
      expect(result).to eq({
        name: "User",
        type: "class"
      })
    end

    it "preserves false values" do
      info = described_class.new(
        name: false,
        type: false,
        superclass: false,
        location: false,
        doc: false,
        namespace: false,
        rubymap: false
      )

      allow(Rubymap::Extractor::LocationConverter).to receive(:to_h).with(false).and_return(false)

      result = info.to_h
      expect(result).to eq({
        name: false,
        type: false,
        superclass: false,
        location: false,
        doc: false,
        namespace: false,
        rubymap: false
      })
    end

    it "uses LocationConverter for location field" do
      info = described_class.new(
        name: "User",
        type: "class",
        location: location
      )

      expect(Rubymap::Extractor::LocationConverter).to receive(:to_h).with(location).and_return({converted: true})

      result = info.to_h
      expect(result[:location]).to eq({converted: true})
    end
  end
end
