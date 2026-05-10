# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SymbolData" do
  # SymbolData is defined in lib/rubymap/symbol_data.rb

  let(:hash) do
    {
      fqname: "MyApp::User",
      type: "class",
      superclass: "ApplicationRecord",
      file: "app/models/user.rb",
      line: 5,
      instance_methods: %w[save find],
      class_methods: %w[create],
      dependencies: %w[EmailService],
      mixins: [{module: "Authenticatable", type: "include"}],
      documentation: "User model",
      metrics: {complexity_score: 4.5, test_coverage: 85.0},
      namespace: ["MyApp"]
    }
  end

  # Test the interface using the SymbolData wrapper.
  subject(:data) { Rubymap::SymbolData.new(hash) }

  describe "named accessors (desired interface)" do
    it "exposes fqname" do
      expect(data.fqname).to eq("MyApp::User")
    end

    it "exposes type" do
      expect(data.type).to eq("class")
    end

    it "exposes superclass" do
      expect(data.superclass).to eq("ApplicationRecord")
    end

    it "exposes file" do
      expect(data.file).to eq("app/models/user.rb")
    end

    it "exposes line" do
      expect(data.line).to eq(5)
    end

    it "exposes instance_methods" do
      expect(data.instance_methods).to eq(%w[save find])
    end

    it "exposes class_methods" do
      expect(data.class_methods).to eq(%w[create])
    end

    it "exposes dependencies" do
      expect(data.dependencies).to eq(%w[EmailService])
    end

    it "exposes mixins" do
      expect(data.mixins).to eq([{module: "Authenticatable", type: "include"}])
    end

    it "exposes documentation" do
      expect(data.documentation).to eq("User model")
    end

    it "provides complexity score" do
      expect(data.complexity_score).to eq(4.5)
    end

    it "returns empty array for nil instance_methods" do
      data_without_methods = Rubymap::SymbolData.new(fqname: "Empty")
      expect(data_without_methods.instance_methods).to eq([])
    end

    it "returns empty array for nil class_methods" do
      data_without_methods = Rubymap::SymbolData.new(fqname: "Empty")
      expect(data_without_methods.class_methods).to eq([])
    end
  end

  describe "nil safety" do
    it "handles nil fqname gracefully" do
      expect(Rubymap::SymbolData.new(fqname: nil).fqname).to be_nil
    end

    it "handles missing metrics" do
      expect(Rubymap::SymbolData.new(fqname: "X").complexity_score).to be_nil
    end
  end
end
