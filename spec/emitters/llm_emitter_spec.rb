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
      xit "generates appropriately sized chunks for LLM consumption" do
        # TODO: Fix token estimation for proper chunk sizing
        chunks = subject.emit(codebase_data)

        chunks.each do |chunk|
          expect(chunk.estimated_tokens).to be_between(500, 4000)
          expect(chunk.content.length).to be_between(2000, 8000) # Rough character estimate
        end
      end

      xit "creates contextually coherent chunks" do
        # TODO: Update test expectations for split chunk format
        chunks = subject.emit(codebase_data)
        user_model_chunk = chunks.find { |c| c.title.include?("User Model") }

        expect(user_model_chunk.content).to include("class User")
        expect(user_model_chunk.content).to include("# Methods")
        expect(user_model_chunk.content).to include("# Relationships")
        expect(user_model_chunk.content).to include("# File Location")
      end

      it "maintains cross-references between related chunks" do
        chunks = subject.emit(codebase_data)

        user_chunk = chunks.find { |c| c.title.include?("User") }
        controller_chunk = chunks.find { |c| c.title.include?("UsersController") }

        expect(user_chunk.references).to include(controller_chunk.id)
        expect(controller_chunk.references).to include(user_chunk.id)
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

      xit "provides navigation context between split chunks" do
        # TODO: Fix navigation context format
        chunks = subject.emit(large_class_data)
        class_chunks = chunks.select { |c| c.title.include?("LargeClass") }

        class_chunks.each do |chunk|
          expect(chunk.content).to include("Part X of Y")
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

    xit "provides clear section boundaries and transitions" do
      # TODO: Ensure proper section separators in all chunks
      chunks = subject.emit(codebase_data)
      user_chunk = chunks.find { |c| c.title.include?("User") }

      expect(user_chunk.content).to include("---") # Clear section separators
      expect(user_chunk.content).to match(/^## \w+/) # Clear section headings
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
      expect(index_content).to include("## Models")
      expect(index_content).to include("- [User Model](models/user.md)")
      expect(index_content).to include("## Controllers")
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
      xit "respects maximum token limits" do
        # TODO: Implement chunk size configuration
        subject.configure(max_tokens_per_chunk: 2000)
        chunks = subject.emit(codebase_data)

        chunks.each do |chunk|
          expect(chunk.estimated_tokens).to be <= 2000
        end
      end

      xit "maintains minimum content coherence despite size constraints" do
        # TODO: Implement minimum coherence logic
        subject.configure(max_tokens_per_chunk: 800) # Very small chunks
        chunks = subject.emit(codebase_data)

        # Even with small chunks, each should contain meaningful content
        chunks.each do |chunk|
          expect(chunk.content.lines.size).to be >= 5 # At least some content
          expect(chunk.content).to match(/^# .+/) # Has a title
        end
      end
    end

    context "when filtering content for specific audiences" do
      xit "supports different detail levels" do
        # TODO: Implement detail level filtering
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

      xit "generates chunks despite missing metadata" do
        # TODO: Improve malformed data handling
        chunks = subject.emit(malformed_data)

        expect(chunks).not_to be_empty
        expect(chunks.first.content).to include("# Code Analysis")
        expect(chunks.first.content).to include("Note: Some metadata unavailable")
      end

      it "handles missing class information gracefully" do
        data_without_classes = codebase_data.dup
        data_without_classes.delete(:classes)

        chunks = subject.emit(data_without_classes)

        expect(chunks).not_to be_empty
        expect(chunks.first.content).to include("No class information available")
      end
    end

    context "when encountering extremely large datasets" do
      xit "provides progress feedback for long operations" do
        # TODO: Fix progress percentage calculation
        large_dataset = EmitterTestData.massive_codebase
        progress_updates = []

        subject.on_progress { |update| progress_updates << update }
        subject.emit(large_dataset)

        expect(progress_updates).not_to be_empty
        expect(progress_updates.last[:percent]).to eq(100)
      end
    end
  end
end
