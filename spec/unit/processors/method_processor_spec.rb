# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::MethodProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }
  
  let(:name_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::NameNormalizer) }
  let(:visibility_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::VisibilityNormalizer) }
  let(:parameter_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::ParameterNormalizer) }
  let(:arity_calculator) { instance_double(Rubymap::Normalizer::Calculators::ArityCalculator) }
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
    allow(normalizers).to receive(:visibility_normalizer).and_return(visibility_normalizer)
    allow(normalizers).to receive(:parameter_normalizer).and_return(parameter_normalizer)
    allow(normalizers).to receive(:arity_calculator).and_return(arity_calculator)
    allow(normalizers).to receive(:confidence_calculator).and_return(confidence_calculator)
  end

  describe "behavior when processing method symbols" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }
    let(:provenance) { Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.8) }

    context "when processing valid method data" do
      let(:method_data) do
        {
          name: "find_by_email",
          class: "User",
          owner: "User",
          scope: "instance",
          visibility: "public",
          parameters: [{ name: "email", type: "String" }],
          source: "static"
        }
      end

      let(:normalized_params) { [{ name: "email", type: "String" }] }

      before do
        allow(parameter_normalizer).to receive(:normalize).with([{ name: "email", type: "String" }]).and_return(normalized_params)
        allow(arity_calculator).to receive(:calculate).with(normalized_params).and_return(1)
        allow(symbol_id_generator).to receive(:generate_method_id).with(
          fqname: "User#find_by_email",
          receiver: "instance",
          arity: 1
        ).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).with("public", errors).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).with("find_by_email").and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).with("find_by_email").and_return("find_by_email")
        allow(confidence_calculator).to receive(:calculate).with(method_data).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "creates a normalized method with all required attributes" do
        processor.process([method_data], result, errors)

        expect(result.methods.size).to eq(1)
        
        normalized_method = result.methods.first
        expect(normalized_method.symbol_id).to eq("method123")
        expect(normalized_method.name).to eq("find_by_email")
        expect(normalized_method.fqname).to eq("User#find_by_email")
        expect(normalized_method.visibility).to eq("public")
        expect(normalized_method.owner).to eq("User")
        expect(normalized_method.scope).to eq("instance")
        expect(normalized_method.parameters).to eq(normalized_params)
        expect(normalized_method.arity).to eq(1)
        expect(normalized_method.canonical_name).to eq("find_by_email")
        expect(normalized_method.available_in).to eq([])
        expect(normalized_method.inferred_visibility).to eq("public")
        expect(normalized_method.source).to eq("static")
        expect(normalized_method.provenance).to eq(provenance)
      end

      it "generates fully qualified name using instance method separator" do
        processor.process([method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.fqname).to eq("User#find_by_email")
      end

      it "delegates parameter normalization to parameter normalizer" do
        processor.process([method_data], result, errors)
        
        expect(parameter_normalizer).to have_received(:normalize).with([{ name: "email", type: "String" }])
      end

      it "delegates arity calculation to arity calculator" do
        processor.process([method_data], result, errors)
        
        expect(arity_calculator).to have_received(:calculate).with(normalized_params)
      end

      it "delegates visibility normalization to visibility normalizer" do
        processor.process([method_data], result, errors)
        
        expect(visibility_normalizer).to have_received(:normalize).with("public", errors)
      end

      it "delegates visibility inference to visibility normalizer" do
        processor.process([method_data], result, errors)
        
        expect(visibility_normalizer).to have_received(:infer_from_name).with("find_by_email")
      end

      it "delegates canonical name generation to name normalizer" do
        processor.process([method_data], result, errors)
        
        expect(name_normalizer).to have_received(:to_snake_case).with("find_by_email")
      end
    end

    context "when processing class method data" do
      let(:class_method_data) do
        {
          name: "create",
          class: "User",
          scope: "class",
          parameters: []
        }
      end

      before do
        allow(parameter_normalizer).to receive(:normalize).with([]).and_return([])
        allow(arity_calculator).to receive(:calculate).with([]).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).with(
          fqname: "User.create",
          receiver: "class",
          arity: 0
        ).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).with(nil, errors).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).with("create").and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).with("create").and_return("create")
        allow(confidence_calculator).to receive(:calculate).with(class_method_data).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "generates fully qualified name using class method separator" do
        processor.process([class_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.fqname).to eq("User.create")
      end

      it "generates method ID with class receiver type" do
        processor.process([class_method_data], result, errors)
        
        expect(symbol_id_generator).to have_received(:generate_method_id).with(
          fqname: "User.create",
          receiver: "class",
          arity: 0
        )
      end
    end

    context "when processing method data with minimal information" do
      let(:minimal_method_data) do
        {
          name: "simple_method"
        }
      end

      before do
        allow(parameter_normalizer).to receive(:normalize).with(nil).and_return([])
        allow(arity_calculator).to receive(:calculate).with([]).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).with(
          fqname: "simple_method",
          receiver: "instance",
          arity: 0
        ).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).with(nil, errors).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).with("simple_method").and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).with("simple_method").and_return("simple_method")
        allow(confidence_calculator).to receive(:calculate).with(minimal_method_data).and_return(0.5)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "uses default values for missing optional fields" do
        processor.process([minimal_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.owner).to be_nil
        expect(normalized_method.scope).to eq("instance")  # Default scope
        expect(normalized_method.fqname).to eq("simple_method")  # No owner prefix
        expect(normalized_method.source).to be_nil  # Uses owner (nil) as source
      end

      it "defaults to instance scope when scope is not specified" do
        processor.process([minimal_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.scope).to eq("instance")
      end

      it "generates simple fqname when no owner is present" do
        processor.process([minimal_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.fqname).to eq("simple_method")
      end
    end

    context "when processing method with owner but no class field" do
      let(:owner_method_data) do
        {
          name: "process",
          owner: "DataProcessor",
          scope: "instance"
        }
      end

      before do
        allow(parameter_normalizer).to receive(:normalize).with(nil).and_return([])
        allow(arity_calculator).to receive(:calculate).with([]).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).and_return("process")
        allow(confidence_calculator).to receive(:calculate).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "uses owner field when class field is missing" do
        processor.process([owner_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.owner).to eq("DataProcessor")
        expect(normalized_method.fqname).to eq("DataProcessor#process")
      end

      it "prefers class field over owner field when both are present" do
        owner_method_data[:class] = "SpecificProcessor"
        
        processor.process([owner_method_data], result, errors)
        
        normalized_method = result.methods.first
        expect(normalized_method.owner).to eq("SpecificProcessor")
      end
    end

    context "when creating provenance information" do
      let(:method_data) do
        {
          name: "test_method",
          source: "runtime"
        }
      end

      before do
        allow(parameter_normalizer).to receive(:normalize).and_return([])
        allow(arity_calculator).to receive(:calculate).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).and_return("test_method")
        allow(confidence_calculator).to receive(:calculate).and_return(0.85)
        allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
      end

      it "creates provenance with explicit source when provided" do
        processor.process([method_data], result, errors)
        
        expect(provenance_tracker).to have_received(:create_provenance).with(
          sources: ["runtime"],
          confidence: 0.85
        )
      end

      it "creates provenance with inferred source when source is missing" do
        method_data.delete(:source)
        
        processor.process([method_data], result, errors)
        
        expect(provenance_tracker).to have_received(:create_provenance).with(
          sources: [Rubymap::Normalizer::DATA_SOURCES[:inferred]],
          confidence: 0.85
        )
      end
    end
  end

  describe "validation behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when validating method data" do
      it "passes validation for data with required name field" do
        valid_data = { name: "valid_method", class: "TestClass" }
        
        expect(processor.validate(valid_data, errors)).to be(true)
        expect(errors).to be_empty
      end

      it "fails validation when name field is nil" do
        invalid_data = { name: nil, class: "TestClass" }
        
        expect(processor.validate(invalid_data, errors)).to be(false)
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("missing required field: name")
        expect(errors.first.data).to eq(invalid_data)
      end

      it "fails validation when name field is missing" do
        invalid_data = { class: "TestClass" }
        
        expect(processor.validate(invalid_data, errors)).to be(false)
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("missing required field: name")
      end

      it "skips processing invalid methods but continues with valid ones" do
        allow(parameter_normalizer).to receive(:normalize).and_return([])
        allow(arity_calculator).to receive(:calculate).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).and_return("valid_method")
        allow(confidence_calculator).to receive(:calculate).and_return(0.8)
        allow(provenance_tracker).to receive(:create_provenance).and_return(
          Rubymap::Normalizer::Provenance.new(sources: ["static"], confidence: 0.8)
        )
        
        mixed_data = [
          { name: nil, class: "TestClass" },
          { name: "valid_method", class: "TestClass" }
        ]
        
        processor.process(mixed_data, result, errors)
        
        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("valid_method")
        expect(errors.size).to eq(1)
      end
    end
  end

  describe "fully qualified name generation behavior" do
    subject(:fqname_generation) { processor.send(:generate_method_fqname, method_name, owner, scope) }

    context "when generating fqname for instance methods" do
      let(:method_name) { "process" }
      let(:owner) { "DataProcessor" }
      let(:scope) { "instance" }

      it "uses # separator for instance methods" do
        expect(fqname_generation).to eq("DataProcessor#process")
      end
    end

    context "when generating fqname for class methods" do
      let(:method_name) { "create" }
      let(:owner) { "User" }
      let(:scope) { "class" }

      it "uses . separator for class methods" do
        expect(fqname_generation).to eq("User.create")
      end
    end

    context "when no owner is present" do
      let(:method_name) { "standalone_method" }
      let(:owner) { nil }
      let(:scope) { "instance" }

      it "returns method name without prefix" do
        expect(fqname_generation).to eq("standalone_method")
      end
    end

    context "when owner is empty string" do
      let(:method_name) { "method" }
      let(:owner) { "" }
      let(:scope) { "instance" }

      it "uses empty owner in fqname" do
        expect(fqname_generation).to eq("#method")
      end
    end
  end

  describe "method scope determination behavior" do
    subject(:scope_determination) { processor.send(:determine_method_scope, method_data) }

    context "when scope is explicitly provided" do
      let(:method_data) { { scope: "class" } }

      it "returns the explicit scope" do
        expect(scope_determination).to eq("class")
      end
    end

    context "when scope is not provided" do
      let(:method_data) { { name: "method_name" } }

      it "defaults to instance scope" do
        expect(scope_determination).to eq("instance")
      end
    end

    context "when scope is nil" do
      let(:method_data) { { scope: nil } }

      it "defaults to instance scope" do
        expect(scope_determination).to eq("instance")
      end
    end

    context "when scope is empty string" do
      let(:method_data) { { scope: "" } }

      it "returns empty string (truthy, not nil)" do
        expect(scope_determination).to eq("")
      end
    end
  end

  describe "edge case behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when processing empty method data" do
      it "handles empty array gracefully" do
        expect { processor.process([], result, errors) }.not_to raise_error
        expect(result.methods).to be_empty
        expect(errors).to be_empty
      end
    end

    context "when processing malformed method data" do
      before do
        allow(parameter_normalizer).to receive(:normalize).and_return([])
        allow(arity_calculator).to receive(:calculate).and_return(0)
        allow(symbol_id_generator).to receive(:generate_method_id).and_return("method123")
        allow(visibility_normalizer).to receive(:normalize).and_return("public")
        allow(visibility_normalizer).to receive(:infer_from_name).and_return("public")
        allow(name_normalizer).to receive(:to_snake_case).and_return("test")
        allow(confidence_calculator).to receive(:calculate).and_return(0.3)
        allow(provenance_tracker).to receive(:create_provenance).and_return(
          Rubymap::Normalizer::Provenance.new(sources: ["inferred"], confidence: 0.3)
        )
      end

      it "handles method data with empty string name" do
        method_data = { name: "", class: "TestClass" }
        
        processor.process([method_data], result, errors)
        
        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("")
      end

      it "handles method data with symbol name" do
        method_data = { name: :symbol_method, class: "TestClass" }
        
        processor.process([method_data], result, errors)
        
        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq(:symbol_method)
      end

      it "handles method data with unusual parameter formats" do
        method_data = { name: "test_method", parameters: "not_an_array" }
        
        processor.process([method_data], result, errors)
        
        expect(parameter_normalizer).to have_received(:normalize).with("not_an_array")
      end
    end
  end
end