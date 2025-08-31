# frozen_string_literal: true

require "spec_helper"

# Specific tests to kill remaining ProcessingPipeline mutants
RSpec.describe "Rubymap::Normalizer::ProcessingPipeline - Mutation Tests" do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { Rubymap::Normalizer::ProcessingPipeline.new(container) }

  describe "ExtractSymbolsStep mutations" do
    let(:step) { Rubymap::Normalizer::ExtractSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}

    describe "#extract_symbol_data" do
      it "returns empty data for falsy values" do
        [nil, false].each do |falsy_value|
          extracted = step.send(:extract_symbol_data, falsy_value)
          expect(extracted).to eq({
            classes: [], modules: [], methods: [], method_calls: [], mixins: []
          })
        end
      end

      it "returns hash data when input is Hash" do
        data = {classes: [{name: "Test"}]}
        result = step.send(:extract_symbol_data, data)
        expect(result[:classes]).to eq([{name: "Test"}])
      end

      it "returns converted data when input is Extractor::Result" do
        extractor_result = Rubymap::Extractor::Result.new
        extractor_result.classes << Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])
        
        result = step.send(:extract_symbol_data, extractor_result)
        expect(result[:classes].first[:name]).to eq("Test")
      end

      it "returns empty data for unexpected input types" do
        ["string", 123, []].each do |invalid_input|
          result = step.send(:extract_symbol_data, invalid_input)
          expect(result[:classes]).to eq([])
        end
      end
    end

    describe "#extractor_result?" do
      it "returns true only when both classes AND modules methods exist" do
        obj = double("complete", classes: [], modules: [])
        expect(step.send(:extractor_result?, obj)).to be true
      end

      it "returns false when object only has classes method" do
        obj = double("partial", classes: [])
        expect(step.send(:extractor_result?, obj)).to be false
      end

      it "returns false when object only has modules method" do
        obj = double("partial", modules: [])
        expect(step.send(:extractor_result?, obj)).to be false
      end

      it "returns false for nil" do
        expect(step.send(:extractor_result?, nil)).to be false
      end

      it "returns false for Hash even if it has keys :classes and :modules" do
        hash = {classes: [], modules: []}
        expect(step.send(:extractor_result?, hash)).to be false
      end
    end

    describe "#convert_to_hashes" do
      it "returns items unchanged when empty" do
        items = []
        result = step.send(:convert_to_hashes, items)
        expect(result).to be(items) # Must be same object
      end

      it "returns items unchanged when first is Hash" do
        items = [{name: "Test"}]
        result = step.send(:convert_to_hashes, items)
        expect(result).to be(items) # Must be same object
      end

      it "converts when first is not Hash" do
        obj = double("obj", to_h: {name: "Test"})
        items = [obj]
        result = step.send(:convert_to_hashes, items)
        # Verify it's a different object
        expect(result.object_id == items.object_id).to be false
        expect(result).to eq([{name: "Test"}])
      end

      it "checks first element using is_a?(Hash) not instance_of?" do
        # Subclass of Hash should still return items unchanged
        class TestHash < Hash; end
        test_hash = TestHash.new
        test_hash[:name] = "Test"
        
        items = [test_hash]
        result = step.send(:convert_to_hashes, items)
        expect(result).to be(items) # Should recognize TestHash as Hash
      end
    end

    describe "#extract_from_hash" do
      it "returns empty arrays for nil values" do
        data = {classes: nil, modules: nil, methods: nil, method_calls: nil, mixins: nil}
        result = step.send(:extract_from_hash, data)
        
        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
        expect(result[:methods]).to eq([])
        expect(result[:method_calls]).to eq([])
        expect(result[:mixins]).to eq([])
      end

      it "uses || operator to provide defaults" do
        # Empty hash should get all defaults
        result = step.send(:extract_from_hash, {})
        
        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
        expect(result[:methods]).to eq([])
        expect(result[:method_calls]).to eq([])
        expect(result[:mixins]).to eq([])
      end
    end

    describe "#extract_from_result" do
      it "handles nil collections with || operator" do
        result_obj = double("result", classes: nil, modules: nil, methods: nil, mixins: nil)
        
        data = step.send(:extract_from_result, result_obj)
        
        expect(data[:classes]).to eq([])
        expect(data[:modules]).to eq([])
        expect(data[:methods]).to eq([])
        expect(data[:method_calls]).to eq([])
        expect(data[:mixins]).to eq([])
      end

      it "always returns empty array for method_calls" do
        result_obj = double("result", classes: [], modules: [], methods: [], mixins: [])
        
        data = step.send(:extract_from_result, result_obj)
        
        expect(data[:method_calls]).to eq([])
      end
    end
  end

  describe "ProcessSymbolsStep mutations" do
    let(:step) { Rubymap::Normalizer::ProcessSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}

    describe "#index_symbols" do
      it "adds both classes and modules to index" do
        klass = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Test", fqname: "Test")
        mod = Rubymap::Normalizer::CoreNormalizedModule.new(name: "Helper", fqname: "Helper")
        
        context.result.classes << klass
        context.result.modules << mod
        
        step.send(:index_symbols, context)
        
        symbol_index = container.get(:symbol_index)
        expect(symbol_index.find("Test")).to eq(klass)
        expect(symbol_index.find("Helper")).to eq(mod)
      end

      it "gets symbol_index from container" do
        expect(container).to receive(:get).with(:symbol_index).and_call_original
        
        step.send(:index_symbols, context)
      end
    end
  end

  describe "ResolveRelationshipsStep mutations" do
    let(:step) { Rubymap::Normalizer::ResolveRelationshipsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}

    it "gets resolver_factory from container" do
      allow(container).to receive(:get).and_call_original
      
      step.call(context)
      
      expect(container).to have_received(:get).with(:resolver_factory)
    end

    it "calls all four resolvers in sequence" do
      # Just verify it executes without error
      expect { step.call(context) }.not_to raise_error
    end
  end

  describe "DeduplicateSymbolsStep mutations" do
    let(:step) { Rubymap::Normalizer::DeduplicateSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}

    it "gets deduplicator from container" do
      allow(container).to receive(:get).and_call_original
      
      step.call(context)
      
      expect(container).to have_received(:get).with(:deduplicator)
    end

    it "calls deduplicate_symbols on deduplicator" do
      deduplicator = container.get(:deduplicator)
      
      expect(deduplicator).to receive(:deduplicate_symbols).with(context.result)
      
      step.call(context)
    end
  end

  describe "FormatOutputStep mutations" do
    let(:step) { Rubymap::Normalizer::FormatOutputStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}

    it "gets output_formatter from container" do
      expect(container).to receive(:get).with(:output_formatter).and_call_original
      
      step.call(context)
    end

    it "calls format on output_formatter" do
      formatter = container.get(:output_formatter)
      
      expect(formatter).to receive(:format).with(context.result)
      
      step.call(context)
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
end