# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::ClassProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }
  let(:name_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::NameNormalizer) }
  let(:provenance) { instance_double(Rubymap::Normalizer::Provenance) }

  subject(:processor) do
    described_class.new(
      symbol_id_generator: symbol_id_generator,
      provenance_tracker: provenance_tracker,
      normalizers: normalizers
    )
  end

  let(:result) { Rubymap::Normalizer::NormalizedResult.new }
  let(:errors) { [] }
  let(:confidence_calculator) { instance_double(Rubymap::Normalizer::Calculators::ConfidenceCalculator) }

  before do
    allow(normalizers).to receive(:name_normalizer).and_return(name_normalizer)
    allow(normalizers).to receive(:confidence_calculator).and_return(confidence_calculator)
    allow(symbol_id_generator).to receive(:generate_class_id).and_return("class_123")
    allow(symbol_id_generator).to receive(:generate_module_id).and_return("module_123")
    allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
    allow(name_normalizer).to receive(:generate_fqname).and_return("TestClass")
    allow(name_normalizer).to receive(:extract_namespace_path).and_return([])
    allow(confidence_calculator).to receive(:calculate).and_return(0.8)
  end

  describe "processing class data" do
    context "when processing valid class data" do
      let(:class_data) do
        {
          name: "User",
          type: "class",
          namespace: "App",
          superclass: "ApplicationRecord",
          location: {file: "app/models/user.rb", line: 1}
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).with("User", "App").and_return("App::User")
        allow(name_normalizer).to receive(:extract_namespace_path).with("App::User").and_return(["App"])
      end

      it "creates a normalized class with correct attributes" do
        processor.process([class_data], result, errors)

        expect(result.classes.size).to eq(1)
        normalized_class = result.classes.first

        expect(normalized_class.name).to eq("User")
        expect(normalized_class.fqname).to eq("App::User")
        expect(normalized_class.kind).to eq("class")
        expect(normalized_class.superclass).to eq("ApplicationRecord")
        expect(normalized_class).to be_a(Rubymap::Normalizer::CoreNormalizedClass)
      end

      it "processes successfully without errors" do
        processor.process([class_data], result, errors)

        expect(errors).to be_empty
      end

      it "handles location information correctly" do
        processor.process([class_data], result, errors)

        normalized_class = result.classes.first
        expect(normalized_class.location).to be_a(Rubymap::Normalizer::Location)
        expect(normalized_class.location.file).to eq("app/models/user.rb")
        expect(normalized_class.location.line).to eq(1)
      end
    end

    context "when processing class data with mixins" do
      let(:class_data) do
        {
          name: "User",
          type: "class",
          mixins: [
            {type: "include", module: "Searchable"},
            {type: "extend", module: "ClassMethods"}
          ]
        }
      end

      it "processes mixins correctly" do
        processor.process([class_data], result, errors)

        normalized_class = result.classes.first
        expect(normalized_class.mixins.size).to eq(2)

        include_mixin = normalized_class.mixins.find { |m| m[:type] == "include" }
        expect(include_mixin[:module]).to eq("Searchable")

        extend_mixin = normalized_class.mixins.find { |m| m[:type] == "extend" }
        expect(extend_mixin[:module]).to eq("ClassMethods")
      end

      it "handles nil mixins gracefully" do
        class_data_with_nil_mixins = class_data.dup
        class_data_with_nil_mixins[:mixins] = nil

        processor.process([class_data_with_nil_mixins], result, errors)

        expect(errors).to be_empty
        expect(result.classes.first.mixins).to eq([])
      end

      it "handles empty mixins array gracefully" do
        class_data_with_empty_mixins = class_data.dup
        class_data_with_empty_mixins[:mixins] = []

        processor.process([class_data_with_empty_mixins], result, errors)

        expect(result.classes.first.mixins).to eq([])
      end
    end

    context "when processing module data" do
      let(:module_data) do
        {
          name: "Searchable",
          type: "module",
          namespace: "App"
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).with("Searchable", "App").and_return("App::Searchable")
        allow(name_normalizer).to receive(:extract_namespace_path).with("App::Searchable").and_return(["App"])
      end

      it "recognizes module type and processes as module" do
        processor.process([module_data], result, errors)

        expect(result.classes).to be_empty
        expect(result.modules.size).to eq(1)

        normalized_module = result.modules.first
        expect(normalized_module.name).to eq("Searchable")
        expect(normalized_module.kind).to eq("module")
        expect(normalized_module).to be_a(Rubymap::Normalizer::CoreNormalizedModule)
      end

      it "handles module type specified via kind field" do
        module_via_kind = {
          name: "Searchable",
          kind: "module",
          type: "class"  # conflicting information - kind should take precedence
        }

        allow(name_normalizer).to receive(:generate_fqname).with("Searchable", nil).and_return("Searchable")
        allow(name_normalizer).to receive(:extract_namespace_path).with("Searchable").and_return([])

        processor.process([module_via_kind], result, errors)

        expect(result.classes).to be_empty
        expect(result.modules.size).to eq(1)
      end
    end

    context "when processing minimal class data" do
      let(:minimal_class_data) do
        {
          name: "SimpleClass"
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).with("SimpleClass", nil).and_return("SimpleClass")
        allow(name_normalizer).to receive(:extract_namespace_path).with("SimpleClass").and_return([])
      end

      it "uses default values for missing optional fields" do
        processor.process([minimal_class_data], result, errors)

        normalized_class = result.classes.first
        expect(normalized_class.kind).to eq("class")
        expect(normalized_class.superclass).to be_nil
        expect(normalized_class.location).to be_nil
      end

      it "generates correct fqname for simple class names" do
        processor.process([minimal_class_data], result, errors)

        expect(result.classes.first.fqname).to eq("SimpleClass")
      end
    end
  end

  describe "validation behavior" do
    context "when processing classes with required fields" do
      it "processes valid class data successfully" do
        valid_data = {name: "User", type: "class"}

        processor.process([valid_data], result, errors)

        expect(errors).to be_empty
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("User")
      end

      it "rejects classes without name field" do
        invalid_data = {type: "class"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("missing required field: name")
        expect(result.classes).to be_empty
      end

      it "rejects classes with nil name field" do
        invalid_data = {name: nil, type: "class"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("missing required field: name")
        expect(result.classes).to be_empty
      end

      it "rejects classes with empty string name" do
        invalid_data = {name: "", type: "class"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("Class/module name cannot be empty")
        expect(result.classes).to be_empty
      end

      it "processes valid classes while skipping invalid ones" do
        mixed_data = [
          {name: nil, type: "class"},  # Invalid - no name
          {name: "ValidClass", type: "class"},  # Valid
          {name: "", type: "class"}  # Invalid - empty name
        ]

        allow(name_normalizer).to receive(:generate_fqname).with("ValidClass", nil).and_return("ValidClass")
        allow(name_normalizer).to receive(:extract_namespace_path).with("ValidClass").and_return([])

        processor.process(mixed_data, result, errors)

        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("ValidClass")
        expect(errors.size).to eq(2)  # Two validation errors
      end
    end
  end

  describe "edge case behavior" do
    context "when processing empty class data" do
      it "handles empty array gracefully" do
        processor.process([], result, errors)

        expect(result.classes).to be_empty
        expect(errors).to be_empty
      end

      it "returns empty array when processing empty data" do
        processed_items = processor.process([], result, errors)

        expect(processed_items).to eq([])
      end
    end

    context "when processing unusual class data" do
      it "handles class data with symbol names" do
        class_data = {name: :SymbolClass, type: "class"}

        allow(name_normalizer).to receive(:generate_fqname).with(:SymbolClass, nil).and_return("SymbolClass")
        allow(name_normalizer).to receive(:extract_namespace_path).with("SymbolClass").and_return([])

        processor.process([class_data], result, errors)

        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq(:SymbolClass)
      end

      it "handles classes without explicit type" do
        class_data = {name: "TestClass"}  # No type specified

        processor.process([class_data], result, errors)

        expect(result.classes.size).to eq(1)
        expect(result.classes.first.kind).to eq("class")  # defaults to "class"
      end

      it "processes classes with various mixin formats" do
        class_data = {
          name: "TestClass",
          included_modules: ["ModuleA"],
          extended_modules: ["ModuleB"],
          prepended_modules: ["ModuleC"]
        }

        processor.process([class_data], result, errors)

        normalized_class = result.classes.first
        expect(normalized_class.mixins.size).to eq(3)

        mixin_types = normalized_class.mixins.map { |m| m[:type] }
        expect(mixin_types).to contain_exactly("include", "extend", "prepend")
      end
    end
  end
end
