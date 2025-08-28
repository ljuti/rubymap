# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Calculators::ConfidenceCalculator do
  subject(:confidence_calculator) { described_class.new }

  describe "behavior when calculating confidence scores" do
    context "when data has RBS source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:rbs] } }

      it "assigns highest base confidence for RBS source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.95)
      end
    end

    context "when data has Sorbet source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:sorbet] } }

      it "assigns high confidence for Sorbet source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.90)
      end
    end

    context "when data has YARD source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:yard] } }

      it "assigns good confidence for YARD source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.80)
      end
    end

    context "when data has runtime source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:runtime] } }

      it "assigns high confidence for runtime source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.85)
      end
    end

    context "when data has static source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:static] } }

      it "assigns moderate confidence for static source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)
      end
    end

    context "when data has inferred source" do
      let(:data) { { source: Rubymap::Normalizer::DATA_SOURCES[:inferred] } }

      it "assigns lowest confidence for inferred source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.50)
      end
    end

    context "when data has no source specified" do
      let(:data) { { name: "SomeClass" } }

      it "defaults to inferred source confidence" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.50)
      end
    end

    context "when data has unknown source" do
      let(:data) { { source: "unknown_source" } }

      it "defaults to inferred source confidence for unknown sources" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.50)
      end
    end

    context "when data has nil source" do
      let(:data) { { source: nil } }

      it "defaults to inferred source confidence for nil source" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.50)
      end
    end
  end

  describe "behavior when applying confidence modifiers" do
    context "when location information is present" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: { file: "app/models/user.rb", line: 10 }
        }
      end

      it "boosts confidence by 0.05 when location is present" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.80)  # 0.75 base + 0.05 location boost
      end
    end

    context "when location information is missing" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static]
        }
      end

      it "does not apply location boost when location is missing" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end

    context "when location is nil" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: nil
        }
      end

      it "does not apply location boost when location is nil" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end

    context "when location is empty hash" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: {}
        }
      end

      it "applies location boost even for empty hash location" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.80)  # 0.75 base + 0.05 location boost
      end
    end

    context "when location is false" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: false
        }
      end

      it "does not apply location boost when location is false" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end
  end

  describe "behavior when applying name-based confidence penalties" do
    context "when name is nil" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: nil
        }
      end

      it "reduces confidence by 0.10 when name is nil" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.65)  # 0.75 base - 0.10 name penalty
      end
    end

    context "when name is empty string" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: ""
        }
      end

      it "reduces confidence by 0.10 when name is empty" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.65)  # 0.75 base - 0.10 name penalty
      end
    end

    context "when name is present" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: "User"
        }
      end

      it "does not apply name penalty when name is present" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end

    context "when name is whitespace only" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: "   "
        }
      end

      it "does not apply name penalty for whitespace-only names" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only (not considered empty)
      end
    end

    context "when name is zero" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: 0
        }
      end

      it "does not apply name penalty for zero (not nil or empty string)" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end

    context "when name is false" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: false
        }
      end

      it "does not apply name penalty for false (not nil or empty string)" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.75)  # Base confidence only
      end
    end
  end

  describe "behavior when applying multiple confidence modifiers" do
    context "when both location boost and name penalty apply" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: { file: "app/models/user.rb", line: 10 },
          name: nil
        }
      end

      it "applies both location boost and name penalty" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.70)  # 0.75 base + 0.05 location - 0.10 name = 0.70
      end
    end

    context "when location boost pushes confidence over 1.0" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:rbs],  # 0.95 base
          location: { file: "app/models/user.rb", line: 10 }  # +0.05 boost
        }
      end

      it "caps confidence at 1.0 maximum" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(1.0)  # Capped at 1.0, not 1.00
      end
    end

    context "when modifiers result in very high confidence" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:sorbet],  # 0.90 base
          location: { file: "app/models/user.rb", line: 10 },  # +0.05 boost
          name: "User"  # No penalty
        }
      end

      it "calculates correct high confidence without capping below 1.0" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.95)  # 0.90 + 0.05 = 0.95
      end
    end

    context "when modifiers result in very low confidence" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:inferred],  # 0.50 base
          name: nil  # -0.10 penalty
        }
      end

      it "allows confidence to go below typical minimum thresholds" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.40)  # 0.50 - 0.10 = 0.40
      end
    end

    context "when all positive modifiers apply" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:rbs],  # 0.95 base (highest)
          location: { file: "app/models/user.rb", line: 10 },  # +0.05 boost
          name: "User"  # No penalty (good name)
        }
      end

      it "achieves maximum confidence with best case scenario" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(1.0)  # 0.95 + 0.05 = 1.00, capped at 1.0
      end
    end

    context "when all negative modifiers apply" do
      let(:data) do
        {
          source: "unknown",  # Defaults to inferred (0.50 base)
          name: ""  # -0.10 penalty (empty name)
          # No location (no boost)
        }
      end

      it "calculates minimum confidence with worst case scenario" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.40)  # 0.50 - 0.10 = 0.40
      end
    end
  end

  describe "edge case behavior" do
    context "when data is nil" do
      it "handles nil data gracefully" do
        expect { confidence_calculator.calculate(nil) }.to raise_error(NoMethodError)
      end
    end

    context "when data is empty hash" do
      let(:data) { {} }

      it "handles empty data hash using defaults" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.50)  # Default inferred confidence
      end
    end

    context "when data has unexpected structure" do
      let(:data) { "not a hash" }

      it "handles non-hash data" do
        expect { confidence_calculator.calculate(data) }.to raise_error(NoMethodError)
      end
    end

    context "when data has symbol keys instead of string keys" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          location: { file: "app/models/user.rb", line: 10 },
          name: "User"
        }
      end

      it "works correctly with symbol keys" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.80)  # 0.75 + 0.05 location boost
      end
    end

    context "when data has extra unexpected keys" do
      let(:data) do
        {
          source: Rubymap::Normalizer::DATA_SOURCES[:static],
          name: "User",
          location: { file: "app/models/user.rb", line: 10 },
          extra_field: "unexpected",
          another_field: 42
        }
      end

      it "ignores unexpected keys and processes known ones" do
        confidence = confidence_calculator.calculate(data)
        
        expect(confidence).to eq(0.80)  # 0.75 base + 0.05 location boost
      end
    end
  end

  describe "source precedence consistency" do
    context "when comparing all source types" do
      it "maintains expected confidence hierarchy" do
        sources_by_confidence = [
          { source: Rubymap::Normalizer::DATA_SOURCES[:rbs], expected: 0.95 },
          { source: Rubymap::Normalizer::DATA_SOURCES[:sorbet], expected: 0.90 },
          { source: Rubymap::Normalizer::DATA_SOURCES[:runtime], expected: 0.85 },
          { source: Rubymap::Normalizer::DATA_SOURCES[:yard], expected: 0.80 },
          { source: Rubymap::Normalizer::DATA_SOURCES[:static], expected: 0.75 },
          { source: Rubymap::Normalizer::DATA_SOURCES[:inferred], expected: 0.50 }
        ]

        sources_by_confidence.each do |test_case|
          data = { source: test_case[:source] }
          confidence = confidence_calculator.calculate(data)
          
          expect(confidence).to eq(test_case[:expected]),
            "Expected #{test_case[:source]} to have confidence #{test_case[:expected]}, got #{confidence}"
        end
      end

      it "ensures RBS has highest confidence" do
        rbs_confidence = confidence_calculator.calculate({ source: Rubymap::Normalizer::DATA_SOURCES[:rbs] })
        other_sources = [
          Rubymap::Normalizer::DATA_SOURCES[:sorbet],
          Rubymap::Normalizer::DATA_SOURCES[:runtime],
          Rubymap::Normalizer::DATA_SOURCES[:yard],
          Rubymap::Normalizer::DATA_SOURCES[:static],
          Rubymap::Normalizer::DATA_SOURCES[:inferred]
        ]

        other_sources.each do |source|
          other_confidence = confidence_calculator.calculate({ source: source })
          expect(rbs_confidence).to be > other_confidence,
            "RBS confidence (#{rbs_confidence}) should be higher than #{source} confidence (#{other_confidence})"
        end
      end

      it "ensures inferred has lowest base confidence" do
        inferred_confidence = confidence_calculator.calculate({ source: Rubymap::Normalizer::DATA_SOURCES[:inferred] })
        other_sources = [
          Rubymap::Normalizer::DATA_SOURCES[:rbs],
          Rubymap::Normalizer::DATA_SOURCES[:sorbet],
          Rubymap::Normalizer::DATA_SOURCES[:runtime],
          Rubymap::Normalizer::DATA_SOURCES[:yard],
          Rubymap::Normalizer::DATA_SOURCES[:static]
        ]

        other_sources.each do |source|
          other_confidence = confidence_calculator.calculate({ source: source })
          expect(inferred_confidence).to be < other_confidence,
            "Inferred confidence (#{inferred_confidence}) should be lower than #{source} confidence (#{other_confidence})"
        end
      end
    end
  end
end