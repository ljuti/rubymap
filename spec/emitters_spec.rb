# frozen_string_literal: true

RSpec.describe "Rubymap::Emitters" do
  let(:sample_indexed_data) do
    {
      metadata: {
        project_name: "TestApp",
        ruby_version: "3.2.0",
        mapping_date: "2023-12-01T10:00:00Z",
        total_classes: 25,
        total_methods: 150
      },
      classes: [
        {
          fqname: "User",
          type: "class",
          superclass: "ApplicationRecord",
          file: "app/models/user.rb",
          line: 1,
          instance_methods: ["save", "full_name", "active?"],
          class_methods: ["find_by_email", "create_with_defaults"],
          documentation: "Represents a user in the system",
          metrics: {
            complexity_score: 3.2,
            public_api_surface: 5,
            test_coverage: 85.0
          }
        },
        {
          fqname: "Admin::UsersController",
          type: "class",
          superclass: "ApplicationController",
          file: "app/controllers/admin/users_controller.rb",
          line: 3,
          instance_methods: ["index", "show", "create"],
          documentation: "Admin interface for managing users"
        }
      ],
      graphs: {
        inheritance: [
          {from: "User", to: "ApplicationRecord", type: "inherits"}
        ],
        dependencies: [
          {from: "Admin::UsersController", to: "User", type: "depends_on"}
        ]
      }
    }
  end

  describe "LLM-friendly emitter" do
    let(:llm_emitter) { Rubymap::Emitters::LLM.new }

    describe "#emit" do
      context "when generating LLM-optimized output" do
        it "creates chunked markdown documentation" do
          output = llm_emitter.emit_structured(sample_indexed_data)

          expect(output[:files]).not_to be_empty
          user_files = output[:files].select { |f| f[:path].include?("user") }
          expect(user_files).not_to be_empty
          expect(user_files.first[:content]).to include("User")
        end

        it "includes context-rich descriptions for each class" do
          output = llm_emitter.emit_structured(sample_indexed_data)

          user_doc = output[:files].find { |f| f[:path] =~ /user/i }
          expect(user_doc).not_to be_nil
          expect(user_doc[:content]).to include("Represents a user in the system")
          expect(user_doc[:content]).to include("ApplicationRecord")
        end

        it "creates relationship summaries" do
          output = llm_emitter.emit_structured(sample_indexed_data)

          relationships_doc = output[:files].find { |f| f[:path] == "relationships.md" }
          expect(relationships_doc).not_to be_nil
          expect(relationships_doc[:content]).to include("Inheritance")
          expect(relationships_doc[:content]).to include("User")
        end

        it "generates overview documentation" do
          output = llm_emitter.emit_structured(sample_indexed_data)

          overview_doc = output[:files].find { |f| f[:path] == "overview.md" }
          expect(overview_doc).not_to be_nil
          expect(overview_doc[:content]).to include("TestApp")
          expect(overview_doc[:content]).to include("25")
          expect(overview_doc[:content]).to include("150")
        end

        it "chunks content to stay within LLM token limits" do
          output = llm_emitter.emit_structured(sample_indexed_data)

          output[:files].each do |file|
            expect(file[:estimated_tokens] || 1000).to be < 8000
          end
        end
      end

      context "when handling complex class hierarchies" do
        let(:complex_hierarchy_data) do
          {
            classes: [
              {fqname: "A", superclass: nil},
              {fqname: "B", superclass: "A"},
              {fqname: "C", superclass: "B"},
              {fqname: "D", superclass: "B"},
              {fqname: "E", superclass: "C"}
            ],
            graphs: {
              inheritance: [
                {from: "B", to: "A", type: "inherits"},
                {from: "C", to: "B", type: "inherits"},
                {from: "D", to: "B", type: "inherits"},
                {from: "E", to: "C", type: "inherits"}
              ]
            }
          }
        end

        it "creates visual hierarchy representations" do
          output = llm_emitter.emit_structured(complex_hierarchy_data)

          hierarchy_doc = output[:files].find { |f| f[:path].include?("hierarchy") }
          expect(hierarchy_doc).not_to be_nil
          expect(hierarchy_doc[:content]).to include("Class Hierarchy")
          expect(hierarchy_doc[:content]).to include("```")
        end
      end
    end

    describe "#emit_to_directory" do
      let(:output_directory) { "spec/tmp/llm_output" }

      it "creates organized markdown file structure" do
        llm_emitter.emit_to_directory(sample_indexed_data, output_directory)

        expect(File).to exist("#{output_directory}/overview.md")
        expect(File).to exist("#{output_directory}/index.md")
        expect(Dir.glob("#{output_directory}/chunks/*.md")).not_to be_empty
      end

      it "creates index files for navigation" do
        llm_emitter.emit_to_directory(sample_indexed_data, output_directory)

        index_content = File.read("#{output_directory}/index.md")
        expect(index_content).to include("User")
        expect(index_content).to include("Classes")
      end
    end
  end
end
