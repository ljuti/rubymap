# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::MethodInfo do
  describe "#initialize" do
    it "sets name as the only required parameter" do
      info = described_class.new(name: "my_method")
      expect(info.name).to eq("my_method")
    end

    it "defaults visibility to public" do
      info = described_class.new(name: "test")
      expect(info.visibility).to eq("public")
    end

    it "defaults receiver_type to instance" do
      info = described_class.new(name: "test")
      expect(info.receiver_type).to eq("instance")
    end

    it "defaults params to empty array" do
      info = described_class.new(name: "test")
      expect(info.params).to eq([])
    end

    it "defaults calls_made to empty array" do
      info = described_class.new(name: "test")
      expect(info.calls_made).to eq([])
    end

    it "defaults branches to 0" do
      info = described_class.new(name: "test")
      expect(info.branches).to eq(0)
    end

    it "defaults loops to 0" do
      info = described_class.new(name: "test")
      expect(info.loops).to eq(0)
    end

    it "defaults conditionals to 0" do
      info = described_class.new(name: "test")
      expect(info.conditionals).to eq(0)
    end

    it "defaults body_lines to 0" do
      info = described_class.new(name: "test")
      expect(info.body_lines).to eq(0)
    end

    it "accepts custom calls_made" do
      calls = [{receiver: nil, method: "puts", arguments: [], has_block: false}]
      info = described_class.new(name: "test", calls_made: calls)
      expect(info.calls_made).to eq(calls)
    end

    it "accepts custom branches, loops, conditionals, and body_lines" do
      info = described_class.new(
        name: "test",
        branches: 5,
        loops: 3,
        conditionals: 2,
        body_lines: 15
      )
      expect(info.branches).to eq(5)
      expect(info.loops).to eq(3)
      expect(info.conditionals).to eq(2)
      expect(info.body_lines).to eq(15)
    end

    it "defaults doc to nil" do
      info = described_class.new(name: "test")
      expect(info.doc).to be_nil
    end

    it "defaults namespace to nil" do
      info = described_class.new(name: "test")
      expect(info.namespace).to be_nil
    end

    it "defaults owner to nil" do
      info = described_class.new(name: "test")
      expect(info.owner).to be_nil
    end

    it "defaults rubymap to nil" do
      info = described_class.new(name: "test")
      expect(info.rubymap).to be_nil
    end
  end

  describe "#to_h" do
    it "includes calls_made key even when empty" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash).to have_key(:calls_made)
      expect(hash[:calls_made]).to eq([])
    end

    it "includes branches key" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash).to have_key(:branches)
      expect(hash[:branches]).to eq(0)
    end

    it "includes loops key" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash).to have_key(:loops)
      expect(hash[:loops]).to eq(0)
    end

    it "includes conditionals key" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash).to have_key(:conditionals)
      expect(hash[:conditionals]).to eq(0)
    end

    it "includes body_lines key" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash).to have_key(:body_lines)
      expect(hash[:body_lines]).to eq(0)
    end

    it "serializes calls_made with populated data" do
      calls = [
        {receiver: ["Rails", "logger"], method: "info", arguments: [{type: :string, value: "hello"}], has_block: false},
        {receiver: nil, method: "save!", arguments: [], has_block: false}
      ]
      info = described_class.new(
        name: "my_method",
        calls_made: calls,
        branches: 2,
        loops: 1,
        conditionals: 1,
        body_lines: 10
      )
      hash = info.to_h
      expect(hash[:calls_made]).to eq(calls)
      expect(hash[:calls_made].size).to eq(2)
      expect(hash[:branches]).to eq(2)
      expect(hash[:loops]).to eq(1)
      expect(hash[:conditionals]).to eq(1)
      expect(hash[:body_lines]).to eq(10)
    end

    it "includes all required keys" do
      info = described_class.new(name: "test")
      hash = info.to_h
      expect(hash.keys).to include(
        :name, :visibility, :receiver_type, :parameters,
        :calls_made, :branches, :loops, :conditionals, :body_lines
      )
    end

    it "excludes nil values via compact" do
      info = described_class.new(name: "test", doc: nil)
      hash = info.to_h
      expect(hash).not_to have_key(:doc)
    end
  end

  describe "#full_name" do
    context "with instance methods" do
      it "uses # separator for instance methods with namespace" do
        info = described_class.new(name: "calculate", namespace: "Calculator")
        expect(info.full_name).to eq("Calculator#calculate")
      end

      it "uses # separator for instance methods with owner" do
        info = described_class.new(name: "calculate", owner: "Calc")
        expect(info.full_name).to eq("Calc#calculate")
      end
    end

    context "with class methods" do
      it "uses . separator" do
        info = described_class.new(name: "create", receiver_type: "class", namespace: "User")
        expect(info.full_name).to eq("User.create")
      end
    end
  end

  describe "#scope" do
    it "returns class for class methods" do
      info = described_class.new(name: "test", receiver_type: "class")
      expect(info.scope).to eq("class")
    end

    it "returns instance for instance methods" do
      info = described_class.new(name: "test", receiver_type: "instance")
      expect(info.scope).to eq("instance")
    end
  end
end
