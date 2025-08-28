# frozen_string_literal: true

require "spec_helper"
require_relative "../support/emitter_test_data"
require_relative "shared_examples/deterministic_output"
require_relative "shared_examples/format_validation"

RSpec.describe "GraphViz Emitter", skip: "GraphViz emitter implementation deferred" do
  include EmitterTestData

  subject { Rubymap::Emitters::GraphViz.new }

  let(:codebase_data) { rails_application }
  let(:output) { subject.emit(codebase_data) }

  it_behaves_like "a deterministic emitter"
  it_behaves_like "a format-validating emitter", :dot

  describe "DOT notation generation" do
    context "when creating inheritance diagrams" do
      let(:inheritance_output) { subject.emit_inheritance_graph(codebase_data) }

      it "generates valid GraphViz DOT syntax" do
        expect(inheritance_output).to match(/^digraph \w+ \{/)
        expect(inheritance_output).to include("}")
      end

      it "represents inheritance relationships correctly" do
        expect(inheritance_output).to include('"User" -> "ApplicationRecord"')
        expect(inheritance_output).to include('[label="inherits"]')
      end

      it "applies appropriate visual styling for class types" do
        expect(inheritance_output).to match(/"User".*\[.*shape=box.*\]/)
        expect(inheritance_output).to match(/"ApplicationRecord".*\[.*color=.*\]/)
      end

      it "handles namespaced classes properly" do
        expect(inheritance_output).to include('"Admin::DashboardController"')
        expect(inheritance_output).to include('"ApplicationController"')
      end
    end

    context "when creating dependency diagrams" do
      let(:dependency_output) { subject.emit_dependency_graph(codebase_data) }

      it "shows class dependencies with clear labels" do
        expect(dependency_output).to include('"OrdersController" -> "Order"')
        expect(dependency_output).to include('[label="depends_on"]')
      end

      it "differentiates dependency types visually" do
        expect(dependency_output).to match(/\[.*style=dashed.*\]/)  # Soft dependencies
        expect(dependency_output).to match(/\[.*style=solid.*\]/)   # Hard dependencies
      end

      it "prevents circular dependency visualization issues" do
        # Should handle circular deps without creating invalid DOT
        circular_data = codebase_data.dup
        circular_data[:graphs][:dependencies] << {from: "Order", to: "OrdersController", type: "depends_on"}
        
        output = subject.emit_dependency_graph(circular_data)
        expect(output).to include("Order")
        expect(output).to include("OrdersController")
        expect(output.scan(/->/).count).to be >= 2
      end
    end

    context "when creating module inclusion diagrams" do
      let(:module_output) { subject.emit_module_graph(codebase_data) }

      it "visualizes module inclusions and extensions" do
        expect(module_output).to include('"Authenticatable"')
        expect(module_output).to include('[label="includes"]')
        expect(module_output).to include('[label="extends"]')
      end

      it "distinguishes between includes, prepends, and extends" do
        expect(module_output).to match(/\[.*label="includes".*color=green.*\]/)
        expect(module_output).to match(/\[.*label="prepends".*color=blue.*\]/)
        expect(module_output).to match(/\[.*label="extends".*color=red.*\]/)
      end
    end
  end

  describe "visual optimization" do
    context "when handling large graphs" do
      let(:codebase_data) { massive_codebase(class_count: 100) }

      it "applies clustering for related classes" do
        expect(output).to include("subgraph cluster_")
        expect(output).to include("label=")
      end

      it "limits graph depth to prevent overwhelming visuals" do
        subject_with_limit = Rubymap::Emitters::GraphViz.new(max_depth: 3)
        limited_output = subject_with_limit.emit(codebase_data)
        
        # Should have fewer edges than unlimited
        unlimited_edges = output.scan(/->/).count
        limited_edges = limited_output.scan(/->/).count
        expect(limited_edges).to be < unlimited_edges
      end

      it "uses ranking to organize layout" do
        expect(output).to include("rankdir=")
        expect(output).to match(/rank=(same|min|max)/)
      end
    end

    context "when applying visual themes" do
      subject { Rubymap::Emitters::GraphViz.new(theme: :dark) }

      it "supports different color schemes" do
        expect(output).to include("bgcolor=")
        expect(output).to include("fontcolor=")
      end

      it "provides consistent styling across node types" do
        # All class nodes should have consistent style
        class_nodes = output.scan(/"[^"]+"\s*\[.*?shape=box.*?\]/)
        expect(class_nodes).not_to be_empty
        expect(class_nodes.all? { |n| n.include?("shape=box") }).to be true
      end
    end
  end

  describe "file output" do
    let(:output_dir) { "spec/tmp/graphs" }
    
    before { FileUtils.mkdir_p(output_dir) }
    after { FileUtils.rm_rf(output_dir) }

    context "when generating multiple graph files" do
      it "creates separate files for different graph types" do
        subject.emit_to_directory(codebase_data, output_dir)
        
        expect(File).to exist("#{output_dir}/inheritance.dot")
        expect(File).to exist("#{output_dir}/dependencies.dot")
        expect(File).to exist("#{output_dir}/modules.dot")
      end

      it "generates a master graph combining all relationships" do
        subject.emit_to_directory(codebase_data, output_dir)
        
        expect(File).to exist("#{output_dir}/complete.dot")
        complete = File.read("#{output_dir}/complete.dot")
        expect(complete).to include("inherits")
        expect(complete).to include("depends_on")
      end
    end

    context "when generating supporting files" do
      it "creates a Makefile for rendering graphs" do
        subject.emit_to_directory(codebase_data, output_dir, include_makefile: true)
        
        expect(File).to exist("#{output_dir}/Makefile")
        makefile = File.read("#{output_dir}/Makefile")
        expect(makefile).to include("dot -Tsvg")
        expect(makefile).to include("dot -Tpng")
      end

      it "includes a README with viewing instructions" do
        subject.emit_to_directory(codebase_data, output_dir, include_readme: true)
        
        expect(File).to exist("#{output_dir}/README.md")
        readme = File.read("#{output_dir}/README.md")
        expect(readme).to include("GraphViz")
        expect(readme).to include("dot -Tsvg inheritance.dot")
      end
    end
  end

  describe "configuration options" do
    context "when filtering graph content" do
      subject do
        Rubymap::Emitters::GraphViz.new(
          include_private: false,
          namespace_filter: "app/models"
        )
      end

      it "excludes private classes when configured" do
        expect(output).not_to include("PrivateHelper")
      end

      it "filters to specific namespaces" do
        expect(output).to include("User")  # In app/models
        expect(output).not_to include("ApplicationHelper")  # In app/helpers
      end
    end

    context "when customizing graph appearance" do
      subject do
        Rubymap::Emitters::GraphViz.new(
          rankdir: "LR",
          node_shape: "ellipse",
          font_size: 12
        )
      end

      it "applies custom layout direction" do
        expect(output).to include("rankdir=LR")
      end

      it "uses specified node shapes" do
        expect(output).to include("shape=ellipse")
      end

      it "sets custom font size" do
        expect(output).to include("fontsize=12")
      end
    end
  end

  describe "performance optimization" do
    context "when processing large codebases" do
      let(:codebase_data) { massive_codebase(class_count: 500) }

      it "generates graphs within reasonable time" do
        expect { output }.to perform_under(3).seconds
      end

      it "produces manageable file sizes" do
        expect(output.bytesize).to be < 1_000_000  # Less than 1MB
      end

      it "applies edge bundling for many relationships" do
        # Should use techniques to reduce visual clutter
        expect(output).to include("concentrate=true")
      end
    end
  end

  describe "special graph types" do
    context "when generating call graphs" do
      let(:call_graph) { subject.emit_call_graph(codebase_data) }

      it "shows method call relationships" do
        expect(call_graph).to include("authenticate")
        expect(call_graph).to include("->")
        expect(call_graph).to include('[label="calls"]')
      end
    end

    context "when generating complexity heat maps" do
      let(:complexity_graph) { subject.emit_complexity_graph(codebase_data) }

      it "uses color gradients to show complexity" do
        expect(complexity_graph).to match(/fillcolor="#[0-9a-f]{6}"/)
        expect(complexity_graph).to include("style=filled")
      end

      it "includes complexity scores in labels" do
        expect(complexity_graph).to match(/label=".*complexity: \d+/)
      end
    end

    context "when generating Rails-specific diagrams" do
      let(:rails_graph) { subject.emit_rails_graph(codebase_data) }

      it "shows MVC relationships" do
        expect(rails_graph).to include("subgraph cluster_models")
        expect(rails_graph).to include("subgraph cluster_views")
        expect(rails_graph).to include("subgraph cluster_controllers")
      end

      it "highlights Rails conventions" do
        expect(rails_graph).to include("ApplicationRecord")
        expect(rails_graph).to include("ApplicationController")
        expect(rails_graph).to include('[style=bold]')  # Rails base classes
      end
    end
  end

  describe "error handling" do
    context "when processing malformed data" do
      let(:codebase_data) { malformed_codebase }

      it "generates valid DOT syntax despite missing fields" do
        expect(output).to match(/^digraph/)
        expect(output).to include("}")
        expect(output.count("{")).to eq(output.count("}"))
      end
    end

    context "when handling special characters in names" do
      let(:codebase_data) do
        data = basic_codebase
        data[:classes].first[:fqname] = "User<Special>"
        data
      end

      it "escapes special GraphViz characters" do
        expect(output).not_to include("User<Special>")
        expect(output).to include("User_Special_")
      end
    end
  end
end