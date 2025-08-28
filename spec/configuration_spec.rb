# frozen_string_literal: true

RSpec.describe Rubymap::Configuration do
  let(:config) { described_class.new }

  describe "default configuration" do
    it "sets default values" do
      expect(config.output_dir).to eq(".rubymap")
      expect(config.format).to eq(:llm)
      expect(config.verbose).to be false
      expect(config.parallel).to be true
      expect(config.progress).to be true
      expect(config.max_depth).to eq(10)
      expect(config.follow_symlinks).to be false
    end

    it "sets default static analysis settings" do
      expect(config.static["paths"]).to eq(["."])
      expect(config.static["exclude"]).to eq(["vendor/", "node_modules/"])
      expect(config.static["follow_requires"]).to be false
      expect(config.static["parse_yard"]).to be false
      expect(config.static["parse_rbs"]).to be false
      expect(config.static["max_file_size"]).to eq(1_000_000)
    end

    it "sets default output settings" do
      expect(config.output["directory"]).to eq(".rubymap")
      expect(config.output["format"]).to eq("llm")
      expect(config.output["split_files"]).to be false
      expect(config.output["include_source"]).to be false
      expect(config.output["include_todos"]).to be false
      expect(config.output["redact_sensitive"]).to be true
    end

    it "sets default runtime settings" do
      expect(config.runtime["enabled"]).to be false
      expect(config.runtime["timeout"]).to eq(30)
      expect(config.runtime["safe_mode"]).to be true
      expect(config.runtime["environment"]).to eq("development")
      expect(config.runtime["skip_initializers"]).to eq([])
      expect(config.runtime["load_paths"]).to eq([])
    end

    it "sets default filter settings" do
      expect(config.filter["include_private"]).to be false
      expect(config.filter["include_protected"]).to be true
      expect(config.filter["exclude_patterns"]).to include("**/vendor/**", "**/spec/**")
      expect(config.filter["include_patterns"]).to eq(["**/*.rb"])
      expect(config.filter["exclude_methods"]).to eq([])
      expect(config.filter["include_only"]).to be_nil
    end

    it "sets default cache settings" do
      expect(config.cache["enabled"]).to be true
      expect(config.cache["directory"]).to eq(".rubymap_cache")
      expect(config.cache["ttl"]).to eq(86400)
    end
  end

  describe "configuration loading" do
    describe ".load_from_string" do
      context "with valid YAML" do
        let(:yaml_content) do
          <<~YAML
            static:
              paths:
                - app/
                - lib/
              exclude:
                - tmp/
              follow_requires: true
              parse_yard: true
              
            output:
              directory: custom_output
              format: json
              split_files: true
              
            runtime:
              enabled: true
              timeout: 60
              environment: production
              
            filter:
              include_private: true
              exclude_patterns:
                - "**/test/**"
          YAML
        end

        it "loads static configuration" do
          config = described_class.load_from_string(yaml_content)
          
          expect(config.static["paths"]).to eq(["app/", "lib/"])
          expect(config.static["exclude"]).to eq(["tmp/"])
          expect(config.static["follow_requires"]).to be true
          expect(config.static["parse_yard"]).to be true
        end

        it "loads output configuration" do
          config = described_class.load_from_string(yaml_content)
          
          expect(config.output["directory"]).to eq("custom_output")
          expect(config.output["format"]).to eq("json")
          expect(config.output["split_files"]).to be true
        end

        it "loads runtime configuration" do
          config = described_class.load_from_string(yaml_content)
          
          expect(config.runtime["enabled"]).to be true
          expect(config.runtime["timeout"]).to eq(60)
          expect(config.runtime["environment"]).to eq("production")
        end

        it "loads filter configuration" do
          config = described_class.load_from_string(yaml_content)
          
          expect(config.filter["include_private"]).to be true
          expect(config.filter["exclude_patterns"]).to eq(["**/test/**"])
        end
      end

      context "with invalid YAML" do
        it "raises ConfigurationError" do
          expect {
            described_class.load_from_string("invalid: yaml: :")
          }.to raise_error(Rubymap::ConfigurationError, /Invalid YAML/)
        end
      end
    end

    describe ".load_from_file" do
      let(:config_file) { Tempfile.new(["config", ".yml"]) }
      
      after { config_file.unlink }

      context "when file exists" do
        before do
          config_file.write(<<~YAML)
            output_dir: custom_dir
            format: json
            verbose: true
          YAML
          config_file.rewind
        end

        it "loads configuration from file" do
          config = described_class.load_from_file(config_file.path)
          
          expect(config.output_dir).to eq("custom_dir")
          expect(config.format).to eq(:json)
          expect(config.verbose).to be true
        end
      end

      context "when file does not exist" do
        it "raises ConfigurationError" do
          expect {
            described_class.load_from_file("/non/existent/file.yml")
          }.to raise_error(Rubymap::ConfigurationError, /not found/)
        end
      end
    end

    describe ".from_hash" do
      it "creates configuration from hash" do
        config = described_class.from_hash({
          output_dir: "from_hash",
          format: "yaml",
          verbose: true,
          static: {
            paths: ["src/"]
          }
        })
        
        expect(config.output_dir).to eq("from_hash")
        expect(config.format).to eq(:yaml)
        expect(config.verbose).to be true
        expect(config.static["paths"]).to eq(["src/"])
      end
    end
  end

  describe "environment variable loading" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "loads from RUBYMAP_ prefixed environment variables" do
      ENV["RUBYMAP_OUTPUT_DIR"] = "env_output"
      ENV["RUBYMAP_FORMAT"] = "json"
      ENV["RUBYMAP_VERBOSE"] = "true"
      
      config = described_class.new
      
      expect(config.output_dir).to eq("env_output")
      expect(config.format).to eq(:json)
      expect(config.verbose).to be true
    end

    it "supports nested configuration via environment variables" do
      ENV["RUBYMAP_STATIC__PARSE_YARD"] = "true"
      ENV["RUBYMAP_RUNTIME__TIMEOUT"] = "120"
      
      config = described_class.new
      
      expect(config.static["parse_yard"]).to be true
      expect(config.runtime["timeout"]).to eq(120)
    end
  end

  describe "profiles" do
    describe ".development" do
      let(:config) { described_class.development }

      it "applies development profile settings" do
        expect(config.verbose).to be true
        expect(config.output_dir).to eq("tmp/rubymap")
        expect(config.output["directory"]).to eq("tmp/rubymap")
        expect(config.runtime["safe_mode"]).to be false
        expect(config.cache["enabled"]).to be false
        expect(config.filter["include_private"]).to be true
      end
    end

    describe ".production" do
      let(:config) { described_class.production }

      it "applies production profile settings" do
        expect(config.verbose).to be false
        expect(config.output_dir).to eq("docs/rubymap")
        expect(config.output["directory"]).to eq("docs/rubymap")
        expect(config.runtime["safe_mode"]).to be true
        expect(config.cache["enabled"]).to be true
        expect(config.filter["include_private"]).to be false
        expect(config.output["redact_sensitive"]).to be true
      end
    end

    describe ".ci" do
      let(:config) { described_class.ci }

      it "applies CI profile settings" do
        expect(config.verbose).to be true
        expect(config.output_dir).to eq("artifacts/rubymap")
        expect(config.output["directory"]).to eq("artifacts/rubymap")
        expect(config.runtime["enabled"]).to be false
        expect(config.parallel).to be false
        expect(config.progress).to be false
      end
    end

    describe "#apply_profile" do
      it "applies named profile" do
        config.apply_profile(:development)
        
        expect(config.verbose).to be true
        expect(config.output_dir).to eq("tmp/rubymap")
      end

      it "raises error for unknown profile" do
        expect {
          config.apply_profile(:unknown)
        }.to raise_error(Rubymap::ConfigurationError, /Unknown profile/)
      end
    end
  end

  describe "validation" do
    describe "#validate!" do
      context "with valid configuration" do
        it "returns true" do
          expect(config.validate!).to be true
        end
      end

      context "with invalid format" do
        before { config.format = :invalid }

        it "raises ConfigurationError" do
          expect {
            config.validate!
          }.to raise_error(Rubymap::ConfigurationError, /Invalid format/)
        end
      end

      context "with invalid timeout" do
        before { config.runtime["timeout"] = -5 }

        it "raises ConfigurationError" do
          expect {
            config.validate!
          }.to raise_error(Rubymap::ConfigurationError, /Timeout must be a positive/)
        end
      end

      context "with invalid environment" do
        before { config.runtime["environment"] = "invalid_env" }

        it "raises ConfigurationError" do
          expect {
            config.validate!
          }.to raise_error(Rubymap::ConfigurationError, /Invalid environment/)
        end
      end

      context "with non-existent path" do
        before { config.static["paths"] = ["/non/existent/path"] }

        it "raises ConfigurationError" do
          expect {
            config.validate!
          }.to raise_error(Rubymap::ConfigurationError, /Path does not exist/)
        end
      end

      context "with non-writable output directory" do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:writable?).and_return(false)
        end

        it "raises ConfigurationError" do
          expect {
            config.validate!
          }.to raise_error(Rubymap::ConfigurationError, /not writable/)
        end
      end
    end

    describe "#validate" do
      it "returns true for valid configuration" do
        expect(config.validate).to be true
      end

      it "returns false for invalid configuration" do
        config.format = :invalid
        expect(config.validate).to be false
      end
    end

    describe "#validate_and_explain" do
      it "returns success message for valid configuration" do
        expect(config.validate_and_explain).to eq("Configuration is valid")
      end

      it "returns detailed error for invalid configuration" do
        config.format = :invalid
        result = config.validate_and_explain
        
        expect(result).to include("Configuration validation failed")
        expect(result).to include("Invalid format")
      end
    end
  end

  describe "backward compatibility methods" do
    it "provides include_private accessor" do
      config.include_private = true
      expect(config.include_private).to be true
      expect(config.filter["include_private"]).to be true
    end

    it "provides include_protected accessor" do
      config.include_protected = false
      expect(config.include_protected).to be false
      expect(config.filter["include_protected"]).to be false
    end

    it "provides exclude_patterns accessor" do
      patterns = ["**/tmp/**"]
      config.exclude_patterns = patterns
      expect(config.exclude_patterns).to eq(patterns)
      expect(config.filter["exclude_patterns"]).to eq(patterns)
    end

    it "provides include_patterns accessor" do
      patterns = ["**/*.rake"]
      config.include_patterns = patterns
      expect(config.include_patterns).to eq(patterns)
      expect(config.filter["include_patterns"]).to eq(patterns)
    end

    it "provides runtime_introspection accessor" do
      config.runtime_introspection = true
      expect(config.runtime_introspection).to be true
      expect(config.runtime["enabled"]).to be true
    end
  end

  describe "#describe" do
    it "provides human-readable description" do
      description = config.describe
      
      expect(description).to include("Rubymap Configuration")
      expect(description).to include("Static Analysis")
      expect(description).to include("Output")
      expect(description).to include("Runtime Analysis")
      expect(description).to include("Filter")
    end
  end

  describe "#merge" do
    let(:other_config) do
      {
        output_dir: "merged",
        static: {
          paths: ["merged/"],
          parse_yard: true
        }
      }
    end

    it "merges configurations" do
      merged = config.merge(other_config)
      
      expect(merged.output_dir).to eq("merged")
      expect(merged.static["paths"]).to eq(["merged/"])
      expect(merged.static["parse_yard"]).to be true
      # Original should have unchanged values
      expect(merged.static["follow_requires"]).to be false
    end

    it "does not modify original configuration" do
      original_output_dir = config.output_dir
      config.merge(other_config)
      
      expect(config.output_dir).to eq(original_output_dir)
    end

    it "merges with another Configuration instance" do
      other = described_class.new
      other.output_dir = "other"
      
      merged = config.merge(other)
      expect(merged.output_dir).to eq("other")
    end
  end

  describe "#deep_merge!" do
    it "merges configuration in place" do
      config.deep_merge!({
        output_dir: "merged",
        static: {
          parse_yard: true
        }
      })
      
      expect(config.output_dir).to eq("merged")
      expect(config.static["parse_yard"]).to be true
    end
  end

  describe "#diff" do
    it "shows differences between configurations" do
      other = described_class.new
      other.output_dir = "different"
      other.verbose = true
      
      differences = config.diff(other)
      
      expect(differences[:output_dir]).to eq({
        from: ".rubymap",
        to: "different"
      })
      expect(differences[:verbose]).to eq({
        from: false,
        to: true
      })
    end
  end

  describe "#to_yaml" do
    it "serializes to YAML" do
      config.output_dir = "test_dir"
      config.format = :json
      
      yaml = config.to_yaml
      parsed = YAML.safe_load(yaml)
      
      expect(parsed["output"]["directory"]).to eq(".rubymap")
      expect(parsed["output"]["format"]).to eq("llm")
    end
  end

  describe "#to_h / #to_hash" do
    it "converts to hash representation" do
      hash = config.to_h
      
      expect(hash).to have_key(:static)
      expect(hash).to have_key(:output)
      expect(hash).to have_key(:runtime)
      expect(hash).to have_key(:filter)
      expect(hash).to have_key(:cache)
    end

    it "includes nested configuration values" do
      hash = config.to_hash
      
      expect(hash[:static]["paths"]).to eq(["."])
      expect(hash[:output]["format"]).to eq("llm")
      expect(hash[:runtime]["enabled"]).to be false
    end
  end

  describe "type coercion" do
    it "coerces boolean strings to booleans" do
      config = described_class.new
      config.verbose = "true"
      config.parallel = "false"
      
      expect(config.verbose).to be true
      expect(config.parallel).to be false
    end

    it "coerces integer strings to integers" do
      config = described_class.new
      config.max_depth = "5"
      
      expect(config.max_depth).to eq(5)
      
      # Test nested value coercion through deep_merge!
      config2 = described_class.new
      config2.deep_merge!({"runtime" => {"timeout" => "120"}})
      expect(config2.runtime["timeout"]).to eq(120)
    end

    it "converts format string to symbol" do
      config = described_class.new
      config.format = "json"
      
      expect(config.format).to eq(:json)
    end
  end

  describe "environment variable expansion" do
    around do |example|
      original_env = ENV.to_h
      example.run
      ENV.replace(original_env)
    end

    it "expands environment variables in paths" do
      ENV["CUSTOM_DIR"] = "/custom/path"
      
      config.output["directory"] = "${CUSTOM_DIR}/output"
      config.resolve_environment_variables
      
      expect(config.output["directory"]).to eq("/custom/path/output")
    end

    it "handles missing environment variables" do
      config.output["directory"] = "${MISSING_VAR}/output"
      config.resolve_environment_variables
      
      expect(config.output["directory"]).to eq("${MISSING_VAR}/output")
    end

    it "expands simple environment variable format" do
      ENV["HOME"] = "/home/user"
      
      config.cache["directory"] = "$HOME/.cache"
      config.resolve_environment_variables
      
      expect(config.cache["directory"]).to eq("/home/user/.cache")
    end
  end
end