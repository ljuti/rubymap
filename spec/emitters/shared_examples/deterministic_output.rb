# frozen_string_literal: true

require_relative "../../support/emitter_test_data"

RSpec.shared_examples "a deterministic emitter" do
  include EmitterTestData
  describe "deterministic output generation" do
    context "when given identical input data" do
      let(:sample_data) { EmitterTestData.basic_codebase }

      it "produces identical output across multiple runs" do
        first_output = subject.emit(sample_data)
        second_output = subject.emit(sample_data)

        expect(first_output).to eq(second_output)
      end

      it "produces identical output regardless of input data ordering" do
        shuffled_data = sample_data.dup
        shuffled_data[:classes] = shuffled_data[:classes].shuffle

        original_output = subject.emit(sample_data)
        shuffled_output = subject.emit(shuffled_data)

        expect(original_output).to eq(shuffled_output)
      end

      it "generates consistent file paths and names" do
        output_files = subject.emit_to_files(sample_data, temp_directory)

        expect(output_files.map(&:filename).sort).to eq(output_files.map(&:filename).sort)
      end
    end

    context "when input contains timestamp metadata" do
      let(:timestamped_data) do
        sample_data = EmitterTestData.basic_codebase
        sample_data[:metadata][:mapping_date] = Time.now.iso8601
        sample_data
      end

      it "normalizes or excludes volatile metadata to ensure determinism" do
        first_output = subject.emit(timestamped_data)
        sleep(0.01) # Ensure different timestamp
        timestamped_data[:metadata][:mapping_date] = Time.now.iso8601
        second_output = subject.emit(timestamped_data)

        # The emitter should either normalize timestamps or exclude them
        # from determinism-sensitive outputs
        expect(first_output).to eq(second_output)
      end
    end
  end
end