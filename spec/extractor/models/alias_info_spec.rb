# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::AliasInfo do
  describe "#to_h" do
    it "includes all fields when all are present" do
      info = described_class.new(
        new_name: "new_method",
        original_name: "old_method",
        location: "file.rb:10",
        namespace: "MyClass"
      )
      
      result = info.to_h
      expect(result).to eq({
        new_name: "new_method",
        original_name: "old_method",
        location: "file.rb:10",
        namespace: "MyClass"
      })
    end
    
    it "excludes nil location" do
      info = described_class.new(
        new_name: "new_method",
        original_name: "old_method",
        location: nil,
        namespace: "MyClass"
      )
      
      result = info.to_h
      expect(result).to eq({
        new_name: "new_method",
        original_name: "old_method",
        namespace: "MyClass"
      })
    end
    
    it "excludes nil namespace" do
      info = described_class.new(
        new_name: "new_method",
        original_name: "old_method",
        location: "file.rb:10",
        namespace: nil
      )
      
      result = info.to_h
      expect(result).to eq({
        new_name: "new_method",
        original_name: "old_method",
        location: "file.rb:10"
      })
    end
    
    it "excludes both nil location and namespace" do
      info = described_class.new(
        new_name: "new_method",
        original_name: "old_method"
      )
      
      result = info.to_h
      expect(result).to eq({
        new_name: "new_method",
        original_name: "old_method"
      })
    end
    
    it "preserves false values" do
      info = described_class.new(
        new_name: false,
        original_name: false,
        location: false,
        namespace: false
      )
      
      result = info.to_h
      expect(result).to eq({
        new_name: false,
        original_name: false,
        location: false,
        namespace: false
      })
    end
  end
end