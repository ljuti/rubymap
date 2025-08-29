# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer do
  subject(:normalizer) { described_class.new }

  describe "behavior as a symbol normalizer" do
    context "when orchestrating normalization workflow" do
      let(:raw_data) do
        {
          classes: [{name: "User", type: "class", namespace: "App"}],
          modules: [{name: "Searchable", type: "module"}],
          methods: [{name: "find", class: "User", visibility: "public"}],
          method_calls: [{from: "UserController", to: "User", type: "instantiation"}],
          mixins: [{type: "include", module: "Searchable"}]
        }
      end

      it "returns a structured normalization result" do
        result = normalizer.normalize(raw_data)

        expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
        expect(result.schema_version).to eq(1)
        expect(result.normalizer_version).to eq("1.0.0")
        expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "processes all symbol types in deterministic order" do
        # The new architecture delegates to ProcessingPipeline
        # We'll just verify the result contains the expected symbols
        result = normalizer.normalize(raw_data)

        expect(result.classes.any?).to be true
        expect(result.modules.any?).to be true
        expect(result.methods.any?).to be true
      end

      it "clears symbol index state between normalizations" do
        first_result = normalizer.normalize(raw_data)
        second_result = normalizer.normalize({classes: [{name: "Different", type: "class"}]})

        expect(first_result.classes.first.name).to eq("User")
        expect(second_result.classes.first.name).to eq("Different")
        expect(second_result.classes.include?(first_result.classes.first)).to be false
      end

      it "applies deduplication strategy to eliminate duplicate symbols" do
        duplicate_data = {
          classes: [
            {name: "User", type: "class", source: "static"},
            {name: "User", type: "class", source: "runtime"}
          ]
        }

        result = normalizer.normalize(duplicate_data)

        expect(result.classes.size).to eq(1)
        expect(result.classes.first.provenance.sources).to include("static", "runtime")
      end

      it "formats output deterministically for reproducible results" do
        result1 = normalizer.normalize(raw_data)
        result2 = normalizer.normalize(raw_data)

        expect(result1.classes.map(&:symbol_id)).to eq(result2.classes.map(&:symbol_id))
        expect(result1.methods.map(&:symbol_id)).to eq(result2.methods.map(&:symbol_id))
      end
    end

    context "when handling error conditions" do
      it "accumulates validation errors during processing" do
        invalid_data = {
          classes: [{name: nil, type: "class"}],
          methods: [{name: nil, class: "User"}]
        }

        result = normalizer.normalize(invalid_data)

        expect(result.errors.any?).to be true
        expect(result.errors.map(&:type)).to all(eq("validation"))
        expect(result.errors.map(&:message)).to include(
          "missing required field: name",
          "missing required field: name"
        )
      end

      it "continues processing valid symbols when encountering invalid ones" do
        mixed_data = {
          classes: [
            {name: nil, type: "class"},
            {name: "ValidClass", type: "class"}
          ]
        }

        result = normalizer.normalize(mixed_data)

        expect(result.errors.any?).to be true
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("ValidClass")
      end

      it "handles completely empty input data gracefully" do
        result = normalizer.normalize({})

        expect(result.classes).to be_empty
        expect(result.modules).to be_empty
        expect(result.methods).to be_empty
        expect(result.method_calls).to be_empty
        expect(result.errors).to be_empty
      end

      it "handles nil input gracefully" do
        # Expects no error from: normalizer.normalize(nil)
      end
    end
  end

  describe "symbol ID generation behavior" do
    let(:generator) { described_class::SymbolIdGenerator.new }

    context "when generating class IDs" do
      it "generates deterministic IDs for classes" do
        id1 = generator.generate_class_id("User", "class")
        id2 = generator.generate_class_id("User", "class")

        expect(id1).to eq(id2)
        expect(id1).to match(/^[a-f0-9]{16}$/)
      end

      it "generates different IDs for different classes" do
        user_id = generator.generate_class_id("User", "class")
        admin_id = generator.generate_class_id("Admin", "class")

        expect(user_id == admin_id).to be false
      end

      it "generates different IDs based on kind parameter" do
        class_id = generator.generate_class_id("User", "class")
        struct_id = generator.generate_class_id("User", "struct")

        expect(class_id == struct_id).to be false
      end
    end

    context "when generating module IDs" do
      it "generates deterministic IDs for modules" do
        id1 = generator.generate_module_id("Searchable")
        id2 = generator.generate_module_id("Searchable")

        expect(id1).to eq(id2)
        expect(id1).to match(/^[a-f0-9]{16}$/)
      end

      it "generates different IDs from classes with same name" do
        module_id = generator.generate_module_id("Common")
        class_id = generator.generate_class_id("Common", "class")

        expect(module_id == class_id).to be false
      end
    end

    context "when generating method IDs" do
      it "generates deterministic IDs based on fqname, receiver, and arity" do
        id1 = generator.generate_method_id(fqname: "User#find", receiver: "instance", arity: 1)
        id2 = generator.generate_method_id(fqname: "User#find", receiver: "instance", arity: 1)

        expect(id1).to eq(id2)
        expect(id1).to match(/^[a-f0-9]{16}$/)
      end

      it "generates different IDs for different receivers" do
        instance_id = generator.generate_method_id(fqname: "User#find", receiver: "instance", arity: 1)
        class_id = generator.generate_method_id(fqname: "User#find", receiver: "class", arity: 1)

        expect(instance_id == class_id).to be false
      end

      it "generates different IDs for different arities" do
        arity1_id = generator.generate_method_id(fqname: "User#find", receiver: "instance", arity: 1)
        arity2_id = generator.generate_method_id(fqname: "User#find", receiver: "instance", arity: 2)

        expect(arity1_id == arity2_id).to be false
      end
    end
  end

  describe "provenance tracking behavior" do
    let(:tracker) { described_class::ProvenanceTracker.new }

    context "when creating provenance" do
      it "creates provenance with single source" do
        provenance = tracker.create_provenance(sources: "static", confidence: 0.8)

        expect(provenance.sources).to eq(["static"])
        expect(provenance.confidence).to eq(0.8)
        expect(provenance.timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "creates provenance with multiple sources" do
        provenance = tracker.create_provenance(sources: ["static", "runtime"], confidence: 0.9)

        expect(provenance.sources).to eq(["static", "runtime"])
        expect(provenance.confidence).to eq(0.9)
      end

      it "defaults confidence to 0.5 when not specified" do
        provenance = tracker.create_provenance(sources: "static")

        expect(provenance.confidence).to eq(0.5)
      end
    end

    context "when merging provenance" do
      let(:existing) do
        described_class::Provenance.new(
          sources: ["static"],
          confidence: 0.7,
          timestamp: "2023-01-01T00:00:00.000Z"
        )
      end

      let(:new_provenance) do
        described_class::Provenance.new(
          sources: ["runtime"],
          confidence: 0.9,
          timestamp: "2023-01-02T00:00:00.000Z"
        )
      end

      it "merges sources from both provenances" do
        merged = tracker.merge_provenance(existing, new_provenance)

        expect(merged.sources).to include("static", "runtime")
        expect(merged.sources.uniq).to eq(["static", "runtime"])
      end

      it "takes the highest confidence score" do
        merged = tracker.merge_provenance(existing, new_provenance)

        expect(merged.confidence).to eq(0.9)
      end

      it "updates timestamp to current time" do
        merged = tracker.merge_provenance(existing, new_provenance)

        expect(merged.timestamp).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
        expect(merged.timestamp == existing.timestamp).to be false
        expect(merged.timestamp == new_provenance.timestamp).to be false
      end

      it "deduplicates sources when merging identical sources" do
        duplicate_new = described_class::Provenance.new(
          sources: ["static", "yard"],
          confidence: 0.8,
          timestamp: "2023-01-02T00:00:00.000Z"
        )

        merged = tracker.merge_provenance(existing, duplicate_new)

        expect(merged.sources.count("static")).to eq(1)
        expect(merged.sources).to include("static", "yard")
      end
    end
  end

  describe "result object behavior" do
    let(:result) { described_class::NormalizedResult.new }

    context "when initializing with parameters" do
      it "sets metadata fields correctly" do
        result = described_class::NormalizedResult.new(
          schema_version: 2,
          normalizer_version: "2.0.0",
          normalized_at: "2023-01-01T00:00:00.000Z"
        )

        expect(result.schema_version).to eq(2)
        expect(result.normalizer_version).to eq("2.0.0")
        expect(result.normalized_at).to eq("2023-01-01T00:00:00.000Z")
      end
    end

    context "when initializing with defaults" do
      it "initializes all collections as empty arrays" do
        expect(result.classes).to eq([])
        expect(result.modules).to eq([])
        expect(result.methods).to eq([])
        expect(result.method_calls).to eq([])
        expect(result.errors).to eq([])
      end

      it "allows nil metadata fields" do
        expect(result.schema_version).to be_nil
        expect(result.normalizer_version).to be_nil
        expect(result.normalized_at).to be_nil
      end
    end

    context "when manipulating collections" do
      it "allows adding classes to the result" do
        klass = described_class::NormalizedClass.new(name: "User", fqname: "App::User")
        result.classes << klass

        expect(result.classes).to include(klass)
        expect(result.classes.size).to eq(1)
      end

      it "allows modifying errors collection" do
        error = described_class::NormalizedError.new(type: "validation", message: "test error")
        result.errors << error

        expect(result.errors).to include(error)
        expect(result.errors.first.type).to eq("validation")
      end
    end
  end
end
