# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::ClassProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }
  
  let(:name_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::NameNormalizer) }
  let(:location_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::LocationNormalizer) }
  let(:confidence_calculator) { instance_double(Rubymap::Normalizer::Calculators::ConfidenceCalculator) }
  
  subject(:processor) do
    described_class.new(
      symbol_id_generator: symbol_id_generator,
      provenance_tracker: provenance_tracker,
      normalizers: normalizers
    )
  end

  before do
    allow(normalizers).to receive(:name_normalizer).and_return(name_normalizer)
    allow(normalizers).to receive(:location_normalizer).and_return(location_normalizer)
    allow(normalizers).to receive(:confidence_calculator).and_return(confidence_calculator)
  end

  describe "behavior when processing class symbols" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }
    let(:provenance) { Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.8) }

    context "when processing valid class data" do
      let(:class_data) do
        {
          name: "User",
          type: "class",
          namespace: "App",
          superclass: "ApplicationRecord",
          location: { file: "app/models/user.rb", line: 1 }
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).with("User", "App").and_return("App::User")
        allow(name_normalizer).to receive(:extract_namespace_path).with("User").and_return([])
        allow(symbol_id_generator).to receive(:generate_class_id).with("App::User", "class").and_return("class123")
        allow(location_normalizer).to receive(:normalize).with({ file: "app/models/user.rb", line: 1 }).and_return(
          Rubymap::Normalizer::NormalizedLocation.new(file: "app/models/user.rb", line: 1)
        )
        allow(confidence_calculator).to receive(:calculate).with(class_data).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "creates a normalized class with all required attributes" do
        processor.process([class_data], result, errors)

        expect(result.classes.size).to eq(1)
        
        normalized_class = result.classes.first
        expect(normalized_class.symbol_id).to eq("class123")
        expect(normalized_class.name).to eq("User")
        expect(normalized_class.fqname).to eq("App::User")
        expect(normalized_class.kind).to eq("class")
        expect(normalized_class.superclass).to eq("ApplicationRecord")
        expect(normalized_class.provenance).to eq(provenance)
      end

      it "initializes class collections as empty arrays" do
        processor.process([class_data], result, errors)
        
        normalized_class = result.classes.first
        expect(normalized_class.children).to eq([])
        expect(normalized_class.inheritance_chain).to eq([])
        expect(normalized_class.instance_methods).to eq([])
        expect(normalized_class.class_methods).to eq([])
        expect(normalized_class.available_instance_methods).to eq([])
        expect(normalized_class.available_class_methods).to eq([])
        expect(normalized_class.mixins).to eq([])
      end

      it "delegates fully qualified name generation to name normalizer" do
        processor.process([class_data], result, errors)
        
        expect(name_normalizer).to have_received(:generate_fqname).with("User", "App")
      end

      it "delegates location normalization to location normalizer" do
        processor.process([class_data], result, errors)
        
        expect(location_normalizer).to have_received(:normalize).with({ file: "app/models/user.rb", line: 1 })
      end

      it "delegates confidence calculation to confidence calculator" do
        processor.process([class_data], result, errors)
        
        expect(confidence_calculator).to have_received(:calculate).with(class_data)
      end

      it "creates provenance with inferred source when source is missing" do
        allow(provenance_tracker).to receive(:create_provenance).and_call_original
        allow(provenance_tracker).to receive(:create_provenance).with(
          sources: [Rubymap::Normalizer::DATA_SOURCES[:inferred]],
          confidence: 0.8
        ).and_return(provenance)
        
        processor.process([class_data], result, errors)
        
        expect(provenance_tracker).to have_received(:create_provenance).with(
          sources: [Rubymap::Normalizer::DATA_SOURCES[:inferred]],
          confidence: 0.8
        )
      end

      it "creates provenance with explicit source when provided" do
        class_data[:source] = "static"
        allow(provenance_tracker).to receive(:create_provenance).and_call_original
        allow(provenance_tracker).to receive(:create_provenance).with(
          sources: ["static"],
          confidence: 0.8
        ).and_return(provenance)
        
        processor.process([class_data], result, errors)
        
        expect(provenance_tracker).to have_received(:create_provenance).with(
          sources: ["static"],
          confidence: 0.8
        )
      end
    end

    context "when processing class data with mixins" do
      let(:class_data) do
        {
          name: "User",
          type: "class",
          mixins: [
            { type: "include", module: "Searchable" },
            { type: "extend", module: "ClassMethods" }
          ]
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).and_return("User")
        allow(name_normalizer).to receive(:extract_namespace_path).and_return([])
        allow(symbol_id_generator).to receive(:generate_class_id).and_return("class123")
        allow(location_normalizer).to receive(:normalize).and_return(nil)
        allow(confidence_calculator).to receive(:calculate).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "assigns mixins to the normalized class" do
        processor.process([class_data], result, errors)
        
        normalized_class = result.classes.first
        expect(normalized_class.mixins.size).to eq(2)
        
        include_mixin = normalized_class.mixins.find { |m| m[:type] == "include" }
        expect(include_mixin[:module]).to eq("Searchable")
        
        extend_mixin = normalized_class.mixins.find { |m| m[:type] == "extend" }
        expect(extend_mixin[:module]).to eq("ClassMethods")
      end

      it "handles nil mixins gracefully" do
        class_data[:mixins] = nil
        
        expect { processor.process([class_data], result, errors) }.not_to raise_error
        
        normalized_class = result.classes.first
        expect(normalized_class.mixins).to eq([])
      end

      it "handles empty mixins array gracefully" do
        class_data[:mixins] = []
        
        processor.process([class_data], result, errors)
        
        normalized_class = result.classes.first
        expect(normalized_class.mixins).to eq([])
      end
    end

    context "when processing module data misclassified as class" do
      let(:module_data) do
        {
          name: "Searchable",
          type: "module",
          namespace: "App"
        }
      end

      before do
        allow(name_normalizer).to receive(:generate_fqname).with("Searchable", "App").and_return("App::Searchable")
        allow(name_normalizer).to receive(:extract_namespace_path).with("Searchable").and_return([])
        allow(symbol_id_generator).to receive(:generate_module_id).with("App::Searchable").and_return("module123")
        allow(location_normalizer).to receive(:normalize).with(nil).and_return(nil)
        allow(confidence_calculator).to receive(:calculate).with(module_data).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "recognizes module type and processes as module instead" do
        processor.process([module_data], result, errors)
        
        expect(result.classes).to be_empty
        expect(result.modules.size).to eq(1)
        
        normalized_module = result.modules.first
        expect(normalized_module.name).to eq("Searchable")
        expect(normalized_module.kind).to eq("module")
      end

      it "recognizes kind field as module indicator" do
        module_data[:kind] = "module"
        module_data[:type] = "class"  # conflicting information
        
        processor.process([module_data], result, errors)
        
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
        allow(symbol_id_generator).to receive(:generate_class_id).with("SimpleClass", "class").and_return("class123")
        allow(location_normalizer).to receive(:normalize).with(nil).and_return(nil)
        allow(confidence_calculator).to receive(:calculate).with(minimal_class_data).and_return(0.5)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "uses default values for missing optional fields" do
        processor.process([minimal_class_data], result, errors)
        
        normalized_class = result.classes.first
        expect(normalized_class.kind).to eq("class")
        expect(normalized_class.superclass).to be_nil
        expect(normalized_class.location).to be_nil
      end

      it "generates fully qualified name with nil namespace" do
        processor.process([minimal_class_data], result, errors)
        
        expect(name_normalizer).to have_received(:generate_fqname).with("SimpleClass", nil)
      end
    end
  end

  describe "validation behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when validating class data" do
      it "passes validation for data with required name field" do
        valid_data = { name: "User", type: "class" }
        
        expect(processor.validate(valid_data, errors)).to be(true)
        expect(errors).to be_empty
      end

      it "fails validation when name field is nil" do
        invalid_data = { name: nil, type: "class" }
        
        expect(processor.validate(invalid_data, errors)).to be(false)
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("missing required field: name")
        expect(errors.first.data).to eq(invalid_data)
      end

      it "fails validation when name field is missing" do
        invalid_data = { type: "class" }
        
        expect(processor.validate(invalid_data, errors)).to be(false)
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("missing required field: name")
      end

      it "skips processing invalid classes but continues with valid ones" do
        allow(name_normalizer).to receive(:generate_fqname).with("ValidClass", nil).and_return("ValidClass")
        allow(name_normalizer).to receive(:extract_namespace_path).and_return([])
        allow(symbol_id_generator).to receive(:generate_class_id).and_return("class123")
        allow(location_normalizer).to receive(:normalize).and_return(nil)
        allow(confidence_calculator).to receive(:calculate).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(
          Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.8)
        )
        
        mixed_data = [
          { name: nil, type: "class" },
          { name: "ValidClass", type: "class" }
        ]
        
        processor.process(mixed_data, result, errors)
        
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("ValidClass")
        expect(errors.size).to eq(1)
      end
    end
  end

  describe "edge case behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when processing empty class data" do
      it "handles empty array gracefully" do
        expect { processor.process([], result, errors) }.not_to raise_error
        expect(result.classes).to be_empty
        expect(errors).to be_empty
      end

      it "returns empty array when processing empty data" do
        processed_classes = processor.process([], result, errors)
        
        expect(processed_classes).to eq([])
      end
    end

    context "when processing malformed class data" do
      before do
        allow(name_normalizer).to receive(:generate_fqname).and_return("TestClass")
        allow(name_normalizer).to receive(:extract_namespace_path).and_return([])
        allow(symbol_id_generator).to receive(:generate_class_id).and_return("class123")
        allow(location_normalizer).to receive(:normalize).and_return(nil)
        allow(confidence_calculator).to receive(:calculate).and_return(0.3)
        allow(provenance_tracker).to receive(:create_provenance).and_return(
          Rubymap::Normalizer::Provenance.new(sources: ["inferred"], confidence: 0.3)
        )
      end

      it "handles class data with empty string name" do
        class_data = { name: "", type: "class" }
        
        processor.process([class_data], result, errors)
        
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("")
      end

      it "handles class data with non-string types gracefully" do
        class_data = { name: :symbol_name, type: "class" }
        
        processor.process([class_data], result, errors)
        
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq(:symbol_name)
      end

      it "handles unusual type values" do
        class_data = { name: "TestClass", type: nil }
        
        processor.process([class_data], result, errors)
        
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.kind).to eq("class")  # defaults to "class"
      end
    end
  end
end