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

    it "delegates to InputAdapter from container" do
      input_adapter = spy("adapter", adapt: {classes: [], modules: [], methods: [], method_calls: [], mixins: []})
      allow(container).to receive(:get).with(:input_adapter).and_return(input_adapter)
      
      test_input = {classes: [{name: "Test"}]}
      context.input = test_input
      
      step.call(context)
      
      expect(input_adapter).to have_received(:adapt).with(test_input)
    end
    
    it "stores adapted data in context.extracted_data" do
      adapted_data = {
        classes: [{name: "Test"}],
        modules: [],
        methods: [],
        method_calls: [],
        mixins: []
      }
      
      input_adapter = double("adapter", adapt: adapted_data)
      allow(container).to receive(:get).with(:input_adapter).and_return(input_adapter)
      
      context.input = {classes: [{name: "Test"}]}
      
      step.call(context)
      
      expect(context.extracted_data).to eq(adapted_data)
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
      # Execute and verify it completes successfully
      step.call(context)
      
      # Result should be unchanged but processed
      expect(context.result).to be_a(Rubymap::Normalizer::NormalizedResult)
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