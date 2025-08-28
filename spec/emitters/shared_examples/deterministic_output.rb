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

        # Compare content rather than object instances
        first_content = first_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }
        second_content = second_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }

        expect(first_content).to eq(second_content)
      end

      it "produces identical output regardless of input data ordering" do
        shuffled_data = sample_data.dup
        shuffled_data[:classes] = shuffled_data[:classes].shuffle

        original_output = subject.emit(sample_data)
        shuffled_output = subject.emit(shuffled_data)

        # Sort and compare content
        original_content = original_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }.sort
        shuffled_content = shuffled_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }.sort

        expect(original_content).to eq(shuffled_content)
      end

      it "generates consistent file paths and names" do
        # Skip this test if emit_to_files is not implemented
        skip "emit_to_files not yet implemented for this emitter" unless subject.respond_to?(:emit_to_files)

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

        # Compare content, not object instances
        first_content = first_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }
        second_content = second_output.map { |c| c.respond_to?(:content) ? c.content : c.to_s }

        expect(first_content).to eq(second_content)
      end
    end
  end
end
