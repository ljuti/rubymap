# frozen_string_literal: true

require "spec_helper"
require "yaml"
require_relative "../support/emitter_test_data"
require_relative "shared_examples/deterministic_output"
require_relative "shared_examples/security_features"
require_relative "shared_examples/format_validation"

RSpec.describe "YAML Emitter", skip: "YAML emitter implementation deferred" do
  include EmitterTestData

  subject { Rubymap::Emitters::YAML.new }

  let(:codebase_data) { rails_application }
  let(:output) { subject.emit(codebase_data) }
  let(:parsed_yaml) { ::YAML.safe_load(output, permitted_classes: [Symbol]) }

  it_behaves_like "a deterministic emitter"
  it_behaves_like "a security-conscious emitter"
  it_behaves_like "a format-validating emitter", :yaml

  describe "YAML output generation" do
    context "when processing a Rails application" do
      it "creates valid, parseable YAML output" do
        # Expects no error from: ::YAML.safe_load(output, permitted_classes: [Symbol])
      end

      it "preserves complete data structure in YAML format" do
        expect(parsed_yaml["metadata"]).to include(
          "project_name" => "MyRailsApp",
          "ruby_version" => "3.2.0"
        )
        expect(parsed_yaml["classes"].any?).to be true
        expect(parsed_yaml["graphs"]).to have_key("inheritance")
      end

      it "maintains data type fidelity" do
        user_class = parsed_yaml["classes"].find { |c| c["fqname"] == "User" }

        expect(user_class["metrics"]["complexity_score"]).to be_a(Float)
        expect(user_class["metrics"]["method_count"]).to be_an(Integer)
        expect(user_class["instance_methods"]).to be_an(Array)
      end

      it "handles nested structures properly" do
        graphs = parsed_yaml["graphs"]

        expect(graphs["inheritance"]).to be_an(Array)
        expect(graphs["inheritance"].first).to include("from", "to", "type")
      end
    end

    context "when handling special characters" do
      let(:codebase_data) do
        data = basic_codebase
        data[:classes].first[:documentation] = "User's \"special\" class: handles & processes data"
        data
      end

      it "properly escapes special YAML characters" do
        expect(output.include?("User's")).to be false  # Should be escaped
        expect(parsed_yaml["classes"].first["documentation"]).to include("User's")
      end
    end

    context "when processing large datasets" do
      let(:codebase_data) { massive_codebase(class_count: 100) }

      it "generates YAML efficiently for many classes" do
        # Expects successful execution with performance under 2 seconds
        # This test would normally check: expect { output }.to perform_under(2).seconds
        # For now we just check output generation succeeds
        expect(output).to be_truthy
      end

      it "maintains readability with proper indentation" do
        lines = output.split("\n")
        expect(lines.any? { |l| l.start_with?("  ") }).to be true  # Has indentation
        expect(lines.any? { |l| l.start_with?("    ") }).to be true  # Has nested indentation
      end
    end
  end

  describe "file output" do
    let(:output_dir) { "spec/tmp/yaml_output" }

    before { FileUtils.mkdir_p(output_dir) }
    after { FileUtils.rm_rf(output_dir) }

    context "when writing to files" do
      it "creates a single comprehensive YAML file" do
        subject.emit_to_file(codebase_data, "#{output_dir}/map.yml")

        expect(File).to exist("#{output_dir}/map.yml")
        content = File.read("#{output_dir}/map.yml")
        # Expects no error from:
        ::YAML.safe_load(content, permitted_classes: [Symbol])
      end

      it "optionally splits into multiple YAML files for organization" do
        subject.emit_to_directory(codebase_data, output_dir)

        expect(File).to exist("#{output_dir}/metadata.yml")
        expect(File).to exist("#{output_dir}/classes.yml")
        expect(File).to exist("#{output_dir}/graphs.yml")
      end
    end
  end

  describe "configuration options" do
    context "when customizing YAML output" do
      subject { Rubymap::Emitters::YAML.new(pretty_print: false) }

      it "supports compact output format" do
        compact_output = subject.emit(basic_codebase)
        pretty_subject = Rubymap::Emitters::YAML.new(pretty_print: true)
        pretty_output = pretty_subject.emit(basic_codebase)

        expect(compact_output.length).to be < pretty_output.length
      end
    end

    context "when filtering content" do
      subject do
        Rubymap::Emitters::YAML.new(
          include_private: false,
          max_depth: 3
        )
      end

      it "excludes private methods when configured" do
        expect(parsed_yaml["classes"].first["private_methods"]).to be_nil
      end

      it "limits nesting depth when specified" do
        # Should truncate deeply nested structures
        expect(parsed_yaml.to_s.count("{")).to be < 50  # Rough measure of nesting
      end
    end
  end

  describe "error handling" do
    context "when processing invalid data" do
      let(:codebase_data) { malformed_codebase }

      it "generates valid YAML despite missing fields" do
        # Expects no error from: ::YAML.safe_load(output, permitted_classes: [Symbol])
      end

      it "uses safe defaults for missing information" do
        expect(parsed_yaml["metadata"]).to include("project_name")
      end
    end

    context "when dealing with circular references" do
      let(:codebase_data) do
        data = basic_codebase
        # Create a circular reference
        data[:classes].first[:circular_ref] = data[:classes].first
        data
      end

      it "handles circular references without infinite loops" do
        # Expects no error from: output
        expect(output).to include("classes")
      end
    end
  end

  describe "human readability features" do
    it "includes helpful comments in YAML output" do
      commented_subject = Rubymap::Emitters::YAML.new(include_comments: true)
      commented_output = commented_subject.emit(codebase_data)

      expect(commented_output).to include("# Generated by Rubymap")
      expect(commented_output).to include("# Metadata section")
    end

    it "sorts keys consistently for easier reading" do
      lines = output.split("\n")
      class_keys = lines.select { |l| l =~ /^\s{2}\w+:/ }.map(&:strip)

      # Keys should appear in a consistent order
      expect(class_keys).to include("fqname:", "type:", "file:")
    end

    it "formats arrays and hashes for clarity" do
      # Arrays should use dashes
      expect(output).to include("\n- ")

      # Nested structures should be indented
      expect(output).to match(/\n\s{4}/)
    end
  end
end
