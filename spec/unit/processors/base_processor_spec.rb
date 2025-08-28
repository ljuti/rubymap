# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Processors::BaseProcessor do
  let(:symbol_id_generator) { instance_double(Rubymap::Normalizer::SymbolIdGenerator) }
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:normalizers) { instance_double(Rubymap::Normalizer::NormalizerRegistry) }

  # Create a concrete test class since BaseProcessor is abstract
  let(:test_processor_class) do
    Class.new(described_class) do
      def process(raw_data, result)
        # Concrete implementation for testing
        "processed"
      end

      def validate(data)
        # Concrete implementation for testing
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

  describe "behavior as an abstract base processor" do
    context "when initializing with dependencies" do
      it "accepts and stores symbol ID generator dependency" do
        expect(processor.send(:symbol_id_generator)).to eq(symbol_id_generator)
      end

      it "accepts and stores provenance tracker dependency" do
        expect(processor.send(:provenance_tracker)).to eq(provenance_tracker)
      end

      it "accepts and stores normalizers registry dependency" do
        expect(processor.send(:normalizers)).to eq(normalizers)
      end
    end

    context "when using template method pattern" do
      it "provides concrete implementation of process method in subclass" do
        result = processor.process([], nil)
        
        expect(result).to eq("processed")
      end

      it "provides concrete implementation of validate method in subclass" do
        result = processor.validate({})
        
        expect(result).to be(true)
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

      it "raises NotImplementedError for process method" do
        expect { abstract_processor.process([], nil) }.to raise_error(
          NotImplementedError, "Subclasses must implement #process"
        )
      end

      it "raises NotImplementedError for validate method" do
        expect { abstract_processor.validate({}) }.to raise_error(
          NotImplementedError, "Subclasses must implement #validate"
        )
      end
    end
  end

  describe "error handling behavior" do
    let(:errors) { [] }

    context "when adding validation errors" do
      it "creates a normalized error with validation type" do
        processor.send(:add_validation_error, "test error message", { test: "data" }, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error).to be_a(Rubymap::Normalizer::NormalizedError)
        expect(error.type).to eq("validation")
        expect(error.message).to eq("test error message")
        expect(error.data).to eq({ test: "data" })
      end

      it "appends errors to existing errors array" do
        errors << "existing error"
        
        processor.send(:add_validation_error, "new error", { test: "data" }, errors)
        
        expect(errors.size).to eq(2)
        expect(errors.last).to be_a(Rubymap::Normalizer::NormalizedError)
        expect(errors.last.message).to eq("new error")
      end

      it "handles nil data gracefully" do
        processor.send(:add_validation_error, "error with nil data", nil, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.message).to eq("error with nil data")
        expect(error.data).to be_nil
      end

      it "handles empty data hash" do
        processor.send(:add_validation_error, "error with empty data", {}, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.data).to eq({})
      end

      it "preserves complex data structures in error data" do
        complex_data = {
          name: "TestClass",
          methods: ["method1", "method2"],
          metadata: { source: "test", confidence: 0.5 }
        }
        
        processor.send(:add_validation_error, "complex error", complex_data, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.data).to eq(complex_data)
        expect(error.data[:metadata]).to eq({ source: "test", confidence: 0.5 })
      end
    end

    context "when handling multiple validation errors" do
      it "accumulates multiple errors in the same errors array" do
        processor.send(:add_validation_error, "first error", { id: 1 }, errors)
        processor.send(:add_validation_error, "second error", { id: 2 }, errors)
        processor.send(:add_validation_error, "third error", { id: 3 }, errors)
        
        expect(errors.size).to eq(3)
        
        expect(errors[0].message).to eq("first error")
        expect(errors[0].data[:id]).to eq(1)
        
        expect(errors[1].message).to eq("second error")
        expect(errors[1].data[:id]).to eq(2)
        
        expect(errors[2].message).to eq("third error")
        expect(errors[2].data[:id]).to eq(3)
      end

      it "maintains error order when adding multiple errors" do
        error_messages = ["error_a", "error_b", "error_c", "error_d", "error_e"]
        
        error_messages.each_with_index do |message, index|
          processor.send(:add_validation_error, message, { index: index }, errors)
        end
        
        expect(errors.size).to eq(5)
        
        errors.each_with_index do |error, index|
          expect(error.message).to eq("error_#{('a'.ord + index).chr}")
          expect(error.data[:index]).to eq(index)
        end
      end
    end

    context "when error data contains edge cases" do
      it "handles error data with symbol keys" do
        symbol_data = { name: :symbol_name, type: :symbol_type }
        
        processor.send(:add_validation_error, "symbol error", symbol_data, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.data[:name]).to eq(:symbol_name)
        expect(error.data[:type]).to eq(:symbol_type)
      end

      it "handles error data with nested arrays" do
        array_data = { items: ["item1", "item2", ["nested", "array"]] }
        
        processor.send(:add_validation_error, "array error", array_data, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.data[:items]).to eq(["item1", "item2", ["nested", "array"]])
      end

      it "handles error data with very long strings" do
        long_string = "x" * 10000
        long_data = { description: long_string }
        
        processor.send(:add_validation_error, "long string error", long_data, errors)
        
        expect(errors.size).to eq(1)
        error = errors.first
        
        expect(error.data[:description]).to eq(long_string)
        expect(error.data[:description].length).to eq(10000)
      end

      it "handles circular reference in error data gracefully" do
        circular_data = { name: "test" }
        circular_data[:self_ref] = circular_data
        
        # Should not raise error even with circular reference
        expect { 
          processor.send(:add_validation_error, "circular error", circular_data, errors) 
        }.not_to raise_error
        
        expect(errors.size).to eq(1)
      end
    end
  end

  describe "dependency access behavior" do
    context "when accessing injected dependencies" do
      it "provides protected access to symbol_id_generator" do
        expect(processor.send(:symbol_id_generator)).to be(symbol_id_generator)
      end

      it "provides protected access to provenance_tracker" do
        expect(processor.send(:provenance_tracker)).to be(provenance_tracker)
      end

      it "provides protected access to normalizers" do
        expect(processor.send(:normalizers)).to be(normalizers)
      end

      it "does not provide public access to dependencies" do
        expect(processor).not_to respond_to(:symbol_id_generator)
        expect(processor).not_to respond_to(:provenance_tracker)
        expect(processor).not_to respond_to(:normalizers)
      end
    end

    context "when dependencies are used in concrete processors" do
      let(:concrete_processor_class) do
        Class.new(described_class) do
          def process(raw_data, result)
            # Use dependencies in realistic way
            symbol_id_generator.generate_class_id("TestClass", "class")
            normalizers.name_normalizer.generate_fqname("TestClass", nil)
            "processed_with_dependencies"
          end

          def validate(data)
            !data.nil?
          end
        end
      end

      let(:concrete_processor) do
        concrete_processor_class.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      let(:name_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::NameNormalizer) }

      before do
        allow(symbol_id_generator).to receive(:generate_class_id).with("TestClass", "class").and_return("class_id_123")
        allow(normalizers).to receive(:name_normalizer).and_return(name_normalizer)
        allow(name_normalizer).to receive(:generate_fqname).with("TestClass", nil).and_return("TestClass")
      end

      it "allows concrete processors to use injected dependencies" do
        result = concrete_processor.process([], nil)
        
        expect(result).to eq("processed_with_dependencies")
        expect(symbol_id_generator).to have_received(:generate_class_id).with("TestClass", "class")
        expect(name_normalizer).to have_received(:generate_fqname).with("TestClass", nil)
      end
    end
  end

  describe "inheritance and polymorphism behavior" do
    context "when creating multiple concrete processor types" do
      let(:processor_type_a) do
        Class.new(described_class) do
          def process(raw_data, result)
            "processor_a_result"
          end

          def validate(data)
            data&.key?(:name)
          end
        end.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      let(:processor_type_b) do
        Class.new(described_class) do
          def process(raw_data, result)
            "processor_b_result"
          end

          def validate(data)
            data&.key?(:type)
          end
        end.new(
          symbol_id_generator: symbol_id_generator,
          provenance_tracker: provenance_tracker,
          normalizers: normalizers
        )
      end

      it "allows different concrete processors to behave differently" do
        expect(processor_type_a.process([], nil)).to eq("processor_a_result")
        expect(processor_type_b.process([], nil)).to eq("processor_b_result")
      end

      it "allows different validation logic in concrete processors" do
        data_with_name = { name: "TestName" }
        data_with_type = { type: "TestType" }
        
        expect(processor_type_a.validate(data_with_name)).to be(true)
        expect(processor_type_a.validate(data_with_type)).to be(false)
        
        expect(processor_type_b.validate(data_with_name)).to be(false)
        expect(processor_type_b.validate(data_with_type)).to be(true)
      end

      it "maintains common interface across different processor types" do
        processors = [processor_type_a, processor_type_b]
        
        processors.each do |processor|
          expect(processor).to respond_to(:process)
          expect(processor).to respond_to(:validate)
          expect(processor).to be_a(described_class)
        end
      end
    end
  end
end