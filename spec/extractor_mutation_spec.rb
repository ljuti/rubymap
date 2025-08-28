# frozen_string_literal: true

RSpec.describe Rubymap::Extractor do
  let(:extractor) { described_class.new }

  describe "#extract_from_file" do
    context "when file does not exist" do
      it "returns an error result for non-existent file" do
        result = extractor.extract_from_file("/non/existent/file.rb")
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to eq("/non/existent/file.rb")
        expect(result.errors).not_to be_empty
        expect(result.errors.first[:type]).to eq("ArgumentError")
        expect(result.errors.first[:message]).to eq("File not found: /non/existent/file.rb")
      end
    end

    context "when file exists" do
      let(:test_file) { "spec/fixtures/test_file.rb" }

      it "reads the file and extracts symbols" do
        result = extractor.extract_from_file(test_file)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to eq(test_file)
        expect(result.classes).not_to be_empty
        expect(result.classes.first.name).to eq("TestClass")
        expect(result.methods).not_to be_empty
        expect(result.methods.first.name).to eq("test_method")
      end

      it "sets the file_path on the result" do
        result = extractor.extract_from_file(test_file)
        expect(result.file_path).to eq(test_file)
      end
    end

    context "when file read raises an error" do
      let(:test_file) { "spec/fixtures/test_file.rb" }

      before do
        allow(File).to receive(:exist?).with(test_file).and_return(true)
        allow(File).to receive(:read).with(test_file).and_raise(Errno::EACCES, "Permission denied")
      end

      it "returns an error result with the file path and error" do
        result = extractor.extract_from_file(test_file)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to eq(test_file)
        expect(result.errors).not_to be_empty
        expect(result.errors.first[:type]).to eq("Errno::EACCES")
        expect(result.errors.first[:message]).to eq("Permission denied - Permission denied")
      end
    end

    context "when parsing fails" do
      let(:test_file) { "spec/fixtures/test_file.rb" }

      before do
        allow(File).to receive(:exist?).with(test_file).and_return(true)
        allow(File).to receive(:read).with(test_file).and_return("class Broken\n  def method_without_end")
      end

      it "returns result with parse errors" do
        result = extractor.extract_from_file(test_file)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to eq(test_file)
        expect(result.errors).not_to be_empty
      end
    end
  end

  describe "#extract_from_code" do
    context "with valid Ruby code" do
      let(:code) { "class TestClass\n  def test_method\n    42\n  end\nend" }

      it "parses and extracts symbols" do
        result = extractor.extract_from_code(code)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes).not_to be_empty
        expect(result.classes.first.name).to eq("TestClass")
        expect(result.methods).not_to be_empty
        expect(result.methods.first.name).to eq("test_method")
      end

    end

    context "with invalid Ruby code" do
      let(:invalid_code) { "class Broken\n  def method_without_end" }

      it "returns result with parse errors" do
        result = extractor.extract_from_code(invalid_code)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.errors).not_to be_empty
        expect(result.errors.first[:context]).to eq("Parse error")
      end

      it "returns empty collections for invalid code" do
        result = extractor.extract_from_code(invalid_code)
        
        expect(result.classes).to be_empty
        expect(result.methods).to be_empty
        expect(result.constants).to be_empty
      end
    end

    context "with empty code" do
      it "returns empty result for empty string" do
        result = extractor.extract_from_code("")
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes).to be_empty
        expect(result.methods).to be_empty
        expect(result.errors).to be_empty
      end

      it "returns empty result for whitespace only" do
        result = extractor.extract_from_code("   \n\n  \t  ")
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes).to be_empty
        expect(result.methods).to be_empty
        expect(result.errors).to be_empty
      end
    end

    context "with comments" do
      let(:code_with_comments) do
        <<~RUBY
          # This is a comment
          class TestClass
            # Another comment
            def test_method
              42 # inline comment
            end
          end
        RUBY
      end

      it "handles comments in the code" do
        result = extractor.extract_from_code(code_with_comments)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes.first.doc).to eq("This is a comment")
        expect(result.methods.first.doc).to eq("Another comment")
      end
    end
  end

  describe "#extract_from_directory" do
    context "when directory does not exist" do
      it "raises ArgumentError with the directory path" do
        expect {
          extractor.extract_from_directory("/non/existent/directory")
        }.to raise_error(ArgumentError, "Directory not found: /non/existent/directory")
      end
    end

    context "when directory exists" do
      let(:test_dir) { "spec/fixtures" }

      before do
        # Create a second test file
        File.write("spec/fixtures/test_file2.rb", "class SecondClass\nend")
      end

      after do
        File.delete("spec/fixtures/test_file2.rb") if File.exist?("spec/fixtures/test_file2.rb")
      end

      it "processes all Ruby files in the directory" do
        result = extractor.extract_from_directory(test_dir)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes.map(&:name)).to include("TestClass", "SecondClass")
      end

      it "uses the provided pattern" do
        result = extractor.extract_from_directory(test_dir, "**/test_file.rb")
        
        expect(result.classes.map(&:name)).to include("TestClass")
        expect(result.classes.map(&:name)).not_to include("SecondClass")
      end

      it "skips non-file entries" do
        # Create a directory inside fixtures
        Dir.mkdir("spec/fixtures/subdir") unless Dir.exist?("spec/fixtures/subdir")
        
        result = extractor.extract_from_directory(test_dir)
        expect(result).to be_a(Rubymap::Extractor::Result)
      ensure
        Dir.rmdir("spec/fixtures/subdir") if Dir.exist?("spec/fixtures/subdir")
      end

      it "merges results from multiple files" do
        result = extractor.extract_from_directory(test_dir)
        
        # All collections should be merged
        expect(result.classes.size).to be >= 2
      end

      it "continues processing if one file has errors" do
        # Create a file with syntax error
        File.write("spec/fixtures/broken.rb", "class Broken\n  def no_end")
        
        result = extractor.extract_from_directory(test_dir)
        
        expect(result.classes.map(&:name)).to include("TestClass", "SecondClass")
        expect(result.errors).not_to be_empty
      ensure
        File.delete("spec/fixtures/broken.rb") if File.exist?("spec/fixtures/broken.rb")
      end
    end

    context "with empty directory" do
      let(:empty_dir) { "spec/fixtures/empty_dir" }

      before do
        Dir.mkdir(empty_dir) unless Dir.exist?(empty_dir)
      end

      after do
        Dir.rmdir(empty_dir) if Dir.exist?(empty_dir)
      end

      it "returns empty result for directory with no Ruby files" do
        result = extractor.extract_from_directory(empty_dir)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.classes).to be_empty
        expect(result.methods).to be_empty
        expect(result.errors).to be_empty
      end
    end
  end

  describe "#initialize" do
    it "creates a new instance" do
      expect(extractor).to be_a(described_class)
    end

    it "does not require any arguments" do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe "private methods" do
    describe "#create_error_result" do
      it "creates result with error and file_path" do
        error = StandardError.new("Test error")
        result = extractor.send(:create_error_result, error, "/path/to/file.rb")
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to eq("/path/to/file.rb")
        expect(result.errors).not_to be_empty
        expect(result.errors.first[:message]).to eq("Test error")
        expect(result.errors.first[:type]).to eq("StandardError")
      end

      it "creates result with error and no file_path" do
        error = StandardError.new("Test error")
        result = extractor.send(:create_error_result, error)
        
        expect(result).to be_a(Rubymap::Extractor::Result)
        expect(result.file_path).to be_nil
        expect(result.errors).not_to be_empty
      end
    end

    describe "#merge_results" do
      let(:target) { Rubymap::Extractor::Result.new }
      let(:source) { Rubymap::Extractor::Result.new }

      before do
        # Add some data to source
        source.classes << Rubymap::Extractor::ClassInfo.new(name: "SourceClass")
        source.modules << Rubymap::Extractor::ModuleInfo.new(name: "SourceModule")
        source.methods << Rubymap::Extractor::MethodInfo.new(name: "source_method")
        source.constants << Rubymap::Extractor::ConstantInfo.new(name: "SOURCE_CONST", value: "42")
        source.attributes << Rubymap::Extractor::AttributeInfo.new(name: "source_attr", type: "reader")
        source.mixins << Rubymap::Extractor::MixinInfo.new(type: "include", module_name: "SourceMixin", target: "SourceClass")
        source.dependencies << Rubymap::Extractor::DependencyInfo.new(type: "require", path: "source_dep")
        source.class_variables << Rubymap::Extractor::ClassVariableInfo.new(name: "@@source_var")
        source.aliases << Rubymap::Extractor::AliasInfo.new(new_name: "source_alias", original_name: "source_method")
        source.patterns << Rubymap::Extractor::PatternInfo.new(type: "concern", target: "SourceModule")
        source.add_error(StandardError.new("Source error"))
      end

      it "merges all collections from source to target" do
        extractor.send(:merge_results, target, source)
        
        expect(target.classes.map(&:name)).to include("SourceClass")
        expect(target.modules.map(&:name)).to include("SourceModule")
        expect(target.methods.map(&:name)).to include("source_method")
        expect(target.constants.map(&:name)).to include("SOURCE_CONST")
        expect(target.attributes.map(&:name)).to include("source_attr")
        expect(target.mixins.map(&:module_name)).to include("SourceMixin")
        expect(target.dependencies.map(&:path)).to include("source_dep")
        expect(target.class_variables.map(&:name)).to include("@@source_var")
        expect(target.aliases.map(&:new_name)).to include("source_alias")
        expect(target.patterns.map(&:type)).to include("concern")
        expect(target.errors).not_to be_empty
      end

      it "appends to existing collections" do
        target.classes << Rubymap::Extractor::ClassInfo.new(name: "TargetClass")
        
        extractor.send(:merge_results, target, source)
        
        expect(target.classes.size).to eq(2)
        expect(target.classes.map(&:name)).to include("TargetClass", "SourceClass")
      end
    end
  end
end