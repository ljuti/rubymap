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
      it "passes through extractor data without conversion" do
        # ExtractorResult should already provide data as hashes
        class_data = [{name: "Test", namespace: []}]
        module_data = [{name: "Helper", namespace: []}]
        
        extractor_result = double("result",
          classes: class_data,
          modules: module_data,
          methods: [],
          mixins: []
        )
        
        # Make it match the ExtractorResult pattern
        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        
        result = adapter.adapt(extractor_result)
        
        expect(result[:classes]).to eq(class_data)
        expect(result[:modules]).to eq(module_data)
        expect(result[:method_calls]).to eq([])
      end
      
      it "handles nil collections in extractor result" do
        extractor_result = double("result",
          classes: nil,
          modules: nil,
          methods: nil,
          mixins: nil
        )
        
        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        
        result = adapter.adapt(extractor_result)
        
        expect(result[:classes]).to eq([])
        expect(result[:modules]).to eq([])
        expect(result[:methods]).to eq([])
        expect(result[:mixins]).to eq([])
      end
      
      it "preserves collection references" do
        class_collection = [{name: "Test"}]
        module_collection = [{name: "Helper"}]
        method_collection = [{name: "test_method"}]
        mixin_collection = [{type: "include"}]
        
        extractor_result = double("result",
          classes: class_collection,
          modules: module_collection,
          methods: method_collection,
          mixins: mixin_collection
        )
        
        allow(extractor_result).to receive(:respond_to?).with(:classes).and_return(true)
        allow(extractor_result).to receive(:respond_to?).with(:modules).and_return(true)
        
        result = adapter.adapt(extractor_result)
        
        # Should return the same collection objects, not copies
        expect(result[:classes]).to be(class_collection)
        expect(result[:modules]).to be(module_collection)
        expect(result[:methods]).to be(method_collection)
        expect(result[:mixins]).to be(mixin_collection)
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
          mixins: []
        })
      end
      
      it "returns empty data for false" do
        result = adapter.adapt(false)
        
        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        })
      end
      
      it "returns empty data for strings" do
        result = adapter.adapt("invalid")
        
        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        })
      end
      
      it "returns empty data for arrays" do
        result = adapter.adapt([1, 2, 3])
        
        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        })
      end
      
      it "returns empty data for numbers" do
        result = adapter.adapt(42)
        
        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        })
      end
      
      it "returns empty data for true" do
        result = adapter.adapt(true)
        
        expect(result).to eq({
          classes: [],
          modules: [],
          methods: [],
          method_calls: [],
          mixins: []
        })
      end
    end
    
    context "duck typing for ExtractorResult" do
      it "recognizes objects with classes and modules methods" do
        duck_typed = double("duck",
          classes: [],
          modules: [],
          methods: [],
          mixins: []
        )
        
        allow(duck_typed).to receive(:respond_to?).with(:classes).and_return(true)
        allow(duck_typed).to receive(:respond_to?).with(:modules).and_return(true)
        
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
  end
end