# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::Services::NamespaceService do
  let(:service) { described_class.new }

  describe "#build_fqname" do
    context "with valid string parts" do
      it "builds fully qualified name from multiple parts" do
        expect(service.build_fqname("MyApp", "Models", "User")).to eq("MyApp::Models::User")
      end

      it "builds name from single part" do
        expect(service.build_fqname("User")).to eq("User")
      end

      it "builds name from two parts" do
        expect(service.build_fqname("MyApp", "User")).to eq("MyApp::User")
      end
    end

    context "with array inputs" do
      it "handles flat array of parts" do
        expect(service.build_fqname(["MyApp", "Models", "User"])).to eq("MyApp::Models::User")
      end

      it "handles nested arrays" do
        expect(service.build_fqname(["MyApp", ["Models", "User"]])).to eq("MyApp::Models::User")
      end

      it "handles deeply nested arrays" do
        expect(service.build_fqname(["MyApp", ["Models", ["Admin", "User"]]])).to eq("MyApp::Models::Admin::User")
      end

      it "handles mixed arrays and strings" do
        expect(service.build_fqname("MyApp", ["Models", "User"])).to eq("MyApp::Models::User")
      end
    end

    context "with nil and empty values" do
      it "filters out nil parts" do
        expect(service.build_fqname("MyApp", nil, "User")).to eq("MyApp::User")
      end

      it "filters out empty string parts" do
        expect(service.build_fqname("MyApp", "", "User")).to eq("MyApp::User")
      end

      it "returns empty string for no valid parts" do
        expect(service.build_fqname(nil, "", nil)).to eq("")
      end

      it "filters nils from arrays" do
        expect(service.build_fqname(["MyApp", nil, "User"])).to eq("MyApp::User")
      end

      it "filters empty strings from arrays" do
        expect(service.build_fqname(["MyApp", "", "User"])).to eq("MyApp::User")
      end
    end

    context "with edge cases" do
      it "handles symbols" do
        expect(service.build_fqname(:MyApp, :Models, :User)).to eq("MyApp::Models::User")
      end

      it "handles mixed types" do
        expect(service.build_fqname("MyApp", :Models, "User")).to eq("MyApp::Models::User")
      end

      it "handles no arguments" do
        expect(service.build_fqname).to eq("")
      end
    end
  end

  describe "#extract_namespace_path" do
    context "with valid fully qualified names" do
      it "extracts namespace path from deeply nested name" do
        expect(service.extract_namespace_path("MyApp::Models::Admin::User")).to eq(["MyApp", "Models", "Admin"])
      end

      it "extracts namespace path from two-level name" do
        expect(service.extract_namespace_path("MyApp::User")).to eq(["MyApp"])
      end

      it "extracts namespace path from three-level name" do
        expect(service.extract_namespace_path("MyApp::Models::User")).to eq(["MyApp", "Models"])
      end
    end

    context "with single names" do
      it "returns empty array for single name" do
        expect(service.extract_namespace_path("User")).to eq([])
      end

      it "returns empty array for single character" do
        expect(service.extract_namespace_path("A")).to eq([])
      end
    end

    context "with nil and empty inputs" do
      it "returns empty array for nil" do
        expect(service.extract_namespace_path(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        expect(service.extract_namespace_path("")).to eq([])
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with multiple namespaces" do
        expect(service.extract_namespace_path(:"MyApp::Models::User")).to eq(["MyApp", "Models"])
      end

      it "handles symbols with single namespace" do
        expect(service.extract_namespace_path(:"MyApp::User")).to eq(["MyApp"])
      end

      it "handles symbols with no namespace" do
        expect(service.extract_namespace_path(:User)).to eq([])
      end

      it "handles numeric inputs" do
        expect(service.extract_namespace_path(123)).to eq([])
      end
    end

    context "with edge cases" do
      it "handles leading double colon" do
        expect(service.extract_namespace_path("::MyApp::User")).to eq(["", "MyApp"])
      end

      it "handles trailing double colon" do
        expect(service.extract_namespace_path("MyApp::")).to eq([])
      end

      it "handles multiple consecutive double colons" do
        expect(service.extract_namespace_path("MyApp::::User")).to eq(["MyApp", ""])
      end

      it "handles just double colons" do
        expect(service.extract_namespace_path("::")).to eq([])
      end
    end
  end

  describe "#extract_simple_name" do
    context "with fully qualified names" do
      it "extracts simple name from deeply nested name" do
        expect(service.extract_simple_name("MyApp::Models::Admin::User")).to eq("User")
      end

      it "extracts simple name from two-level name" do
        expect(service.extract_simple_name("MyApp::User")).to eq("User")
      end

      it "extracts simple name from three-level name" do
        expect(service.extract_simple_name("MyApp::Models::User")).to eq("User")
      end
    end

    context "with single names" do
      it "returns the name itself if no namespace" do
        expect(service.extract_simple_name("User")).to eq("User")
      end

      it "returns single character name" do
        expect(service.extract_simple_name("A")).to eq("A")
      end
    end

    context "with nil and empty inputs" do
      it "returns nil for nil input" do
        expect(service.extract_simple_name(nil)).to be_nil
      end

      it "returns nil for empty string input" do
        expect(service.extract_simple_name("")).to be_nil
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with multiple namespaces" do
        expect(service.extract_simple_name(:"MyApp::Models::User")).to eq("User")
      end

      it "handles symbols with single namespace" do
        expect(service.extract_simple_name(:"MyApp::User")).to eq("User")
      end

      it "handles symbols with no namespace" do
        expect(service.extract_simple_name(:User)).to eq("User")
      end

      it "handles numeric inputs" do
        expect(service.extract_simple_name(123)).to eq("123")
      end
    end

    context "with edge cases" do
      it "handles leading double colon" do
        expect(service.extract_simple_name("::MyApp::User")).to eq("User")
      end

      it "handles trailing double colon" do
        expect(service.extract_simple_name("MyApp::")).to eq("MyApp")
      end

      it "handles multiple consecutive double colons" do
        expect(service.extract_simple_name("MyApp::::User")).to eq("User")
      end

      it "handles just double colons" do
        expect(service.extract_simple_name("::")).to be_nil
      end

      it "verifies last element extraction" do
        parts = "A::B::C".split("::")
        expect(parts.last).to eq("C")
        expect(service.extract_simple_name("A::B::C")).to eq("C")
      end
    end
  end

  describe "#extract_parent_namespace" do
    context "with fully qualified names" do
      it "extracts parent namespace from deeply nested name" do
        expect(service.extract_parent_namespace("MyApp::Models::Admin::User")).to eq("MyApp::Models::Admin")
      end

      it "extracts parent namespace from three-level name" do
        expect(service.extract_parent_namespace("MyApp::Models::User")).to eq("MyApp::Models")
      end

      it "extracts parent namespace from two-level name" do
        expect(service.extract_parent_namespace("MyApp::User")).to eq("MyApp")
      end
    end

    context "with single names" do
      it "returns nil for single name" do
        expect(service.extract_parent_namespace("User")).to be_nil
      end

      it "returns nil for single character" do
        expect(service.extract_parent_namespace("A")).to be_nil
      end
    end

    context "with nil and empty inputs" do
      it "returns nil for nil input" do
        expect(service.extract_parent_namespace(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(service.extract_parent_namespace("")).to be_nil
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with multiple namespaces" do
        expect(service.extract_parent_namespace(:"MyApp::Models::User")).to eq("MyApp::Models")
      end

      it "handles symbols with two namespaces" do
        expect(service.extract_parent_namespace(:"MyApp::User")).to eq("MyApp")
      end

      it "handles symbols with no namespace" do
        expect(service.extract_parent_namespace(:User)).to be_nil
      end

      it "handles numeric inputs" do
        expect(service.extract_parent_namespace(123)).to be_nil
      end
    end

    context "with edge cases" do
      it "handles leading double colon" do
        expect(service.extract_parent_namespace("::MyApp::User")).to eq("::MyApp")
      end

      it "handles trailing double colon" do
        expect(service.extract_parent_namespace("MyApp::")).to be_nil
      end

      it "handles multiple consecutive double colons" do
        expect(service.extract_parent_namespace("MyApp::::User")).to eq("MyApp::")
      end

      it "handles just double colons" do
        expect(service.extract_parent_namespace("::")).to be_nil
      end

      it "verifies size condition with exactly one element" do
        parts = "Single".split("::")
        expect(parts.size).to eq(1)
        expect(service.extract_parent_namespace("Single")).to be_nil
      end

      it "verifies size condition with multiple elements" do
        parts = "A::B".split("::")
        expect(parts.size).to eq(2)
        expect(service.extract_parent_namespace("A::B")).to eq("A")
      end
    end
  end

  describe "#fully_qualified?" do
    context "with fully qualified names" do
      it "returns true for names starting with ::" do
        expect(service.fully_qualified?("::User")).to be true
      end

      it "returns true for nested names starting with ::" do
        expect(service.fully_qualified?("::MyApp::User")).to be true
      end

      it "returns true for deeply nested names starting with ::" do
        expect(service.fully_qualified?("::MyApp::Models::User")).to be true
      end

      it "returns true for just double colons" do
        expect(service.fully_qualified?("::")).to be true
      end
    end

    context "with regular names" do
      it "returns false for simple names" do
        expect(service.fully_qualified?("User")).to be false
      end

      it "returns false for namespaced names without leading ::" do
        expect(service.fully_qualified?("MyApp::User")).to be false
      end

      it "returns false for deeply nested names without leading ::" do
        expect(service.fully_qualified?("MyApp::Models::User")).to be false
      end

      it "returns false for single character names" do
        expect(service.fully_qualified?("A")).to be false
      end
    end

    context "with nil and empty inputs" do
      it "returns false for nil" do
        expect(service.fully_qualified?(nil)).to be false
      end

      it "returns false for empty string" do
        expect(service.fully_qualified?("")).to be false
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with leading ::" do
        expect(service.fully_qualified?(:"::User")).to be true
      end

      it "handles symbols without leading ::" do
        expect(service.fully_qualified?(:User)).to be false
      end

      it "handles numeric inputs" do
        expect(service.fully_qualified?(123)).to be false
      end

      it "handles string representations of numbers starting with ::" do
        expect(service.fully_qualified?("::123")).to be true
      end
    end

    context "with edge cases" do
      it "returns false for names with :: in middle" do
        expect(service.fully_qualified?("My::App")).to be false
      end

      it "returns false for names ending with ::" do
        expect(service.fully_qualified?("MyApp::")).to be false
      end

      it "returns false for names with multiple :: but not at start" do
        expect(service.fully_qualified?("My::App::User")).to be false
      end

      it "verifies start_with? method behavior" do
        expect("::Test".start_with?("::")).to be true
        expect("Test::".start_with?("::")).to be false
        expect(service.fully_qualified?("::Test")).to be true
        expect(service.fully_qualified?("Test::")).to be false
      end
    end
  end

  describe "#normalize_name" do
    context "with names having leading ::" do
      it "removes leading :: from simple name" do
        expect(service.normalize_name("::User")).to eq("User")
      end

      it "removes leading :: from namespaced name" do
        expect(service.normalize_name("::MyApp::User")).to eq("MyApp::User")
      end

      it "removes leading :: from deeply nested name" do
        expect(service.normalize_name("::MyApp::Models::User")).to eq("MyApp::Models::User")
      end

      it "handles just double colons" do
        expect(service.normalize_name("::")).to eq("")
      end

      it "removes only first occurrence of leading ::" do
        expect(service.normalize_name("::::User")).to eq("::User")
      end
    end

    context "with names without leading ::" do
      it "preserves simple name without leading ::" do
        expect(service.normalize_name("User")).to eq("User")
      end

      it "preserves namespaced name without leading ::" do
        expect(service.normalize_name("MyApp::User")).to eq("MyApp::User")
      end

      it "preserves deeply nested name without leading ::" do
        expect(service.normalize_name("MyApp::Models::User")).to eq("MyApp::Models::User")
      end
    end

    context "with nil and empty inputs" do
      it "returns nil for nil input" do
        expect(service.normalize_name(nil)).to be_nil
      end

      it "returns empty string for empty string" do
        expect(service.normalize_name("")).to eq("")
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with leading ::" do
        expect(service.normalize_name(:"::User")).to eq("User")
      end

      it "handles symbols without leading ::" do
        expect(service.normalize_name(:User)).to eq("User")
      end

      it "handles symbols with namespaces" do
        expect(service.normalize_name(:"::MyApp::User")).to eq("MyApp::User")
      end

      it "handles numeric inputs" do
        expect(service.normalize_name(123)).to eq("123")
      end

      it "handles numeric inputs with leading ::" do
        expect(service.normalize_name("::123")).to eq("123")
      end
    end

    context "with edge cases" do
      it "preserves :: in middle of name" do
        expect(service.normalize_name("::My::App::User")).to eq("My::App::User")
      end

      it "preserves :: at end of name" do
        expect(service.normalize_name("::MyApp::")).to eq("MyApp::")
      end

      it "handles whitespace with leading ::" do
        expect(service.normalize_name("::  User  ")).to eq("  User  ")
      end

      it "verifies gsub pattern matches only leading ::" do
        expect("::Test::More".gsub(/^::/, "")).to eq("Test::More")
        expect("Test::::More".gsub(/^::/, "")).to eq("Test::::More")
      end

      it "correctly handles multiple consecutive :: at the beginning" do
        # Test that verifies the exact behavior with multiple leading ::
        # The regex /^::/ only matches the first :: at the beginning
        expect(service.normalize_name("::::User")).to eq("::User")
        expect(service.normalize_name("::::::User")).to eq("::::User")
      end

      it "returns exact string object for non-matching input" do
        # When there's no leading ::, the string should be returned as-is
        input = "User"
        result = service.normalize_name(input)
        expect(result).to eq("User")
        # Verify it's a new string object (not the same object)
        expect(result.object_id).not_to eq(input.object_id)
      end

      it "handles string with only colons differently than empty" do
        # Edge case to ensure exact pattern matching
        expect(service.normalize_name("::::")).to eq("::")
        expect(service.normalize_name("::")).to eq("")
        expect(service.normalize_name(":")).to eq(":")
      end

      it "only removes :: from the beginning of the entire string, not from beginning of lines" do
        # Test that \A:: only matches at string start, not line start
        multiline_input = "First\n::Second"
        # With /\A::/ this stays "First\n::Second" (only matches string start)
        expect(service.normalize_name(multiline_input)).to eq("First\n::Second")

        # Removes :: only from the very beginning
        expect(service.normalize_name("::First\n::Second")).to eq("First\n::Second")
      end
    end
  end

  describe "#resolve_in_namespace" do
    context "when name is not fully qualified" do
      it "resolves simple name within namespace" do
        expect(service.resolve_in_namespace("User", "MyApp")).to eq("MyApp::User")
      end

      it "resolves name within nested namespace" do
        expect(service.resolve_in_namespace("User", "MyApp::Models")).to eq("MyApp::Models::User")
      end

      it "resolves name within deeply nested namespace" do
        expect(service.resolve_in_namespace("Profile", "MyApp::Models::User")).to eq("MyApp::Models::User::Profile")
      end

      it "resolves namespaced name within namespace" do
        expect(service.resolve_in_namespace("Models::User", "MyApp")).to eq("MyApp::Models::User")
      end
    end

    context "when name is fully qualified" do
      it "returns fully qualified name unchanged" do
        expect(service.resolve_in_namespace("::User", "MyApp::Models")).to eq("::User")
      end

      it "returns nested fully qualified name unchanged" do
        expect(service.resolve_in_namespace("::MyApp::User", "OtherApp")).to eq("::MyApp::User")
      end

      it "returns deeply nested fully qualified name unchanged" do
        expect(service.resolve_in_namespace("::MyApp::Models::User", "OtherApp::Controllers")).to eq("::MyApp::Models::User")
      end
    end

    context "when namespace is nil or empty" do
      it "returns name unchanged when namespace is nil" do
        expect(service.resolve_in_namespace("User", nil)).to eq("User")
      end

      it "returns name unchanged when namespace is empty string" do
        expect(service.resolve_in_namespace("User", "")).to eq("User")
      end

      it "returns namespaced name unchanged when namespace is nil" do
        expect(service.resolve_in_namespace("MyApp::User", nil)).to eq("MyApp::User")
      end

      it "returns namespaced name unchanged when namespace is empty" do
        expect(service.resolve_in_namespace("MyApp::User", "")).to eq("MyApp::User")
      end
    end

    context "with symbols and type conversion" do
      it "handles symbol names" do
        expect(service.resolve_in_namespace(:User, "MyApp")).to eq("MyApp::User")
      end

      it "handles symbol namespaces" do
        expect(service.resolve_in_namespace("User", :MyApp)).to eq("MyApp::User")
      end

      it "handles both symbol name and namespace" do
        expect(service.resolve_in_namespace(:User, :MyApp)).to eq("MyApp::User")
      end

      it "handles numeric inputs" do
        expect(service.resolve_in_namespace(123, "MyApp")).to eq("MyApp::123")
      end

      it "handles fully qualified symbol names" do
        expect(service.resolve_in_namespace(:"::User", "MyApp")).to eq(:"::User")
      end
    end

    context "with edge cases" do
      it "handles empty name" do
        expect(service.resolve_in_namespace("", "MyApp")).to eq("MyApp::")
      end

      it "handles whitespace in namespace" do
        expect(service.resolve_in_namespace("User", "My App")).to eq("My App::User")
      end

      it "handles namespace ending with ::" do
        expect(service.resolve_in_namespace("User", "MyApp::")).to eq("MyApp::::User")
      end

      it "preserves exact formatting" do
        expect(service.resolve_in_namespace("User", "MyApp::Models")).to eq("MyApp::Models::User")
      end

      it "verifies fully_qualified? check integration" do
        # Test that the method properly uses fully_qualified? check
        allow(service).to receive(:fully_qualified?).with("::User").and_return(true)
        result = service.resolve_in_namespace("::User", "MyApp")
        expect(result).to eq("::User")
        expect(service).to have_received(:fully_qualified?).with("::User")
      end

      it "verifies nil and empty namespace conditions" do
        # Test both nil and empty conditions separately
        expect(service.resolve_in_namespace("User", nil)).to eq("User")
        expect(service.resolve_in_namespace("User", "")).to eq("User")
      end
    end
  end

  describe "#nested_in?" do
    context "when child is nested in parent" do
      it "returns true for directly nested namespace" do
        expect(service.nested_in?("MyApp::User", "MyApp")).to be true
      end

      it "returns true for deeply nested namespace" do
        expect(service.nested_in?("MyApp::Models::User", "MyApp")).to be true
      end

      it "returns true for nested namespace at two levels" do
        expect(service.nested_in?("MyApp::Models::User", "MyApp::Models")).to be true
      end

      it "returns true for very deeply nested namespace" do
        expect(service.nested_in?("MyApp::Models::Admin::User::Profile", "MyApp::Models")).to be true
      end
    end

    context "when child is not nested in parent" do
      it "returns false for completely different namespaces" do
        expect(service.nested_in?("OtherApp::User", "MyApp")).to be false
      end

      it "returns false for similar but different namespaces" do
        expect(service.nested_in?("MyApplication::User", "MyApp")).to be false
      end

      it "returns false for parent longer than child" do
        expect(service.nested_in?("MyApp", "MyApp::Models")).to be false
      end

      it "returns false for same namespace" do
        expect(service.nested_in?("MyApp", "MyApp")).to be false
      end

      it "returns false for prefix without double colon" do
        expect(service.nested_in?("MyAppUser", "MyApp")).to be false
      end

      it "returns false for exact same nested namespace" do
        expect(service.nested_in?("MyApp::Models::User", "MyApp::Models::User")).to be false
      end
    end

    context "with nil values" do
      it "returns false when child namespace is nil" do
        expect(service.nested_in?(nil, "MyApp")).to be false
      end

      it "returns false when parent namespace is nil" do
        expect(service.nested_in?("MyApp::User", nil)).to be false
      end

      it "returns false when both namespaces are nil" do
        expect(service.nested_in?(nil, nil)).to be false
      end
    end

    context "with empty strings" do
      it "returns false for empty child" do
        expect(service.nested_in?("", "MyApp")).to be false
      end

      it "returns false for empty parent" do
        expect(service.nested_in?("MyApp::User", "")).to be false
      end

      it "returns false for both empty" do
        expect(service.nested_in?("", "")).to be false
      end
    end

    context "with symbols and type conversion" do
      it "handles symbol child" do
        expect(service.nested_in?(:"MyApp::User", "MyApp")).to be true
      end

      it "handles symbol parent" do
        expect(service.nested_in?("MyApp::User", :MyApp)).to be true
      end

      it "handles both symbols" do
        expect(service.nested_in?(:"MyApp::User", :MyApp)).to be true
      end

      it "handles numeric inputs" do
        expect(service.nested_in?(123, 12)).to be false
      end
    end

    context "with edge cases" do
      it "returns false for partial matches" do
        expect(service.nested_in?("MyApp_Extended::User", "MyApp")).to be false
      end

      it "returns false for case sensitivity" do
        expect(service.nested_in?("myapp::User", "MyApp")).to be false
      end

      it "handles single character namespaces" do
        expect(service.nested_in?("A::B", "A")).to be true
      end

      it "handles namespaces with numbers" do
        expect(service.nested_in?("V2::MyApp::User", "V2::MyApp")).to be true
      end

      it "handles leading double colons in child" do
        expect(service.nested_in?("::MyApp::User", "MyApp")).to be false
      end

      it "handles leading double colons in parent" do
        expect(service.nested_in?("MyApp::User", "::MyApp")).to be false
      end

      it "verifies start_with? pattern matching" do
        # Test the exact pattern used in the implementation
        child = "MyApp::Models::User"
        parent = "MyApp::Models"
        pattern = "#{parent}::"
        expect(child.start_with?(pattern)).to be true
        expect(service.nested_in?(child, parent)).to be true
      end
    end
  end

  describe "#nesting_level" do
    context "with nil and empty inputs" do
      it "returns 0 for nil namespace" do
        expect(service.nesting_level(nil)).to eq(0)
      end

      it "returns 0 for empty string" do
        expect(service.nesting_level("")).to eq(0)
      end
    end

    context "with single names" do
      it "returns 1 for single name" do
        expect(service.nesting_level("User")).to eq(1)
      end

      it "returns 1 for single character" do
        expect(service.nesting_level("A")).to eq(1)
      end

      it "returns 1 for single number" do
        expect(service.nesting_level("123")).to eq(1)
      end
    end

    context "with nested namespaces" do
      it "returns 2 for one level of nesting" do
        expect(service.nesting_level("MyApp::User")).to eq(2)
      end

      it "returns 3 for two levels of nesting" do
        expect(service.nesting_level("MyApp::Models::User")).to eq(3)
      end

      it "returns 4 for three levels of nesting" do
        expect(service.nesting_level("MyApp::Models::Admin::User")).to eq(4)
      end

      it "returns 5 for four levels of nesting" do
        expect(service.nesting_level("MyApp::Models::Admin::User::Profile")).to eq(5)
      end
    end

    context "with symbols and type conversion" do
      it "handles symbols with single name" do
        expect(service.nesting_level(:User)).to eq(1)
      end

      it "handles symbols with nested names" do
        expect(service.nesting_level(:"MyApp::User")).to eq(2)
      end

      it "handles symbols with deeply nested names" do
        expect(service.nesting_level(:"MyApp::Models::User")).to eq(3)
      end

      # MUTATION COVERAGE TEST - Implementation detail (we handle numbers by converting to string)
      # it "handles numeric inputs that cause method errors" do
      #   expect { service.nesting_level(123) }.to raise_error(NoMethodError)
      # end
    end

    context "with edge cases" do
      it "handles leading double colons" do
        expect(service.nesting_level("::MyApp::User")).to eq(3)
      end

      it "handles trailing double colons" do
        expect(service.nesting_level("MyApp::")).to eq(1)
      end

      it "handles multiple consecutive double colons" do
        expect(service.nesting_level("MyApp::::User")).to eq(3)
      end

      it "handles just double colons" do
        expect(service.nesting_level("::")).to eq(0)
      end

      it "handles empty parts in namespace" do
        expect(service.nesting_level("MyApp::User")).to eq(2)
      end

      it "handles whitespace in parts" do
        expect(service.nesting_level("My App::User")).to eq(2)
      end

      it "verifies split behavior" do
        parts = "A::B::C".split("::")
        expect(parts).to eq(["A", "B", "C"])
        expect(parts.size).to eq(3)
        expect(service.nesting_level("A::B::C")).to eq(3)
      end

      it "verifies nil/empty early returns" do
        expect(service.nesting_level(nil)).to eq(0)
        expect(service.nesting_level("")).to eq(0)
      end
    end
  end

  describe "#common_namespace" do
    context "when names share common namespace" do
      it "finds common namespace at same level" do
        expect(service.common_namespace("MyApp::Models::User", "MyApp::Models::Post")).to eq("MyApp::Models")
      end

      it "finds partial common namespace" do
        expect(service.common_namespace("MyApp::Models::User", "MyApp::Controllers::UserController")).to eq("MyApp")
      end

      it "finds common namespace with different nesting levels" do
        expect(service.common_namespace("MyApp::Models::Admin::User", "MyApp::Models::Post")).to eq("MyApp::Models")
      end

      it "finds root level common namespace" do
        expect(service.common_namespace("MyApp::User", "MyApp::Post")).to eq("MyApp")
      end

      it "handles single name as common namespace" do
        expect(service.common_namespace("User", "User::Profile")).to eq("User")
      end

      it "handles exact same names" do
        expect(service.common_namespace("MyApp::User", "MyApp::User")).to eq("MyApp::User")
      end
    end

    context "when names have no common namespace" do
      it "returns nil for completely different namespaces" do
        expect(service.common_namespace("MyApp::User", "OtherApp::User")).to be_nil
      end

      it "returns nil for similar but different root namespaces" do
        expect(service.common_namespace("MyApplication::User", "MyApp::User")).to be_nil
      end

      it "returns nil for single names that are different" do
        expect(service.common_namespace("User", "Post")).to be_nil
      end

      it "returns nil for case-sensitive differences" do
        expect(service.common_namespace("myapp::User", "MyApp::User")).to be_nil
      end
    end

    context "with nil inputs" do
      it "returns nil if first name is nil" do
        expect(service.common_namespace(nil, "MyApp::User")).to be_nil
      end

      it "returns nil if second name is nil" do
        expect(service.common_namespace("MyApp::User", nil)).to be_nil
      end

      it "returns nil if both names are nil" do
        expect(service.common_namespace(nil, nil)).to be_nil
      end
    end

    context "with empty strings" do
      it "returns nil for empty first name" do
        expect(service.common_namespace("", "MyApp::User")).to be_nil
      end

      it "returns nil for empty second name" do
        expect(service.common_namespace("MyApp::User", "")).to be_nil
      end

      it "returns nil for both empty strings" do
        expect(service.common_namespace("", "")).to be_nil
      end
    end

    context "with symbols and type conversion" do
      it "handles symbol inputs" do
        expect(service.common_namespace(:"MyApp::User", :"MyApp::Post")).to eq("MyApp")
      end

      it "handles mixed symbol and string" do
        expect(service.common_namespace(:"MyApp::User", "MyApp::Post")).to eq("MyApp")
      end

      it "handles numeric inputs" do
        expect(service.common_namespace(123, 124)).to be_nil
      end

      it "handles same numeric input" do
        expect(service.common_namespace(123, 123)).to eq("123")
      end
    end

    context "with edge cases" do
      it "handles leading double colons" do
        expect(service.common_namespace("::MyApp::User", "::MyApp::Post")).to eq("::MyApp")
      end

      it "handles mixed leading double colons" do
        expect(service.common_namespace("::MyApp::User", "MyApp::Post")).to be_nil
      end

      it "handles trailing double colons" do
        expect(service.common_namespace("MyApp::", "MyApp::User")).to eq("MyApp")
      end

      it "handles consecutive double colons" do
        expect(service.common_namespace("MyApp::::User", "MyApp::::Post")).to eq("MyApp::")
      end

      it "handles single character namespaces" do
        expect(service.common_namespace("A::B", "A::C")).to eq("A")
      end

      it "handles whitespace in namespaces" do
        expect(service.common_namespace("My App::User", "My App::Post")).to eq("My App")
      end

      it "returns nil when one name is prefix of other but not namespace" do
        expect(service.common_namespace("MyApp", "MyAppExtended::User")).to be_nil
      end

      it "verifies zip behavior and early break" do
        parts1 = ["A", "B", "C"]
        parts2 = ["A", "X", "Y"]
        common_parts = []

        parts1.zip(parts2).each do |p1, p2|
          break unless p1 == p2
          common_parts << p1
        end

        expect(common_parts).to eq(["A"])
        expect(service.common_namespace("A::B::C", "A::X::Y")).to eq("A")
      end

      it "verifies empty result handling" do
        expect(service.common_namespace("A::B", "X::Y")).to be_nil
      end
    end
  end
end
