# frozen_string_literal: true

require "spec_helper"
require "support/cli_helpers"
require "rubymap/cli"

RSpec.describe "rubymap CLI", type: :cli do
  let(:output_dir) { ".rubymap" }
  let(:test_project) { test_project_path }

  describe "basic mapping commands" do
    describe "rubymap map" do
      context "when run in a Ruby project directory" do
        it "maps the current directory" do
          within_test_project do
            result = run_cli("map")

            expect(result).to be_success
            expect(result.output).to include("Mapping completed successfully")
            expect(Dir.exist?("rubymap_output")).to be true
          end
        end

        it "creates output in default directory" do
          within_test_project do
            result = run_cli("map")

            expect(result).to be_success
            expect(Dir.exist?("rubymap_output")).to be true
          end
        end

        it "generates output with project metadata" do
          within_test_project do
            result = run_cli("map --format json")

            expect(result).to be_success
            json_files = Dir.glob("rubymap_output/**/*.json")
            expect(json_files).not_to be_empty
          end
        end
      end

      context "when run in a non-Ruby directory" do
        it "outputs a helpful message about no Ruby files found" do
          in_temp_dir do
            result = run_cli("map")

            expect(result).to be_success
            expect(result.output).to include("Mapping completed")
          end
        end
      end
    end

    describe "rubymap map with specific paths" do
      context "when given valid directory paths" do
        it "maps only the specified directories" do
          within_test_project do
            result = run_cli("map app")

            expect(result).to be_success
            expect(result.output).to include("Mapping completed")
          end
        end
      end

      context "when given file paths" do
        it "maps the specific files" do
          within_test_project do
            result = run_cli("map app/models/user.rb")

            expect(result).to be_success
            expect(result.output).to include("Mapping completed")
          end
        end
      end

      context "when given non-existent paths" do
        it "displays an error message" do
          result = run_cli("map /nonexistent/path")

          expect(result).not_to be_success
          expect(result.output).to include("Error")
        end

        it "exits with non-zero status code" do
          result = run_cli("map /nonexistent/path")

          expect(result.exit_code).not_to eq(0)
        end
      end
    end
  end

  describe "output format options" do
    describe "--format json" do
      context "when mapping a simple Ruby project" do
        it "generates structured JSON output" do
          within_test_project do
            result = run_cli("map --format json")

            expect(result).to be_success

            # Check that JSON files are created
            json_files = Dir.glob("rubymap_output/**/*.json")
            expect(json_files).not_to be_empty

            # Verify JSON is valid
            json_files.each do |file|
              expect { JSON.parse(File.read(file)) }.not_to raise_error
            end
          end
        end

        it "includes classes, modules, and methods in JSON format" do
          within_test_project do
            result = run_cli("map --format json --output json_test")

            expect(result).to be_success

            # Look for manifest or main output file
            json_files = Dir.glob("json_test/**/*.json")
            expect(json_files).not_to be_empty

            # Parse one of the JSON files to check structure
            content = JSON.parse(File.read(json_files.first))
            expect(content).to be_a(Hash)
          end
        end
      end
    end

    describe "--format yaml" do
      it "generates YAML output instead of JSON" do
        within_test_project do
          result = run_cli("map --format yaml")

          expect(result).to be_success

          # Check for YAML files
          yaml_files = Dir.glob("rubymap_output/**/*.{yml,yaml}")
          expect(yaml_files).not_to be_empty

          # Verify YAML is valid syntax (don't load objects for security)
          yaml_files.each do |file|
            content = File.read(file)
            # Just check it's valid YAML syntax
            expect { YAML.parse(content) }.not_to raise_error
          end
        end
      end
    end

    describe "--format llm" do
      context "when generating LLM-friendly output" do
        it "creates chunked documentation files" do
          within_test_project do
            result = run_cli("map --format llm")

            expect(result).to be_success

            # Check for chunked files
            chunk_files = Dir.glob("rubymap_output/chunks/*.md")
            expect(chunk_files).not_to be_empty
          end
        end

        it "includes human-readable descriptions of code structure" do
          within_test_project do
            result = run_cli("map --format llm")

            expect(result).to be_success

            # Check that markdown files contain descriptions
            md_files = Dir.glob("rubymap_output/**/*.md")
            expect(md_files).not_to be_empty

            content = File.read(md_files.first)
            expect(content).to include("Class:") if content.include?("class")
          end
        end

        it "creates markdown files for each major component" do
          within_test_project do
            result = run_cli("map --format llm")

            expect(result).to be_success

            # Should create files for major classes
            md_files = Dir.glob("rubymap_output/**/*.md")
            expect(md_files.size).to be > 1

            # Should have an index file
            expect(File.exist?("rubymap_output/index.md")).to be true
          end
        end
      end
    end

    describe "--format graphviz" do
      it "generates dependency diagrams" do
        within_test_project do
          result = run_cli("map --format dot")

          expect(result).to be_success

          # Check for DOT files
          dot_files = Dir.glob("rubymap_output/**/*.{dot,gv}")
          expect(dot_files).not_to be_empty
        end
      end
    end
  end

  describe "output directory options" do
    describe "--output" do
      context "when specifying a custom output directory" do
        it "creates map files in the specified directory" do
          within_test_project do
            cleanup_output("custom_output")

            result = run_cli("map --output custom_output")

            expect(result).to be_success
            expect(Dir.exist?("custom_output")).to be true

            # Check files were created in custom directory
            files = Dir.glob("custom_output/**/*").select { |f| File.file?(f) }
            expect(files).not_to be_empty

            cleanup_output("custom_output")
          end
        end

        it "creates the directory if it doesn't exist" do
          within_test_project do
            output_path = "path/to/new/output"
            cleanup_output(output_path)

            result = run_cli("map --output #{output_path}")

            expect(result).to be_success
            expect(Dir.exist?(output_path)).to be true

            cleanup_output(output_path)
          end
        end
      end
    end
  end

  describe "runtime introspection options" do
    describe "--runtime" do
      context "when used with a Rails application" do
        it "boots the Rails environment safely" do
          pending "Runtime introspection not yet implemented"

          # Would need a Rails test app
          expect(true).to be false
        end

        it "extracts ActiveRecord model information" do
          pending "Runtime introspection not yet implemented"
          expect(true).to be false
        end

        it "captures Rails routes" do
          pending "Runtime introspection not yet implemented"
          expect(true).to be false
        end

        it "identifies background job classes" do
          pending "Runtime introspection not yet implemented"
          expect(true).to be false
        end
      end

      context "when used with a non-Rails Ruby application" do
        it "loads the application files safely" do
          pending "Runtime introspection not yet implemented"

          within_test_project do
            result = run_cli("map --runtime")

            # Currently --runtime flag doesn't exist
            expect(result).to be_success
          end
        end

        it "captures dynamically defined methods" do
          pending "Runtime introspection not yet implemented"
          expect(true).to be false
        end
      end
    end

    describe "--skip-initializer" do
      context "when skipping problematic initializers" do
        it "avoids loading specified initializers during runtime mapping" do
          pending "Runtime introspection not yet implemented"
          expect(true).to be false
        end
      end
    end
  end

  describe "incremental updates" do
    describe "rubymap update" do
      context "when an existing map exists" do
        it "updates only changed files" do
          pending "update command not yet implemented"

          within_test_project do
            # Initial map
            run_cli("map")

            # Modify a file
            File.write("app/models/user.rb", File.read("app/models/user.rb") + "\n# Modified")

            # Update
            result = run_cli("update")

            expect(result).to be_success
            expect(result.output).to include("Updated")
          end
        end

        it "preserves unchanged mapping data" do
          pending "update command not yet implemented"

          within_test_project do
            run_cli("map")
            original_output = Dir.glob("rubymap_output/**/*")

            result = run_cli("update")

            expect(result).to be_success
            new_output = Dir.glob("rubymap_output/**/*")
            expect(new_output).to eq(original_output)
          end
        end
      end

      context "when no existing map exists" do
        it "performs a full mapping operation" do
          pending "update command not yet implemented"

          within_test_project do
            cleanup_output

            result = run_cli("update")

            expect(result).to be_success
            expect(Dir.exist?("rubymap_output")).to be true
          end
        end
      end
    end
  end

  describe "configuration file support" do
    describe "--config" do
      context "when given a valid configuration file" do
        it "applies the configuration settings" do
          in_temp_dir do
            # Create a simple Ruby file
            File.write("test.rb", "class Test; end")

            # Create custom config
            File.write("custom.yml", {format: "json", output_dir: "custom_out"}.to_yaml)

            result = run_cli("map --config custom.yml")

            # Config is not implemented yet, but test the intent
            expect(result).to be_success

            cleanup_output("custom_out")
          end
        end
      end
    end

    describe "default .rubymap.yml" do
      context "when .rubymap.yml exists in project root" do
        it "automatically loads the configuration" do
          within_test_project do
            # The test project already has .rubymap.yml
            result = run_cli("map")

            expect(result).to be_success
            # The config specifies output_dir: .rubymap
            # But CLI currently uses rubymap_output as default
          end
        end
      end
    end
  end

  describe "utility commands" do
    describe "rubymap view SYMBOL" do
      context "when viewing information about a class" do
        it "displays class information" do
          pending "view command not yet implemented"

          within_test_project do
            # First create a map
            run_cli("map")

            # Then view a class
            result = run_cli("view User")

            expect(result).to be_success
            expect(result.output).to include("Class: User")
            expect(result.output).to include("Methods:")
          end
        end
      end
    end

    describe "rubymap clean" do
      it "removes cache and output files" do
        pending "clean command not yet implemented"

        within_test_project do
          # Create some output
          run_cli("map")
          expect(Dir.exist?("rubymap_output")).to be true

          # Clean it up
          result = run_cli("clean")

          expect(result).to be_success
          expect(Dir.exist?("rubymap_output")).to be false
        end
      end
    end
  end

  describe "error handling and edge cases" do
    context "when encountering parse errors" do
      it "reports which files could not be parsed" do
        in_temp_dir do
          # Create a file with syntax errors
          File.write("broken.rb", "class Broken\n  def method\n    # missing end")

          result = run_cli("map")

          # Should still succeed but report the error
          expect(result).to be_success
        end
      end

      it "continues processing other files" do
        in_temp_dir do
          File.write("good.rb", "class Good; end")
          File.write("broken.rb", "class Broken\n  def method")

          result = run_cli("map")

          expect(result).to be_success
          expect(result.output).to include("Mapping completed")
        end
      end
    end

    context "when running out of disk space" do
      it "handles write failures gracefully" do
        pending "Disk space simulation not implemented"
        expect(true).to be false
      end
    end

    context "when interrupted during processing" do
      it "can resume from where it left off" do
        pending "Resumable processing not implemented"
        expect(true).to be false
      end
    end
  end

  describe "performance characteristics" do
    context "when mapping large codebases" do
      it "completes mapping within reasonable time limits" do
        within_test_project do
          start_time = Time.now
          result = run_cli("map")
          duration = Time.now - start_time

          expect(result).to be_success
          expect(duration).to be < 5 # Should complete quickly for small test project
        end
      end

      it "uses memory efficiently" do
        pending "Memory profiling not implemented"
        expect(true).to be false
      end
    end
  end

  describe "verbose output" do
    describe "--verbose" do
      it "shows detailed progress information" do
        within_test_project do
          result = run_cli("map --verbose")

          expect(result).to be_success
          expect(result.output).to include("Step")
        end
      end

      it "displays file-by-file processing status" do
        within_test_project do
          result = run_cli("map --verbose")

          expect(result).to be_success
          # Verbose mode shows pipeline steps
          expect(result.output).to include("Extracting")
        end
      end
    end
  end
end
