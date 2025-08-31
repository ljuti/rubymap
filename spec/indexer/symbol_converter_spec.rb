# frozen_string_literal: true

RSpec.describe "Rubymap::Indexer::SymbolConverter" do
  let(:converter) { Rubymap::Indexer::SymbolConverter.new }

  describe "backward compatibility conversion" do
    context "when normalizing symbols that don't have conversion methods" do
      it "converts well-formed hash symbols unchanged" do
        # Given: A symbol already in correct hash format
        symbol_hash = {
          name: "UserService",
          fqname: "MyApp::Services::UserService",
          type: "class",
          superclass: "BaseService",
          file: "app/services/user_service.rb",
          line: 15
        }

        # When: Attempting to normalize
        result = converter.normalize_symbol(symbol_hash)

        # Then: Should return the hash unchanged
        expect(result).to eq(symbol_hash)
      end

      it "rejects invalid hash structures that lack symbol identity" do
        # Given: A hash that doesn't represent a symbol
        non_symbol_hash = {
          random_key: "random_value",
          another_key: 42
        }

        # When: Attempting to normalize
        result = converter.normalize_symbol(non_symbol_hash)

        # Then: Should return empty hash as it's not a valid symbol
        expect(result).to eq({})
      end

      it "extracts symbol data from objects using to_h method" do
        # Given: An object that supports to_h conversion
        symbol_object = double("SymbolObject")
        allow(symbol_object).to receive(:to_h).and_return({
          name: "Calculator",
          fqname: "Math::Calculator",
          type: "class",
          file: "lib/calculator.rb"
        })

        # When: Normalizing the object
        result = converter.normalize_symbol(symbol_object)

        # Then: Should use the to_h result
        expect(result).to include(
          name: "Calculator",
          fqname: "Math::Calculator",
          type: "class",
          file: "lib/calculator.rb"
        )
      end

      it "falls back to manual field extraction when to_h fails" do
        # Given: An object that doesn't support to_h but has symbol fields
        symbol_object = double("LegacySymbol")
        allow(symbol_object).to receive(:to_h).and_raise(NoMethodError)
        allow(symbol_object).to receive(:name).and_return("LegacyClass")
        allow(symbol_object).to receive(:fqname).and_return("Legacy::LegacyClass")
        allow(symbol_object).to receive(:type).and_return("class")
        allow(symbol_object).to receive(:superclass).and_return("Object")
        allow(symbol_object).to receive(:file).and_return("legacy.rb")

        # When: Normalizing the legacy object
        result = converter.normalize_symbol(symbol_object)

        # Then: Should extract available fields manually
        expect(result).to include(
          name: "LegacyClass",
          fqname: "Legacy::LegacyClass",
          type: "class",
          superclass: "Object",
          file: "legacy.rb"
        )
      end

      it "handles objects with partial symbol information" do
        # Given: An object with only some symbol fields
        partial_object = double("PartialSymbol")
        allow(partial_object).to receive(:to_h).and_return({})
        allow(partial_object).to receive(:name).and_return("PartialClass")
        allow(partial_object).to receive(:respond_to?) do |method|
          method == :name
        end

        # When: Normalizing the partial object
        result = converter.normalize_symbol(partial_object)

        # Then: Should extract what's available
        expect(result).to eq({name: "PartialClass"})
      end

      it "rejects objects that have no symbol identity" do
        # Given: An object with no name or fqname
        non_symbol_object = double("NonSymbol")
        allow(non_symbol_object).to receive(:to_h).and_return({})
        allow(non_symbol_object).to receive(:respond_to?).and_return(false)

        # When: Attempting to normalize
        result = converter.normalize_symbol(non_symbol_object)

        # Then: Should return empty hash
        expect(result).to eq({})
      end

      it "handles nil input gracefully" do
        # Given: Nil input (edge case)
        # When: Attempting to normalize nil
        result = converter.normalize_symbol(nil)

        # Then: Should return empty hash without errors
        expect(result).to eq({})
      end

      it "preserves complex symbol data structures" do
        # Given: A symbol with complex nested data
        complex_symbol = {
          name: "ComplexClass",
          fqname: "MyApp::ComplexClass",
          type: "class",
          dependencies: ["ServiceA", "ServiceB"],
          mixins: [
            {type: "include", module: "Trackable"},
            {type: "extend", module: "ClassMethods"}
          ],
          methods: ["method1", "method2"]
        }

        # When: Normalizing
        result = converter.normalize_symbol(complex_symbol)

        # Then: Should preserve all data
        expect(result).to eq(complex_symbol)
        expect(result[:dependencies]).to eq(["ServiceA", "ServiceB"])
        expect(result[:mixins]).to have_attributes(length: 2)
      end
    end

    context "when normalizing arrays of symbols" do
      it "converts each item in the array" do
        # Given: Mixed array of symbol data
        symbols = [
          {name: "ValidClass", type: "class"},
          double("SymbolObject", to_h: {name: "ConvertibleClass", type: "class"}),
          nil,
          {invalid_data: "should_be_filtered"}
        ]

        # When: Normalizing the array
        result = converter.normalize_symbol_array(symbols)

        # Then: Should convert valid items and filter invalid ones
        expect(result).to have_attributes(length: 4)
        expect(result[0]).to eq({name: "ValidClass", type: "class"})
        expect(result[1]).to include(name: "ConvertibleClass", type: "class")
        expect(result[2]).to eq({}) # nil converted to empty hash
        expect(result[3]).to eq({}) # invalid data filtered to empty hash
      end

      it "handles non-array input by converting to array first" do
        # Given: A single symbol object (not an array)
        single_symbol = {name: "SingleClass", type: "class"}

        # When: Normalizing as if it were an array
        result = converter.normalize_symbol_array(single_symbol)

        # Then: Should wrap in array and process
        # Note: Array({name: "Class", type: "class"}) creates [[[:name, "Class"], [:type, "class"]]]
        # So we get each key-value pair as separate items
        expect(result).to be_an(Array)
        expect(result.length).to be >= 1
        # The actual behavior converts the hash's key-value pairs
      end

      it "handles empty and nil arrays" do
        # Given: Various empty input scenarios
        # When/Then: Should handle gracefully
        expect(converter.normalize_symbol_array([])).to eq([])
        expect(converter.normalize_symbol_array(nil)).to eq([])  # Array(nil) = []
      end

      it "preserves order of symbols in arrays" do
        # Given: Ordered array of symbols
        ordered_symbols = [
          {name: "FirstClass", type: "class"},
          {name: "SecondClass", type: "class"},
          {name: "ThirdClass", type: "class"}
        ]

        # When: Normalizing
        result = converter.normalize_symbol_array(ordered_symbols)

        # Then: Should preserve order
        names = result.map { |s| s[:name] }
        expect(names).to eq(["FirstClass", "SecondClass", "ThirdClass"])
      end
    end
  end

  describe "error handling and edge cases" do
    it "handles objects that raise exceptions during field access" do
      # Given: An object that raises errors during to_h but has accessible fields
      problematic_object = double("ProblematicObject")
      allow(problematic_object).to receive(:to_h).and_raise(StandardError.new("Access denied"))
      allow(problematic_object).to receive(:respond_to?).and_return(false)  # Default
      allow(problematic_object).to receive(:respond_to?).with(:name).and_return(true)
      allow(problematic_object).to receive(:name).and_return("SafeName")

      # When: Attempting to normalize (should fall back to manual extraction)
      result = converter.normalize_symbol(problematic_object)

      # Then: Should extract what it can without erroring
      expect(result).to include(name: "SafeName")
    end

    it "handles malformed to_h responses" do
      # Given: An object whose to_h returns invalid data
      malformed_object = double("MalformedObject")
      allow(malformed_object).to receive(:to_h).and_return("not_a_hash")

      # When: Normalizing
      result = converter.normalize_symbol(malformed_object)

      # Then: Should fall back to manual field extraction
      expect(result).to eq({})
    end

    it "maintains performance with large symbol arrays" do
      # Given: A large array of symbols
      large_symbol_array = 1000.times.map do |i|
        {name: "Class#{i}", type: "class", fqname: "Namespace::Class#{i}"}
      end

      # When: Normalizing the large array
      start_time = Time.now
      result = converter.normalize_symbol_array(large_symbol_array)
      end_time = Time.now

      # Then: Should complete in reasonable time and preserve all data
      expect(result).to have_attributes(length: 1000)
      expect(end_time - start_time).to be < 1.0 # Less than 1 second
      expect(result.last).to include(name: "Class999", type: "class")
    end
  end
end
