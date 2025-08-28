# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emitter_test_data"
require_relative "shared_examples/deterministic_output"
require_relative "shared_examples/security_features"

RSpec.describe "JSON Emitter", skip: "JSON emitter implementation deferred" do
  include EmitterTestData
  # This tests the behavior of generating structured JSON output for machine consumption
  # Focus: Data fidelity, structure consistency, performance, and integration capabilities

  subject { Rubymap::Emitters::JSON.new }
  let(:codebase_data) { EmitterTestData.rails_application }

  it_behaves_like "a deterministic emitter", :json
  it_behaves_like "a security-conscious emitter"

  describe "structured data generation" do
    context "when emitting basic codebase information" do
      let(:simple_data) { EmitterTestData.basic_codebase }

      it "produces valid JSON that can be parsed" do
        json_output = subject.emit(simple_data)

        expect { JSON.parse(json_output) }.not_to raise_error
      end

      it "preserves all essential metadata in the output" do
        json_output = subject.emit(simple_data)
        parsed = JSON.parse(json_output)

        expect(parsed["metadata"]["project_name"]).to eq("TestApp")
        expect(parsed["metadata"]["total_classes"]).to eq(3)
        expect(parsed["metadata"]["ruby_version"]).to eq("3.2.0")
      end

      it "maintains complete fidelity of class information" do
        json_output = subject.emit(simple_data)
        parsed = JSON.parse(json_output)

        user_class = parsed["classes"].find { |c| c["fqname"] == "User" }
        expect(user_class["superclass"]).to eq("ApplicationRecord")
        expect(user_class["instance_methods"]).to include("save", "full_name", "active?")
        expect(user_class["file"]).to eq("app/models/user.rb")
      end

      it "preserves relationship graph structure" do
        json_output = subject.emit(simple_data)
        parsed = JSON.parse(json_output)

        inheritance_graph = parsed["graphs"]["inheritance"]
        user_inheritance = inheritance_graph.find { |rel| rel["from"] == "User" }

        expect(user_inheritance["to"]).to eq("ApplicationRecord")
        expect(user_inheritance["type"]).to eq("inherits")
      end
    end

    context "when handling complex Rails applications" do
      it "structures Rails-specific information appropriately" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        user_model = parsed["classes"].find { |c| c["fqname"] == "User" }
        expect(user_model["associations"]).to be_a(Hash)
        expect(user_model["validations"]).to be_an(Array)
        expect(user_model["callbacks"]).to be_an(Array)
      end

      it "maintains controller action information" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        controller = parsed["classes"].find { |c| c["fqname"] == "UsersController" }
        expect(controller["instance_methods"]).to include("index", "show", "create", "update", "destroy")
        expect(controller["before_actions"]).to include("authenticate_user!")
      end

      it "preserves service layer dependencies" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        service = parsed["classes"].find { |c| c["fqname"] == "UserService" }
        expect(service["dependencies"]).to include("User", "EmailService")
      end
    end

    context "when handling metrics and quality data" do
      it "includes all calculated metrics in the output" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        user_model = parsed["classes"].find { |c| c["fqname"] == "User" }
        metrics = user_model["metrics"]

        expect(metrics["complexity_score"]).to eq(4.2)
        expect(metrics["test_coverage"]).to eq(95.0)
        expect(metrics["lines_of_code"]).to eq(150)
      end

      it "maintains precision for floating point metrics" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        # Ensure no precision loss in numeric data
        user_model = parsed["classes"].find { |c| c["fqname"] == "User" }
        expect(user_model["metrics"]["complexity_score"]).to be_within(0.01).of(4.2)
      end
    end
  end

  describe "output format and structure behavior" do
    context "when generating standard JSON schema" do
      it "follows a consistent schema structure across different inputs" do
        simple_output = JSON.parse(subject.emit(EmitterTestData.basic_codebase))
        complex_output = JSON.parse(subject.emit(EmitterTestData.rails_application))

        # Both should have the same top-level structure
        expect(simple_output.keys.sort).to eq(complex_output.keys.sort)
        expect(simple_output["metadata"].keys).to all(be_a(String))
        expect(complex_output["metadata"].keys).to all(be_a(String))
      end

      it "uses consistent data types for equivalent fields" do
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        parsed["classes"].each do |klass|
          expect(klass["fqname"]).to be_a(String)
          expect(klass["instance_methods"]).to be_an(Array)
          expect(klass["line"]).to be_a(Integer) if klass["line"]
        end
      end

      it "handles null and empty values appropriately" do
        data_with_nulls = EmitterTestData.malformed_codebase
        json_output = subject.emit(data_with_nulls)
        parsed = JSON.parse(json_output)

        # Should handle null values without breaking JSON structure
        expect(parsed).to have_key("classes")
        expect(parsed["classes"]).to be_an(Array)
      end
    end

    context "when configuring output format options" do
      it "supports pretty-printed JSON for human readability" do
        subject.configure(pretty_print: true)
        json_output = subject.emit(codebase_data)

        expect(json_output).to include("  ") # Contains indentation
        expect(json_output).to include("\n") # Contains newlines
      end

      it "supports compact JSON for minimal file size" do
        subject.configure(pretty_print: false)
        json_output = subject.emit(codebase_data)

        expect(json_output).not_to include("  ") # No extra indentation
        expect(json_output.count("\n")).to be <= 1 # Minimal newlines
      end

      it "allows custom schema version specification" do
        subject.configure(schema_version: "2.0")
        json_output = subject.emit(codebase_data)
        parsed = JSON.parse(json_output)

        expect(parsed["schema_version"]).to eq("2.0")
      end
    end
  end

  describe "file organization and partitioning" do
    let(:temp_directory) { "spec/tmp/json_emitter" }

    before { FileUtils.mkdir_p(temp_directory) }
    after { FileUtils.rm_rf(temp_directory) }

    context "when emitting to file system" do
      it "creates a logical directory structure" do
        subject.emit_to_files(codebase_data, temp_directory)

        expect(File).to exist("#{temp_directory}/rubymap.json")
        expect(File).to exist("#{temp_directory}/classes.json")
        expect(File).to exist("#{temp_directory}/graphs.json")
        expect(File).to exist("#{temp_directory}/metadata.json")
      end

      it "partitions large datasets into manageable files" do
        large_dataset = EmitterTestData.massive_codebase
        subject.emit_to_files(large_dataset, temp_directory)

        class_files = Dir.glob("#{temp_directory}/classes_*.json")
        expect(class_files.size).to be > 1 # Should be partitioned

        # Each partition should be reasonably sized
        class_files.each do |file|
          file_size_mb = File.size(file) / 1024.0 / 1024.0
          expect(file_size_mb).to be < 10 # Less than 10MB per file
        end
      end

      it "creates a manifest file describing the output structure" do
        subject.emit_to_files(codebase_data, temp_directory)
        manifest = JSON.parse(File.read("#{temp_directory}/manifest.json"))

        expect(manifest).to have_key("files")
        expect(manifest).to have_key("schema_version")
        expect(manifest).to have_key("generation_info")

        expect(manifest["files"]).to include(
          hash_including("filename" => "classes.json", "type" => "classes")
        )
      end
    end

    context "when handling incremental updates" do
      let(:updated_data) do
        data = codebase_data.dup
        data[:classes] << EmitterTestData.basic_service_class
        data[:metadata][:total_classes] = 6
        data
      end

      it "detects which files need regeneration" do
        # Initial generation
        subject.emit_to_files(codebase_data, temp_directory)
        initial_mtime = File.mtime("#{temp_directory}/classes.json")

        sleep(0.01) # Ensure different timestamp

        # Update with new data
        changed_files = subject.emit_to_files(updated_data, temp_directory, incremental: true)

        expect(changed_files).to include("classes.json")
        expect(changed_files).to include("metadata.json")
        expect(File.mtime("#{temp_directory}/classes.json")).to be > initial_mtime
      end

      it "preserves unchanged files during incremental updates" do
        subject.emit_to_files(codebase_data, temp_directory)
        graphs_mtime = File.mtime("#{temp_directory}/graphs.json")

        sleep(0.01)

        # Update that doesn't affect graphs
        data_copy = codebase_data.dup
        data_copy[:metadata][:project_name] = "UpdatedApp"
        subject.emit_to_files(data_copy, temp_directory, incremental: true)

        # Graphs file should be unchanged
        expect(File.mtime("#{temp_directory}/graphs.json")).to eq(graphs_mtime)
      end
    end
  end

  describe "performance and scalability characteristics" do
    context "when processing large datasets" do
      let(:large_dataset) { EmitterTestData.massive_codebase }

      it "completes emission within reasonable time limits" do
        start_time = Time.now
        subject.emit(large_dataset)
        duration = Time.now - start_time

        expect(duration).to be < 5.0 # Should complete within 5 seconds
      end

      it "maintains memory efficiency during processing" do
        initial_memory = memory_usage
        subject.emit(large_dataset)
        final_memory = memory_usage

        # Memory growth should be reasonable (less than 100MB for 1000 classes)
        memory_growth_mb = (final_memory - initial_memory) / 1024.0 / 1024.0
        expect(memory_growth_mb).to be < 100
      end

      it "supports streaming emission for very large datasets" do
        subject.configure(streaming: true)

        chunks = []
        subject.emit_stream(large_dataset) do |chunk|
          chunks << chunk
          expect(chunk).to be_a(String)
          expect { JSON.parse(chunk) }.not_to raise_error
        end

        expect(chunks.size).to be > 1
      end
    end

    context "when handling concurrent access" do
      it "produces thread-safe output when accessed concurrently" do
        threads = 3.times.map do
          Thread.new do
            subject.emit(codebase_data)
          end
        end

        outputs = threads.map(&:value)

        # All outputs should be identical
        expect(outputs.uniq.size).to eq(1)
        expect { JSON.parse(outputs.first) }.not_to raise_error
      end
    end
  end

  describe "error handling and validation" do
    context "when encountering invalid input data" do
      it "handles missing required fields gracefully" do
        invalid_data = {classes: [{type: "class"}]} # Missing fqname

        expect { subject.emit(invalid_data) }.not_to raise_error

        json_output = subject.emit(invalid_data)
        parsed = JSON.parse(json_output)

        expect(parsed["errors"]).to include("Missing required field: fqname")
      end

      it "validates data structure before emission" do
        invalid_data = {classes: "not_an_array"}

        expect { subject.emit(invalid_data) }.not_to raise_error

        json_output = subject.emit(invalid_data)
        parsed = JSON.parse(json_output)

        expect(parsed["errors"]).to include(match(/Invalid data structure/))
      end

      it "continues processing despite individual record errors" do
        mixed_data = {
          classes: [
            EmitterTestData.basic_user_class,
            {type: "class"}, # Invalid - missing fqname
            EmitterTestData.basic_service_class
          ]
        }

        json_output = subject.emit(mixed_data)
        parsed = JSON.parse(json_output)

        # Should include valid classes
        expect(parsed["classes"].size).to eq(2)
        expect(parsed["classes"].map { |c| c["fqname"] }).to include("User", "UserService")

        # Should report errors for invalid records
        expect(parsed["errors"]).not_to be_empty
      end
    end

    context "when encountering file system issues" do
      let(:readonly_directory) { "spec/tmp/readonly" }

      before do
        FileUtils.mkdir_p(readonly_directory)
        File.chmod(0o444, readonly_directory) # Read-only
      end

      after { FileUtils.rm_rf(readonly_directory) }

      it "provides clear error messages for write permission issues" do
        expect do
          subject.emit_to_files(codebase_data, readonly_directory)
        end.to raise_error(Rubymap::Emitters::FileSystemError, /Permission denied/)
      end

      it "attempts recovery strategies for partial write failures" do
        allow(File).to receive(:write).and_raise(Errno::ENOSPC).once # Disk full
        allow(File).to receive(:write).and_call_original # Then succeed

        expect { subject.emit_to_files(codebase_data, temp_directory) }.not_to raise_error
      end
    end
  end

  private

  def memory_usage
    GC.start
    `ps -o rss= -p #{Process.pid}`.to_i
  end
end
