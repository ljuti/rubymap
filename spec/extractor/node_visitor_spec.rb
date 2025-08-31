# frozen_string_literal: true

require "spec_helper"
require "prism"

RSpec.describe Rubymap::Extractor::NodeVisitor do
  let(:context) { Rubymap::Extractor::ExtractionContext.new }
  let(:result) { Rubymap::Extractor::Result.new }
  let(:visitor) { described_class.new(context, result) }

  describe "#initialize" do
    it "initializes with context and result" do
      expect(visitor.context).to eq(context)
      expect(visitor.result).to eq(result)
    end

    it "creates a registry" do
      expect(visitor.registry).to be_a(Rubymap::Extractor::NodeHandlerRegistry)
    end

    it "initializes all extractors" do
      # Check that all extractors are initialized in the hash
      extractors = visitor.instance_variable_get(:@extractors)
      expect(extractors[:class]).to be_a(Rubymap::Extractor::ClassExtractor)
      expect(extractors[:module]).to be_a(Rubymap::Extractor::ModuleExtractor)
      expect(extractors[:method]).to be_a(Rubymap::Extractor::MethodExtractor)
      expect(extractors[:call]).to be_a(Rubymap::Extractor::CallExtractor)
      expect(extractors[:constant]).to be_a(Rubymap::Extractor::ConstantExtractor)
      expect(extractors[:class_variable]).to be_a(Rubymap::Extractor::ClassVariableExtractor)
      expect(extractors[:alias]).to be_a(Rubymap::Extractor::AliasExtractor)
    end
  end

  describe "#visit" do
    context "with nil node" do
      it "returns early without processing" do
        expect(visitor).not_to receive(:visit_children)
        expect(visitor.visit(nil)).to be_nil
      end
    end

    context "with a node that has a handler" do
      it "calls the appropriate handler method" do
        node = double("node")
        allow(visitor.registry).to receive(:handler_for).with(node).and_return(:handle_test)
        expect(visitor).to receive(:handle_test).with(node)
        
        visitor.visit(node)
      end
    end

    context "with a node that has no handler" do
      it "visits children by default" do
        node = double("node")
        allow(visitor.registry).to receive(:handler_for).with(node).and_return(nil)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.visit(node)
      end
    end

    context "when an error occurs" do
      it "adds error to result and continues" do
        node = double("node", class: double(name: "ErrorNode"))
        error = StandardError.new("Test error")
        
        allow(visitor.registry).to receive(:handler_for).with(node).and_return(:handle_error)
        allow(visitor).to receive(:handle_error).and_raise(error)
        
        expect(result).to receive(:add_error).with(error, "Error processing ErrorNode")
        
        visitor.visit(node)
      end
    end
  end

  describe "#visit_children" do
    context "with a node that responds to child_nodes" do
      it "visits each child node" do
        child1 = double("child1")
        child2 = double("child2")
        node = double("node", child_nodes: [child1, nil, child2])
        
        expect(visitor).to receive(:visit).with(child1).ordered
        expect(visitor).to receive(:visit).with(child2).ordered
        
        visitor.send(:visit_children, node)
      end
    end

    context "with a node that responds to body" do
      it "visits the body" do
        body = double("body")
        node = double("node", body: body)
        allow(node).to receive(:respond_to?).with(:child_nodes).and_return(false)
        allow(node).to receive(:respond_to?).with(:body).and_return(true)
        
        expect(visitor).to receive(:visit).with(body)
        
        visitor.send(:visit_children, node)
      end
    end

    context "with a node that has neither child_nodes nor body" do
      it "does nothing" do
        node = double("node")
        allow(node).to receive(:respond_to?).with(:child_nodes).and_return(false)
        allow(node).to receive(:respond_to?).with(:body).and_return(false)
        
        expect(visitor).not_to receive(:visit)
        
        visitor.send(:visit_children, node)
      end
    end
  end

  describe "handler methods" do
    # Test that each handler uses the correct extractor
    it "uses the correct extractor for each node type" do
      # This test verifies the mapping between handlers and extractors
      extractors = visitor.instance_variable_get(:@extractors)
      
      # Test that we have all expected extractors
      expect(extractors.keys).to match_array([:class, :module, :method, :call, :constant, :class_variable, :alias])
      
      # Each extractor should be of the correct type
      expect(extractors[:class]).to be_a(Rubymap::Extractor::ClassExtractor)
      expect(extractors[:module]).to be_a(Rubymap::Extractor::ModuleExtractor)
      expect(extractors[:method]).to be_a(Rubymap::Extractor::MethodExtractor)
      expect(extractors[:call]).to be_a(Rubymap::Extractor::CallExtractor)
      expect(extractors[:constant]).to be_a(Rubymap::Extractor::ConstantExtractor)
      expect(extractors[:class_variable]).to be_a(Rubymap::Extractor::ClassVariableExtractor)
      expect(extractors[:alias]).to be_a(Rubymap::Extractor::AliasExtractor)
    end
    
    describe "#handle_program" do
      it "visits the statements" do
        statements = double("statements")
        node = double("program", statements: statements)
        
        expect(visitor).to receive(:visit).with(statements)
        
        visitor.send(:handle_program, node)
      end
    end

    describe "#handle_statements" do
      it "visits each statement in the body" do
        stmt1 = double("stmt1")
        stmt2 = double("stmt2")
        node = double("statements", body: [stmt1, stmt2])
        
        expect(visitor).to receive(:visit).with(stmt1).ordered
        expect(visitor).to receive(:visit).with(stmt2).ordered
        
        visitor.send(:handle_statements, node)
      end

      it "handles nil body" do
        node = double("statements", body: nil)
        
        expect(visitor).not_to receive(:visit)
        
        visitor.send(:handle_statements, node)
      end
    end

    describe "#handle_class" do
      it "delegates to class extractor and visits children" do
        node = double("class_node")
        block_called = false
        
        # Mock the extractor to capture the block
        class_extractor = visitor.instance_variable_get(:@extractors)[:class]
        allow(class_extractor).to receive(:extract) do |n, &block|
          expect(n).to eq(node)
          block.call if block
          block_called = true
        end
        
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_class, node)
        expect(block_called).to be true
      end
    end

    describe "#handle_module" do
      it "delegates to module extractor and visits children" do
        node = double("module_node")
        block_called = false
        
        module_extractor = visitor.instance_variable_get(:@extractors)[:module]
        allow(module_extractor).to receive(:extract) do |n, &block|
          expect(n).to eq(node)
          block.call if block
          block_called = true
        end
        
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_module, node)
        expect(block_called).to be true
      end
    end

    describe "#handle_method" do
      it "delegates to method extractor and visits children" do
        node = double("method_node")
        
        method_extractor = visitor.instance_variable_get(:@extractors)[:method]
        expect(method_extractor).to receive(:extract).with(node)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_method, node)
      end
    end

    describe "#handle_call" do
      it "delegates to call extractor and visits children" do
        node = double("call_node")
        
        call_extractor = visitor.instance_variable_get(:@extractors)[:call]
        expect(call_extractor).to receive(:extract).with(node)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_call, node)
      end
    end

    describe "#handle_constant" do
      it "delegates to constant extractor and visits children" do
        node = double("constant_node")
        
        constant_extractor = visitor.instance_variable_get(:@extractors)[:constant]
        expect(constant_extractor).to receive(:extract).with(node)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_constant, node)
      end
    end

    describe "#handle_class_variable" do
      it "delegates to class variable extractor and visits children" do
        node = double("class_var_node")
        
        class_var_extractor = visitor.instance_variable_get(:@extractors)[:class_variable]
        expect(class_var_extractor).to receive(:extract).with(node)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_class_variable, node)
      end
    end

    describe "#handle_alias" do
      it "delegates to alias extractor and visits children" do
        node = double("alias_node")
        
        alias_extractor = visitor.instance_variable_get(:@extractors)[:alias]
        expect(alias_extractor).to receive(:extract).with(node)
        expect(visitor).to receive(:visit_children).with(node)
        
        visitor.send(:handle_alias, node)
      end
    end
  end
end