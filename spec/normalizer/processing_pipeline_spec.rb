# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Normalizer::ProcessingPipeline do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { described_class.new(container) }

  describe "#execute" do
    it "processes empty hash input" do
      result = pipeline.execute({})
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.classes).to eq([])
      expect(result.modules).to eq([])
      expect(result.methods).to eq([])
    end

    it "processes nil input" do
      result = pipeline.execute(nil)
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.classes).to eq([])
      expect(result.errors).to eq([])
    end

    it "processes string input as invalid" do
      result = pipeline.execute("invalid")
      expect(result.classes).to eq([])
      expect(result.modules).to eq([])
    end

    it "processes array input as invalid" do
      result = pipeline.execute([1, 2, 3])
      expect(result.classes).to eq([])
      expect(result.modules).to eq([])
    end

    it "processes Extractor::Result objects" do
      extractor_result = Rubymap::Extractor::Result.new
      extractor_result.file_path = "test.rb"
      extractor_result.classes << Rubymap::Extractor::ClassInfo.new(
        name: "TestClass",
        namespace: []
      )
      
      result = pipeline.execute(extractor_result)
      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("TestClass")
    end

    it "processes hash with all symbol types" do
      data = {
        classes: [{name: "User", location: {file: "user.rb", line: 1}}],
        modules: [{name: "Helper", location: {file: "helper.rb", line: 1}}],
        methods: [{name: "save", owner: "User", location: {file: "user.rb", line: 10}}],
        method_calls: [{from: "User#save", to: "DB#write"}],
        mixins: [{module: "Helper", target: "User", type: "include"}]
      }
      
      result = pipeline.execute(data)
      expect(result.classes.size).to eq(1)
      expect(result.modules.size).to eq(1)
      expect(result.methods.size).to eq(1)
    end
  end

  describe "#process_symbols" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    it "handles nil input" do
      pipeline.send(:process_symbols, nil, result, errors)
      expect(result.classes).to eq([])
    end

    it "handles hash input" do
      data = {classes: [{name: "Test"}]}
      pipeline.send(:process_symbols, data, result, errors)
      expect(result.classes.size).to eq(1)
    end

    it "handles Extractor::Result input" do
      extractor_result = Rubymap::Extractor::Result.new
      extractor_result.file_path = "test.rb"
      extractor_result.classes << Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])
      
      pipeline.send(:process_symbols, extractor_result, result, errors)
      expect(result.classes.size).to eq(1)
    end

    it "handles invalid input types" do
      pipeline.send(:process_symbols, "invalid", result, errors)
      expect(result.classes).to eq([])
      
      pipeline.send(:process_symbols, 123, result, errors)
      expect(result.classes).to eq([])
      
      pipeline.send(:process_symbols, [1, 2, 3], result, errors)
      expect(result.classes).to eq([])
    end
  end

  describe "#extract_symbol_data" do
    it "returns empty data for nil input" do
      data = pipeline.send(:extract_symbol_data, nil)
      expect(data).to eq({
        classes: [],
        modules: [],
        methods: [],
        method_calls: [],
        mixins: []
      })
    end

    it "returns empty data for invalid input types" do
      data = pipeline.send(:extract_symbol_data, "string")
      expect(data[:classes]).to eq([])
      
      data = pipeline.send(:extract_symbol_data, 123)
      expect(data[:classes]).to eq([])
      
      data = pipeline.send(:extract_symbol_data, [])
      expect(data[:classes]).to eq([])
    end

    it "extracts from hash correctly" do
      input = {
        classes: [{name: "Test"}],
        modules: [{name: "Helper"}]
      }
      
      data = pipeline.send(:extract_symbol_data, input)
      expect(data[:classes]).to eq([{name: "Test"}])
      expect(data[:modules]).to eq([{name: "Helper"}])
      expect(data[:methods]).to eq([])
    end

    it "extracts from Extractor::Result correctly" do
      extractor_result = Rubymap::Extractor::Result.new
      extractor_result.file_path = "test.rb"
      class_info = Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])
      extractor_result.classes << class_info
      
      data = pipeline.send(:extract_symbol_data, extractor_result)
      expect(data[:classes].size).to eq(1)
      expect(data[:classes].first[:name]).to eq("Test")
    end
  end

  describe "#extractor_result?" do
    it "returns true for Extractor::Result objects" do
      extractor_result = Rubymap::Extractor::Result.new
      expect(pipeline.send(:extractor_result?, extractor_result)).to be true
    end

    it "returns false for hashes" do
      expect(pipeline.send(:extractor_result?, {})).to be false
    end

    it "returns false for nil" do
      expect(pipeline.send(:extractor_result?, nil)).to be false
    end

    it "returns false for objects without required methods" do
      obj = double("incomplete", classes: [])
      expect(pipeline.send(:extractor_result?, obj)).to be false
    end

    it "returns true for objects with classes and modules methods" do
      obj = double("complete", classes: [], modules: [])
      expect(pipeline.send(:extractor_result?, obj)).to be true
    end
  end

  describe "#convert_to_hashes" do
    it "returns empty array for empty input" do
      result = pipeline.send(:convert_to_hashes, [])
      expect(result).to eq([])
    end

    it "returns hashes unchanged" do
      hashes = [{name: "Test"}, {name: "Test2"}]
      result = pipeline.send(:convert_to_hashes, hashes)
      expect(result).to eq(hashes)
    end

    it "converts objects with to_h method" do
      obj1 = double("obj1", to_h: {name: "Test1"})
      obj2 = double("obj2", to_h: {name: "Test2"})
      
      result = pipeline.send(:convert_to_hashes, [obj1, obj2])
      expect(result).to eq([{name: "Test1"}, {name: "Test2"}])
    end

    it "handles mixed array with first element as hash" do
      items = [{name: "Hash"}, double("obj", to_h: {name: "Object"})]
      result = pipeline.send(:convert_to_hashes, items)
      expect(result).to eq(items) # Returns unchanged when first is hash
    end
  end

  describe "#extract_from_hash" do
    it "extracts all symbol types" do
      data = {
        classes: [{name: "A"}],
        modules: [{name: "B"}],
        methods: [{name: "C"}],
        method_calls: [{from: "D", to: "E"}],
        mixins: [{module: "F"}]
      }
      
      result = pipeline.send(:extract_from_hash, data)
      expect(result[:classes]).to eq([{name: "A"}])
      expect(result[:modules]).to eq([{name: "B"}])
      expect(result[:methods]).to eq([{name: "C"}])
      expect(result[:method_calls]).to eq([{from: "D", to: "E"}])
      expect(result[:mixins]).to eq([{module: "F"}])
    end

    it "provides empty arrays for missing keys" do
      result = pipeline.send(:extract_from_hash, {})
      expect(result[:classes]).to eq([])
      expect(result[:modules]).to eq([])
      expect(result[:methods]).to eq([])
      expect(result[:method_calls]).to eq([])
      expect(result[:mixins]).to eq([])
    end

    it "handles nil values" do
      data = {
        classes: nil,
        modules: nil,
        methods: nil,
        method_calls: nil,
        mixins: nil
      }
      
      result = pipeline.send(:extract_from_hash, data)
      expect(result[:classes]).to eq([])
      expect(result[:modules]).to eq([])
      expect(result[:methods]).to eq([])
      expect(result[:method_calls]).to eq([])
      expect(result[:mixins]).to eq([])
    end
  end

  describe "#extract_from_result" do
    it "converts Extractor::Result to hash format" do
      extractor_result = Rubymap::Extractor::Result.new
      extractor_result.file_path = "test.rb"
      
      class_info = Rubymap::Extractor::ClassInfo.new(name: "TestClass", namespace: [])
      module_info = Rubymap::Extractor::ModuleInfo.new(name: "TestModule", namespace: [])
      method_info = Rubymap::Extractor::MethodInfo.new(name: "test_method", owner: "TestClass")
      mixin_info = Rubymap::Extractor::MixinInfo.new(type: "include", module_name: "TestModule", target: "TestClass")
      
      extractor_result.classes << class_info
      extractor_result.modules << module_info  
      extractor_result.methods << method_info
      extractor_result.mixins << mixin_info
      
      data = pipeline.send(:extract_from_result, extractor_result)
      
      expect(data[:classes].size).to eq(1)
      expect(data[:classes].first[:name]).to eq("TestClass")
      
      expect(data[:modules].size).to eq(1)
      expect(data[:modules].first[:name]).to eq("TestModule")
      
      expect(data[:methods].size).to eq(1)
      expect(data[:methods].first[:name]).to eq("test_method")
      
      expect(data[:method_calls]).to eq([]) # Result doesn't have method_calls
      
      expect(data[:mixins].size).to eq(1)
      expect(data[:mixins].first[:module]).to eq("TestModule")
    end

    it "handles nil collections" do
      extractor_result = double("result", classes: nil, modules: nil, methods: nil, mixins: nil)
      
      data = pipeline.send(:extract_from_result, extractor_result)
      
      expect(data[:classes]).to eq([])
      expect(data[:modules]).to eq([])
      expect(data[:methods]).to eq([])
      expect(data[:method_calls]).to eq([])
      expect(data[:mixins]).to eq([])
    end
  end

  describe "#create_empty_symbol_data" do
    it "returns hash with all empty arrays" do
      data = pipeline.send(:create_empty_symbol_data)
      
      expect(data).to be_a(Hash)
      expect(data[:classes]).to eq([])
      expect(data[:modules]).to eq([])
      expect(data[:methods]).to eq([])
      expect(data[:method_calls]).to eq([])
      expect(data[:mixins]).to eq([])
    end
  end

  describe "#resolve_relationships" do
    it "executes all resolvers in order" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      # Add test data
      parent = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Parent", fqname: "Parent")
      child = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Child", fqname: "Child", superclass: "Parent")
      result.classes << parent
      result.classes << child
      
      pipeline.send(:resolve_relationships, result)
      
      # Verify relationships were resolved
      expect(child.inheritance_chain).to include("Parent")
    end
  end

  describe "#deduplicate_symbols" do
    it "deduplicates symbols in result" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      # Add duplicate class with proper provenance
      provenance = Rubymap::Normalizer::Provenance.new(
        sources: ["test.rb"]
      )
      
      class1 = Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "Test", 
        fqname: "Test",
        provenance: provenance
      )
      class2 = Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "Test", 
        fqname: "Test",
        provenance: provenance
      )
      result.classes << class1
      result.classes << class2
      
      pipeline.send(:deduplicate_symbols, result)
      
      expect(result.classes.size).to eq(1)
    end
  end

  describe "#format_output" do
    it "formats the result" do
      result = Rubymap::Normalizer::NormalizedResult.new
      result.classes << Rubymap::Normalizer::CoreNormalizedClass.new(name: "Test", fqname: "Test")
      
      pipeline.send(:format_output, result)
      
      # Verify formatting was applied
      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("Test")
    end
  end

  describe "#index_symbols" do
    it "indexes classes and modules" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      class1 = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Test", fqname: "Test")
      module1 = Rubymap::Normalizer::CoreNormalizedModule.new(name: "Helper", fqname: "Helper")
      
      result.classes << class1
      result.modules << module1
      
      pipeline.send(:index_symbols, result)
      
      symbol_index = container.get(:symbol_index)
      expect(symbol_index.find("Test")).to eq(class1)
      expect(symbol_index.find("Helper")).to eq(module1)
    end
  end
end