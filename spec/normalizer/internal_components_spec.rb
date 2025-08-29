# frozen_string_literal: true

require "spec_helper"

# Tests for internal components of the Normalizer
RSpec.describe "Normalizer Internal Components" do
  describe "SymbolIdGenerator" do
    let(:generator) { Rubymap::Normalizer::SymbolIdGenerator.new }

    describe "#generate_class_id" do
      it "generates consistent IDs for same input" do
        id1 = generator.generate_class_id("MyApp::User", "class")
        id2 = generator.generate_class_id("MyApp::User", "class")
        expect(id1).to eq(id2)
      end

      it "generates different IDs for different names" do
        id1 = generator.generate_class_id("User", "class")
        id2 = generator.generate_class_id("Post", "class")
        expect(id1 == id2).to be false
      end

      it "generates different IDs for different kinds" do
        id1 = generator.generate_class_id("User", "class")
        id2 = generator.generate_class_id("User", "singleton")
        expect(id1 == id2).to be false
      end

      it "returns 16 character hex string" do
        id = generator.generate_class_id("User", "class")
        expect(id).to match(/^[a-f0-9]{16}$/)
      end
    end

    describe "#generate_module_id" do
      it "generates consistent IDs" do
        id1 = generator.generate_module_id("Trackable")
        id2 = generator.generate_module_id("Trackable")
        expect(id1).to eq(id2)
      end

      it "differs from class ID with same name" do
        class_id = generator.generate_class_id("Helper", "class")
        module_id = generator.generate_module_id("Helper")
        expect(class_id == module_id).to be false
      end
    end

    describe "#generate_method_id" do
      it "considers all parameters for uniqueness" do
        id1 = generator.generate_method_id(fqname: "User#save", receiver: "User", arity: 0)
        id2 = generator.generate_method_id(fqname: "User#save", receiver: "User", arity: 1)
        expect(id1 == id2).to be false
      end

      it "generates consistent IDs for same parameters" do
        id1 = generator.generate_method_id(fqname: "User#save", receiver: "User", arity: 0)
        id2 = generator.generate_method_id(fqname: "User#save", receiver: "User", arity: 0)
        expect(id1).to eq(id2)
      end
    end
  end

  describe "ProvenanceTracker" do
    let(:tracker) { Rubymap::Normalizer::ProvenanceTracker.new }

    describe "#create_provenance" do
      it "creates provenance with single source" do
        prov = tracker.create_provenance(sources: "static", confidence: 0.8)
        expect(prov.sources).to eq(["static"])
        expect(prov.confidence).to eq(0.8)
        expect(prov.timestamp).to match(/\d{4}-\d{2}-\d{2}T/)
      end

      it "creates provenance with multiple sources" do
        prov = tracker.create_provenance(sources: ["static", "runtime"], confidence: 0.9)
        expect(prov.sources).to eq(["static", "runtime"])
      end

      it "uses default confidence if not provided" do
        prov = tracker.create_provenance(sources: "static")
        expect(prov.confidence).to eq(0.5)
      end
    end

    describe "#merge_provenance" do
      it "merges sources from both provenances" do
        prov1 = tracker.create_provenance(sources: ["static"], confidence: 0.7)
        prov2 = tracker.create_provenance(sources: ["runtime"], confidence: 0.8)

        merged = tracker.merge_provenance(prov1, prov2)
        expect(merged.sources).to include("static", "runtime")
      end

      it "takes highest confidence" do
        prov1 = tracker.create_provenance(sources: "static", confidence: 0.6)
        prov2 = tracker.create_provenance(sources: "runtime", confidence: 0.9)

        merged = tracker.merge_provenance(prov1, prov2)
        expect(merged.confidence).to eq(0.9)
      end

      it "removes duplicate sources" do
        prov1 = tracker.create_provenance(sources: ["static", "yard"], confidence: 0.7)
        prov2 = tracker.create_provenance(sources: ["static", "runtime"], confidence: 0.8)

        merged = tracker.merge_provenance(prov1, prov2)
        expect(merged.sources.count("static")).to eq(1)
      end

      it "updates timestamp to current time" do
        old_time = Time.now - 3600  # 1 hour ago
        prov1 = Rubymap::Normalizer::Provenance.new(
          sources: ["static"],
          confidence: 0.7,
          timestamp: old_time.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
        prov2 = tracker.create_provenance(sources: "runtime", confidence: 0.8)

        merged = tracker.merge_provenance(prov1, prov2)
        merged_time = Time.parse(merged.timestamp)
        expect(merged_time).to be > old_time
      end
    end
  end

  describe "NormalizedResult" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }

    it "initializes with empty collections" do
      expect(result.classes).to eq([])
      expect(result.modules).to eq([])
      expect(result.methods).to eq([])
      expect(result.method_calls).to eq([])
      expect(result.errors).to eq([])
    end

    it "accepts metadata parameters" do
      result = Rubymap::Normalizer::NormalizedResult.new(
        schema_version: 2,
        normalizer_version: "2.0.0",
        normalized_at: "2024-01-01T00:00:00.000Z"
      )

      expect(result.schema_version).to eq(2)
      expect(result.normalizer_version).to eq("2.0.0")
      expect(result.normalized_at).to eq("2024-01-01T00:00:00.000Z")
    end

    it "allows adding symbols" do
      result.classes << Rubymap::Normalizer::NormalizedClass.new(name: "User")
      result.modules << Rubymap::Normalizer::NormalizedModule.new(name: "Helper")
      result.methods << Rubymap::Normalizer::NormalizedMethod.new(name: "save")

      expect(result.classes.size).to eq(1)
      expect(result.modules.size).to eq(1)
      expect(result.methods.size).to eq(1)
    end
  end

  describe "NormalizedClass" do
    it "accepts all expected fields" do
      klass = Rubymap::Normalizer::NormalizedClass.new(
        symbol_id: "abc123",
        name: "User",
        fqname: "MyApp::User",
        kind: "class",
        superclass: "ApplicationRecord",
        location: Rubymap::Normalizer::NormalizedLocation.new(file: "user.rb", line: 1),
        namespace_path: ["MyApp"],
        children: ["MyApp::User::Profile"],
        inheritance_chain: ["ApplicationRecord", "ActiveRecord::Base"],
        instance_methods: ["save", "update"],
        class_methods: ["find", "all"],
        available_instance_methods: ["save", "update", "validate"],
        available_class_methods: ["find", "all", "where"],
        mixins: [{type: "include", module: "Trackable"}],
        provenance: Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.9, timestamp: "2024-01-01T00:00:00.000Z")
      )

      expect(klass.symbol_id).to eq("abc123")
      expect(klass.name).to eq("User")
      expect(klass.fqname).to eq("MyApp::User")
      expect(klass.instance_methods).to include("save", "update")
    end

    it "allows nil values for optional fields" do
      klass = Rubymap::Normalizer::NormalizedClass.new(
        name: "User"
      )

      expect(klass.name).to eq("User")
      expect(klass.symbol_id).to be_nil
      expect(klass.superclass).to be_nil
      expect(klass.children).to be_nil
    end
  end

  describe "NormalizedMethod" do
    it "accepts all expected fields" do
      method = Rubymap::Normalizer::NormalizedMethod.new(
        symbol_id: "method123",
        name: "save",
        fqname: "User#save",
        visibility: "public",
        owner: "User",
        scope: "instance",
        parameters: [{kind: "req", name: "validate"}],
        arity: 1,
        canonical_name: "save",
        available_in: ["User", "AdminUser"],
        inferred_visibility: "public",
        source: "defined",
        provenance: Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.8, timestamp: "2024-01-01T00:00:00.000Z")
      )

      expect(method.name).to eq("save")
      expect(method.owner).to eq("User")
      expect(method.arity).to eq(1)
    end
  end

  describe "Struct behaviors" do
    it "NormalizedLocation works as a struct" do
      location = Rubymap::Normalizer::NormalizedLocation.new(file: "app/models/user.rb", line: 42)
      expect(location.file).to eq("app/models/user.rb")
      expect(location.line).to eq(42)
    end

    it "NormalizedMethodCall works as a struct" do
      call = Rubymap::Normalizer::NormalizedMethodCall.new(
        from: "UserController#create",
        to: "User#save",
        type: "instance"
      )
      expect(call.from).to eq("UserController#create")
      expect(call.to).to eq("User#save")
      expect(call.type).to eq("instance")
    end

    it "Provenance works as a struct" do
      prov = Rubymap::Normalizer::Provenance.new(
        sources: ["static", "runtime"],
        confidence: 0.95,
        timestamp: "2024-01-01T12:00:00.000Z"
      )
      expect(prov.sources).to eq(["static", "runtime"])
      expect(prov.confidence).to eq(0.95)
    end

    it "NormalizedError works as a struct" do
      error = Rubymap::Normalizer::NormalizedError.new(
        type: "validation_error",
        message: "Missing required field: name",
        data: {field: "name", value: nil}
      )
      expect(error.type).to eq("validation_error")
      expect(error.message).to include("Missing required field")
      expect(error.data[:field]).to eq("name")
    end
  end

  describe "Data source constants" do
    it "defines all expected data sources" do
      sources = Rubymap::Normalizer::DATA_SOURCES
      expect(sources[:static]).to eq("static")
      expect(sources[:runtime]).to eq("runtime")
      expect(sources[:yard]).to eq("yard")
      expect(sources[:rbs]).to eq("rbs")
      expect(sources[:sorbet]).to eq("sorbet")
      expect(sources[:inferred]).to eq("inferred")
    end

    it "defines source precedence order" do
      precedence = Rubymap::Normalizer::SOURCE_PRECEDENCE
      expect(precedence["static"]).to be > precedence["runtime"]
      expect(precedence["runtime"]).to be > precedence["rbs"]
      expect(precedence["rbs"]).to be > precedence["inferred"]
    end

    it "has correct precedence values" do
      precedence = Rubymap::Normalizer::SOURCE_PRECEDENCE
      expect(precedence["inferred"]).to eq(1)
      expect(precedence["yard"]).to eq(2)
      expect(precedence["sorbet"]).to eq(3)
      expect(precedence["rbs"]).to eq(4)
      expect(precedence["runtime"]).to eq(5)
      expect(precedence["static"]).to eq(6)
    end
  end

  describe "Schema and version constants" do
    it "defines schema version" do
      expect(Rubymap::Normalizer::SCHEMA_VERSION).to eq(1)
    end

    it "defines normalizer version" do
      expect(Rubymap::Normalizer::NORMALIZER_VERSION).to eq("1.0.0")
    end
  end
end
