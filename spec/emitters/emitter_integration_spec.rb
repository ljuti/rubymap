# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emitter_test_data"

RSpec.describe "Emitter Integration", skip: "Integration tests deferred until all emitters implemented" do
  include EmitterTestData

  let(:codebase_data) { rails_application }
  let(:output_dir) { "spec/tmp/integrated_output" }

  before { FileUtils.mkdir_p(output_dir) }
  after { FileUtils.rm_rf(output_dir) }

  describe "multi-format emission" do
    let(:emitter_manager) { Rubymap::EmitterManager.new }

    context "when generating all formats simultaneously" do
      it "produces consistent data across all output formats" do
        json_output = Rubymap::Emitters::JSON.new.emit(codebase_data)
        yaml_output = Rubymap::Emitters::YAML.new.emit(codebase_data)

        json_data = JSON.parse(json_output)
        yaml_data = YAML.safe_load(yaml_output, permitted_classes: [Symbol])

        # Core data should be identical
        expect(json_data["metadata"]["total_classes"]).to eq(yaml_data["metadata"]["total_classes"])
        expect(json_data["classes"].count).to eq(yaml_data["classes"].count)
      end

      it "coordinates file output without conflicts" do
        emitter_manager.emit_all(codebase_data, output_dir)

        expect(File).to exist("#{output_dir}/map.json")
        expect(File).to exist("#{output_dir}/map.yml")
        expect(Dir.exist?("#{output_dir}/chunks")).to be true
        expect(Dir.exist?("#{output_dir}/graphs")).to be true
      end

      it "generates a unified manifest for all outputs" do
        emitter_manager.emit_all(codebase_data, output_dir)

        expect(File).to exist("#{output_dir}/manifest.json")
        manifest = JSON.parse(File.read("#{output_dir}/manifest.json"))

        expect(manifest["outputs"]).to have_key("json")
        expect(manifest["outputs"]).to have_key("yaml")
        expect(manifest["outputs"]).to have_key("llm_chunks")
        expect(manifest["outputs"]).to have_key("graphs")
      end
    end

    context "when using selective emission" do
      it "emits only requested formats" do
        emitter_manager.emit(codebase_data, output_dir, formats: [:json, :llm])

        expect(File).to exist("#{output_dir}/map.json")
        expect(Dir.exist?("#{output_dir}/chunks")).to be true
        expect(File.exist?("#{output_dir}/map.yml")).to be false
        expect(Dir.exist?("#{output_dir}/graphs")).to be false
      end

      it "supports custom configuration per format" do
        configs = {
          json: {pretty: true},
          llm: {chunk_size: 1000},
          graphviz: {theme: :dark}
        }

        emitter_manager.emit(codebase_data, output_dir,
          formats: [:json, :llm, :graphviz],
          configs: configs)

        json_content = File.read("#{output_dir}/map.json")
        expect(json_content).to include("\n  ")  # Pretty printed

        chunks = Dir.glob("#{output_dir}/chunks/*.md")
        chunk_content = File.read(chunks.first)
        expect(chunk_content.length).to be < 1500  # Respects chunk size
      end
    end
  end

  describe "incremental updates" do
    let(:initial_data) { basic_codebase }
    let(:updated_data) do
      data = basic_codebase.deep_dup
      data[:classes] << {
        fqname: "NewClass",
        type: "class",
        file: "lib/new_class.rb"
      }
      data
    end

    context "when performing incremental emission" do
      before do
        # Initial emission
        Rubymap::EmitterManager.new.emit_all(initial_data, output_dir)
      end

      it "detects and emits only changed content" do
        manager = Rubymap::EmitterManager.new
        result = manager.emit_incremental(updated_data, output_dir)

        expect(result[:updated_files]).to include("chunks/NewClass.md")
        expect(result[:unchanged_files].count).to be > 0
      end

      it "updates manifest with delta information" do
        manager = Rubymap::EmitterManager.new
        manager.emit_incremental(updated_data, output_dir)

        manifest = JSON.parse(File.read("#{output_dir}/manifest.json"))
        expect(manifest).to have_key("last_update")
        expect(manifest).to have_key("delta")
        expect(manifest["delta"]["added_classes"]).to include("NewClass")
      end

      it "maintains consistency across all formats during updates" do
        manager = Rubymap::EmitterManager.new
        manager.emit_incremental(updated_data, output_dir)

        json_data = JSON.parse(File.read("#{output_dir}/map.json"))
        yaml_data = YAML.safe_load_file("#{output_dir}/map.yml", permitted_classes: [Symbol])

        expect(json_data["classes"].map { |c| c["fqname"] }).to include("NewClass")
        expect(yaml_data["classes"].map { |c| c["fqname"] }).to include("NewClass")
      end
    end
  end

  describe "cross-format linking" do
    context "when generating documentation with cross-references" do
      before do
        Rubymap::EmitterManager.new.emit_all(codebase_data, output_dir)
      end

      it "creates consistent references between LLM chunks and graphs" do
        chunk_files = Dir.glob("#{output_dir}/chunks/*.md")
        chunk_content = File.read(chunk_files.first)

        # Should reference graph files
        expect(chunk_content).to match(/See graph: .*\.dot/)
      end

      it "maintains bidirectional links between formats" do
        json_data = JSON.parse(File.read("#{output_dir}/map.json"))

        # JSON should reference chunk files
        user_class = json_data["classes"].find { |c| c["fqname"] == "User" }
        expect(user_class).to have_key("chunk_ref")
        expect(user_class["chunk_ref"]).to match(/chunks\/.*\.md/)
      end

      it "includes format-specific URLs in manifest" do
        manifest = JSON.parse(File.read("#{output_dir}/manifest.json"))

        expect(manifest["outputs"]["llm_chunks"]).to have_key("index_url")
        expect(manifest["outputs"]["graphs"]).to have_key("viewer_url")
      end
    end
  end

  describe "error recovery and atomicity" do
    context "when one emitter fails" do
      it "continues with other formats and logs failures" do
        # Simulate a failure in YAML emitter
        allow_any_instance_of(Rubymap::Emitters::YAML).to receive(:emit).and_raise("YAML error")

        manager = Rubymap::EmitterManager.new
        result = manager.emit_all(codebase_data, output_dir, continue_on_error: true)

        expect(File).to exist("#{output_dir}/map.json")  # JSON still created
        expect(File.exist?("#{output_dir}/map.yml")).to be false  # YAML failed
        expect(result[:errors]).to include("YAML emission failed: YAML error")
      end

      it "supports transactional emission with rollback" do
        manager = Rubymap::EmitterManager.new

        # Simulate failure midway
        call_count = 0
        allow_any_instance_of(Rubymap::Emitters::GraphViz).to receive(:emit) do
          call_count += 1
          raise "GraphViz error" if call_count == 1
        end

        expect do
          manager.emit_all(codebase_data, output_dir, transactional: true)
        end.to raise_error("GraphViz error")

        # Should rollback all outputs
        expect(Dir.empty?(output_dir)).to be true
      end
    end

    context "when handling concurrent emission" do
      it "safely emits formats in parallel without conflicts" do
        manager = Rubymap::EmitterManager.new(parallel: true)

        start_time = Time.now
        manager.emit_all(codebase_data, output_dir)
        duration = Time.now - start_time

        # Should complete faster than sequential
        expect(duration).to be < 2.0

        # All outputs should be present and valid
        expect(File).to exist("#{output_dir}/map.json")
        expect(File).to exist("#{output_dir}/map.yml")
        expect(Dir.exist?("#{output_dir}/chunks")).to be true
        expect(Dir.exist?("#{output_dir}/graphs")).to be true
      end

      it "maintains thread safety for shared resources" do
        manager = Rubymap::EmitterManager.new(parallel: true)

        # Run multiple times to check for race conditions
        3.times do |i|
          FileUtils.rm_rf(output_dir)
          FileUtils.mkdir_p(output_dir)

          manager.emit_all(codebase_data, output_dir)

          manifest = JSON.parse(File.read("#{output_dir}/manifest.json"))
          expect(manifest["outputs"].keys.count).to eq(4)  # All formats present
        end
      end
    end
  end

  describe "packaging and distribution" do
    context "when creating distribution packages" do
      it "bundles all outputs into a distributable archive" do
        manager = Rubymap::EmitterManager.new
        manager.emit_all(codebase_data, output_dir)

        package = manager.create_package(output_dir, "#{output_dir}/package.zip")

        expect(File).to exist("#{output_dir}/package.zip")
        expect(package[:size_mb]).to be > 0
        expect(package[:file_count]).to be > 5
      end

      it "generates checksums for all output files" do
        manager = Rubymap::EmitterManager.new
        manager.emit_all(codebase_data, output_dir)

        checksums_file = "#{output_dir}/checksums.sha256"
        expect(File).to exist(checksums_file)

        checksums = File.read(checksums_file)
        expect(checksums).to include("map.json")
        expect(checksums).to include("map.yml")
        expect(checksums).to match(/[a-f0-9]{64}/)  # SHA256 hashes
      end

      it "creates a distribution README" do
        manager = Rubymap::EmitterManager.new
        manager.emit_all(codebase_data, output_dir, include_readme: true)

        expect(File).to exist("#{output_dir}/README.md")
        readme = File.read("#{output_dir}/README.md")

        expect(readme).to include("Generated by Rubymap")
        expect(readme).to include("Output Formats")
        expect(readme).to include("Usage Instructions")
      end
    end
  end

  describe "performance benchmarking" do
    context "when processing various codebase sizes" do
      [10, 50, 100].each do |size|
        it "scales linearly for #{size} classes" do
          data = massive_codebase(class_count: size)
          manager = Rubymap::EmitterManager.new

          start_time = Time.now
          manager.emit_all(data, output_dir)
          duration = Time.now - start_time

          # Should scale roughly linearly
          expected_time = size * 0.05  # 50ms per class as baseline
          expect(duration).to be < expected_time
        end
      end
    end

    it "provides performance metrics in the manifest" do
      manager = Rubymap::EmitterManager.new
      manager.emit_all(codebase_data, output_dir)

      manifest = JSON.parse(File.read("#{output_dir}/manifest.json"))

      expect(manifest["performance"]).to include("total_duration_ms")
      expect(manifest["performance"]).to include("format_durations")
      expect(manifest["performance"]["format_durations"]).to have_key("json")
      expect(manifest["performance"]["format_durations"]).to have_key("llm_chunks")
    end
  end
end
