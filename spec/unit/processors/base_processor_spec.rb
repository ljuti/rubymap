# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::BaseProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }

  # Create a concrete test class since BaseProcessor is abstract
  let(:test_processor_class) do
    Class.new(described_class) do
      def normalize_item(data)
        # Simple test normalization
        OpenStruct.new(name: data[:name], processed: true)
      end

      def add_to_result(item, result)
        # Use classes array for testing since NormalizedResult is a struct
        result.classes << item
      end

      def validate_specific(data, errors)
        if data[:name] == "invalid"
          add_validation_error("Test validation error", data, errors)
          return false
        end
        true
      end
    end
  end

  subject(:processor) do
    test_processor_class.new(
      symbol_id_generator: symbol_id_generator,
      provenance_tracker: provenance_tracker,
      normalizers: normalizers
    )
  end

  describe "processing behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when processing valid data" do
      let(:valid_data) { [{name: "test_item"}] }

      it "processes items and adds them to result" do
        processed_items = processor.process(valid_data, result, errors)

        expect(processed_items.size).to eq(1)
        expect(processed_items.first.name).to eq("test_item")
        expect(processed_items.first.processed).to be(true)
        expect(result.classes.size).to eq(1)
        expect(errors).to be_empty
      end

      it "returns array of processed items" do
        processed_items = processor.process(valid_data, result, errors)

        expect(processed_items).to be_an(Array)
        expect(processed_items.first).to have_attributes(name: "test_item", processed: true)
      end
    end

    context "when processing empty data" do
      it "handles empty array gracefully" do
        processed_items = processor.process([], result, errors)

        expect(processed_items).to eq([])
        expect(errors).to be_empty
      end
    end

    context "when data fails validation" do
      let(:invalid_data) { [{name: "invalid"}, {name: "valid"}] }

      it "skips invalid items and continues processing valid ones" do
        processed_items = processor.process(invalid_data, result, errors)

        expect(processed_items.size).to eq(1)
        expect(processed_items.first.name).to eq("valid")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("Test validation error")
      end

      it "records validation errors for invalid items" do
        processor.process(invalid_data, result, errors)

        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.data).to eq({name: "invalid"})
      end
    end

    context "when using abstract base processor directly" do
      subject(:abstract_processor) do
        described_class.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      it "raises NotImplementedError when normalize_item is not implemented" do
        expect { abstract_processor.process([{name: "test"}], result, errors) }.to raise_error(
          NotImplementedError, "Subclasses must implement #normalize_item"
        )
      end
    end
  end

  describe "validation behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when processing items with missing required fields" do
      it "rejects items without name field" do
        data_without_name = [{type: "test"}]

        processed_items = processor.process(data_without_name, result, errors)

        expect(processed_items).to be_empty
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("missing required field: name")
      end

      it "rejects items with nil name field" do
        data_with_nil_name = [{name: nil, type: "test"}]

        processed_items = processor.process(data_with_nil_name, result, errors)

        expect(processed_items).to be_empty
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("missing required field: name")
      end
    end

    context "when processing mixed valid and invalid data" do
      it "processes valid items while skipping invalid ones" do
        mixed_data = [
          {name: nil},  # Invalid - no name
          {name: "valid_item"},  # Valid
          {name: "invalid"},  # Invalid - custom validation
          {name: "another_valid_item"}  # Valid
        ]

        processed_items = processor.process(mixed_data, result, errors)

        expect(processed_items.size).to eq(2)
        expect(processed_items.map(&:name)).to contain_exactly("valid_item", "another_valid_item")
        expect(errors.size).to eq(2)  # One for nil name, one for custom validation
      end
    end

    context "when subclass adds custom validation" do
      it "respects custom validation rules" do
        data_with_custom_invalid = [{name: "invalid"}]  # This triggers our test validation

        processed_items = processor.process(data_with_custom_invalid, result, errors)

        expect(processed_items).to be_empty
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("Test validation error")
      end
    end
  end

  describe "dependency injection behavior" do
    context "when using injected dependencies" do
      let(:dependency_aware_processor_class) do
        Class.new(described_class) do
          def normalize_item(data)
            # Use injected dependencies to demonstrate they're accessible
            id = symbol_id_generator.generate_class_id(data[:name], "test")
            OpenStruct.new(id: id, name: data[:name])
          end

          def add_to_result(item, result)
            result.test_items ||= []
            result.test_items << item
          end
        end
      end

      let(:dependency_aware_processor) do
        dependency_aware_processor_class.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      let(:result) { Rubymap::Normalizer::NormalizedResult.new }
      let(:errors) { [] }

      before do
        allow(symbol_id_generator).to receive(:generate_class_id).and_return("generated_id_123")
      end

      it "provides access to dependencies within concrete processor implementations" do
        data = [{name: "TestClass"}]

        processed_items = dependency_aware_processor.process(data, result, errors)

        expect(processed_items.first.id).to eq("generated_id_123")
        expect(symbol_id_generator).to have_received(:generate_class_id).with("TestClass", "test")
      end

      it "does not expose dependencies as public methods" do
        expect(processor.respond_to?(:symbol_id_generator)).to be false
        expect(processor.respond_to?(:provenance_tracker)).to be false
        expect(processor.respond_to?(:normalizers)).to be false
      end
    end
  end

  describe "template method pattern behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }
    let(:errors) { [] }

    context "when subclasses override specific hooks" do
      let(:custom_processor_class) do
        Class.new(described_class) do
          def normalize_item(data)
            # Custom normalization logic
            OpenStruct.new(
              name: data[:name].upcase,
              custom_field: "processed"
            )
          end

          def add_to_result(item, result)
            # Use modules array for custom storage test
            result.modules << item
          end

          def validate_specific(data, errors)
            if data[:name]&.start_with?("invalid_")
              add_validation_error("Custom validation failed", data, errors)
              return false
            end
            true
          end

          def post_process_item(item, raw_data, result)
            item.post_processed = true
          end
        end
      end

      let(:custom_processor) do
        custom_processor_class.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      it "allows subclasses to customize normalization behavior" do
        data = [{name: "test_item"}]

        processed_items = custom_processor.process(data, result, errors)

        expect(processed_items.first.name).to eq("TEST_ITEM")
        expect(processed_items.first.custom_field).to eq("processed")
      end

      it "allows subclasses to customize validation behavior" do
        data = [{name: "invalid_item"}, {name: "valid_item"}]

        processed_items = custom_processor.process(data, result, errors)

        expect(processed_items.size).to eq(1)
        expect(processed_items.first.name).to eq("VALID_ITEM")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("Custom validation failed")
      end

      it "allows subclasses to customize result storage" do
        data = [{name: "test_item"}]

        custom_processor.process(data, result, errors)

        expect(result.modules.size).to eq(1)
        expect(result.modules.first.name).to eq("TEST_ITEM")
      end

      it "allows subclasses to add post-processing behavior" do
        data = [{name: "test_item"}]

        processed_items = custom_processor.process(data, result, errors)

        expect(processed_items.first.post_processed).to be(true)
      end
    end
  end
end
