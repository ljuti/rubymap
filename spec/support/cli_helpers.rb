# frozen_string_literal: true

require "open3"
require "tmpdir"
require "fileutils"
require "json"
require "yaml"

module CLIHelpers
  # Execute a CLI command and capture output
  def run_cli(command, input: nil, env: {})
    # Use the full path to the executable
    exe_path = File.expand_path("../../../exe/rubymap", __FILE__)

    # Ensure the executable can find the lib directory
    lib_path = File.expand_path("../../../lib", __FILE__)
    env = env.merge("RUBYLIB" => lib_path)

    # Run the command
    cmd = "#{exe_path} #{command}"

    stdout, stderr, status = Open3.capture3(env, cmd, stdin_data: input)

    CLIResult.new(stdout, stderr, status)
  end

  # Execute CLI command directly without bundler (for testing exe/rubymap directly)
  def run_rubymap(args, **options)
    exe_path = File.expand_path("../../exe/rubymap", __dir__)
    env = options.fetch(:env, {})
    input = options.fetch(:input, nil)

    # Ensure Ruby can find the lib directory
    env["RUBYLIB"] = File.expand_path("../../lib", __dir__)

    stdout, stderr, status = Open3.capture3(env, exe_path, *args.split, stdin_data: input)
    CLIResult.new(stdout, stderr, status)
  end

  # Run a block within the test project directory
  def within_test_project(&block)
    Dir.chdir(test_project_path, &block)
  end

  # Run a block in a temporary directory
  def in_temp_dir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        yield dir
      end
    end
  end

  # Create a temporary project with given structure
  def create_temp_project(structure = {})
    in_temp_dir do |dir|
      structure.each do |path, content|
        full_path = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full_path))

        if content.nil?
          FileUtils.mkdir_p(full_path)
        else
          File.write(full_path, content)
        end
      end

      yield dir
    end
  end

  # Create a config file with given options
  def create_config_file(options = {}, filename: ".rubymap.yml")
    File.write(filename, options.to_yaml)
  end

  # Clean up generated files
  def cleanup_output(dir = ".rubymap")
    FileUtils.rm_rf(dir) if File.exist?(dir)
  end

  # Path to test project fixtures
  def test_project_path
    File.expand_path("../fixtures/test_project", __dir__)
  end

  # Parse JSON output file
  def parse_json_output(path = ".rubymap/output.json")
    return nil unless File.exist?(path)
    JSON.parse(File.read(path))
  end

  # Parse YAML output file
  def parse_yaml_output(path = ".rubymap/output.yaml")
    return nil unless File.exist?(path)
    YAML.load_file(path)
  end

  # Check if LLM markdown files were created
  def llm_files_created?(dir = ".rubymap")
    return false unless Dir.exist?(dir)

    markdown_files = Dir.glob(File.join(dir, "**/*.md"))
    !markdown_files.empty?
  end

  # Result wrapper for CLI commands
  class CLIResult
    attr_reader :stdout, :stderr, :status

    def initialize(stdout, stderr, status)
      @stdout = stdout
      @stderr = stderr
      @status = status
    end

    def output
      @stdout
    end

    def error
      @stderr
    end

    def success?
      @status.success?
    end

    def exit_code
      @status.exitstatus
    end

    def to_s
      @stdout
    end

    # Helpers for common assertions
    def includes?(text)
      output.include?(text) || error.include?(text)
    end

    def json_output
      JSON.parse(output)
    rescue JSON::ParserError
      nil
    end

    def lines
      output.lines.map(&:chomp)
    end
  end
end

# Shared examples for CLI commands
RSpec.shared_examples "a successful command" do
  it "exits with status 0" do
    expect(result).to be_success
  end

  it "does not output to stderr" do
    expect(result.stderr).to be_empty
  end
end

RSpec.shared_examples "a failed command" do
  it "exits with non-zero status" do
    expect(result).not_to be_success
  end

  it "outputs error message" do
    expect(result.stderr).not_to be_empty
  end
end

RSpec.shared_examples "creates output files" do |format|
  it "creates output directory" do
    expect(Dir.exist?(output_dir)).to be true
  end

  case format
  when :json
    it "creates JSON output file" do
      expect(File.exist?(File.join(output_dir, "output.json"))).to be true
    end

    it "creates valid JSON" do
      json = parse_json_output(File.join(output_dir, "output.json"))
      expect(json).to be_a(Hash)
    end
  when :yaml
    it "creates YAML output file" do
      expect(File.exist?(File.join(output_dir, "output.yaml"))).to be true
    end

    it "creates valid YAML" do
      yaml = parse_yaml_output(File.join(output_dir, "output.yaml"))
      expect(yaml).to be_a(Hash)
    end
  when :llm
    it "creates markdown files" do
      expect(llm_files_created?(output_dir)).to be true
    end

    it "creates index file" do
      expect(File.exist?(File.join(output_dir, "index.md"))).to be true
    end
  end
end

RSpec.shared_examples "respects configuration file" do
  let(:config_file) { ".rubymap.yml" }

  before do
    create_config_file(config_options, filename: config_file)
  end

  after do
    File.delete(config_file) if File.exist?(config_file)
  end

  it "loads configuration from file" do
    expect(result).to be_success
  end

  it "applies configuration settings" do
    # This should be customized based on specific config options
    expect(result.output).to include("Configuration loaded")
  end
end

# Configure RSpec to use these helpers
RSpec.configure do |config|
  config.include CLIHelpers, type: :cli

  # Ensure clean state for CLI tests
  config.before(:each, type: :cli) do
    cleanup_output
  end

  config.after(:each, type: :cli) do
    cleanup_output
  end
end
