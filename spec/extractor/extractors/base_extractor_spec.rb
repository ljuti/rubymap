# frozen_string_literal: true

require "spec_helper"
require "prism"

RSpec.describe Rubymap::Extractor::BaseExtractor do
  let(:context) { instance_double(Rubymap::Extractor::ExtractionContext, comments: []) }
  let(:result) { instance_double(Rubymap::Extractor::Result) }
  let(:extractor) { described_class.new(context, result) }

  describe "#initialize" do
    it "initializes with context and result" do
      expect(extractor.context).to eq(context)
      expect(extractor.result).to eq(result)
    end

    it "creates new documentation service instance" do
      doc_service = extractor.documentation_service
      expect(doc_service).to be_a(Rubymap::Extractor::Services::DocumentationService)
      expect(doc_service).to be_a(Rubymap::Extractor::Services::DocumentationService)
    end

    it "creates new namespace service instance" do
      namespace_service = extractor.namespace_service
      expect(namespace_service).to be_a(Rubymap::Extractor::Services::NamespaceService)
      expect(namespace_service).to be_a(Rubymap::Extractor::Services::NamespaceService)
    end

    it "creates distinct service instances for each extractor" do
      extractor1 = described_class.new(context, result)
      extractor2 = described_class.new(context, result)

      expect(extractor1.documentation_service).not_to be(extractor2.documentation_service)
      expect(extractor1.namespace_service).not_to be(extractor2.namespace_service)
    end

    it "creates services that can be used immediately" do
      # Test that services are actual working instances, not just type checks
      expect(extractor.documentation_service).to respond_to(:extract_documentation)
      expect(extractor.documentation_service).to respond_to(:extract_inline_comment)
      expect(extractor.documentation_service).to respond_to(:extract_yard_tags)
      expect(extractor.namespace_service).to respond_to(:build_fqname)
    end

    it "stores context and result as readable attributes" do
      new_context = double("new_context")
      new_result = double("new_result")
      new_extractor = described_class.new(new_context, new_result)

      expect(new_extractor.context).to be(new_context)
      expect(new_extractor.result).to be(new_result)
    end
  end

  describe "#extract_documentation" do
    it "delegates to documentation service with correct parameters" do
      node = double("node")
      comments = [double("comment")]
      allow(context).to receive(:comments).and_return(comments)

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_documentation).with(node, comments).and_return("documentation")

      result = extractor.send(:extract_documentation, node)
      expect(result).to eq("documentation")
    end

    it "returns exactly what documentation service returns" do
      node = double("node")
      comments = []
      allow(context).to receive(:comments).and_return(comments)

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_documentation).with(node, comments).and_return(nil)

      result = extractor.send(:extract_documentation, node)
      expect(result).to be_nil
    end
  end

  describe "#extract_inline_comment" do
    it "delegates to documentation service with correct parameters" do
      node = double("node")
      comments = [double("comment")]
      allow(context).to receive(:comments).and_return(comments)

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_inline_comment).with(node, comments).and_return("inline comment")

      result = extractor.send(:extract_inline_comment, node)
      expect(result).to eq("inline comment")
    end
  end

  describe "#extract_yard_tags" do
    it "delegates to documentation service with correct parameter" do
      documentation = "@param name [String] the name"

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_yard_tags).with(documentation).and_return({param: "name [String] the name"})

      result = extractor.send(:extract_yard_tags, documentation)
      expect(result).to eq({param: "name [String] the name"})
    end

    it "returns result from documentation service unchanged when empty" do
      documentation = "Some docs"

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_yard_tags).with(documentation).and_return({})

      result = extractor.send(:extract_yard_tags, documentation)
      expect(result).to eq({})
    end

    it "passes exact documentation string to service" do
      documentation = "specific documentation"

      expect(extractor.documentation_service).to receive(:extract_yard_tags)
        .with(documentation)
        .and_return({})

      extractor.send(:extract_yard_tags, documentation)
    end
  end

  describe "#extract_constant_name" do
    context "with nil node" do
      it "returns nil exactly" do
        result = extractor.send(:extract_constant_name, nil)
        expect(result).to be_nil
        expect(result).not_to eq("")
        expect(result).not_to eq(false)
      end
    end

    context "with falsy node" do
      it "returns nil for false" do
        result = extractor.send(:extract_constant_name, false)
        expect(result).to be_nil
      end
    end

    context "with Prism::ConstantReadNode" do
      it "extracts name as string from simple constant" do
        parse_result = Prism.parse("User")
        constant_node = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_node)
        expect(result).to eq("User")
      end

      it "extracts name as string from different constant" do
        parse_result = Prism.parse("ApplicationRecord")
        constant_node = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_node)
        expect(result).to eq("ApplicationRecord")
      end

      it "converts name to string exactly" do
        parse_result = Prism.parse("SomeConstant")
        constant_node = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_node)
        expect(result).to be_a(String)
        expect(result).to eq("SomeConstant")
      end
    end

    context "with Prism::ConstantPathNode" do
      it "extracts simple constant path" do
        parse_result = Prism.parse("A::B")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("A::B")
      end

      it "extracts nested constant path" do
        parse_result = Prism.parse("A::B::C")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("A::B::C")
      end

      it "extracts deeply nested constant path" do
        parse_result = Prism.parse("A::B::C::D::E")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("A::B::C::D::E")
      end

      it "handles constant path with root namespace" do
        parse_result = Prism.parse("::User")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("User")  # Current implementation doesn't preserve leading ::
      end

      it "handles complex constant path with root namespace" do
        parse_result = Prism.parse("::A::B::C")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("A::B::C")  # Current implementation doesn't preserve leading ::
      end

      it "joins parts with exactly :: separator" do
        parse_result = Prism.parse("Module::Class")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to include("::")
        expect(result).not_to include(":::")
        expect(result).to eq("Module::Class")
      end

      it "handles constant path where parent is nil" do
        parse_result = Prism.parse("::TopLevel")
        constant_path = parse_result.value.statements.body.first
        
        # Verify this actually creates a path with nil parent
        expect(constant_path.parent).to be_nil

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("TopLevel")  # Current implementation doesn't preserve leading ::
      end

      it "compacts nil values from parts array" do
        # This tests the `parts.compact.join("::") behavior
        parse_result = Prism.parse("::A::B")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        # Should not have empty segments from nil parent
        expect(result).not_to match(/::::/)
        expect(result).to eq("A::B")  # Current implementation doesn't preserve leading ::
      end

      context "with recursive constant path extraction" do
        it "recursively extracts parent constant names" do
          parse_result = Prism.parse("Outer::Inner::Deep")
          constant_path = parse_result.value.statements.body.first

          result = extractor.send(:extract_constant_name, constant_path)
          expect(result).to eq("Outer::Inner::Deep")
        end

        it "handles mixed ConstantReadNode and ConstantPathNode parents" do
          # This tests the recursive call: extract_constant_name(current)
          parse_result = Prism.parse("A::B::C")
          constant_path = parse_result.value.statements.body.first

          result = extractor.send(:extract_constant_name, constant_path)
          expect(result).to eq("A::B::C")
        end
      end
    end

    context "with non-Prism constant node types" do
      it "calls to_s on string node" do
        node = "SomeConstant"
        result = extractor.send(:extract_constant_name, node)
        expect(result).to eq("SomeConstant")
      end

      it "calls to_s on numeric node" do
        node = 42
        result = extractor.send(:extract_constant_name, node)
        expect(result).to eq("42")
      end

      it "calls to_s on symbol node" do
        node = :some_symbol
        result = extractor.send(:extract_constant_name, node)
        expect(result).to eq("some_symbol")
      end

      it "calls to_s on object with custom to_s" do
        node = double("custom_node", to_s: "CustomConstant")
        result = extractor.send(:extract_constant_name, node)
        expect(result).to eq("CustomConstant")
      end

      it "returns exact result of to_s method" do
        node = double("node", to_s: "ExactResult")
        result = extractor.send(:extract_constant_name, node)
        expect(result).to be_a(String)
        expect(result).to eq("ExactResult")
      end
    end

    context "edge cases for mutation killing" do
      it "returns nil when node evaluates to nil" do
        result = extractor.send(:extract_constant_name, nil)
        expect(result).to be_nil
      end

      it "handles empty constant path correctly" do
        # Create a scenario that might produce empty path
        parse_result = Prism.parse("::")
        constant_path = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_path)
        expect(result).to eq("")  # Current implementation returns empty string for ::
      end

      it "preserves exact string format from Prism nodes" do
        parse_result = Prism.parse("VerySpecificConstantName")
        constant_node = parse_result.value.statements.body.first

        result = extractor.send(:extract_constant_name, constant_node)
        expect(result).to eq("VerySpecificConstantName")
        expect(result.length).to eq("VerySpecificConstantName".length)
      end
    end
  end

  # Test the protected method accessibility
  describe "method visibility" do
    it "makes extract_constant_name protected" do
      expect(described_class.protected_instance_methods).to include(:extract_constant_name)
    end

    it "makes documentation methods protected" do
      expect(described_class.protected_instance_methods).to include(:extract_documentation)
      expect(described_class.protected_instance_methods).to include(:extract_inline_comment)
      expect(described_class.protected_instance_methods).to include(:extract_yard_tags)
    end
  end
end
