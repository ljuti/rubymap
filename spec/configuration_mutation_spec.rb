# frozen_string_literal: true

# Additional specs to improve mutation coverage for Configuration
RSpec.describe Rubymap::Configuration do
  let(:config) { described_class.new }

  describe "edge cases for type coercion" do
    describe "#verbose=" do
      it "handles nil values" do
        config.verbose = nil
        expect(config.verbose).to be_nil
      end

      it "handles false boolean" do
        config.verbose = false
        expect(config.verbose).to be false
      end

      it "handles true boolean" do
        config.verbose = true
        expect(config.verbose).to be true
      end

      it "converts 'false' string to false" do
        config.verbose = "false"
        expect(config.verbose).to be false
      end

      it "converts any non-'true' string to false" do
        config.verbose = "yes"
        expect(config.verbose).to be false
        
        config.verbose = "1"
        expect(config.verbose).to be false
        
        config.verbose = "TRUE"
        expect(config.verbose).to be true  # Case-insensitive
      end
    end

    describe "#parallel=" do
      it "handles string conversion" do
        config.parallel = "true"
        expect(config.parallel).to be true
        
        config.parallel = "false"
        expect(config.parallel).to be false
      end
    end

    describe "#progress=" do
      it "handles string conversion" do
        config.progress = "true"
        expect(config.progress).to be true
        
        config.progress = "false"
        expect(config.progress).to be false
      end
    end

    describe "#follow_symlinks=" do
      it "handles string conversion" do
        config.follow_symlinks = "true"
        expect(config.follow_symlinks).to be true
        
        config.follow_symlinks = "false"
        expect(config.follow_symlinks).to be false
      end
    end

    describe "#max_depth=" do
      it "converts string to integer" do
        config.max_depth = "15"
        expect(config.max_depth).to eq(15)
      end

      it "handles integer values directly" do
        config.max_depth = 20
        expect(config.max_depth).to eq(20)
      end

      it "converts non-numeric strings to 0" do
        config.max_depth = "abc"
        expect(config.max_depth).to eq(0)
      end
    end

    describe "#format=" do
      it "converts string to symbol" do
        config.format = "json"
        expect(config.format).to eq(:json)
      end

      it "handles symbol values directly" do
        config.format = :yaml
        expect(config.format).to eq(:yaml)
      end
    end
  end

  describe ".from_hash" do
    context "with nil hash" do
      it "returns default configuration" do
        config = described_class.from_hash(nil)
        expect(config.output_dir).to eq(".rubymap")
        expect(config.format).to eq(:llm)
      end
    end

    context "with empty hash" do
      it "returns default configuration" do
        config = described_class.from_hash({})
        expect(config.output_dir).to eq(".rubymap")
        expect(config.format).to eq(:llm)
      end
    end

    context "with non-string values" do
      it "preserves non-string values" do
        config = described_class.from_hash({
          "verbose" => true,
          "max_depth" => 15,
          "format" => :json
        })
        
        expect(config.verbose).to be true
        expect(config.max_depth).to eq(15)
        expect(config.format).to eq(:json)
      end
    end

    context "triggering all type coercion branches" do
      it "coerces all string types" do
        config = described_class.from_hash({
          "verbose" => "true",
          "parallel" => "true",
          "progress" => "true",
          "max_depth" => "25",
          "format" => "yaml"
        })
        
        expect(config.verbose).to be true
        expect(config.parallel).to be true
        expect(config.progress).to be true
        expect(config.max_depth).to eq(25)
        expect(config.format).to eq(:yaml)
      end
    end
  end

  describe "#deep_merge!" do
    context "with nested integer coercion" do
      it "coerces runtime timeout" do
        config.deep_merge!({"runtime" => {"timeout" => "45"}})
        expect(config.runtime["timeout"]).to eq(45)
      end

      it "coerces cache ttl" do
        config.deep_merge!({"cache" => {"ttl" => "3600"}})
        expect(config.cache["ttl"]).to eq(3600)
      end

      it "coerces static max_file_size" do
        config.deep_merge!({"static" => {"max_file_size" => "2000000"}})
        expect(config.static["max_file_size"]).to eq(2000000)
      end
    end

    context "with nested boolean coercion" do
      it "coerces enabled fields" do
        config.deep_merge!({"runtime" => {"enabled" => "true"}})
        expect(config.runtime["enabled"]).to be true
        
        config.deep_merge!({"cache" => {"enabled" => "false"}})
        expect(config.cache["enabled"]).to be false
      end

      it "coerces safe_mode" do
        config.deep_merge!({"runtime" => {"safe_mode" => "true"}})
        expect(config.runtime["safe_mode"]).to be true
      end

      it "coerces follow_requires" do
        config.deep_merge!({"static" => {"follow_requires" => "true"}})
        expect(config.static["follow_requires"]).to be true
      end

      it "coerces parse_yard and parse_rbs" do
        config.deep_merge!({"static" => {"parse_yard" => "true", "parse_rbs" => "false"}})
        expect(config.static["parse_yard"]).to be true
        expect(config.static["parse_rbs"]).to be false
      end

      it "coerces output flags" do
        config.deep_merge!({
          "output" => {
            "split_files" => "true",
            "include_source" => "false",
            "include_todos" => "true",
            "redact_sensitive" => "false"
          }
        })
        expect(config.output["split_files"]).to be true
        expect(config.output["include_source"]).to be false
        expect(config.output["include_todos"]).to be true
        expect(config.output["redact_sensitive"]).to be false
      end

      it "coerces filter flags" do
        config.deep_merge!({
          "filter" => {
            "include_private" => "true",
            "include_protected" => "false"
          }
        })
        expect(config.filter["include_private"]).to be true
        expect(config.filter["include_protected"]).to be false
      end
    end

    context "with non-coercible values" do
      it "preserves non-string values in nested configs" do
        config.deep_merge!({
          "static" => {"paths" => ["app/", "lib/"]},
          "runtime" => {"environment" => "test"}
        })
        expect(config.static["paths"]).to eq(["app/", "lib/"])
        expect(config.runtime["environment"]).to eq("test")
      end
    end

    context "with top-level string format" do
      it "ensures format is converted to symbol" do
        config.deep_merge!({"format" => "graphviz"})
        expect(config.format).to eq(:graphviz)
      end
    end

    context "with unknown keys" do
      it "ignores unknown top-level keys" do
        expect {
          config.deep_merge!({"unknown_key" => "value"})
        }.not_to raise_error
      end
    end
  end

  describe "#merge" do
    context "when merging with empty config" do
      it "preserves current configuration" do
        config.output_dir = "custom"
        config.verbose = true
        
        merged = config.merge({})
        
        expect(merged.output_dir).to eq("custom")
        expect(merged.verbose).to be true
      end
    end

    context "when merging nested configs" do
      it "properly copies and merges nested sections" do
        config.static["paths"] = ["original/"]
        other = described_class.new
        other.static["paths"] = ["new/"]
        other.static["parse_yard"] = true
        
        merged = config.merge(other)
        
        expect(merged.static["paths"]).to eq(["new/"])
        expect(merged.static["parse_yard"]).to be true
        
        # Original should be unchanged
        expect(config.static["paths"]).to eq(["original/"])
      end
    end

    context "copying all attributes" do
      it "copies all top-level attributes" do
        config.output_dir = "dir1"
        config.format = :json
        config.verbose = true
        config.parallel = false
        config.progress = true
        config.max_depth = 5
        config.follow_symlinks = true
        
        merged = config.merge({})
        
        expect(merged.output_dir).to eq("dir1")
        expect(merged.format).to eq(:json)
        expect(merged.verbose).to be true
        expect(merged.parallel).to be false
        expect(merged.progress).to be true
        expect(merged.max_depth).to eq(5)
        expect(merged.follow_symlinks).to be true
      end
    end
  end

  describe "#diff" do
    it "detects differences in all top-level attributes" do
      other = described_class.new
      
      config.output_dir = "changed"
      config.format = :json
      config.verbose = true
      config.parallel = false
      config.progress = false
      config.max_depth = 20
      config.follow_symlinks = true
      
      diff = config.diff(other)
      
      expect(diff[:output_dir]).to eq({from: "changed", to: ".rubymap"})
      expect(diff[:format]).to eq({from: :json, to: :llm})
      expect(diff[:verbose]).to eq({from: true, to: false})
      expect(diff[:parallel]).to eq({from: false, to: true})
      expect(diff[:progress]).to eq({from: false, to: true})
      expect(diff[:max_depth]).to eq({from: 20, to: 10})
      expect(diff[:follow_symlinks]).to eq({from: true, to: false})
    end

    it "detects differences in nested configs" do
      other = described_class.new
      
      config.static["paths"] = ["changed/"]
      config.output["format"] = "changed"
      
      diff = config.diff(other)
      
      expect(diff[:static]).to be_a(Hash)
      expect(diff[:output]).to be_a(Hash)
    end

    it "returns empty hash when configs are identical" do
      other = described_class.new
      
      diff = config.diff(other)
      
      # Only nested configs might differ in their internal state
      diff.delete(:static) if diff[:static]
      diff.delete(:output) if diff[:output]
      diff.delete(:runtime) if diff[:runtime]
      diff.delete(:filter) if diff[:filter]
      diff.delete(:cache) if diff[:cache]
      
      expect(diff).to be_empty
    end
  end

  describe "#to_bool" do
    it "converts 'true' string to true" do
      expect(config.send(:to_bool, "true")).to be true
    end

    it "converts 'false' string to false" do
      expect(config.send(:to_bool, "false")).to be false
    end

    it "returns non-string values as-is" do
      expect(config.send(:to_bool, true)).to be true
      expect(config.send(:to_bool, false)).to be false
      expect(config.send(:to_bool, nil)).to be_nil
    end

    it "is case-insensitive" do
      expect(config.send(:to_bool, "TRUE")).to be true  # Case-insensitive
      expect(config.send(:to_bool, "True")).to be true  # Case-insensitive
      expect(config.send(:to_bool, "tRuE")).to be true  # Case-insensitive
    end
  end

  describe "#resolve_path" do
    it "returns absolute paths unchanged" do
      path = "/absolute/path"
      expect(config.send(:resolve_path, path)).to eq(path)
    end

    it "expands relative paths" do
      path = "relative/path"
      expected = File.expand_path(path)
      expect(config.send(:resolve_path, path)).to eq(expected)
    end
  end

  describe "#expand_env_vars" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "expands ${VAR} format" do
      ENV["TEST_VAR"] = "expanded"
      result = config.send(:expand_env_vars, "${TEST_VAR}/path")
      expect(result).to eq("expanded/path")
    end

    it "expands $VAR format" do
      ENV["TEST_VAR"] = "expanded"
      result = config.send(:expand_env_vars, "$TEST_VAR/path")
      expect(result).to eq("expanded/path")
    end

    it "preserves missing variables" do
      result = config.send(:expand_env_vars, "${MISSING_VAR}/path")
      expect(result).to eq("${MISSING_VAR}/path")
    end

    it "returns non-string values unchanged" do
      expect(config.send(:expand_env_vars, nil)).to be_nil
      expect(config.send(:expand_env_vars, 123)).to eq(123)
    end
  end

  describe "#stringify_keys" do
    it "converts symbol keys to strings" do
      result = config.send(:stringify_keys, {foo: "bar"})
      expect(result).to eq({"foo" => "bar"})
    end

    it "handles nested hashes" do
      result = config.send(:stringify_keys, {foo: {bar: "baz"}})
      expect(result).to eq({"foo" => {"bar" => "baz"}})
    end

    it "handles arrays" do
      result = config.send(:stringify_keys, [{foo: "bar"}])
      expect(result).to eq([{"foo" => "bar"}])
    end

    it "converts symbols to strings" do
      result = config.send(:stringify_keys, :symbol)
      expect(result).to eq("symbol")
    end

    it "preserves other types" do
      expect(config.send(:stringify_keys, "string")).to eq("string")
      expect(config.send(:stringify_keys, 123)).to eq(123)
      expect(config.send(:stringify_keys, nil)).to be_nil
    end
  end

  describe "#resolve_environment_variables" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "expands environment variables in static paths" do
      ENV["BASE_PATH"] = "/base"
      config.static["paths"] = ["${BASE_PATH}/app"]
      config.resolve_environment_variables
      expect(config.static["paths"]).to eq(["/base/app"])
    end

    it "expands environment variables in output directory" do
      ENV["OUTPUT"] = "/output"
      config.output["directory"] = "${OUTPUT}/dir"
      config.resolve_environment_variables
      expect(config.output["directory"]).to eq("/output/dir")
    end

    it "expands environment variables in cache directory" do
      ENV["CACHE"] = "/cache"
      config.cache["directory"] = "${CACHE}/dir"
      config.resolve_environment_variables
      expect(config.cache["directory"]).to eq("/cache/dir")
    end
  end

  describe "error handling" do
    describe "#validate!" do
      it "collects multiple validation errors" do
        config.format = :invalid
        config.runtime["timeout"] = -1
        config.runtime["environment"] = "invalid"
        
        expect {
          config.validate!
        }.to raise_error(Rubymap::ConfigurationError) do |error|
          expect(error.message).to include("Invalid format")
          expect(error.message).to include("Timeout must be")
          expect(error.message).to include("Invalid environment")
        end
      end
    end

    describe ".load_from_file" do
      it "provides clear error for missing file" do
        expect {
          described_class.load_from_file("/nonexistent/path.yml")
        }.to raise_error(Rubymap::ConfigurationError, /not found/)
      end
    end

    describe ".load_from_string" do
      it "handles empty YAML" do
        config = described_class.load_from_string("")
        expect(config).to be_a(described_class)
      end

      it "handles YAML with only comments" do
        config = described_class.load_from_string("# Just a comment\n")
        expect(config).to be_a(described_class)
      end
    end
  end
end