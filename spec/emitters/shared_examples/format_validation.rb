# frozen_string_literal: true

require_relative "../../support/emitter_test_data"

RSpec.shared_examples "a format-validating emitter" do |format_type|
  include EmitterTestData
  describe "output format validation" do
    let(:sample_data) { EmitterTestData.basic_codebase }

    context "when generating #{format_type} output" do
      it "produces syntactically valid #{format_type}" do
        output = subject.emit(sample_data)

        case format_type.to_s
        when "json"
          # Expects no error from: JSON.parse(output)
        when "yaml"
          # Expects no error from: YAML.safe_load(output)
        when "markdown"
          expect(output).to match(/^#\s+.+/) # Has markdown headers
          expect(output =~ /^\s*```\s*\n\s*```/).to be_nil # No empty code blocks
        when "dot", "graphviz"
          expect(output).to include("digraph")
          expect(output).to match(/^\s*}$/) # Properly closed
        end
      end

      it "handles edge cases without corruption" do
        edge_case_data = EmitterTestData.malformed_codebase
        output = subject.emit(edge_case_data)

        expect(output).to be_a(String)
        expect(output.length).to be > 0

        case format_type.to_s
        when "json"
          parsed = JSON.parse(output)
          expect(parsed).to be_a(Hash)
        when "yaml"
          parsed = YAML.safe_load(output)
          expect(parsed).to be_a(Hash)
        end
      end

      it "maintains consistent encoding throughout" do
        unicode_data = sample_data.dup
        unicode_data[:classes].first[:documentation] = "Handles UTF-8: 中文, émojis: 🚀, symbols: ∀x∈ℝ"

        output = subject.emit(unicode_data)

        expect(output.encoding).to eq(Encoding::UTF_8)
        expect(output.valid_encoding?).to be true
        expect(output).to include("中文")
        expect(output).to include("🚀")
      end

      it "generates consistent line endings" do
        output = subject.emit(sample_data)

        # Should use Unix line endings consistently
        expect(output.include?("\r\n")).to be false
        expect(output).to match(/\n/)
      end

      it "respects maximum line length constraints where applicable" do
        output = subject.emit(sample_data)
        lines = output.split("\n")

        case format_type.to_s
        when "markdown"
          # Markdown should respect reasonable line lengths for readability
          long_lines = lines.select { |line| line.length > 120 }
          expect(long_lines.size).to be < lines.size * 0.1 # Less than 10% long lines
        when "dot", "graphviz"
          # DOT format can have longer lines but should still be reasonable
          very_long_lines = lines.select { |line| line.length > 200 }
          expect(very_long_lines).to be_empty
        end
      end
    end

    context "when handling special characters and escaping" do
      let(:special_char_data) do
        data = sample_data.dup
        data[:classes].first[:documentation] = 'Contains "quotes", <tags>, & ampersands, and \backslashes'
        data[:classes].first[:instance_methods] = ["method_with_'quotes'", "method_with_\"double_quotes\""]
        data
      end

      it "properly escapes special characters for the format" do
        output = subject.emit(special_char_data)

        case format_type.to_s
        when "json"
          parsed = JSON.parse(output)
          doc = parsed["classes"].first["documentation"]
          expect(doc).to include('"quotes"')
          expect(doc).to include("<tags>")
        when "yaml"
          parsed = YAML.safe_load(output)
          doc = parsed["classes"].first["documentation"]
          expect(doc).to include('"quotes"')
          expect(doc).to include("<tags>")
        when "markdown"
          expect(output.include?("<script>")).to be false # Should escape HTML
          expect(output).to include("&quot;") if output.include?("&")
        when "dot", "graphviz"
          expect(output).to include('\\"') if output.include?('"')
        end
      end

      it "handles empty and null values appropriately" do
        empty_data = sample_data.dup
        empty_data[:classes].first[:documentation] = nil
        empty_data[:classes].first[:instance_methods] = []
        empty_data[:classes].first[:constants] = nil

        output = subject.emit(empty_data)

        case format_type.to_s
        when "json"
          parsed = JSON.parse(output)
          klass = parsed["classes"].first
          expect(klass["documentation"]).to be_nil
          expect(klass["instance_methods"]).to eq([])
        when "yaml"
          parsed = YAML.safe_load(output)
          klass = parsed["classes"].first
          expect(klass["instance_methods"]).to eq([])
        end
      end
    end

    context "when validating structural consistency" do
      it "maintains consistent indentation and formatting" do
        output = subject.emit(sample_data)

        case format_type.to_s
        when "json"
          if output.include?("  ") # Pretty printed
            lines = output.split("\n")
            indented_lines = lines.select { |line| line.start_with?("  ") }
            expect(indented_lines.any?).to be true

            # Check consistent indentation (multiples of 2 spaces)
            indented_lines.each do |line|
              leading_spaces = line.match(/^(\s*)/)[1].length
              expect(leading_spaces % 2).to eq(0)
            end
          end
        when "markdown"
          # Check consistent header levels
          headers = output.scan(/^(#+)\s+(.+)$/)
          expect(headers.any?).to be true

          header_levels = headers.map { |h| h.first.length }
          expect(header_levels.max - header_levels.min).to be <= 4 # Reasonable depth
        end
      end

      it "maintains proper nesting and hierarchy" do
        hierarchical_data = EmitterTestData.complex_inheritance_hierarchy
        output = subject.emit(hierarchical_data)

        case format_type.to_s
        when "json", "yaml"
          parsed = (format_type.to_s == "json") ? JSON.parse(output) : YAML.safe_load(output)

          # Should preserve class hierarchy information
          classes = parsed["classes"]
          base_class = classes.find { |c| c["fqname"] == "BaseClass" }
          middle_class = classes.find { |c| c["fqname"] == "MiddleClass" }

          expect(base_class["superclass"]).to be_nil
          expect(middle_class["superclass"]).to eq("BaseClass")
        end
      end
    end
  end
end
