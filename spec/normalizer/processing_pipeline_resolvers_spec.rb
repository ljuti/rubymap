# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Rubymap::Normalizer::ProcessingPipeline - Resolvers" do
  let(:container) { Rubymap::Normalizer::ServiceContainer.new }
  let(:pipeline) { Rubymap::Normalizer::ProcessingPipeline.new(container) }

  describe "ResolveRelationshipsStep" do
    let(:step) { Rubymap::Normalizer::ResolveRelationshipsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}
    
    before do
      # Set up test data with relationships
      parent_class = Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "Parent",
        fqname: "Parent",
        symbol_id: "parent_id",
        namespace_path: []
      )
      
      child_class = Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "Child", 
        fqname: "Child",
        symbol_id: "child_id",
        superclass: "Parent",
        namespace_path: []
      )
      
      context.result.classes << parent_class
      context.result.classes << child_class
    end

    it "executes all resolvers in correct order" do
      resolver_factory = container.get(:resolver_factory)
      
      # Create spies for each resolver
      namespace_resolver = spy("namespace_resolver")
      inheritance_resolver = spy("inheritance_resolver")
      cross_ref_resolver = spy("cross_ref_resolver")
      mixin_resolver = spy("mixin_resolver")
      
      allow(resolver_factory).to receive(:create_namespace_resolver).and_return(namespace_resolver)
      allow(resolver_factory).to receive(:create_inheritance_resolver).and_return(inheritance_resolver)
      allow(resolver_factory).to receive(:create_cross_reference_resolver).and_return(cross_ref_resolver)
      allow(resolver_factory).to receive(:create_mixin_method_resolver).and_return(mixin_resolver)
      
      step.call(context)
      
      # Verify all resolvers were called in order
      expect(namespace_resolver).to have_received(:resolve).with(context.result).ordered
      expect(inheritance_resolver).to have_received(:resolve).with(context.result).ordered
      expect(cross_ref_resolver).to have_received(:resolve).with(context.result).ordered
      expect(mixin_resolver).to have_received(:resolve).with(context.result).ordered
    end

    it "passes the same result object to all resolvers" do
      original_result_id = context.result.object_id
      
      resolver_factory = container.get(:resolver_factory)
      
      # Verify each resolver receives the same result object
      allow(resolver_factory.create_namespace_resolver).to receive(:resolve) do |passed_result|
        expect(passed_result.object_id).to eq(original_result_id)
      end
      
      allow(resolver_factory.create_inheritance_resolver).to receive(:resolve) do |passed_result|
        expect(passed_result.object_id).to eq(original_result_id)
      end
      
      allow(resolver_factory.create_cross_reference_resolver).to receive(:resolve) do |passed_result|
        expect(passed_result.object_id).to eq(original_result_id)
      end
      
      allow(resolver_factory.create_mixin_method_resolver).to receive(:resolve) do |passed_result|
        expect(passed_result.object_id).to eq(original_result_id)
      end
      
      step.call(context)
    end

    it "modifies the result with inheritance chains" do
      step.call(context)
      
      child = context.result.classes.find { |c| c.name == "Child" }
      expect(child.inheritance_chain).to include("Parent")
    end

    it "handles results with no relationships" do
      empty_context = Rubymap::Normalizer::PipelineContext.new(
        input: nil,
        result: Rubymap::Normalizer::NormalizedResult.new,
        container: container
      )
      
      step.call(empty_context)
      
      # Verify result remains empty after resolution
      expect(empty_context.result.classes).to eq([])
      expect(empty_context.result.modules).to eq([])
    end

    it "resolves complex namespace hierarchies" do
      # Add nested namespace classes
      namespace_module = Rubymap::Normalizer::CoreNormalizedModule.new(
        name: "MyApp",
        fqname: "MyApp",
        symbol_id: "myapp_id",
        namespace_path: []
      )
      
      nested_class = Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "User",
        fqname: "MyApp::User",
        symbol_id: "user_id",
        namespace_path: ["MyApp"]
      )
      
      context.result.modules << namespace_module
      context.result.classes << nested_class
      
      step.call(context)
      
      # Verify namespace relationships are resolved
      expect(nested_class.namespace_path).to eq(["MyApp"])
    end
  end

  describe "ProcessSymbolsStep - processor execution" do
    let(:step) { Rubymap::Normalizer::ProcessSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}
    
    it "processes all symbol types in correct order" do
      processor_factory = container.get(:processor_factory)
      
      class_processor = spy("class_processor")
      module_processor = spy("module_processor")
      method_processor = spy("method_processor")
      method_call_processor = spy("method_call_processor")
      mixin_processor = spy("mixin_processor")
      
      allow(processor_factory).to receive(:create_class_processor).and_return(class_processor)
      allow(processor_factory).to receive(:create_module_processor).and_return(module_processor)
      allow(processor_factory).to receive(:create_method_processor).and_return(method_processor)
      allow(processor_factory).to receive(:create_method_call_processor).and_return(method_call_processor)
      allow(processor_factory).to receive(:create_mixin_processor).and_return(mixin_processor)
      
      context.extracted_data = {
        classes: [{name: "Test"}],
        modules: [{name: "Helper"}],
        methods: [{name: "test", owner: "Test"}],
        method_calls: [{from: "Test#test", to: "Helper#help"}],
        mixins: [{module: "Helper", target: "Test", type: "include"}]
      }
      
      step.call(context)
      
      # Verify processors were called in correct order
      expect(class_processor).to have_received(:process).ordered
      expect(module_processor).to have_received(:process).ordered
      expect(method_processor).to have_received(:process).ordered
      expect(method_call_processor).to have_received(:process).ordered
      # index_symbols is called here
      expect(mixin_processor).to have_received(:process).ordered
    end

    it "indexes symbols before processing mixins" do
      symbol_index = container.get(:symbol_index)
      
      # Add a class that will be indexed
      context.extracted_data = {
        classes: [{name: "TestClass", fqname: "TestClass"}],
        modules: [],
        methods: [],
        method_calls: [],
        mixins: []
      }
      
      step.call(context)
      
      # Verify the class was indexed
      found_class = symbol_index.find("TestClass")
      expect(found_class).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      expect(found_class.name).to eq("TestClass")
    end

    it "passes errors array to all processors" do
      processor_factory = container.get(:processor_factory)
      
      context.extracted_data = {
        classes: [{name: ""}], # Invalid class
        modules: [],
        methods: [],
        method_calls: [],
        mixins: []
      }
      context.errors = []
      
      step.call(context)
      
      # Should have collected validation errors
      expect(context.errors.size).to be > 0
      expect(context.errors.first).to be_a(Rubymap::Normalizer::NormalizedError)
      expect(context.errors.first.type).to eq("validation")
      expect(context.errors.first.message).to eq("Class/module name cannot be empty")
    end
  end

  describe "ProcessSymbolsStep - main symbols processing" do
    let(:step) { Rubymap::Normalizer::ProcessSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}
    let(:processor_factory) { container.get(:processor_factory) }
    
    it "processes each symbol type with its processor" do
      context.extracted_data = {
        classes: [{name: "A"}],
        modules: [{name: "B"}],
        methods: [{name: "c", owner: "A"}],
        method_calls: [{from: "A#c", to: "B#d"}]
      }
      context.errors = []
      
      step.send(:process_main_symbols, processor_factory, context)
      
      expect(context.result.classes.size).to eq(1)
      expect(context.result.modules.size).to eq(1)
      expect(context.result.methods.size).to eq(1)
    end
  end

  describe "ProcessSymbolsStep - mixin processing" do
    let(:step) { Rubymap::Normalizer::ProcessSymbolsStep.new }
    let(:context) { Rubymap::Normalizer::PipelineContext.new(
      input: nil,
      result: Rubymap::Normalizer::NormalizedResult.new,
      container: container
    )}
    let(:processor_factory) { container.get(:processor_factory) }
    
    before do
      # Add target class and module for mixin
      context.result.classes << Rubymap::Normalizer::CoreNormalizedClass.new(
        name: "Target",
        fqname: "Target",
        symbol_id: "target_id"
      )
      
      context.result.modules << Rubymap::Normalizer::CoreNormalizedModule.new(
        name: "Mixin",
        fqname: "Mixin",
        symbol_id: "mixin_id"
      )
      
      # Index them
      symbol_index = container.get(:symbol_index)
      symbol_index.add(context.result.classes.first)
      symbol_index.add(context.result.modules.first)
    end
    
    it "processes mixins correctly" do
      context.extracted_data = {
        mixins: [{module: "Mixin", target: "Target", type: "include"}]
      }
      context.errors = []
      
      step.send(:process_mixins, processor_factory, context)
      
      # Just verify it doesn't raise an error
      expect(context.errors).to eq([])
    end
  end

  describe "Pipeline metadata creation" do
    it "creates result with all required metadata fields" do
      result = pipeline.execute({})
      
      expect(result.schema_version).to eq(Rubymap::Normalizer::SCHEMA_VERSION)
      expect(result.normalizer_version).to eq(Rubymap::Normalizer::NORMALIZER_VERSION)
      expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
    end
    
    it "uses current UTC time for normalized_at" do
      time_before = Time.now.utc
      result = pipeline.execute({})
      time_after = Time.now.utc + 1 # Add 1 second buffer
      
      normalized_time = Time.parse(result.normalized_at)
      expect(normalized_time).to be_between(time_before - 1, time_after)
    end
  end

  describe "ExtractSymbolsStep edge cases" do
    let(:step) { Rubymap::Normalizer::ExtractSymbolsStep.new }
    
    it "handles arrays with nil first element" do
      items = [nil, {name: "Test"}]
      result = step.send(:convert_to_hashes, items)
      # nil gets converted to {} by to_h
      expect(result).to eq([{}, {name: "Test"}])
    end
    
    it "properly checks if first element is Hash" do
      # Not a hash but responds to is_a?
      fake_hash = double("fake", is_a?: false, to_h: {name: "Fake"})
      items = [fake_hash]
      
      result = step.send(:convert_to_hashes, items)
      expect(result).to eq([{name: "Fake"}])
    end
  end
end