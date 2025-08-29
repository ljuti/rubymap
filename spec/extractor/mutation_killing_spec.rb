# frozen_string_literal: true

require "spec_helper"
require "prism"

# This spec file is specifically designed to kill mutations in the Extractor classes
# by testing edge cases and ensuring all code paths are exercised

RSpec.describe "Extractor Mutation Killing" do
  describe Rubymap::Extractor::Services::DocumentationService do
    let(:service) { described_class.new }

    it "correctly distinguishes documentation comments from regular comments" do
      doc_comment = double(slice: "## Important")
      regular_comment = double(slice: "# Regular")
      no_hash = double(slice: "No hash")
      
      expect(service.documentation_comment?(doc_comment)).to be true
      expect(service.documentation_comment?(regular_comment)).to be false
      expect(service.documentation_comment?(no_hash)).to be false
    end

    it "extracts documentation only from immediately preceding comments" do
      node = double(location: double(start_line: 10))
      
      # Comments with gap should not be extracted
      gap_comment = double(location: double(start_line: 7), slice: "# Gap comment")
      immediate_comment = double(location: double(start_line: 9), slice: "# Immediate")
      
      result = service.extract_documentation(node, [gap_comment, immediate_comment])
      expect(result).to eq("Immediate")
      
      # Only gap comment should return nil
      result = service.extract_documentation(node, [gap_comment])
      expect(result).to be_nil
    end

    it "correctly handles inline comment column positions" do
      node = double(location: double(start_line: 5, end_column: 20))
      
      # Comment after node position
      after_comment = double(location: double(start_line: 5, start_column: 25), slice: "# after")
      
      # Comment before node position (should not be extracted)
      before_comment = double(location: double(start_line: 5, start_column: 10), slice: "# before")
      
      expect(service.extract_inline_comment(node, [after_comment])).to eq("after")
      expect(service.extract_inline_comment(node, [before_comment])).to be_nil
      
      # Exact column boundary
      boundary_comment = double(location: double(start_line: 5, start_column: 20), slice: "# boundary")
      expect(service.extract_inline_comment(node, [boundary_comment])).to be_nil
    end

    it "handles YARD tag extraction with proper array conversion" do
      # Single param becomes string
      doc1 = "@param x [String] the x"
      result1 = service.extract_yard_tags(doc1)
      expect(result1[:param]).to be_a(String)
      expect(result1[:param]).to eq("x [String] the x")
      
      # Multiple params become array
      doc2 = "@param x [String] the x\n@param y [Integer] the y"
      result2 = service.extract_yard_tags(doc2)
      expect(result2[:param]).to be_a(Array)
      expect(result2[:param]).to eq(["x [String] the x", "y [Integer] the y"])
      
      # Three params stay as array
      doc3 = "@param x [String] x\n@param y [Integer] y\n@param z [Boolean] z"
      result3 = service.extract_yard_tags(doc3)
      expect(result3[:param]).to be_a(Array)
      expect(result3[:param].size).to eq(3)
    end
  end

  describe Rubymap::Extractor::Services::NamespaceService do
    let(:service) { described_class.new }

    it "correctly builds FQNames with various inputs" do
      # All valid parts
      expect(service.build_fqname("A", "B", "C")).to eq("A::B::C")
      
      # Mix of valid and invalid
      expect(service.build_fqname("A", nil, "C")).to eq("A::C")
      expect(service.build_fqname("A", "", "C")).to eq("A::C")
      expect(service.build_fqname(nil, "B", nil)).to eq("B")
      
      # All invalid
      expect(service.build_fqname(nil, "", nil)).to eq("")
      expect(service.build_fqname([])).to eq("")
      
      # Nested arrays
      expect(service.build_fqname(["A", ["B", "C"]])).to eq("A::B::C")
      expect(service.build_fqname([["A"], ["B"]])).to eq("A::B")
    end

    it "correctly identifies fully qualified names" do
      expect(service.fully_qualified?("::User")).to be true
      expect(service.fully_qualified?("::")).to be true
      expect(service.fully_qualified?("User")).to be false
      expect(service.fully_qualified?(":User")).to be false
      expect(service.fully_qualified?("")).to be false
      expect(service.fully_qualified?(nil)).to be false
    end

    it "correctly resolves names in namespaces" do
      # Regular resolution
      expect(service.resolve_in_namespace("User", "MyApp")).to eq("MyApp::User")
      expect(service.resolve_in_namespace("User", "MyApp::Models")).to eq("MyApp::Models::User")
      
      # Early returns for fully qualified
      expect(service.resolve_in_namespace("::User", "MyApp")).to eq("::User")
      expect(service.resolve_in_namespace("::User", nil)).to eq("::User")
      
      # Early returns for nil/empty namespace
      expect(service.resolve_in_namespace("User", nil)).to eq("User")
      expect(service.resolve_in_namespace("User", "")).to eq("User")
      
      # Order matters - fully qualified check comes first
      expect(service.resolve_in_namespace("::User", "")).to eq("::User")
    end

    it "correctly determines namespace nesting" do
      # Direct nesting
      expect(service.nested_in?("A::B", "A")).to be true
      expect(service.nested_in?("A::B::C", "A::B")).to be true
      
      # Not nested (different prefix)
      expect(service.nested_in?("B::C", "A")).to be false
      expect(service.nested_in?("AB::C", "A")).to be false
      
      # Same namespace is not nested
      expect(service.nested_in?("A", "A")).to be false
      
      # Nil cases
      expect(service.nested_in?(nil, "A")).to be false
      expect(service.nested_in?("A", nil)).to be false
      expect(service.nested_in?(nil, nil)).to be false
    end

    it "correctly finds common namespaces" do
      # Full common path
      expect(service.common_namespace("A::B::C", "A::B::D")).to eq("A::B")
      
      # Partial common path
      expect(service.common_namespace("A::B::C", "A::D::E")).to eq("A")
      
      # No common path
      expect(service.common_namespace("A::B", "C::D")).to be_nil
      
      # One name is prefix of other
      expect(service.common_namespace("A", "A::B")).to eq("A")
      expect(service.common_namespace("A::B", "A")).to eq("A")
      
      # Empty result from no match
      expect(service.common_namespace("A", "B")).to be_nil
      
      # Nil handling
      expect(service.common_namespace(nil, "A")).to be_nil
      expect(service.common_namespace("A", nil)).to be_nil
    end

    it "correctly normalizes names" do
      expect(service.normalize_name("::User")).to eq("User")
      expect(service.normalize_name("::::User")).to eq("::User")
      expect(service.normalize_name("User")).to eq("User")
      expect(service.normalize_name("::")).to eq("")
      expect(service.normalize_name("")).to eq("")
      expect(service.normalize_name(nil)).to be_nil
    end

    it "correctly calculates nesting levels" do
      expect(service.nesting_level(nil)).to eq(0)
      expect(service.nesting_level("")).to eq(0)
      expect(service.nesting_level("A")).to eq(1)
      expect(service.nesting_level("A::B")).to eq(2)
      expect(service.nesting_level("A::B::C::D::E")).to eq(5)
      expect(service.nesting_level("::A")).to eq(2) # Empty string before ::
    end
  end

  describe Rubymap::Extractor::ExtractionContext do
    let(:context) { described_class.new }

    it "maintains independent stack copies" do
      context.push_namespace("A")
      stack1 = context.namespace_stack
      
      context.push_namespace("B")
      stack2 = context.namespace_stack
      
      expect(stack1).to eq(["A"])
      expect(stack2).to eq(["A", "B"])
      expect(stack1).to be_frozen
      expect(stack2).to be_frozen
      
      # Attempting to modify should raise error
      expect { stack1 << "C" }.to raise_error(FrozenError)
    end

    it "properly manages current_class in with_namespace" do
      original = "Original"
      context.instance_variable_set(:@current_class, original)
      
      context.with_namespace("New") do
        expect(context.current_class).to eq("New")
        
        context.with_namespace("Nested") do
          expect(context.current_class).to eq("Nested")
        end
        
        expect(context.current_class).to eq("New")
      end
      
      expect(context.current_class).to eq(original)
    end

    it "handles empty visibility stack edge case" do
      # Pop all default visibility
      context.pop_visibility
      
      # Should still return public as default
      expect(context.current_visibility).to eq(:public)
      
      # Pop again should still work
      result = context.pop_visibility
      expect(result).to be_nil
      expect(context.current_visibility).to eq(:public)
    end

    it "properly resets all state" do
      # Set up complex state
      context.push_namespace("A")
      context.push_namespace("B")
      context.push_visibility(:private)
      context.push_visibility(:protected)
      context.comments = [:comment1, :comment2]
      context.instance_variable_set(:@current_class, "SomeClass")
      
      # Reset
      context.reset!
      
      # Verify everything is reset
      expect(context.namespace_stack).to eq([])
      expect(context.visibility_stack).to eq([:public])
      expect(context.comments).to eq([])
      expect(context.current_class).to be_nil
      expect(context.namespace_depth).to eq(0)
      expect(context.visibility_depth).to eq(1)
    end
  end

  describe Rubymap::Extractor::Concerns::ResultMergeable do
    let(:test_class) do
      Class.new do
        include Rubymap::Extractor::Concerns::ResultMergeable
        attr_accessor :classes, :modules, :methods
        def initialize
          @classes = []
          @modules = []
          @methods = []
        end
      end
    end

    it "merges all collections correctly" do
      target = test_class.new
      target.classes = [:class1]
      target.modules = [:module1]
      target.methods = [:method1]
      
      source = test_class.new
      source.classes = [:class2]
      source.modules = [:module2]
      source.methods = [:method2]
      
      target.merge_results!(target, source)
      
      expect(target.classes).to eq([:class1, :class2])
      expect(target.modules).to eq([:module1, :module2])
      expect(target.methods).to eq([:method1, :method2])
    end

    it "handles missing collections gracefully" do
      target = test_class.new
      source = double("source")
      
      # Should not raise error for missing methods
      expect { target.merge_results!(target, source) }.not_to raise_error
    end

    it "returns the target after merging" do
      target = test_class.new
      source = test_class.new
      
      result = target.merge_results!(target, source)
      expect(result).to eq(target)
      
      result = target.merge!(source)
      expect(result).to eq(target)
    end
  end
end