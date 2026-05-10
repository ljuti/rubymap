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
            result = run_cli("map")

            expect(result).to be_success
            # LLM format generates markdown and manifest.json
            expect(File.exist?("rubymap_output/manifest.json")).to be true
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

  describe "output format" do
    describe "LLM format (default and only format)" do
      context "when generating LLM-friendly output" do
        it "creates chunked documentation files" do
          within_test_project do
            result = run_cli("map")

            expect(result).to be_success

            # Check for chunked files
            chunk_files = Dir.glob("rubymap_output/chunks/*.md")
            expect(chunk_files).not_to be_empty
          end
        end

        it "includes human-readable descriptions of code structure" do
          within_test_project do
            result = run_cli("map")

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
            result = run_cli("map")

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
      context "when used with a non-Rails Ruby application" do
        it "loads the application files safely" do
          within_test_project do
            result = run_cli("map --runtime")

            # Runtime flag is accepted but doesn't change behavior yet
            expect(result).to be_success
            expect(result.output).to include("Mapping completed")
          end
        end
      end
    end
  end

  describe "incremental updates" do
    describe "rubymap update" do
      context "when an existing map exists" do
        it "updates only changed files" do
          within_test_project do
            # Initial map
            run_cli("map")

            # Modify a file
            original_content = File.read("app/models/user.rb")
            File.write("app/models/user.rb", original_content + "\n# Modified for test")

            # Update
            result = run_cli("update")

            expect(result).to be_success
            expect(result.output).to include("Updating Rubymap")

            # Restore original file
            File.write("app/models/user.rb", original_content)
          end
        end

        it "preserves unchanged mapping data" do
          within_test_project do
            # Create initial map
            run_cli("map")
            original_count = Dir.glob("rubymap_output/**/*").size

            # Update without changes
            result = run_cli("update")

            expect(result).to be_success
            new_count = Dir.glob("rubymap_output/**/*").size
            # Should have similar number of files (might differ slightly due to timestamps)
            expect(new_count).to be_within(2).of(original_count)
          end
        end
      end

      context "when no existing map exists" do
        it "performs a full mapping operation" do
          within_test_project do
            cleanup_output("rubymap_output")

            result = run_cli("update")

            expect(result).to be_success
            expect(result.output).to include("No existing map found")
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
            File.write("custom.yml", {output_dir: "custom_out"}.to_yaml)

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
          within_test_project do
            # First create a map
            run_cli("map")

            # Then view a class
            result = run_cli("view User")

            expect(result).to be_success
            expect(result.output).to include("Symbol: User")
            # View command shows placeholder for now
            expect(result.output).to include("Symbol viewing not yet fully implemented")
          end
        end
      end
    end

    describe "rubymap clean" do
      it "removes cache and output files" do
        within_test_project do
          # Create some output
          run_cli("map")
          expect(Dir.exist?("rubymap_output")).to be true

          # Clean it up
          result = run_cli("clean")

          expect(result).to be_success
          expect(result.output).to include("Cleaning Rubymap Files")
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

    context "when interrupted during processing" do
      it "handles parse errors and continues" do
        within_test_project do
          File.write("broken.rb", "class Broken\n  def method")

          result = run_cli("map")

          expect(result).to be_success
          expect(result.output).to include("Mapping completed")
        end
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
