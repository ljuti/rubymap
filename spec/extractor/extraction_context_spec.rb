# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::ExtractionContext do
  let(:context) { described_class.new }

  describe "#initialize" do
    it "initializes with empty namespace stack" do
      expect(context.current_namespace).to eq("")
    end

    it "initializes with public visibility" do
      expect(context.current_visibility).to eq(:public)
    end

    it "initializes with nil current class" do
      expect(context.current_class).to be_nil
    end

    it "initializes with empty comments array" do
      expect(context.comments).to eq([])
    end
  end

  describe "namespace management" do
    describe "#push_namespace" do
      it "adds namespace to stack" do
        context.push_namespace("MyApp")
        expect(context.current_namespace).to eq("MyApp")
      end

      it "builds nested namespaces" do
        context.push_namespace("MyApp")
        context.push_namespace("Models")
        expect(context.current_namespace).to eq("MyApp::Models")
      end
    end

    describe "#pop_namespace" do
      it "removes namespace from stack" do
        context.push_namespace("MyApp")
        context.push_namespace("Models")
        context.pop_namespace
        expect(context.current_namespace).to eq("MyApp")
      end

      it "returns the popped namespace" do
        context.push_namespace("MyApp")
        expect(context.pop_namespace).to eq("MyApp")
      end

      it "returns nil when stack is empty" do
        expect(context.pop_namespace).to be_nil
      end
    end

    describe "#namespace_depth" do
      it "returns 0 for empty stack" do
        expect(context.namespace_depth).to eq(0)
      end

      it "returns correct depth" do
        context.push_namespace("MyApp")
        context.push_namespace("Models")
        expect(context.namespace_depth).to eq(2)
      end
    end

    describe "#with_namespace" do
      it "temporarily adds namespace" do
        context.with_namespace("MyApp") do
          expect(context.current_namespace).to eq("MyApp")
        end
        expect(context.current_namespace).to eq("")
      end

      it "nests within existing namespace" do
        context.push_namespace("MyApp")
        context.with_namespace("Models") do
          expect(context.current_namespace).to eq("MyApp::Models")
        end
        expect(context.current_namespace).to eq("MyApp")
      end

      it "sets current_class during block" do
        expect(context.current_class).to be_nil
        context.with_namespace("User") do
          expect(context.current_class).to eq("User")
        end
        expect(context.current_class).to be_nil
      end

      it "restores current_class after exception" do
        context.instance_variable_set(:@current_class, "Original")
        expect {
          context.with_namespace("User") do
            expect(context.current_class).to eq("User")
            raise "test error"
          end
        }.to raise_error("test error")
        expect(context.current_class).to eq("Original")
      end

      it "restores namespace after exception" do
        context.push_namespace("MyApp")
        expect {
          context.with_namespace("Models") do
            expect(context.current_namespace).to eq("MyApp::Models")
            raise "test error"
          end
        }.to raise_error("test error")
        expect(context.current_namespace).to eq("MyApp")
      end
    end

    describe "#namespace_stack" do
      it "returns frozen copy of stack" do
        context.push_namespace("MyApp")
        stack = context.namespace_stack
        expect(stack).to eq(["MyApp"])
        expect(stack).to be_frozen
      end

      it "returns independent copy" do
        context.push_namespace("MyApp")
        stack = context.namespace_stack
        context.push_namespace("Models")
        expect(stack).to eq(["MyApp"])
        expect(context.namespace_stack).to eq(["MyApp", "Models"])
      end
    end
  end

  describe "visibility management" do
    describe "#push_visibility" do
      it "adds visibility to stack" do
        context.push_visibility(:private)
        expect(context.current_visibility).to eq(:private)
      end

      it "maintains visibility stack" do
        context.push_visibility(:private)
        context.push_visibility(:protected)
        expect(context.current_visibility).to eq(:protected)
      end
    end

    describe "#pop_visibility" do
      it "removes visibility from stack" do
        context.push_visibility(:private)
        context.pop_visibility
        expect(context.current_visibility).to eq(:public)
      end

      it "returns the popped visibility" do
        context.push_visibility(:private)
        expect(context.pop_visibility).to eq(:private)
      end

      it "maintains public as default" do
        context.pop_visibility
        expect(context.current_visibility).to eq(:public)
      end
    end

    describe "#visibility_depth" do
      it "returns 1 for initial state" do
        expect(context.visibility_depth).to eq(1)
      end

      it "returns correct depth" do
        context.push_visibility(:private)
        context.push_visibility(:protected)
        expect(context.visibility_depth).to eq(3)
      end
    end

    describe "#with_visibility" do
      it "temporarily changes visibility" do
        context.with_visibility(:private) do
          expect(context.current_visibility).to eq(:private)
        end
        expect(context.current_visibility).to eq(:public)
      end

      it "nests visibility changes" do
        context.with_visibility(:private) do
          context.with_visibility(:protected) do
            expect(context.current_visibility).to eq(:protected)
          end
          expect(context.current_visibility).to eq(:private)
        end
        expect(context.current_visibility).to eq(:public)
      end

      it "restores visibility after exception" do
        expect {
          context.with_visibility(:private) do
            expect(context.current_visibility).to eq(:private)
            raise "test error"
          end
        }.to raise_error("test error")
        expect(context.current_visibility).to eq(:public)
      end
    end

    describe "#visibility_stack" do
      it "returns frozen copy of stack" do
        context.push_visibility(:private)
        stack = context.visibility_stack
        expect(stack).to eq([:public, :private])
        expect(stack).to be_frozen
      end

      it "returns independent copy" do
        context.push_visibility(:private)
        stack = context.visibility_stack
        context.push_visibility(:protected)
        expect(stack).to eq([:public, :private])
        expect(context.visibility_stack).to eq([:public, :private, :protected])
      end
    end
  end

  describe "#reset!" do
    it "clears namespace stack" do
      context.push_namespace("MyApp")
      context.push_namespace("Models")
      context.reset!
      expect(context.current_namespace).to eq("")
    end

    it "resets visibility to public" do
      context.push_visibility(:private)
      context.reset!
      expect(context.current_visibility).to eq(:public)
    end

    it "clears current class" do
      context.instance_variable_set(:@current_class, "User")
      context.reset!
      expect(context.current_class).to be_nil
    end

    it "clears comments" do
      context.comments = [double("comment")]
      context.reset!
      expect(context.comments).to eq([])
    end

    it "resets all state to initial values" do
      context.push_namespace("MyApp")
      context.push_visibility(:private)
      context.comments = [double("comment")]
      context.instance_variable_set(:@current_class, "User")
      
      context.reset!
      
      expect(context.current_namespace).to eq("")
      expect(context.current_visibility).to eq(:public)
      expect(context.current_class).to be_nil
      expect(context.comments).to eq([])
      expect(context.namespace_depth).to eq(0)
      expect(context.visibility_depth).to eq(1)
    end
  end

  describe "comments management" do
    it "allows setting comments" do
      comments = [double("comment1"), double("comment2")]
      context.comments = comments
      expect(context.comments).to eq(comments)
    end

    it "allows modifying comments array" do
      context.comments << double("comment")
      expect(context.comments.size).to eq(1)
    end
  end
end