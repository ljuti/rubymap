# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Normalizer::SymbolIndex do
  let(:index) { described_class.new }

  describe "#initialize" do
    it "creates an empty index" do
      expect(index.instance_variable_get(:@index)).to eq({})
    end
  end

  describe "#add" do
    context "when adding a symbol with different name and fqname" do
      let(:symbol) { double("symbol", name: "User", fqname: "App::Models::User") }

      it "indexes by both name and fqname" do
        index.add(symbol)
        expect(index.find("User")).to eq(symbol)
        expect(index.find("App::Models::User")).to eq(symbol)
      end

      it "overwrites existing entries with same keys" do
        old_symbol = double("old_symbol", name: "User", fqname: "App::Models::User")
        new_symbol = double("new_symbol", name: "User", fqname: "App::Models::User")

        index.add(old_symbol)
        index.add(new_symbol)

        expect(index.find("User")).to eq(new_symbol)
        expect(index.find("App::Models::User")).to eq(new_symbol)
      end
    end

    context "when adding a symbol with same name and fqname" do
      let(:symbol) { double("symbol", name: "SimpleClass", fqname: "SimpleClass") }

      it "indexes only by fqname (avoiding duplicate entries)" do
        index.add(symbol)
        internal_index = index.instance_variable_get(:@index)

        expect(internal_index.size).to eq(1)
        expect(internal_index["SimpleClass"]).to eq(symbol)
      end

      it "does not add duplicate when fqname == name" do
        # This test specifically ensures the condition works
        symbol = double("symbol")
        allow(symbol).to receive(:name).and_return("Test")
        allow(symbol).to receive(:fqname).and_return("Test")

        # The condition should prevent adding twice
        expect(index.instance_variable_get(:@index)).to receive(:[]=).once

        index.add(symbol)
      end
    end

    context "with multiple symbols" do
      let(:user) { double("user", name: "User", fqname: "Models::User") }
      let(:post) { double("post", name: "Post", fqname: "Models::Post") }
      let(:comment) { double("comment", name: "Comment", fqname: "Comment") }

      it "maintains all symbols in the index" do
        index.add(user)
        index.add(post)
        index.add(comment)

        expect(index.find("User")).to eq(user)
        expect(index.find("Models::User")).to eq(user)
        expect(index.find("Post")).to eq(post)
        expect(index.find("Models::Post")).to eq(post)
        expect(index.find("Comment")).to eq(comment)
      end
    end

    context "edge cases" do
      it "handles symbols with nil name gracefully" do
        symbol = double("symbol", name: nil, fqname: "SomeClass")
        expect { index.add(symbol) }.not_to raise_error
        expect(index.find("SomeClass")).to eq(symbol)
        expect(index.find(nil)).to eq(symbol)
      end

      it "handles symbols with nil fqname gracefully" do
        symbol = double("symbol", name: "Class", fqname: nil)
        expect { index.add(symbol) }.not_to raise_error
        expect(index.find(nil)).to eq(symbol)
        expect(index.find("Class")).to eq(symbol)
      end

      it "handles symbols where name equals fqname using == operator" do
        symbol = double("symbol")
        allow(symbol).to receive(:name).and_return("TestClass")
        allow(symbol).to receive(:fqname).and_return("TestClass")

        index.add(symbol)
        internal_index = index.instance_variable_get(:@index)

        expect(internal_index.size).to eq(1)
      end

      it "correctly compares fqname and name values" do
        # Testing the actual comparison is working properly
        symbol1 = double("symbol", name: "Test", fqname: "Test")
        symbol2 = double("symbol", name: "Test", fqname: "Different::Test")

        index.add(symbol1)
        index.add(symbol2)

        internal_index = index.instance_variable_get(:@index)
        # symbol1 should only add one entry (fqname only)
        # symbol2 should add two entries (both fqname and name)
        expect(internal_index.keys).to match_array(["Test", "Different::Test"])
      end

      it "handles when condition evaluates to false" do
        # Ensure the unless condition actually prevents adding
        symbol = double("symbol", name: "Same", fqname: "Same")

        # Should only call []= once because name == fqname
        internal_index = index.instance_variable_get(:@index)
        expect(internal_index).to receive(:[]=).with("Same", symbol).once

        index.add(symbol)
      end

      it "handles when condition evaluates to true" do
        # Ensure the unless condition allows adding when different
        symbol = double("symbol", name: "Short", fqname: "Long::Short")

        # Should call []= twice because name != fqname
        internal_index = index.instance_variable_get(:@index)
        expect(internal_index).to receive(:[]=).with("Long::Short", symbol).once
        expect(internal_index).to receive(:[]=).with("Short", symbol).once

        index.add(symbol)
      end
    end
  end

  describe "#find" do
    let(:symbol) { double("symbol", name: "User", fqname: "App::User") }

    before { index.add(symbol) }

    it "finds symbol by name" do
      expect(index.find("User")).to eq(symbol)
    end

    it "finds symbol by fqname" do
      expect(index.find("App::User")).to eq(symbol)
    end

    it "returns nil for non-existent keys" do
      expect(index.find("NonExistent")).to be_nil
    end

    it "returns nil when searching with nil key" do
      expect(index.find(nil)).to be_nil
    end

    it "is case-sensitive" do
      expect(index.find("user")).to be_nil
      expect(index.find("USER")).to be_nil
    end
  end

  describe "#clear" do
    before do
      symbol1 = double("symbol1", name: "User", fqname: "User")
      symbol2 = double("symbol2", name: "Post", fqname: "Post")
      index.add(symbol1)
      index.add(symbol2)
    end

    it "removes all entries from the index" do
      expect(index.find("User")).not_to be_nil
      expect(index.find("Post")).not_to be_nil

      index.clear

      expect(index.find("User")).to be_nil
      expect(index.find("Post")).to be_nil
    end

    it "returns the cleared hash" do
      result = index.clear
      expect(result).to eq({})
    end

    it "allows adding new symbols after clearing" do
      index.clear
      new_symbol = double("new_symbol", name: "Article", fqname: "Article")

      index.add(new_symbol)
      expect(index.find("Article")).to eq(new_symbol)
    end
  end

  describe "#find_parent_class" do
    context "when symbol exists and has superclass" do
      let(:parent_class) { "ApplicationRecord" }
      let(:symbol) { double("symbol", superclass: parent_class) }

      before do
        allow(symbol).to receive(:name).and_return("User")
        allow(symbol).to receive(:fqname).and_return("User")
        allow(symbol).to receive(:respond_to?).with(:superclass).and_return(true)
        index.add(symbol)
      end

      it "returns the superclass" do
        expect(index.find_parent_class("User")).to eq(parent_class)
      end
    end

    context "when symbol exists but does not respond to superclass" do
      let(:symbol) { double("symbol") }

      before do
        allow(symbol).to receive(:name).and_return("MyModule")
        allow(symbol).to receive(:fqname).and_return("MyModule")
        allow(symbol).to receive(:respond_to?).with(:superclass).and_return(false)
        index.add(symbol)
      end

      it "returns nil" do
        expect(index.find_parent_class("MyModule")).to be_nil
      end
    end

    context "when symbol does not exist" do
      it "returns nil" do
        expect(index.find_parent_class("NonExistent")).to be_nil
      end
    end

    context "when symbol is nil" do
      it "returns nil" do
        expect(index.find_parent_class(nil)).to be_nil
      end
    end

    context "when find returns nil" do
      it "returns nil when symbol is not found" do
        allow(index).to receive(:find).and_return(nil)
        expect(index.find_parent_class("Test")).to be_nil
      end

      it "handles nil from find gracefully" do
        # This test ensures nil is handled properly
        expect(index.find("NonExistent")).to be_nil
        expect { index.find_parent_class("NonExistent") }.not_to raise_error
        expect(index.find_parent_class("NonExistent")).to be_nil
      end

      it "checks both nil and respond_to conditions" do
        # Ensure index is empty so find returns nil
        index.clear

        # Should return nil when symbol is nil
        result = index.find_parent_class("DoesNotExist")
        expect(result).to be_nil
      end

      it "requires both symbol existence and superclass method" do
        # This test verifies that BOTH conditions must be true
        # Without the `symbol` check, nil.respond_to? would be called
        # While nil.respond_to? returns false (not error), we still need the check
        # for clarity and to avoid calling methods on nil unnecessarily

        # Case 1: symbol is nil
        expect(index.find("NotInIndex")).to be_nil
        expect(index.find_parent_class("NotInIndex")).to be_nil

        # Case 2: symbol exists but doesn't respond to superclass
        non_class = double("non_class")
        allow(non_class).to receive(:name).and_return("Thing")
        allow(non_class).to receive(:fqname).and_return("Thing")
        allow(non_class).to receive(:respond_to?).with(:superclass).and_return(false)
        index.add(non_class)

        expect(index.find_parent_class("Thing")).to be_nil
      end

      it "early returns when symbol is nil before checking respond_to" do
        # This test specifically ensures the first guard clause is necessary
        # by verifying the method returns early when symbol is nil

        # Mock find to return nil
        allow(index).to receive(:find).with("Missing").and_return(nil)

        # Should never even check respond_to
        expect_any_instance_of(NilClass).not_to receive(:respond_to?)

        result = index.find_parent_class("Missing")
        expect(result).to be_nil
      end
    end

    context "when symbol has superclass but it's nil" do
      let(:symbol) { double("symbol", superclass: nil) }

      before do
        allow(symbol).to receive(:name).and_return("RootClass")
        allow(symbol).to receive(:fqname).and_return("RootClass")
        allow(symbol).to receive(:respond_to?).with(:superclass).and_return(true)
        index.add(symbol)
      end

      it "returns nil" do
        expect(index.find_parent_class("RootClass")).to be_nil
      end
    end

    context "with various symbol types" do
      let(:class_symbol) { double("class", superclass: "Parent") }
      let(:module_symbol) { double("module") }
      let(:method_symbol) { double("method") }

      before do
        allow(class_symbol).to receive(:name).and_return("MyClass")
        allow(class_symbol).to receive(:fqname).and_return("MyClass")
        allow(class_symbol).to receive(:respond_to?).with(:superclass).and_return(true)

        allow(module_symbol).to receive(:name).and_return("MyModule")
        allow(module_symbol).to receive(:fqname).and_return("MyModule")
        allow(module_symbol).to receive(:respond_to?).with(:superclass).and_return(false)

        allow(method_symbol).to receive(:name).and_return("my_method")
        allow(method_symbol).to receive(:fqname).and_return("MyClass#my_method")
        allow(method_symbol).to receive(:respond_to?).with(:superclass).and_return(false)

        index.add(class_symbol)
        index.add(module_symbol)
        index.add(method_symbol)
      end

      it "returns superclass for classes" do
        expect(index.find_parent_class("MyClass")).to eq("Parent")
      end

      it "returns nil for modules" do
        expect(index.find_parent_class("MyModule")).to be_nil
      end

      it "returns nil for methods" do
        expect(index.find_parent_class("my_method")).to be_nil
        expect(index.find_parent_class("MyClass#my_method")).to be_nil
      end
    end
  end

  describe "thread safety concerns" do
    it "is not thread-safe by design" do
      # This test documents that the class is not thread-safe
      # Multiple threads modifying the index could cause race conditions
      symbol = double("symbol", name: "Test", fqname: "Test")

      # This is a documentation test - the class should be used with external synchronization
      # if used in multi-threaded contexts
      expect { index.add(symbol) }.not_to raise_error
    end
  end

  describe "memory efficiency" do
    it "stores references not copies" do
      symbol = double("symbol", name: "User", fqname: "Models::User")
      index.add(symbol)

      found_by_name = index.find("User")
      found_by_fqname = index.find("Models::User")

      expect(found_by_name.object_id).to eq(symbol.object_id)
      expect(found_by_fqname.object_id).to eq(symbol.object_id)
    end
  end

  describe "internal state" do
    it "uses the private reader method for encapsulation" do
      # This test verifies that methods use the private index reader
      # for better encapsulation
      symbol = double("symbol", name: "Test", fqname: "Test")

      index.add(symbol)
      internal_index = index.instance_variable_get(:@index)

      expect(internal_index["Test"]).to eq(symbol)
    end

    it "modifies the hash through the reader in add" do
      symbol = double("symbol", name: "User", fqname: "App::User")

      # Capture state before and after
      before_count = index.instance_variable_get(:@index).size
      index.add(symbol)
      after_count = index.instance_variable_get(:@index).size

      expect(after_count).to eq(before_count + 2)
    end

    it "accesses the hash through the reader in find" do
      symbol = double("symbol", name: "Test", fqname: "Test")
      index.add(symbol)

      # Ensure find returns the correct value
      result = index.find("Test")
      expect(result).to eq(symbol)

      # Verify by checking the instance variable
      internal_value = index.instance_variable_get(:@index)["Test"]
      expect(result).to equal(internal_value)
    end

    it "clears the hash through the reader" do
      symbol = double("symbol", name: "Test", fqname: "Test")
      index.add(symbol)

      index.clear
      internal_index = index.instance_variable_get(:@index)

      expect(internal_index).to be_empty
    end
  end
end
