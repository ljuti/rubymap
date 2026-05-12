# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Normalizer::InputAdapter do
  let(:adapter) { described_class.new }

  describe "#adapt" do
    context "with Hash input" do
      it "normalizes hash data with all symbol types" do
        input = {
          classes: [{name: "Test"}],
          modules: [{name: "Helper"}],
          methods: [{name: "test"}],
          method_calls: [{from: "a", to: "b"}],
          mixins: [{type: "include"}]
        }

        result = adapter.adapt(input)

        expect(result[:classes]).to eq([{name: "Test"}])
        expect(result[:modules]).to eq([{name: "Helper"}])
        expect(result[:methods]).to eq([{name: "test"}])
        expect(result[:method_calls]).to eq([{from: "a", to: "b"}])
        expect(result[:mixins]).to eq([{type: "include"}])
      end

      it "converts nil values to empty arrays" do
        input = {classes: nil, modules: nil}
        result = adapter.adapt(input)

        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
      end

      it "provides empty arrays for missing keys" do
        input = {classes: [{name: "Test"}]}
        result = adapter.adapt(input)

        expect(result[:modules]).to eq([])
        expect(result[:methods]).to eq([])
        expect(result[:method_calls]).to eq([])
        expect(result[:mixins]).to eq([])
      end

      it "wraps non-array values in arrays" do
        input = {classes: {name: "Single"}}
        result = adapter.adapt(input)

        expect(result[:classes]).to eq([{name: "Single"}])
      end
    end

    context "with Extractor::Result input" do
      it "uses ExtractorResult's to_h method for conversion" do
        # ExtractorResult provides a to_h method that converts all its data
        hash_data = {
          classes: [{name: "Test", namespace: []}],
          modules: [{name: "Helper", namespace: []}],
          methods: [],
          mixins: [],
          constants: [],
          attributes: []
        }

        extractor_result = double("result")

        # Make it match the ExtractorResult pattern
        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        allow(extractor_result).to receive(:to_h).and_return(hash_data)

        result = adapter.adapt(extractor_result)

        expect(result[:classes]).to eq([{name: "Test", namespace: []}])
        expect(result[:modules]).to eq([{name: "Helper", namespace: []}])
        expect(result[:method_calls]).to eq([])
      end

      it "handles nil collections in extractor result" do
        hash_data = {
          classes: nil,
          modules: nil,
          methods: nil,
          mixins: nil
        }

        extractor_result = double("result")

        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        allow(extractor_result).to receive(:to_h).and_return(hash_data)

        result = adapter.adapt(extractor_result)

        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
        expect(result[:methods]).to eq([])
        expect(result[:mixins]).to eq([])
      end

      it "uses to_h method for data conversion" do
        hash_data = {
          classes: [{name: "Test"}],
          modules: [{name: "Helper"}],
          methods: [{name: "test_method"}],
          mixins: [{type: "include"}]
        }

        extractor_result = double("result")

        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        allow(extractor_result).to receive(:to_h).and_return(hash_data)

        result = adapter.adapt(extractor_result)

        # Should get the data from to_h method
        expect(result[:classes]).to eq([{name: "Test"}])
        expect(result[:modules]).to eq([{name: "Helper"}])
        expect(result[:methods]).to eq([{name: "test_method"}])
        expect(result[:mixins]).to eq([{type: "include"}])
      end
    end

    context "with invalid input" do
      it "returns empty data for nil" do
        result = adapter.adapt(nil)

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end

      it "returns empty data for false" do
        result = adapter.adapt(false)

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end

      it "returns empty data for strings" do
        result = adapter.adapt("invalid")

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end

      it "returns empty data for arrays" do
        result = adapter.adapt([1, 2, 3])

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end

      it "returns empty data for numbers" do
        result = adapter.adapt(42)

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end

      it "returns empty data for true" do
        result = adapter.adapt(true)

        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: [],
          attributes: [],
          dependencies: [],
          patterns: [],
          class_variables: [],
          aliases: []
        })
      end
    end

    context "duck typing for ExtractorResult" do
      it "recognizes objects with classes and modules methods" do
        hash_data = {
          classes: [],
          modules: [],
          methods: [],
          mixins: []
        }

        duck_typed = double("duck")

        allow(duck_typed).to receive(:respond_to?).with(:classes).and_return(true)
        allow(duck_typed).to receive(:respond_to?).with(:modules).and_return(true)
        allow(duck_typed).to receive(:to_h).and_return(hash_data)

        # This should be treated as an ExtractorResult
        result = adapter.adapt(duck_typed)

        expect(result).to include(:classes, :modules, :methods, :method_calls, :mixins)
      end

      it "does not recognize objects with only classes method" do
        partial = double("partial", classes: [])
        allow(partial).to receive(:respond_to?).with(:classes).and_return(true)
        allow(partial).to receive(:respond_to?).with(:modules).and_return(false)

        result = adapter.adapt(partial)

        # Should return empty data since it's not a valid ExtractorResult
        expect(result[:classes]).to eq([])
      end

      it "does not recognize Hash even with classes and modules keys" do
        hash = {classes: [], modules: []}

        result = adapter.adapt(hash)

        # Should be processed as a Hash, not ExtractorResult
        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
      end
    end


    context "deriving method_calls from methods" do
      it "derives method_calls from methods' calls_made arrays" do
        input = {
          methods: [
            {
              name: "save",
              owner: "User",
              scope: "instance",
              calls_made: [
                {receiver: ["Rails", "logger"], method: "info"},
                {method: "valid?"}
              ]
            },
            {
              name: "find",
              owner: "User",
              scope: "class",
              calls_made: [
                {receiver: ["ActiveRecord", "Base"], method: "find_by"}
              ]
            }
          ]
        }

        result = adapter.adapt(input)

        expect(result[:method_calls]).to include(
          {from: "User#save", to: "Rails.logger.info", type: "method_call"},
          {from: "User#save", to: "valid?", type: "method_call"},
          {from: "User.find", to: "ActiveRecord.Base.find_by", type: "method_call"}
        )
        expect(result[:method_calls].size).to eq(3)
      end

      it "handles methods with empty calls_made" do
        input = {
          methods: [
            {name: "empty_method", owner: "Test", calls_made: []}
          ]
        }

        result = adapter.adapt(input)
        expect(result[:method_calls]).to eq([])
      end

      it "handles methods without calls_made key" do
        input = {
          methods: [
            {name: "simple", owner: "Test"}
          ]
        }

        result = adapter.adapt(input)
        expect(result[:method_calls]).to eq([])
      end

      it "merges hash-level method_calls with derived ones" do
        input = {
          methods: [
            {name: "save", owner: "User", scope: "instance", calls_made: [{method: "valid?"}]}
          ],
          method_calls: [{from: "A", to: "B", type: "method_call"}]
        }

        result = adapter.adapt(input)

        expect(result[:method_calls]).to include(
          {from: "A", to: "B", type: "method_call"},
          {from: "User#save", to: "valid?", type: "method_call"}
        )
        expect(result[:method_calls].size).to eq(2)
      end
    end
  end
end

