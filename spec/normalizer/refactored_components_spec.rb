# frozen_string_literal: true

require "spec_helper"

# Tests for the refactored Normalizer components to kill remaining mutations
RSpec.describe "Refactored Normalizer Components" do
  describe Rubymap::Normalizer::ServiceContainer do
    let(:container) { described_class.new }

    describe "#get" do
      it "returns the same instance for the same service" do
        service1 = container.get(:symbol_index)
        service2 = container.get(:symbol_index)
        expect(service1).to be(service2)
      end

      it "creates services lazily" do
        expect(container.instance_variable_get(:@services)[:symbol_index]).to be_nil
        container.get(:symbol_index)
        expect(container.instance_variable_get(:@services)[:symbol_index]).to be_truthy
      end

      it "returns different instances for different services" do
        index = container.get(:symbol_index)
        dedup = container.get(:deduplicator)
        expect(index.equal?(dedup)).to be false
      end

      it "raises error for unknown service" do
        expect { container.get(:unknown_service) }.to raise_error(ArgumentError)
      end
    end

    describe "#register" do
      it "allows registering custom services" do
        custom_service = double("custom_service")
        container.register(:custom, custom_service)
        expect(container.get(:custom)).to be(custom_service)
      end

      it "overwrites existing service definitions" do
        service1 = double("service1")
        service2 = double("service2")
        container.register(:test, service1)
        container.register(:test, service2)
        expect(container.get(:test)).to be(service2)
      end
    end
  end

  describe Rubymap::Normalizer::ProcessingPipeline do
    let(:container) { Rubymap::Normalizer::ServiceContainer.new }
    let(:pipeline) { described_class.new(container) }

    describe "#execute" do
      it "returns a NormalizedResult" do
        result = pipeline.execute({})
        expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
      end

      it "handles nil input gracefully" do
        result = pipeline.execute(nil)
        expect(result.classes).to eq([])
        expect(result.modules).to eq([])
      end

      it "processes nil input without errors" do
        result = pipeline.execute(nil)
        expect(result.errors).to eq([])
      end

      it "processes classes" do
        data = {
          classes: [
            {name: "User", location: {file: "user.rb", line: 1}}
          ]
        }
        result = pipeline.execute(data)
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("User")
      end

      it "processes modules" do
        data = {
          modules: [
            {name: "Helper", location: {file: "helper.rb", line: 1}}
          ]
        }
        result = pipeline.execute(data)
        expect(result.modules.size).to eq(1)
        expect(result.modules.first.name).to eq("Helper")
      end

      it "processes methods" do
        data = {
          methods: [
            {name: "save", owner: "User", location: {file: "user.rb", line: 10}}
          ]
        }
        result = pipeline.execute(data)
        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("save")
      end

      it "sets metadata correctly" do
        result = pipeline.execute({})
        expect(result.schema_version).to eq(Rubymap::Normalizer::SCHEMA_VERSION)
        expect(result.normalizer_version).to eq(Rubymap::Normalizer::NORMALIZER_VERSION)
        expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "collects errors during processing" do
        data = {
          classes: [
            {name: "", location: {file: "bad.rb", line: 1}}
          ]
        }
        result = pipeline.execute(data)
        expect(result.errors.any?).to be true
      end
    end
  end

  describe Rubymap::Normalizer::SymbolFinder do
    let(:symbol_index) { Rubymap::Normalizer::SymbolIndex.new }
    let(:finder) { described_class.new(symbol_index) }

    before do
      @user_class = double("User", name: "User", fqname: "User")
      @post_class = double("Post", name: "Post", fqname: "Post")
      symbol_index.add(@user_class)
      symbol_index.add(@post_class)
    end

    describe "#find_symbol" do
      it "finds symbol by fqname" do
        result = finder.find_symbol("User")
        expect(result).to eq(@user_class)
      end

      it "returns nil for non-existent symbol" do
        result = finder.find_symbol("NonExistent")
        expect(result).to be_nil
      end

      it "searches in provided result when index miss" do
        admin = double("Admin", name: "Admin", fqname: "Admin")
        result_obj = double("result", classes: [admin], modules: [])
        result = finder.find_symbol("Admin", result_obj)
        expect(result).to eq(admin)
      end

      it "prefers index match over collection" do
        other_user = double("OtherUser", name: "User", fqname: "User")
        result_obj = double("result", classes: [other_user], modules: [])
        result = finder.find_symbol("User", result_obj)
        expect(result).to eq(@user_class)
      end
    end
  end

  describe Rubymap::Normalizer::ProcessorFactory do
    let(:symbol_id_generator) { Rubymap::Normalizer::SymbolIdGenerator.new }
    let(:provenance_tracker) { Rubymap::Normalizer::ProvenanceTracker.new }
    let(:normalizer_registry) { Rubymap::Normalizer::NormalizerRegistry.new }
    let(:factory) { described_class.new(symbol_id_generator, provenance_tracker, normalizer_registry) }

    describe "#create_class_processor" do
      it "returns a ClassProcessor instance" do
        processor = factory.create_class_processor
        expect(processor).to be_a(Rubymap::Normalizer::Processors::ClassProcessor)
      end

      it "returns a new instance on each call" do
        processor1 = factory.create_class_processor
        processor2 = factory.create_class_processor
        expect(processor1.equal?(processor2)).to be false
      end
    end

    describe "#create_method_processor" do
      it "returns a MethodProcessor instance" do
        processor = factory.create_method_processor
        expect(processor).to be_a(Rubymap::Normalizer::Processors::MethodProcessor)
      end
    end

    describe "#create_method_call_processor" do
      it "returns a MethodCallProcessor instance" do
        processor = factory.create_method_call_processor
        expect(processor).to be_a(Rubymap::Normalizer::Processors::MethodCallProcessor)
      end
    end
  end

  describe Rubymap::Normalizer::ResolverFactory do
    let(:container) { Rubymap::Normalizer::ServiceContainer.new }
    let(:factory) { described_class.new(container) }

    describe "#create_namespace_resolver" do
      it "returns a NamespaceResolver instance" do
        resolver = factory.create_namespace_resolver
        expect(resolver).to be_a(Rubymap::Normalizer::Resolvers::NamespaceResolver)
      end
    end

    describe "#create_inheritance_resolver" do
      it "returns an InheritanceResolver instance" do
        resolver = factory.create_inheritance_resolver
        expect(resolver).to be_a(Rubymap::Normalizer::Resolvers::InheritanceResolver)
      end
    end

    describe "#create_cross_reference_resolver" do
      it "returns a CrossReferenceResolver instance" do
        resolver = factory.create_cross_reference_resolver
        expect(resolver).to be_a(Rubymap::Normalizer::Resolvers::CrossReferenceResolver)
      end
    end
  end

  describe "Processor Template Method Pattern" do
    let(:processor) do
      Rubymap::Normalizer::Processors::ClassProcessor.new(
        symbol_id_generator: Rubymap::Normalizer::SymbolIdGenerator.new,
        provenance_tracker: Rubymap::Normalizer::ProvenanceTracker.new,
        normalizers: Rubymap::Normalizer::NormalizerRegistry.new
      )
    end

    it "processes valid items" do
      data = [
        {name: "User", location: {file: "user.rb", line: 1}}
      ]
      result = Rubymap::Normalizer::NormalizedResult.new
      errors = []

      processor.process(data, result, errors)

      expect(result.classes.size).to eq(1)
      expect(errors).to be_empty
    end

    it "skips invalid items and records errors" do
      data = [
        {name: "", location: {file: "bad.rb", line: 1}},
        {name: "Valid", location: {file: "good.rb", line: 1}}
      ]
      result = Rubymap::Normalizer::NormalizedResult.new
      errors = []

      processor.process(data, result, errors)

      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("Valid")
      expect(errors.size).to eq(1)
    end

    it "handles exceptions during processing" do
      data = [{name: "Test", location: {file: "test.rb", line: 1}}]
      result = Rubymap::Normalizer::NormalizedResult.new
      errors = []

      allow(processor).to receive(:normalize_item).and_raise("Processing error")

      processor.process(data, result, errors)

      expect(result.classes).to be_empty
      expect(errors.size).to eq(1)
      expect(errors.first.type).to eq("processing")
    end
  end

  describe "Domain Model Structs" do
    describe Rubymap::Normalizer::CoreNormalizedClass do
      it "sets default values" do
        klass = described_class.new(name: "User")
        expect(klass.kind).to eq("class")
        expect(klass.children).to eq([])
        expect(klass.instance_methods).to eq([])
        expect(klass.class_methods).to eq([])
        expect(klass.mixins).to eq([])
      end

      it "has helper methods" do
        klass = described_class.new(name: "User", superclass: "ApplicationRecord")
        expect(klass.has_superclass?).to be true
        expect(klass.has_mixins?).to be false
      end
    end

    describe Rubymap::Normalizer::CoreNormalizedMethod do
      it "sets default values" do
        method = described_class.new(name: "save")
        expect(method.visibility).to eq("public")
        expect(method.scope).to eq("instance")
        expect(method.arity).to eq(0)
        expect(method.parameters).to eq([])
      end

      it "has helper methods" do
        method = described_class.new(name: "find", scope: "class")
        expect(method.class_method?).to be true
        expect(method.instance_method?).to be false
        expect(method.public?).to be true
      end
    end

    describe Rubymap::Normalizer::Location do
      it "validates location" do
        location = described_class.new(file: "user.rb", line: 1)
        expect(location.valid?).to be true

        invalid = described_class.new(file: nil, line: 1)
        expect(invalid.valid?).to be false
      end

      it "formats to string" do
        location = described_class.new(file: "app/models/user.rb", line: 42)
        expect(location.to_s).to eq("app/models/user.rb:42")
      end
    end
  end

  describe "Method Arity Calculation" do
    let(:processor) do
      Rubymap::Normalizer::Processors::MethodProcessor.new(
        symbol_id_generator: Rubymap::Normalizer::SymbolIdGenerator.new,
        provenance_tracker: Rubymap::Normalizer::ProvenanceTracker.new,
        normalizers: Rubymap::Normalizer::NormalizerRegistry.new
      )
    end

    it "calculates arity for required parameters" do
      data = {
        name: "process",
        owner: "Handler",
        parameters: [
          {kind: "req", name: "a"},
          {kind: "req", name: "b"}
        ],
        location: {file: "handler.rb", line: 1}
      }

      method = processor.normalize_item(data)
      expect(method.arity).to eq(2)
    end

    it "calculates negative arity for optional parameters" do
      data = {
        name: "process",
        owner: "Handler",
        parameters: [
          {kind: "req", name: "a"},
          {kind: "opt", name: "b"}
        ],
        location: {file: "handler.rb", line: 1}
      }

      method = processor.normalize_item(data)
      expect(method.arity).to eq(-2)
    end

    it "handles rest parameters" do
      data = {
        name: "process",
        owner: "Handler",
        parameters: [
          {kind: "req", name: "a"},
          {kind: "rest", name: "args"}
        ],
        location: {file: "handler.rb", line: 1}
      }

      method = processor.normalize_item(data)
      expect(method.arity).to eq(-2)
    end

    it "handles keyword parameters" do
      data = {
        name: "process",
        owner: "Handler",
        parameters: [
          {kind: "keyreq", name: "key"},
          {kind: "keyopt", name: "opt"}
        ],
        location: {file: "handler.rb", line: 1}
      }

      method = processor.normalize_item(data)
      expect(method.arity).to eq(-1)
    end
  end
end
