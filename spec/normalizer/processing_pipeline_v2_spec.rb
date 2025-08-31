# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/rubymap/normalizer/processing_pipeline_v2"

RSpec.describe Rubymap::Normalizer::ProcessingPipelineV2 do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { described_class.new(container) }

  describe "improved design benefits" do
    it "allows testing individual steps in isolation" do
      step = Rubymap::Normalizer::ExtractSymbolsStep.new
      context = Rubymap::Normalizer::PipelineContext.new(
        input: {classes: [{name: "Test"}]},
        result: Rubymap::Normalizer::NormalizedResult.new,
        container: container
      )
      
      step.call(context)
      
      expect(context.extracted_data[:classes]).to eq([{name: "Test"}])
    end

    it "allows custom pipeline steps for testing" do
      # Create a spy step to verify execution
      custom_step = double("custom_step")
      expect(custom_step).to receive(:call).once
      
      pipeline.with_steps([custom_step])
      pipeline.execute({})
    end

    it "allows skipping specific steps for focused testing" do
      # Only test extraction and processing, skip everything else
      extraction_step = Rubymap::Normalizer::ExtractSymbolsStep.new
      processing_step = Rubymap::Normalizer::ProcessSymbolsStep.new
      
      pipeline.with_steps([extraction_step, processing_step])
      
      result = pipeline.execute({classes: [{name: "Test"}]})
      expect(result.classes.size).to eq(1)
    end

    it "makes dependencies explicit through context" do
      context = Rubymap::Normalizer::PipelineContext.new(
        input: {},
        result: Rubymap::Normalizer::NormalizedResult.new,
        container: container
      )
      
      # Each step only depends on the context, not on other steps
      step = Rubymap::Normalizer::DeduplicateSymbolsStep.new
      expect { step.call(context) }.not_to raise_error
    end
  end

  describe "#execute" do
    it "processes input through all default steps" do
      input = {
        classes: [{name: "User", location: {file: "user.rb", line: 1}}],
        modules: [{name: "Helper", location: {file: "helper.rb", line: 1}}]
      }
      
      result = pipeline.execute(input)
      
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.classes.size).to eq(1)
      expect(result.modules.size).to eq(1)
    end

    it "handles nil input gracefully" do
      result = pipeline.execute(nil)
      
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.classes).to eq([])
      expect(result.modules).to eq([])
    end

    it "sets metadata correctly" do
      result = pipeline.execute({})
      
      expect(result.schema_version).to eq(Rubymap::Normalizer::SCHEMA_VERSION)
      expect(result.normalizer_version).to eq(Rubymap::Normalizer::NORMALIZER_VERSION)
      expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
    end
  end

  describe "individual steps" do
    let(:context) do
      Rubymap::Normalizer::PipelineContext.new(
        input: nil,
        result: Rubymap::Normalizer::NormalizedResult.new,
        container: container
      )
    end

    describe Rubymap::Normalizer::ExtractSymbolsStep do
      let(:step) { described_class.new }

      it "extracts symbols from hash input" do
        context.input = {classes: [{name: "Test"}]}
        step.call(context)
        
        expect(context.extracted_data[:classes]).to eq([{name: "Test"}])
      end

      it "extracts symbols from Extractor::Result" do
        result = Rubymap::Extractor::Result.new
        result.classes << Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])
        
        context.input = result
        step.call(context)
        
        expect(context.extracted_data[:classes].first[:name]).to eq("Test")
      end

      it "returns empty data for invalid input" do
        context.input = "invalid"
        step.call(context)
        
        expect(context.extracted_data[:classes]).to eq([])
      end
    end

    describe Rubymap::Normalizer::ProcessSymbolsStep do
      let(:step) { described_class.new }

      it "processes extracted data through processors" do
        context.extracted_data = {
          classes: [{name: "Test"}],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        }
        
        step.call(context)
        
        expect(context.result.classes.size).to eq(1)
      end

      it "indexes symbols after processing" do
        context.extracted_data = {
          classes: [{name: "Test", fqname: "Test"}],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        }
        
        step.call(context)
        
        symbol_index = container.get(:symbol_index)
        found_symbol = symbol_index.find("Test")
        expect(found_symbol).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
        expect(found_symbol.fqname).to eq("Test")
      end
    end

    describe Rubymap::Normalizer::ResolveRelationshipsStep do
      let(:step) { described_class.new }

      it "resolves relationships in correct order" do
        # Add test data with relationships
        parent = Rubymap::Normalizer::CoreNormalizedClass.new(
          name: "Parent",
          fqname: "Parent"
        )
        child = Rubymap::Normalizer::CoreNormalizedClass.new(
          name: "Child",
          fqname: "Child",
          superclass: "Parent"
        )
        
        context.result.classes << parent
        context.result.classes << child
        
        step.call(context)
        
        # Relationships should be resolved
        expect(child.inheritance_chain).to include("Parent")
      end

      it "uses configurable resolver types" do
        # The resolver types are now a constant, making them easier to test
        expect(described_class::RESOLVER_TYPES).to eq([
          :namespace_resolver,
          :inheritance_resolver,
          :cross_reference_resolver,
          :mixin_method_resolver
        ])
      end
    end

    describe Rubymap::Normalizer::DeduplicateSymbolsStep do
      let(:step) { described_class.new }

      it "deduplicates symbols" do
        provenance = Rubymap::Normalizer::Provenance.new(sources: ["test.rb"])
        
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
        
        context.result.classes << class1
        context.result.classes << class2
        
        step.call(context)
        
        expect(context.result.classes.size).to eq(1)
      end
    end

    describe Rubymap::Normalizer::FormatOutputStep do
      let(:step) { described_class.new }

      it "formats output and sets errors" do
        context.errors << "test error"
        
        step.call(context)
        
        expect(context.result.errors).to eq(["test error"])
      end
    end
  end

  describe "custom pipeline configuration" do
    it "allows replacing all steps" do
      # Create a minimal pipeline for testing
      extract_step = Rubymap::Normalizer::ExtractSymbolsStep.new
      
      pipeline.with_steps([extract_step])
      
      result = pipeline.execute({classes: [{name: "Test"}]})
      
      # Only extraction happened, no processing
      expect(result.classes).to eq([])
    end

    it "allows inserting custom steps" do
      executed = false
      
      custom_step = Class.new(Rubymap::Normalizer::PipelineStep) do
        define_method :call do |context|
          executed = true
          context.result.classes << Rubymap::Normalizer::CoreNormalizedClass.new(
            name: "Injected",
            fqname: "Injected"
          )
        end
      end.new
      
      pipeline.with_steps([custom_step])
      result = pipeline.execute({})
      
      expect(executed).to be true
      expect(result.classes.first.name).to eq("Injected")
    end
  end
end