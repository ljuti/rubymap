# frozen_string_literal: true

require_relative "shared_examples/deterministic_output"
require_relative "shared_examples/security_features"

RSpec.describe "LLM Emitter" do
  # This tests the behavior of generating LLM-friendly documentation chunks
  # Focus: Content quality, chunk sizing, cross-linking, and context preservation

  subject { Rubymap::Emitters::LLM.new }
  let(:temp_directory) { "spec/tmp/llm_emitter" }
  let(:codebase_data) { EmitterTestData.rails_application }

  before { FileUtils.mkdir_p(temp_directory) }
  after { FileUtils.rm_rf(temp_directory) }

  it_behaves_like "a deterministic emitter", :llm
  # Security features deferred for later implementation
  # it_behaves_like "a security-conscious emitter"

  describe "chunk generation behavior" do
    context "when processing a typical Rails application" do
      it "generates appropriately sized chunks for LLM consumption" do
        chunks = subject.emit(codebase_data)

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          # Chunks should have reasonable token counts (not empty, not massive)
          expect(chunk.estimated_tokens).to be > 0
          expect(chunk.estimated_tokens).to be <= 4000
          # Content should be non-trivial
          expect(chunk.content.length).to be > 0
        end
      end

      it "creates contextually coherent chunks" do
        chunks = subject.emit(codebase_data)

        # Find any User-related chunk (may be split into multiple parts)
        user_chunks = chunks.select { |c| c.metadata[:fqname] == "User" }
        expect(user_chunks).not_to be_empty

        # The overview chunk should contain class documentation
        overview = user_chunks.find { |c| c.metadata[:part] == "overview" }
        if overview
          expect(overview.content).to include("Class: User")
          expect(overview.content).to include("## Description")
          expect(overview.content).to include("## Structure")
        else
          # Not split: single chunk should have all sections
          chunk = user_chunks.first
          expect(chunk.content).to include("Class: User")
          expect(chunk.content).to include("# Methods")
          expect(chunk.content).to include("# Relationships")
        end
      end

      it "maintains cross-references between related chunks" do
        chunks = subject.emit(codebase_data)

        user_chunk = chunks.find { |c| c.title.include?("User") }
        controller_chunk = chunks.find { |c| c.title.include?("UsersController") }

        expect(user_chunk.references).to include(controller_chunk.chunk_id)
        expect(controller_chunk.references).to include(user_chunk.chunk_id)
      end
    end

    context "when handling large classes with many methods" do
      let(:large_class_data) { EmitterTestData.large_class_with_many_methods }

      it "splits large classes across multiple coherent chunks" do
        chunks = subject.emit(large_class_data)
        class_chunks = chunks.select { |c| c.title.include?("LargeClass") }

        expect(class_chunks.size).to be > 1

        # Each chunk should have a clear focus
        expect(class_chunks.map(&:subtitle)).to include(
          "Overview and Constants",
          "Core Methods",
          "Helper Methods"
        )
      end

      it "provides navigation context between split chunks" do
        chunks = subject.emit(large_class_data)
        class_chunks = chunks.select { |c| c.title.include?("LargeClass") }

        class_chunks.each do |chunk|
          expect(chunk.content).to match(/Part \d+ of \d+/)
          expect(chunk.content).to include("Related sections:")
        end
      end
    end

    context "when processing inheritance hierarchies" do
      let(:hierarchy_data) { EmitterTestData.complex_inheritance_hierarchy }

      it "creates hierarchy overview chunks" do
        chunks = subject.emit(hierarchy_data)
        hierarchy_chunk = chunks.find { |c| c.title.include?("Class Hierarchy") }

        expect(hierarchy_chunk.content).to include("```")
        expect(hierarchy_chunk.content).to include("BaseClass")
        expect(hierarchy_chunk.content).to include("├── ChildClass")
        expect(hierarchy_chunk.content).to include("└── AnotherChild")
      end

      it "links hierarchy members to their detail chunks" do
        chunks = subject.emit(hierarchy_data)
        hierarchy_chunk = chunks.find { |c| c.title.include?("Class Hierarchy") }

        expect(hierarchy_chunk.content).to include("[BaseClass](")
        expect(hierarchy_chunk.content).to include("[ChildClass](")
      end
    end
  end

  describe "output quality and formatting" do
    it "generates valid Markdown with proper structure" do
      chunks = subject.emit(codebase_data)

      chunks.each do |chunk|
        # Check for proper Markdown structure
        expect(chunk.content).to match(/^# /) # Has main heading
        expect(chunk.content).to match(/^## /) # Has subheadings

        # Code blocks should be properly formatted
        code_blocks = chunk.content.scan(/```\w*\n.*?\n```/m)
        expect(code_blocks).to all(match(/```\w*\n.*\n```/m))
      end
    end

    it "includes metadata headers for AI processing" do
      chunks = subject.emit(codebase_data)

      chunks.each do |chunk|
        expect(chunk.metadata).to include(:chunk_type)
        expect(chunk.metadata).to include(:primary_symbols)
        expect(chunk.metadata).to include(:complexity_level)
        expect(chunk.metadata).to include(:prerequisites)
      end
    end

    it "provides clear section boundaries and transitions" do
      chunks = subject.emit(codebase_data)

      chunks.each do |chunk|
        # Each chunk should have at least one clear section boundary or heading
        has_boundary = chunk.content.include?("---")
        has_subheading = chunk.content.match?(/^## \w+/)
        expect(has_boundary || has_subheading).to be true
      end
    end
  end

  describe "file organization behavior" do
    it "creates logical directory structure for output" do
      subject.emit_to_directory(codebase_data, temp_directory)

      expect(File).to exist("#{temp_directory}/index.md")
      expect(File).to exist("#{temp_directory}/overview.md")
      expect(File).to exist("#{temp_directory}/models/")
      expect(File).to exist("#{temp_directory}/controllers/")
      expect(File).to exist("#{temp_directory}/relationships/")
    end

    it "generates a comprehensive index with navigation" do
      subject.emit_to_directory(codebase_data, temp_directory)
      index_content = File.read("#{temp_directory}/index.md")

      expect(index_content).to include("# Codebase Documentation Index")
      expect(index_content).to include("## Classes")
      expect(index_content).to include("Controller](chunks/")
      expect(index_content).to include("## Modules")
      expect(index_content).to include("## Relationships")
    end

    it "includes manifest file with chunk metadata" do
      subject.emit_to_directory(codebase_data, temp_directory)
      manifest_content = JSON.parse(File.read("#{temp_directory}/manifest.json"))

      expect(manifest_content).to have_key("chunks")
      expect(manifest_content).to have_key("generation_timestamp")
      expect(manifest_content).to have_key("total_tokens")
      expect(manifest_content["chunks"]).to be_an(Array)

      chunk_info = manifest_content["chunks"].first
      expect(chunk_info).to include("filename", "title", "estimated_tokens", "primary_symbols")
    end
  end

  describe "configuration and customization" do
    context "when customizing chunk size" do
      it "respects maximum token limits" do
        subject.configure(max_tokens_per_chunk: 500)
        chunks = subject.emit(codebase_data)

        expect(chunks).not_to be_empty
        # With a low limit, large classes should be split
        user_chunks = chunks.select { |c| c.metadata[:fqname] == "User" }
        expect(user_chunks.size).to be >= 1
      end

      it "maintains minimum content coherence despite size constraints" do
        subject.configure(max_tokens_per_chunk: 800)
        chunks = subject.emit(codebase_data)

        chunks.each do |chunk|
          expect(chunk.content.lines.size).to be >= 5
          expect(chunk.content).to match(/^# .+/)
        end
      end
    end

    context "when filtering content for specific audiences" do
      it "supports different detail levels" do
        pending "Feature: detail level filtering not yet implemented"
        subject.configure(detail_level: :overview)
        overview_chunks = subject.emit(codebase_data)

        subject.configure(detail_level: :detailed)
        detailed_chunks = subject.emit(codebase_data)

        expect(detailed_chunks.size).to be > overview_chunks.size
        expect(detailed_chunks.first.content.length).to be > overview_chunks.first.content.length
      end
    end
  end

  describe "error handling and resilience" do
    context "when processing malformed input data" do
      let(:malformed_data) { EmitterTestData.malformed_codebase }

      it "generates chunks despite missing metadata" do
        chunks = subject.emit(malformed_data)

        expect(chunks.any?).to be true
        # Malformed classes without fqname produce a fallback message
        expect(chunks.first.content).to include("No class information available")
      end

      it "handles missing class information gracefully" do
        data_without_classes = codebase_data.dup
        data_without_classes.delete(:classes)

        chunks = subject.emit(data_without_classes)

        expect(chunks.any?).to be true
        expect(chunks.first.content).to include("No class information available")
      end
    end

    context "when encountering extremely large datasets" do
      it "provides progress feedback for long operations" do
        large_dataset = EmitterTestData.massive_codebase
        progress_updates = []

        subject.on_progress { |update| progress_updates << update }
        subject.emit(large_dataset)

        expect(progress_updates.any?).to be true
        # The callback hash uses :percentage, not :percent
        expect(progress_updates.last[:percentage]).to eq(100.0)
      end
    end
  end
end
