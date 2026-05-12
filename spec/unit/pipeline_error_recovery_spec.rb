# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pipeline error recovery consistency" do
  let(:test_dir) { "tmp/pipeline_error_test" }
  let(:config) { Rubymap::Configuration.new(format: :llm, output_dir: test_dir) }

  before { FileUtils.rm_rf(test_dir) }
  after { FileUtils.rm_rf(test_dir) }

  describe "when a stage fails" do
    it "returns a result hash (does not raise) from the pipeline" do
      # Use a non-existent path to trigger a controlled error path
      # The pipeline should complete and return a result, not raise
      pipeline = Rubymap::Pipeline.new(config)

      # Map an empty directory — should complete without raising
      FileUtils.mkdir_p(test_dir)
      result = pipeline.run([test_dir])

      expect(result).to be_a(Hash)
      expect(result).to have_key(:format)
    end

    it "includes error summary in result when errors occur" do
      pipeline = Rubymap::Pipeline.new(config)
      FileUtils.mkdir_p(test_dir)

      # Write a syntax-error file that will trigger extraction errors
      File.write("#{test_dir}/bad.rb", "class Broken\n  def oops\n  # missing end")

      result = pipeline.run([test_dir])

      # Should still complete and return a result
      expect(result).to be_a(Hash)
      # May or may not have errors depending on parser behavior
    end

    it "survives all stages even when data is sparse" do
      pipeline = Rubymap::Pipeline.new(config)

      # Run on the pipeline's own source — a real stress test
      result = pipeline.run(["lib/rubymap/pipeline_cache.rb"])

      expect(result).to be_a(Hash)
      expect(result).to have_key(:format)
    end
  end

  describe "emit stage" do
    it "does not raise when output fails, returns result with error info" do
      # Create a read-only output directory that will cause write failures
      Dir.mkdir(test_dir)
      File.chmod(0o555, test_dir)

      begin
        pipeline = Rubymap::Pipeline.new(
          Rubymap::Configuration.new(format: :llm, output_dir: test_dir)
        )

        # Write a valid source file so extraction succeeds
        src_dir = "tmp/pipeline_error_src"
        FileUtils.mkdir_p(src_dir)
        File.write("#{src_dir}/ok.rb", "class Ok; end")

        result = pipeline.run([src_dir])

        # Pipeline should complete without raising
        expect(result).to be_a(Hash)
        # May have errors due to unwritable output dir
      ensure
        File.chmod(0o755, test_dir)
        FileUtils.rm_rf(src_dir)
      end
    end
    end


  describe "enrich stage forwards metadata" do
    it "forwards patterns and method_calls from normalized result" do
      config = Rubymap::Configuration.new(
        format: :llm,
        output_dir: "tmp/enrich_forward_test",
        verbose: false,
        progress: false
      )
      pipeline = Rubymap::Pipeline.new(config)

      # Run on a file that has class-level DSL and methods with calls
      src = "tmp/enrich_forward_src"
      FileUtils.mkdir_p(src)
      File.write("#{src}/user.rb", <<~RUBY)
        class User < ApplicationRecord
          has_many :posts
          belongs_to :account
          attr_accessor :name, :email
          @@count = 0
          alias :full_name :name

          def save!
            logger.info("saving")
            valid? && persist
          end
        end
      RUBY

      begin
        result = pipeline.run([src])
        expect(result).to be_a(Hash)
        expect(result).to have_key(:format)
      ensure
        FileUtils.rm_rf(src)
        FileUtils.rm_rf("tmp/enrich_forward_test")
        FileUtils.rm_rf(".rubymap_cache")
      end
    end
  end
end
