# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Normalizer::ProcessingPipeline do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { described_class.new(container) }

  describe "#initialize" do
    it "requires a container parameter" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "initializes with the provided container" do
      custom_container = Rubymap::Normalizer::ServiceContainer.new
      pipeline = described_class.new(custom_container)
      expect(pipeline.instance_variable_get(:@container)).to eq(custom_container)
    end

    it "initializes with default steps in correct order" do
      pipeline = described_class.new(container)
      steps = pipeline.steps

      expect(steps.size).to eq(5)
      expect(steps[0]).to be_a(Rubymap::Normalizer::ExtractSymbolsStep)
      expect(steps[1]).to be_a(Rubymap::Normalizer::ProcessSymbolsStep)
      expect(steps[2]).to be_a(Rubymap::Normalizer::ResolveRelationshipsStep)
      expect(steps[3]).to be_a(Rubymap::Normalizer::DeduplicateSymbolsStep)
      expect(steps[4]).to be_a(Rubymap::Normalizer::FormatOutputStep)
    end
  end

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

    it "sets metadata correctly" do
      result = pipeline.execute({})

      expect(result.schema_version).to eq(Rubymap::Normalizer::SCHEMA_VERSION)
      expect(result.normalizer_version).to eq(Rubymap::Normalizer::NORMALIZER_VERSION)
      expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
    end

    it "executes all default steps in order" do
      # Test that all steps are executed
      result = pipeline.execute({})

      # Result should have gone through all steps
      expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      expect(result.errors).to eq([])
    end

    it "step order matters - wrong order breaks relationships" do
      # Steps in wrong order should break functionality
      # ResolveRelationshipsStep before symbols are indexed won't resolve properly
      wrong_order_pipeline = pipeline.with_steps([
        Rubymap::Normalizer::ExtractSymbolsStep.new,
        Rubymap::Normalizer::ResolveRelationshipsStep.new,  # Wrong - before processing/indexing
        Rubymap::Normalizer::ProcessSymbolsStep.new,
        Rubymap::Normalizer::DeduplicateSymbolsStep.new,
        Rubymap::Normalizer::FormatOutputStep.new
      ])

      data = {
        classes: [
          {name: "Parent"},
          {name: "Child", superclass: "Parent"}
        ],
        modules: []
      }

      result = wrong_order_pipeline.execute(data)

      # Child exists but inheritance chain won't be resolved
      # because resolve happened before symbols were indexed
      child = result.classes.find { |c| c.name == "Child" }
      expect(child).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      expect(child.name).to eq("Child")
      expect(child.inheritance_chain).to eq([]) # No inheritance resolved
    end

    it "step order matters - correct order succeeds" do
      data = {
        classes: [
          {name: "Parent"},
          {name: "Child", superclass: "Parent"}
        ],
        modules: []
      }

      result = pipeline.execute(data)

      # With correct order, relationships are resolved
      child = result.classes.find { |c| c.name == "Child" }
      parent = result.classes.find { |c| c.name == "Parent" }

      expect(child).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      expect(parent).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      expect(child.superclass).to eq("Parent")
    end
  end

  describe "#with_steps" do
    it "allows customization of pipeline steps" do
      custom_step = double("custom_step")
      expect(custom_step).to receive(:call).with(kind_of(Rubymap::Normalizer::PipelineContext))

      pipeline.with_steps([custom_step])
      pipeline.execute({})
    end

    it "returns self for chaining" do
      expect(pipeline.with_steps([])).to eq(pipeline)
    end

    it "missing extract step means no data extraction" do
      # Without ExtractSymbolsStep, no data gets extracted
      incomplete_pipeline = pipeline.with_steps([
        # Missing ExtractSymbolsStep
        Rubymap::Normalizer::ProcessSymbolsStep.new,
        Rubymap::Normalizer::ResolveRelationshipsStep.new,
        Rubymap::Normalizer::DeduplicateSymbolsStep.new,
        Rubymap::Normalizer::FormatOutputStep.new
      ])

      result = incomplete_pipeline.execute({classes: [{name: "Test"}]})
      expect(result.classes).to eq([]) # No extraction happened
    end

    it "missing process step means no symbols in result" do
      # Without ProcessSymbolsStep, extracted data doesn't become symbols
      incomplete_pipeline = pipeline.with_steps([
        Rubymap::Normalizer::ExtractSymbolsStep.new,
        # Missing ProcessSymbolsStep
        Rubymap::Normalizer::ResolveRelationshipsStep.new,
        Rubymap::Normalizer::DeduplicateSymbolsStep.new,
        Rubymap::Normalizer::FormatOutputStep.new
      ])

      result = incomplete_pipeline.execute({classes: [{name: "Test"}]})
      expect(result.classes).to eq([]) # No processing happened
    end

    it "missing deduplicate step means duplicates remain" do
      # Without DeduplicateSymbolsStep, duplicates aren't removed
      incomplete_pipeline = pipeline.with_steps([
        Rubymap::Normalizer::ExtractSymbolsStep.new,
        Rubymap::Normalizer::ProcessSymbolsStep.new,
        Rubymap::Normalizer::ResolveRelationshipsStep.new,
        # Missing DeduplicateSymbolsStep
        Rubymap::Normalizer::FormatOutputStep.new
      ])

      # Create duplicate classes
      data = {
        classes: [
          {name: "Test", location: {file: "a.rb", line: 1}},
          {name: "Test", location: {file: "b.rb", line: 1}}
        ]
      }

      result = incomplete_pipeline.execute(data)
      expect(result.classes.size).to eq(2) # Duplicates not removed
    end
  end

  describe "individual steps" do
    describe Rubymap::Normalizer::ExtractSymbolsStep do
      let(:step) { described_class.new }
      let(:context) {
        Rubymap::Normalizer::PipelineContext.new(
          input: nil,
          result: Rubymap::Normalizer::NormalizedResult.new,
          container: container
        )
      }

      it "extracts symbols from hash input" do
        context.input = {classes: [{name: "Test"}]}
        step.call(context)

        expect(context.extracted_data[:classes]).to eq([{name: "Test"}])
      end

      it "extracts symbols from Extractor::Result" do
        extractor_result = Rubymap::Extractor::Result.new
        extractor_result.classes << Rubymap::Extractor::ClassInfo.new(name: "Test", namespace: [])

        context.input = extractor_result
        step.call(context)

        expect(context.extracted_data[:classes].size).to eq(1)
        expect(context.extracted_data[:classes].first[:name]).to eq("Test")
      end

      it "returns empty data for invalid input" do
        context.input = "invalid"
        step.call(context)

        expect(context.extracted_data[:classes]).to eq([])
        expect(context.extracted_data[:modules]).to eq([])
      end
    end

    describe Rubymap::Normalizer::ProcessSymbolsStep do
      let(:step) { described_class.new }
      let(:context) {
        Rubymap::Normalizer::PipelineContext.new(
          input: nil,
          result: Rubymap::Normalizer::NormalizedResult.new,
          container: container
        )
      }

      before do
        context.extracted_data = {
          classes: [{name: "Test", location: {file: "test.rb", line: 1}}],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        }
      end

      it "processes extracted data through processors" do
        step.call(context)

        expect(context.result.classes.size).to eq(1)
        expect(context.result.classes.first.name).to eq("Test")
      end

      it "indexes symbols after processing" do
        step.call(context)

        symbol_index = container.get(:symbol_index)
        expect(symbol_index.find("Test")).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      end

      it "processes all processor types in order" do
        processor_factory = container.get(:processor_factory)

        # Create spies for each processor
        processors = {}
        described_class::PROCESSORS.each do |proc_type, _|
          processors[proc_type] = spy(proc_type.to_s)
          allow(processor_factory).to receive("create_#{proc_type}").and_return(processors[proc_type])
        end

        mixin_processor = spy("mixin_processor")
        allow(processor_factory).to receive(:create_mixin_processor).and_return(mixin_processor)

        context.extracted_data = {
          classes: [{name: "A"}],
          modules: [{name: "B"}],
          methods: [{name: "c"}],
          method_calls: [{from: "a", to: "b"}],
          mixins: [{type: "include"}]
        }

        step.call(context)

        # Verify all processors were called in order
        described_class::PROCESSORS.each_with_index do |(proc_type, data_key), index|
          expect(processors[proc_type]).to have_received(:process).with(
            context.extracted_data[data_key],
            context.result,
            context.errors
          ).ordered
        end

        # Verify mixin processor was called last
        expect(mixin_processor).to have_received(:process).with(
          context.extracted_data[:mixins],
          context.result,
          context.errors
        ).ordered
      end

      it "handles missing data keys with empty arrays" do
        context.extracted_data = {classes: [{name: "Test"}]}  # Missing other keys

        # Should process successfully
        step.call(context)

        expect(context.result.classes.size).to eq(1)
        expect(context.result.classes.first.name).to eq("Test")
      end

      it "processes mixins after indexing symbols" do
        # Setup: Create symbols that will be indexed
        context.extracted_data = {
          classes: [{name: "Target", location: {file: "target.rb", line: 1}}],
          modules: [{name: "Mixin", location: {file: "mixin.rb", line: 1}}],
          methods: [],
          method_calls: [],
          mixins: [{module: "Mixin", target: "Target", type: "include"}]
        }

        # Spy on mixin processor to verify it's called
        processor_factory = container.get(:processor_factory)
        mixin_processor = spy("mixin_processor")
        allow(processor_factory).to receive(:create_mixin_processor).and_return(mixin_processor)

        step.call(context)

        # Verify mixin processor was called with the mixin data
        expect(mixin_processor).to have_received(:process).with(
          [{module: "Mixin", target: "Target", type: "include"}],
          context.result,
          context.errors
        )

        # Verify symbols were indexed before mixin processing
        symbol_index = container.get(:symbol_index)
        target = symbol_index.find("Target")
        mixin = symbol_index.find("Mixin")

        expect(target).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
        expect(target.name).to eq("Target")
        expect(mixin).to be_a(Rubymap::Normalizer::NormalizedModule)
        expect(mixin.name).to eq("Mixin")
      end
    end

    describe Rubymap::Normalizer::ResolveRelationshipsStep do
      let(:step) { described_class.new }
      let(:context) {
        Rubymap::Normalizer::PipelineContext.new(
          input: nil,
          result: Rubymap::Normalizer::NormalizedResult.new,
          container: container
        )
      }

      before do
        parent = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Parent", fqname: "Parent")
        child = Rubymap::Normalizer::CoreNormalizedClass.new(name: "Child", fqname: "Child", superclass: "Parent")
        context.result.classes << parent
        context.result.classes << child
      end

      it "resolves relationships in correct order" do
        step.call(context)

        child = context.result.classes.find { |c| c.name == "Child" }
        expect(child.inheritance_chain).to include("Parent")
      end

      it "uses configurable resolver types" do
        # Verify all resolver types are called
        resolver_factory = container.get(:resolver_factory)

        %i[namespace_resolver inheritance_resolver cross_reference_resolver mixin_method_resolver].each do |resolver_type|
          resolver = double(resolver_type)
          expect(resolver).to receive(:resolve).with(context.result)
          allow(resolver_factory).to receive("create_#{resolver_type}").and_return(resolver)
        end

        step.call(context)
      end
    end

    describe Rubymap::Normalizer::DeduplicateSymbolsStep do
      let(:step) { described_class.new }
      let(:context) {
        Rubymap::Normalizer::PipelineContext.new(
          input: nil,
          result: Rubymap::Normalizer::NormalizedResult.new,
          container: container
        )
      }

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
      let(:context) {
        Rubymap::Normalizer::PipelineContext.new(
          input: nil,
          result: Rubymap::Normalizer::NormalizedResult.new,
          container: container
        )
      }

      it "formats output and sets errors" do
        context.errors = ["test error"]
        context.result.classes << Rubymap::Normalizer::CoreNormalizedClass.new(name: "Test", fqname: "Test")

        step.call(context)

        expect(context.result.errors).to eq(["test error"])
      end
    end
  end

  describe "improved design benefits" do
    it "allows testing individual steps in isolation" do
      # Each step can be tested independently
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
      recording_step = Class.new do
        attr_reader :called

        def call(context)
          @called = true
        end
      end.new

      pipeline.with_steps([recording_step])
      pipeline.execute({})

      expect(recording_step.called).to be true
    end

    it "makes dependencies explicit through context" do
      context = Rubymap::Normalizer::PipelineContext.new(
        input: {},
        result: Rubymap::Normalizer::NormalizedResult.new,
        container: container
      )

      expect(context.container).to eq(container)
      expect(context.input).to eq({})
      expect(context.result).to be_a(Rubymap::Normalizer::NormalizedResult)
    end

    it "allows skipping specific steps for focused testing" do
      # Can test with only specific steps
      extract_step = Rubymap::Normalizer::ExtractSymbolsStep.new

      pipeline.with_steps([extract_step])
      result = pipeline.execute({classes: [{name: "Test"}]})

      # Only extraction happened, no processing
      expect(result.classes).to eq([])  # Not processed into result
    end
  end
end
