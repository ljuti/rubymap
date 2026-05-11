# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Emitter::EmitterManager do
  let(:manager) { described_class.new }
  let(:output_dir) { "tmp/emitter_manager_test" }
  let(:test_data) do
    {
      classes: [
        {fqname: "User", type: "class", superclass: "ApplicationRecord",
         file: "app/models/user.rb", line: 1, instance_methods: %w[name email],
         class_methods: [], dependencies: [], mixins: [],
         documentation: "User model", metrics: {complexity_score: 3}}
      ],
      modules: [],
      methods: [],
      metadata: {project_name: "TestProject", total_classes: 1, total_methods: 2, ruby_version: RUBY_VERSION},
      graphs: {inheritance: [], dependencies: []}
    }
  end

  before do
    FileUtils.rm_rf(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe "#emit" do
    it "emits LLM format to the specified directory" do
      result = manager.emit(test_data, output_dir, formats: [:llm])

      expect(result.keys).to include(:llm)
      expect(Dir).to exist(output_dir)
      files = result[:llm]
      expect(files).to be_an(Array)
      expect(files).not_to be_empty
    end

    it "raises on unsupported format" do
      expect {
        manager.emit(test_data, output_dir, formats: [:xml])
      }.to raise_error(ArgumentError, /Unknown format/)
    end

    it "creates output directory if it does not exist" do
      FileUtils.rm_rf(output_dir)
      manager.emit(test_data, output_dir, formats: [:llm])
      expect(Dir).to exist(output_dir)
    end
  end

  describe "#emit_all" do
    it "emits LLM format and generates manifest" do
      result = manager.emit_all(test_data, output_dir, formats: [:llm])

      expect(result[:formats]).to include(:llm)
      expect(result[:manifest]).to be_a(String)
      expect(File).to exist(result[:manifest])
      manifest = JSON.parse(File.read(result[:manifest]))
      expect(manifest["outputs"]).to have_key("llm")
    end

    it "handles empty source gracefully" do
      empty_data = {classes: [], modules: [], methods: [], metadata: {
        project_name: "Empty", total_classes: 0, total_methods: 0
      }, graphs: {}}

      result = manager.emit_all(empty_data, output_dir, formats: [:llm])
      expect(result[:formats]).to include(:llm)
    end
  end
end
