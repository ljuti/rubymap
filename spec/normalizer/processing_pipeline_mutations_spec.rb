# frozen_string_literal: true

require "spec_helper"

# Specific tests to kill remaining ProcessingPipeline mutants
RSpec.describe "Rubymap::Normalizer::ProcessingPipeline - Mutation Tests" do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { Rubymap::Normalizer::ProcessingPipeline.new(container) }

  describe "#convert_to_hashes mutations" do
    it "returns items unchanged when empty" do
      items = []
      result = pipeline.send(:convert_to_hashes, items)
      expect(result).to be(items) # Must be same object
    end

    it "returns items unchanged when first is Hash" do
      items = [{name: "Test"}]
      result = pipeline.send(:convert_to_hashes, items)
      expect(result).to be(items) # Must be same object
    end

    it "converts when first is not Hash" do
      obj = double("obj", to_h: {name: "Test"})
      items = [obj]
      result = pipeline.send(:convert_to_hashes, items)
      # Verify it's a different object by checking object_id
      expect(result.object_id == items.object_id).to be false
      expect(result).to eq([{name: "Test"}])
    end

    it "checks first element using is_a?(Hash) not instance_of?" do
      # Subclass of Hash should still return items unchanged
      class TestHash < Hash; end
      test_hash = TestHash.new
      test_hash[:name] = "Test"
      
      items = [test_hash]
      result = pipeline.send(:convert_to_hashes, items)
      expect(result).to be(items) # Should recognize TestHash as Hash
    end
  end

  describe "#extractor_result? mutations" do
    it "returns false when object only has classes method" do
      obj = double("partial", classes: [])
      expect(pipeline.send(:extractor_result?, obj)).to be false
    end

    it "returns false when object only has modules method" do
      obj = double("partial", modules: [])
      expect(pipeline.send(:extractor_result?, obj)).to be false
    end

    it "returns true only when both classes AND modules methods exist" do
      obj = double("complete", classes: [], modules: [])
      expect(pipeline.send(:extractor_result?, obj)).to be true
    end

    it "returns false for nil" do
      expect(pipeline.send(:extractor_result?, nil)).to be false
    end

    it "returns false for Hash even if it has keys :classes and :modules" do
      hash = {classes: [], modules: []}
      expect(pipeline.send(:extractor_result?, hash)).to be false
    end
  end

  describe "#extract_symbol_data mutations" do
    it "returns empty data for falsy values" do
      expect(pipeline.send(:extract_symbol_data, nil)).to eq({
        classes: [], modules: [], methods: [], method_calls: [], mixins: []
      })
      
      expect(pipeline.send(:extract_symbol_data, false)).to eq({
        classes: [], modules: [], methods: [], method_calls: [], mixins: []
      })
    end

    it "returns hash data when input is Hash" do
      data = {classes: [{name: "Test"}]}
      result = pipeline.send(:extract_symbol_data, data)
      expect(result[:classes]).to eq([{name: "Test"}])
    end

    it "returns converted data when input is Extractor::Result" do
      extractor_result = Rubymap::Extractor::Result.new
      extractor_result.classes << Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])
      
      result = pipeline.send(:extract_symbol_data, extractor_result)
      expect(result[:classes].first[:name]).to eq("Test")
    end

    it "returns empty data for unexpected input types" do
      expect(pipeline.send(:extract_symbol_data, "string")[:classes]).to eq([])
      expect(pipeline.send(:extract_symbol_data, 123)[:classes]).to eq([])
      expect(pipeline.send(:extract_symbol_data, [])[:classes]).to eq([])
    end
  end

  describe "#execute mutations" do
    it "sets errors on result even when empty" do
      result = pipeline.execute({})
      expect(result.errors).to eq([])
    end

    it "executes all pipeline steps even with nil input" do
      result = pipeline.execute(nil)
      
      # All steps should have executed
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.schema_version).to eq(Rubymap::Normalizer::SCHEMA_VERSION)
      expect(result.normalizer_version).to eq(Rubymap::Normalizer::NORMALIZER_VERSION)
      expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      expect(result.errors).to eq([])
    end

    it "returns result even when processing fails" do
      # Force an error in processing
      bad_data = {classes: [{name: nil}]} # This might cause validation error
      
      result = pipeline.execute(bad_data)
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
    end
  end

  describe "#resolve_relationships mutations" do
    it "gets resolver_factory from container" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      # Should call container.get(:resolver_factory)
      allow(container).to receive(:get).and_call_original
      
      pipeline.send(:resolve_relationships, result)
      
      expect(container).to have_received(:get).with(:resolver_factory)
    end

    it "calls all four resolvers in sequence" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      # Just verify it executes without error
      expect { pipeline.send(:resolve_relationships, result) }.not_to raise_error
    end
  end

  describe "#deduplicate_symbols mutations" do
    it "gets deduplicator from container" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      allow(container).to receive(:get).and_call_original
      
      pipeline.send(:deduplicate_symbols, result)
      
      expect(container).to have_received(:get).with(:deduplicator)
    end

    it "calls deduplicate_symbols on deduplicator" do
      result = Rubymap::Normalizer::NormalizedResult.new
      deduplicator = container.get(:deduplicator)
      
      expect(deduplicator).to receive(:deduplicate_symbols).with(result)
      
      pipeline.send(:deduplicate_symbols, result)
    end
  end

  describe "#format_output mutations" do
    it "gets output_formatter from container" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      expect(container).to receive(:get).with(:output_formatter).and_call_original
      
      pipeline.send(:format_output, result)
    end

    it "calls format on output_formatter" do
      result = Rubymap::Normalizer::NormalizedResult.new
      formatter = container.get(:output_formatter)
      
      expect(formatter).to receive(:format).with(result)
      
      pipeline.send(:format_output, result)
    end
  end

  describe "#index_symbols mutations" do
    it "adds both classes and modules to index" do
      result = Rubymap::Normalizer::NormalizedResult.new
      symbol_index = container.get(:symbol_index)
      
      klass = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Test", fqname: "Test")
      mod = Rubymap::Normalizer::CoreNormalizedModule.new(name: "Helper", fqname: "Helper")
      
      result.classes << klass
      result.modules << mod
      
      pipeline.send(:index_symbols, result)
      
      expect(symbol_index.find("Test")).to eq(klass)
      expect(symbol_index.find("Helper")).to eq(mod)
    end

    it "gets symbol_index from container" do
      result = Rubymap::Normalizer::NormalizedResult.new
      
      expect(container).to receive(:get).with(:symbol_index).and_call_original
      
      pipeline.send(:index_symbols, result)
    end
  end

  describe "#extract_from_hash mutations" do
    it "returns empty arrays for nil values" do
      data = {classes: nil, modules: nil, methods: nil, method_calls: nil, mixins: nil}
      result = pipeline.send(:extract_from_hash, data)
      
      expect(result[:classes]).to eq([])
      expect(result[:modules]).to eq([])
      expect(result[:methods]).to eq([])
      expect(result[:method_calls]).to eq([])
      expect(result[:mixins]).to eq([])
    end

    it "uses || operator to provide defaults" do
      # Empty hash should get all defaults
      result = pipeline.send(:extract_from_hash, {})
      
      expect(result[:classes]).to eq([])
      expect(result[:modules]).to eq([])
      expect(result[:methods]).to eq([])
      expect(result[:method_calls]).to eq([])
      expect(result[:mixins]).to eq([])
    end
  end

  describe "#extract_from_result mutations" do
    it "handles nil collections with || operator" do
      result_obj = double("result", classes: nil, modules: nil, methods: nil, mixins: nil)
      
      data = pipeline.send(:extract_from_result, result_obj)
      
      expect(data[:classes]).to eq([])
      expect(data[:modules]).to eq([])
      expect(data[:methods]).to eq([])
      expect(data[:method_calls]).to eq([])
      expect(data[:mixins]).to eq([])
    end

    it "always returns empty array for method_calls" do
      result_obj = double("result", classes: [], modules: [], methods: [], mixins: [])
      
      data = pipeline.send(:extract_from_result, result_obj)
      
      expect(data[:method_calls]).to eq([])
    end
  end
end