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

      it "handles tags with trailing whitespace" do
        doc = "@param name [String] the name   "
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("name [String] the name")
      end

      it "handles tags without space separator" do
        doc = "@paramname [String] the name"
        result = service.extract_yard_tags(doc)
        expect(result[:paramname]).to eq("[String] the name")
      end

      it "handles tags with multiple spaces" do
        doc = "@param    name [String] the name"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("name [String] the name")
      end

      it "handles empty tag value after spaces" do
        doc = "@param    "
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("")
      end
    end
  end

  # Additional comprehensive tests to kill alive mutations
  describe "mutation killing tests" do
    describe "#clean_comment_text edge cases" do
      it "handles comment with single # and no space" do
        expect(service.send(:clean_comment_text, "#text")).to eq("text")
      end

      it "handles comment with single # and space" do
        expect(service.send(:clean_comment_text, "# text")).to eq("text")
      end

      it "handles comment with ## and no space" do
        expect(service.send(:clean_comment_text, "##text")).to eq("text")
      end

      it "handles comment with ## and space" do
        expect(service.send(:clean_comment_text, "## text")).to eq("text")
      end

      it "handles comment with ### (more than ##)" do
        expect(service.send(:clean_comment_text, "### text")).to eq("# text")
      end

      it "handles empty comment" do
        expect(service.send(:clean_comment_text, "#")).to eq("")
      end

      it "handles comment with only space after #" do
        expect(service.send(:clean_comment_text, "# ")).to eq("")
      end

      it "handles comment without # prefix" do
        expect(service.send(:clean_comment_text, "text")).to eq("text")
      end

      it "preserves internal # characters" do
        expect(service.send(:clean_comment_text, "# text # with # hashes")).to eq("text # with # hashes")
      end
    end

    describe "#find_documentation_comments edge cases" do
      it "stops collecting when there is a gap larger than 1 line" do
        comments = [
          double("comment", location: double(start_line: 5), slice: "# distant"),
          double("comment", location: double(start_line: 7), slice: "# gap"),
          double("comment", location: double(start_line: 9), slice: "# immediate")
        ]
        result = service.send(:find_documentation_comments, comments, 10)
        # Should only collect the comment on line 9, breaking at the gap
        expect(result.length).to eq(1)
        expect(result[0].slice).to eq("# immediate")
      end

      it "handles comments with exact gap of 1 line before node" do
        comments = [
          double("comment", location: double(start_line: 8), slice: "# comment"),
          double("comment", location: double(start_line: 9), slice: "# immediate")
        ]
        result = service.send(:find_documentation_comments, comments, 10)
        # Both consecutive comments should be selected
        expect(result.length).to eq(2)
        expect(result[0].slice).to eq("# comment")
        expect(result[1].slice).to eq("# immediate")
      end

      it "handles comments with gap exactly 2 lines before node" do
        comments = [
          double("comment", location: double(start_line: 7), slice: "# distant"),
          double("comment", location: double(start_line: 9), slice: "# immediate")
        ]
        result = service.send(:find_documentation_comments, comments, 10)
        # Should only collect the comment on line 9
        expect(result.length).to eq(1)
        expect(result[0].slice).to eq("# immediate")
      end

      it "handles multiple consecutive comment blocks" do
        comments = [
          double("comment", location: double(start_line: 10), slice: "# block1"),
          double("comment", location: double(start_line: 11), slice: "# block1"),
          # gap
          double("comment", location: double(start_line: 13), slice: "# block2"),
          double("comment", location: double(start_line: 14), slice: "# block2")
        ]
        result = service.send(:find_documentation_comments, comments, 15)
        # Should select the last consecutive block (lines 13-14)
        expect(result.length).to eq(2)
        expect(result[0].slice).to eq("# block2")
        expect(result[1].slice).to eq("# block2")
      end

      it "handles comments on same line as each other but different from node" do
        comments = [
          double("comment", location: double(start_line: 4), slice: "# comment1"),
          double("comment", location: double(start_line: 4), slice: "# comment2")
        ]
        result = service.send(:find_documentation_comments, comments, 5)
        # Only one comment from the same line will be selected
        expect(result.length).to eq(1)
      end

      it "preserves exact order of consecutive comments" do
        comments = [
          double("comment", location: double(start_line: 3), slice: "# first"),
          double("comment", location: double(start_line: 4), slice: "# second"),
          double("comment", location: double(start_line: 5), slice: "# third")
        ]
        result = service.send(:find_documentation_comments, comments, 6)
        expect(result.length).to eq(3)
        expect(result[0].slice).to eq("# first")
        expect(result[1].slice).to eq("# second")
        expect(result[2].slice).to eq("# third")
      end
    end

    describe "#extract_inline_comment exact position testing" do
      it "returns nil when comment start_column equals node end_column" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comment = double("comment",
          location: double(start_line: 5, start_column: 20),
          slice: "# at boundary")

        expect(service.extract_inline_comment(node, [comment])).to be_nil
      end

      it "extracts comment when start_column is exactly end_column + 1" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comment = double("comment",
          location: double(start_line: 5, start_column: 21),
          slice: "# just after")

        result = service.extract_inline_comment(node, [comment])
        expect(result).to eq("just after")
      end

      it "handles multiple comments on same line, returns first matching" do
        node = double("node", location: double(start_line: 5, end_column: 20))
        comments = [
          double("comment", location: double(start_line: 5, start_column: 15), slice: "# before"),
          double("comment", location: double(start_line: 5, start_column: 25), slice: "# after1"),
          double("comment", location: double(start_line: 5, start_column: 30), slice: "# after2")
        ]

        result = service.extract_inline_comment(node, comments)
        expect(result).to eq("after1")
      end
    end

    describe "#documentation_comment? exact matching" do
      it "returns false for single # at start" do
        comment = double("comment", slice: "# regular")
        expect(service.documentation_comment?(comment)).to be false
      end

      it "returns true for exactly ##" do
        comment = double("comment", slice: "##")
        expect(service.documentation_comment?(comment)).to be true
      end

      it "returns true for ## with trailing content" do
        comment = double("comment", slice: "##content")
        expect(service.documentation_comment?(comment)).to be true
      end

      it "returns false when ## is not at the start" do
        comment = double("comment", slice: "text ## comment")
        expect(service.documentation_comment?(comment)).to be false
      end

      it "returns false for empty string" do
        comment = double("comment", slice: "")
        expect(service.documentation_comment?(comment)).to be false
      end
    end

    describe "#extract_yard_tags regex and parsing edge cases" do
      it "extracts tag with only tag name and space" do
        doc = "@param "
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("")
      end

      it "handles tag name with numbers and underscores" do
        doc = "@param_1 value"
        result = service.extract_yard_tags(doc)
        expect(result[:param_1]).to eq("value")
      end

      it "strips trailing whitespace in tag values" do
        doc = "@param   value with spaces  "
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("value with spaces")
      end

      it "handles multiple spaces between tag and value" do
        doc = "@param      value"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("value")
      end

      it "handles tag at start of line with no leading whitespace" do
        doc = "@param value"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("value")
      end

      it "handles tag with tab character" do
        doc = "@param\tvalue"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("value")
      end

      it "ignores malformed tags without space" do
        doc = "@paramvalue"
        result = service.extract_yard_tags(doc)
        expect(result).to eq({})
      end

      it "handles mixed valid and invalid tags" do
        doc = "@param valid\n@invalidtag notag\n@return [String]"
        result = service.extract_yard_tags(doc)
        expect(result.keys).to contain_exactly(:param, :invalidtag, :return)
        expect(result[:param]).to eq("valid")
        expect(result[:invalidtag]).to eq("notag")
        expect(result[:return]).to eq("[String]")
      end

      it "converts first occurrence to string, subsequent to array" do
        doc = "@param first\n@param second"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq(["first", "second"])
      end

      it "handles three or more tags of same type" do
        doc = "@param first\n@param second\n@param third"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq(["first", "second", "third"])
      end

      it "handles @ symbol in tag value" do
        doc = "@param user@example.com"
        result = service.extract_yard_tags(doc)
        expect(result[:param]).to eq("user@example.com")
      end
    end

    describe "#extract_documentation with exact return values" do
      it "returns exact string for single comment" do
        node = double("node", location: double(start_line: 2))
        comment = double("comment", location: double(start_line: 1), slice: "# exact text")
        result = service.extract_documentation(node, [comment])
        expect(result).to eq("exact text")
      end

      it "returns exactly nil when no preceding comments" do
        node = double("node", location: double(start_line: 1))
        comments = [double("comment", location: double(start_line: 2), slice: "# after")]
        result = service.extract_documentation(node, comments)
        expect(result).to be_nil
      end

      it "joins multiple comments with exact newline character" do
        node = double("node", location: double(start_line: 4))
        comments = [
          double("comment", location: double(start_line: 2), slice: "# first"),
          double("comment", location: double(start_line: 3), slice: "# second")
        ]
        result = service.extract_documentation(node, comments)
        expect(result).to eq("first\nsecond")
      end

      it "handles empty comment content" do
        node = double("node", location: double(start_line: 2))
        comment = double("comment", location: double(start_line: 1), slice: "#")
        result = service.extract_documentation(node, [comment])
        expect(result).to eq("")
      end
    end

    describe "boundary conditions and comparisons" do
      it "handles node at line 1 with no possible preceding comments" do
        node = double("node", location: double(start_line: 1))
        comments = [
          double("comment", location: double(start_line: 1), slice: "# same line"),
          double("comment", location: double(start_line: 2), slice: "# after")
        ]
        result = service.extract_documentation(node, comments)
        expect(result).to be_nil
      end

      it "handles very large line numbers" do
        node = double("node", location: double(start_line: 999999))
        comment = double("comment", location: double(start_line: 999998), slice: "# large line")
        result = service.extract_documentation(node, [comment])
        expect(result).to eq("large line")
      end
    end
  end
end
