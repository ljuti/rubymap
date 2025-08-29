# frozen_string_literal: true

require "spec_helper"
require "prism"

RSpec.describe Rubymap::Extractor::Services::DocumentationService do
  let(:service) { described_class.new }

  describe "#extract_documentation" do
    context "with nil inputs" do
      it "returns nil when node is nil" do
        expect(service.extract_documentation(nil, [])).to be_nil
      end

      it "returns nil when comments are nil" do
        node = double("node", location: double(start_line: 5))
        expect(service.extract_documentation(node, nil)).to be_nil
      end

      it "returns nil when comments are empty" do
        node = double("node", location: double(start_line: 5))
        expect(service.extract_documentation(node, [])).to be_nil
      end

      it "returns nil when node doesn't respond to location" do
        node = double("node")
        comments = [double("comment")]
        expect(service.extract_documentation(node, comments)).to be_nil
      end
    end

    context "with comments not preceding the node" do
      it "returns nil when all comments are after the node" do
        node = double("node", location: double(start_line: 5))
        comment = double("comment", location: double(start_line: 10))
        expect(service.extract_documentation(node, [comment])).to be_nil
      end

      it "returns nil when comments have gaps before the node" do
        node = double("node", location: double(start_line: 10))
        comment = double("comment", location: double(start_line: 5))
        expect(service.extract_documentation(node, [comment])).to be_nil
      end
    end

    context "with valid documentation comments" do
      it "extracts single line documentation" do
        node = double("node", location: double(start_line: 5))
        comment = double("comment", 
          location: double(start_line: 4),
          slice: "# This is documentation")
        
        result = service.extract_documentation(node, [comment])
        expect(result).to eq("This is documentation")
      end

      it "extracts multi-line documentation" do
        node = double("node", location: double(start_line: 5))
        comments = [
          double("comment", location: double(start_line: 2), slice: "# First line"),
          double("comment", location: double(start_line: 3), slice: "# Second line"),
          double("comment", location: double(start_line: 4), slice: "# Third line")
        ]
        
        result = service.extract_documentation(node, comments)
        expect(result).to eq("First line\nSecond line\nThird line")
      end

      it "handles documentation comments with ##" do
        node = double("node", location: double(start_line: 3))
        comment = double("comment",
          location: double(start_line: 2),
          slice: "## Important documentation")
        
        result = service.extract_documentation(node, [comment])
        expect(result).to eq("Important documentation")
      end
    end
  end

  describe "#extract_inline_comment" do
    context "with nil inputs" do
      it "returns nil when node is nil" do
        expect(service.extract_inline_comment(nil, [])).to be_nil
      end

      it "returns nil when comments are nil" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        expect(service.extract_inline_comment(node, nil)).to be_nil
      end

      it "returns nil when comments are empty" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        expect(service.extract_inline_comment(node, [])).to be_nil
      end

      it "returns nil when node doesn't respond to location" do
        node = double("node")
        comments = [double("comment")]
        expect(service.extract_inline_comment(node, comments)).to be_nil
      end
    end

    context "with inline comments" do
      it "extracts inline comment on the same line" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comment = double("comment",
          location: double(start_line: 5, start_column: 25),
          slice: "# inline comment")
        
        result = service.extract_inline_comment(node, [comment])
        expect(result).to eq("inline comment")
      end

      it "returns nil when comment is before the node on same line" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comment = double("comment",
          location: double(start_line: 5, start_column: 5),
          slice: "# before node")
        
        expect(service.extract_inline_comment(node, [comment])).to be_nil
      end

      it "returns nil when comment is on different line" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comment = double("comment",
          location: double(start_line: 6, start_column: 25),
          slice: "# different line")
        
        expect(service.extract_inline_comment(node, [comment])).to be_nil
      end
    end
  end

  describe "#documentation_comment?" do
    it "returns true for comments starting with ##" do
      comment = double("comment", slice: "## Documentation")
      expect(service.documentation_comment?(comment)).to be true
    end

    it "returns false for regular comments" do
      comment = double("comment", slice: "# Regular comment")
      expect(service.documentation_comment?(comment)).to be false
    end

    it "returns false for non-comment text" do
      comment = double("comment", slice: "Not a comment")
      expect(service.documentation_comment?(comment)).to be false
    end
  end

  describe "#extract_yard_tags" do
    context "with nil or empty documentation" do
      it "returns empty hash for nil documentation" do
        expect(service.extract_yard_tags(nil)).to eq({})
      end

      it "returns empty hash for empty documentation" do
        expect(service.extract_yard_tags("")).to eq({})
      end
    end

    context "with YARD tags" do
      it "extracts single YARD tag" do
        doc = "@param name [String] the user name"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("name [String] the user name")
      end

      it "extracts multiple different YARD tags" do
        doc = "@param name [String] the user name\n@return [User] the created user"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("name [String] the user name")
        expect(result[:return]).to eq("[User] the created user")
      end

      it "handles multiple tags of the same type" do
        doc = "@param name [String] the name\n@param age [Integer] the age"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq(["name [String] the name", "age [Integer] the age"])
      end

      it "ignores non-YARD content" do
        doc = "This is a description\n@param name [String] the name\nMore description"
        result = service.extract_yard_tags(doc)
        expect(result.keys).to eq([:param])
        expect(result[:param]).to eq("name [String] the name")
      end

      it "handles tags with no content" do
        doc = "@deprecated"
        result = service.extract_yard_tags(doc)
        expect(result).to eq({})  # Tag with no content is not extracted
      end
    end
  end
end