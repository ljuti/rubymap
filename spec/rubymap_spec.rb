# frozen_string_literal: true

RSpec.describe Rubymap do
  describe "module structure" do
    it "has a version number" do
      expect(Rubymap.gem_version).to be_truthy
    end

    it "defines an Error class inheriting from StandardError" do
      expect(Rubymap::Error).to be < StandardError
    end
  end

  describe "API interface" do
    describe ".map" do
      context "when given a valid path" do
        it "returns a mapping result" do
          # Create a test file
          test_dir = "spec/tmp/test_project"
          FileUtils.mkdir_p(test_dir)
          File.write("#{test_dir}/test.rb", "class TestClass; end")

          result = Rubymap.map(test_dir, format: :llm)

          expect(result).to be_a(Hash)
          expect(result[:format]).to eq(:llm)
        ensure
          FileUtils.rm_rf(test_dir)
        end
      end

      context "when given invalid paths" do
        it "raises Rubymap::NotFoundError for non-existent paths" do
          expect {
            Rubymap.map("/non/existent/path")
          }.to raise_error(Rubymap::NotFoundError, /Path does not exist/)
        end
      end
    end

    describe ".configure" do
      it "accepts a configuration block" do
        Rubymap.configure do |config|
          config.format = :json
          config.verbose = true
        end

        expect(Rubymap.configuration.format).to eq(:json)
        expect(Rubymap.configuration.verbose).to be(true)
      ensure
        Rubymap.reset_configuration!
      end

      it "returns the configuration object" do
        config = Rubymap.configure
        expect(config).to be_a(Rubymap::Configuration)
      end
    end
  end

  describe "behavior as a developer tool" do
    context "when mapping a Ruby codebase" do
      it "extracts classes and modules" do
        skip "Implementation pending"
      end

      it "extracts methods and constants" do
        skip "Implementation pending"
      end

      it "tracks inheritance relationships" do
        skip "Implementation pending"
      end

      it "tracks mixin relationships" do
        skip "Implementation pending"
      end

      it "generates LLM-friendly output" do
        skip "Implementation pending"
      end
    end

    context "when mapping with runtime introspection" do
      it "captures dynamic methods" do
        skip "Implementation pending"
      end

      it "extracts ActiveRecord associations" do
        skip "Implementation pending"
      end

      it "maps Rails routes" do
        skip "Implementation pending"
      end
    end
  end
end
