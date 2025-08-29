# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::MethodProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }
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

  before do
    allow(symbol_id_generator).to receive(:generate_method_id).and_return("method_123")
    allow(provenance_tracker).to receive(:create_provenance).and_return(provenance)
  end

  describe "processing method data" do
    context "when processing valid instance method data" do
      let(:method_data) do
        {
          name: "find_by_email",
          class: "User",
          scope: "instance",
          visibility: "public",
          parameters: [{kind: "req", name: "email", type: "String"}],
          source: "static"
        }
      end

      it "creates a normalized method with correct attributes" do
        processor.process([method_data], result, errors)

        expect(result.methods.size).to eq(1)
        normalized_method = result.methods.first

        expect(normalized_method.name).to eq("find_by_email")
        expect(normalized_method.fqname).to eq("User#find_by_email")
        expect(normalized_method.owner).to eq("User")
        expect(normalized_method.scope).to eq("instance")
        expect(normalized_method.visibility).to eq("public")
        expect(normalized_method.source).to eq("static")
        expect(normalized_method).to be_a(Rubymap::Normalizer::NormalizedMethod)
      end

      it "generates fully qualified name with instance method separator" do
        processor.process([method_data], result, errors)

        expect(result.methods.first.fqname).to eq("User#find_by_email")
      end

      it "calculates arity correctly for required parameters" do
        processor.process([method_data], result, errors)

        expect(result.methods.first.arity).to eq(1)
      end

      it "processes successfully without errors" do
        processor.process([method_data], result, errors)

        expect(errors).to be_empty
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

      it "generates fully qualified name with class method separator" do
        processor.process([class_method_data], result, errors)

        expect(result.methods.first.fqname).to eq("User.create")
      end

      it "correctly identifies scope as class" do
        processor.process([class_method_data], result, errors)

        expect(result.methods.first.scope).to eq("class")
      end

      it "calculates zero arity for empty parameters" do
        processor.process([class_method_data], result, errors)

        expect(result.methods.first.arity).to eq(0)
      end
    end

    context "when processing method data with minimal information" do
      let(:minimal_method_data) do
        {
          name: "simple_method",
          class: "TestClass"  # Required for validation to pass
        }
      end

      it "uses default values for missing optional fields" do
        processor.process([minimal_method_data], result, errors)

        normalized_method = result.methods.first
        expect(normalized_method.owner).to eq("TestClass")
        expect(normalized_method.scope).to eq("instance")  # Default scope
        expect(normalized_method.visibility).to eq("public")  # Default visibility
        expect(normalized_method.arity).to eq(0)  # No parameters
      end

      it "defaults to instance scope when scope is not specified" do
        processor.process([minimal_method_data], result, errors)

        expect(result.methods.first.scope).to eq("instance")
      end

      it "generates correct fqname with owner" do
        processor.process([minimal_method_data], result, errors)

        expect(result.methods.first.fqname).to eq("TestClass#simple_method")
      end
    end

    context "when processing method with owner vs class field" do
      it "uses owner field when class field is missing" do
        owner_method_data = {
          name: "process",
          owner: "DataProcessor",
          scope: "instance"
        }

        processor.process([owner_method_data], result, errors)

        normalized_method = result.methods.first
        expect(normalized_method.owner).to eq("DataProcessor")
        expect(normalized_method.fqname).to eq("DataProcessor#process")
      end

      it "prefers class field over owner field when both are present" do
        both_fields_data = {
          name: "process",
          owner: "DataProcessor",
          class: "SpecificProcessor",
          scope: "instance"
        }

        processor.process([both_fields_data], result, errors)

        expect(result.methods.first.owner).to eq("SpecificProcessor")
      end
    end

    context "when processing methods with different parameter types" do
      it "correctly calculates arity for required parameters" do
        method_with_required = {
          name: "test_method",
          class: "TestClass",
          parameters: [{kind: "req", name: "arg1"}, {kind: "req", name: "arg2"}]
        }

        processor.process([method_with_required], result, errors)

        expect(result.methods.first.arity).to eq(2)
      end

      it "correctly calculates arity for methods with optional parameters" do
        method_with_optional = {
          name: "test_method",
          class: "TestClass",
          parameters: [{kind: "req", name: "arg1"}, {kind: "opt", name: "arg2"}]
        }

        processor.process([method_with_optional], result, errors)

        # Ruby arity for methods with optional params is -(required + 1)
        expect(result.methods.first.arity).to eq(-2)
      end

      it "correctly calculates arity for methods with rest parameters" do
        method_with_rest = {
          name: "test_method",
          class: "TestClass",
          parameters: [{kind: "req", name: "arg1"}, {kind: "rest", name: "args"}]
        }

        processor.process([method_with_rest], result, errors)

        expect(result.methods.first.arity).to eq(-2)
      end
    end
  end

  describe "validation behavior" do
    context "when processing methods with required fields" do
      it "processes valid method data successfully" do
        valid_data = {name: "valid_method", class: "TestClass"}

        processor.process([valid_data], result, errors)

        expect(errors).to be_empty
        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("valid_method")
      end

      it "rejects methods without name field" do
        invalid_data = {class: "TestClass"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("missing required field: name")
        expect(result.methods).to be_empty
      end

      it "rejects methods with nil name field" do
        invalid_data = {name: nil, class: "TestClass"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("missing required field: name")
        expect(result.methods).to be_empty
      end

      it "rejects methods without owner or class field" do
        invalid_data = {name: "method_without_owner"}

        processor.process([invalid_data], result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("Method must have an owner or class")
        expect(result.methods).to be_empty
      end

      it "processes valid methods while skipping invalid ones" do
        mixed_data = [
          {name: nil, class: "TestClass"},  # Invalid - no name
          {name: "valid_method", class: "TestClass"},  # Valid
          {name: "orphaned_method"}  # Invalid - no owner/class
        ]

        processor.process(mixed_data, result, errors)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("valid_method")
        expect(errors.size).to eq(2)  # Two validation errors
      end
    end
  end

  describe "fully qualified name generation" do
    context "when processing instance methods" do
      it "uses # separator for instance methods" do
        method_data = {name: "process", class: "DataProcessor", scope: "instance"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.fqname).to eq("DataProcessor#process")
      end
    end

    context "when processing class methods" do
      it "uses . separator for class methods" do
        method_data = {name: "create", class: "User", scope: "class"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.fqname).to eq("User.create")
      end
    end

    context "when owner information is incomplete" do
      it "handles methods with empty string owner" do
        method_data = {name: "method", class: "", scope: "instance"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.fqname).to eq("#method")
      end
    end
  end

  describe "scope handling behavior" do
    context "when scope is explicitly provided" do
      it "uses the explicit class scope" do
        method_data = {name: "method_name", class: "TestClass", scope: "class"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.scope).to eq("class")
      end

      it "uses the explicit instance scope" do
        method_data = {name: "method_name", class: "TestClass", scope: "instance"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.scope).to eq("instance")
      end
    end

    context "when scope is not provided" do
      it "defaults to instance scope" do
        method_data = {name: "method_name", class: "TestClass"}

        processor.process([method_data], result, errors)

        expect(result.methods.first.scope).to eq("instance")
      end
    end

    context "when scope is nil" do
      it "defaults to instance scope" do
        method_data = {name: "method_name", class: "TestClass", scope: nil}

        processor.process([method_data], result, errors)

        expect(result.methods.first.scope).to eq("instance")
      end
    end
  end

  describe "edge case behavior" do
    context "when processing empty method data" do
      it "handles empty array gracefully" do
        processor.process([], result, errors)

        expect(result.methods).to be_empty
        expect(errors).to be_empty
      end
    end

    context "when processing unusual method data" do
      it "handles method data with empty string name" do
        method_data = {name: "", class: "TestClass"}

        processor.process([method_data], result, errors)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("")
      end

      it "handles method data with symbol name" do
        method_data = {name: :symbol_method, class: "TestClass"}

        processor.process([method_data], result, errors)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first.name).to eq("symbol_method")
      end

      it "processes methods without explicit visibility" do
        method_data = {name: "test_method", class: "TestClass"}

        processor.process([method_data], result, errors)

        # Should default to public visibility
        expect(result.methods.first.visibility).to eq("public")
      end

      it "handles methods with private visibility based on naming" do
        method_data = {name: "_private_method", class: "TestClass"}

        processor.process([method_data], result, errors)

        # Should infer private visibility from underscore prefix
        expect(result.methods.first.inferred_visibility).to eq("private")
      end
    end
  end
end
