# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::BaseExtractor do
  let(:context) { instance_double(Rubymap::Extractor::ExtractionContext, comments: []) }
  let(:result) { instance_double(Rubymap::Extractor::Result) }
  let(:extractor) { described_class.new(context, result) }

  describe "#initialize" do
    it "initializes with context and result" do
      expect(extractor.context).to eq(context)
      expect(extractor.result).to eq(result)
    end

    it "creates documentation service" do
      expect(extractor.documentation_service).to be_a(Rubymap::Extractor::Services::DocumentationService)
    end

    it "creates namespace service" do
      expect(extractor.namespace_service).to be_a(Rubymap::Extractor::Services::NamespaceService)
    end

    it "creates new service instances for each extractor" do
      extractor1 = described_class.new(context, result)
      extractor2 = described_class.new(context, result)

      expect(extractor1.documentation_service == extractor2.documentation_service).to be false
      expect(extractor1.namespace_service == extractor2.namespace_service).to be false
    end
  end

  describe "#extract_documentation" do
    it "delegates to documentation service" do
      node = double("node")
      comments = [double("comment")]
      allow(context).to receive(:comments).and_return(comments)

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_documentation).with(node, comments).and_return("documentation")

      result = extractor.send(:extract_documentation, node)
      expect(result).to eq("documentation")
    end
  end

  describe "#extract_inline_comment" do
    it "delegates to documentation service" do
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
    it "delegates to documentation service" do
      documentation = "@param name [String] the name"

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_yard_tags).with(documentation).and_return({param: "name [String] the name"})

      result = extractor.send(:extract_yard_tags, documentation)
      expect(result).to eq({param: "name [String] the name"})
    end

    it "returns result from documentation service unchanged" do
      documentation = "Some docs"

      doc_service = instance_double(Rubymap::Extractor::Services::DocumentationService)
      allow(extractor).to receive(:documentation_service).and_return(doc_service)

      expect(doc_service).to receive(:extract_yard_tags).with(documentation).and_return({})

      result = extractor.send(:extract_yard_tags, documentation)
      expect(result).to eq({})
    end
  end

  describe "#extract_constant_name" do
    context "with nil node" do
      it "returns nil" do
        expect(extractor.send(:extract_constant_name, nil)).to be_nil
      end
    end

    context "with non-Prism node types" do
      it "calls to_s on the node" do
        node = double("node", to_s: "SomeConstant")
        expect(extractor.send(:extract_constant_name, node)).to eq("SomeConstant")
      end
    end

    # Note: Testing with actual Prism nodes would require Prism to be loaded
    # and actual node instances created, which is tested in integration tests
  end
end
