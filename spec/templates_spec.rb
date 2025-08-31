# frozen_string_literal: true

require "spec_helper"
require "rubymap/templates"

RSpec.describe Rubymap::Templates do
  describe "module interface" do
    it "provides a default directory" do
      expect(Rubymap::Templates.default_directory).to include("templates/default")
    end

    it "provides a global registry" do
      expect(Rubymap::Templates.registry).to be_a(Rubymap::Templates::Registry)
    end

    it "provides a convenience render method" do
      # Register a test template
      Rubymap::Templates.registry.register(:test, :simple,
        File.expand_path("../fixtures/templates/simple.erb", __FILE__))

      # Create the test template file
      template_dir = File.expand_path("../fixtures/templates", __FILE__)
      FileUtils.mkdir_p(template_dir)
      File.write(File.join(template_dir, "simple.erb"), "Hello <%= @name %>!")

      result = Rubymap::Templates.render(:test, :simple, {name: "World"})
      expect(result).to eq("Hello World!")
    ensure
      FileUtils.rm_rf(template_dir) if defined?(template_dir)
    end
  end

  describe Rubymap::Templates::Registry do
    let(:registry) { Rubymap::Templates::Registry.new }

    before do
      # Prevent loading default templates during tests
      allow(registry).to receive(:load_defaults)
    end

    describe "#register" do
      it "registers a template" do
        registry.register(:test, :sample, "/path/to/sample.erb")
        # Force check without loading defaults
        registry.instance_variable_set(:@loaded_defaults, true)
        expect(registry.template_exists?(:test, :sample)).to be true
      end

      it "organizes templates by format" do
        registry.register(:test_llm, :class, "/path/llm/class.erb")
        registry.register(:test_markdown, :class, "/path/markdown/class.erb")
        registry.instance_variable_set(:@loaded_defaults, true)

        expect(registry.get_template(:test_llm, :class)).to eq("/path/llm/class.erb")
        expect(registry.get_template(:test_markdown, :class)).to eq("/path/markdown/class.erb")
      end
    end

    describe "#register_user_template" do
      it "registers user template overrides" do
        registry.register(:llm, :class, "/default/class.erb")
        registry.register_user_template(:llm, :class, "/user/class.erb")

        expect(registry.get_template(:llm, :class)).to eq("/user/class.erb")
      end
    end

    describe "#get_template" do
      it "raises error for non-existent template" do
        expect {
          registry.get_template(:unknown, :template)
        }.to raise_error(Rubymap::Templates::TemplateNotFoundError)
      end

      it "prefers user templates over defaults" do
        registry.register(:llm, :test, "/default.erb")
        registry.register_user_template(:llm, :test, "/user.erb")

        expect(registry.get_template(:llm, :test)).to eq("/user.erb")
      end
    end

    describe "#list_templates" do
      it "lists all registered templates with their types" do
        registry.register(:test, :class, "/default/class.erb")
        registry.register_user_template(:test, :module, "/user/module.erb")
        registry.instance_variable_set(:@loaded_defaults, true)

        list = registry.list_templates

        expect(list[:test][:class]).to eq({path: "/default/class.erb", type: :default})
        expect(list[:test][:module]).to eq({path: "/user/module.erb", type: :user})
      end
    end

    describe "#clear!" do
      it "removes all registered templates" do
        registry.register(:test, :class, "/path.erb")
        registry.instance_variable_set(:@loaded_defaults, true)

        registry.clear!

        # After clear, loaded_defaults should be false
        expect(registry.instance_variable_get(:@loaded_defaults)).to be false
        # Force loaded state to avoid auto-loading
        registry.instance_variable_set(:@loaded_defaults, true)
        expect(registry.template_exists?(:test, :class)).to be false
      end
    end
  end

  describe Rubymap::Templates::Renderer do
    let(:registry) { Rubymap::Templates::Registry.new }
    let(:renderer) { Rubymap::Templates::Renderer.new(:llm) }
    let(:template_dir) { File.expand_path("../fixtures/templates", __FILE__) }

    before do
      FileUtils.mkdir_p(template_dir)
      Rubymap::Templates.registry.clear!
    end

    after do
      FileUtils.rm_rf(template_dir)
    end

    describe "#render" do
      it "renders a template with data" do
        template_path = File.join(template_dir, "greeting.erb")
        File.write(template_path, "Hello <%= @name %>!")

        Rubymap::Templates.registry.register(:llm, :greeting, template_path)

        result = renderer.render(:greeting, {name: "Ruby"})
        expect(result).to eq("Hello Ruby!")
      end

      it "raises RenderError on template errors" do
        template_path = File.join(template_dir, "error.erb")
        File.write(template_path, "<%= undefined_method %>")

        Rubymap::Templates.registry.register(:llm, :error, template_path)

        expect {
          renderer.render(:error, {})
        }.to raise_error(Rubymap::Templates::RenderError)
      end

      it "handles ERB trim mode correctly" do
        template_path = File.join(template_dir, "trim.erb")
        File.write(template_path, "<% if true -%>\nHello\n<% end -%>")

        Rubymap::Templates.registry.register(:llm, :trim, template_path)

        result = renderer.render(:trim, {})
        expect(result).to eq("Hello\n")
      end
    end

    describe "#render_collection" do
      it "renders a collection of items" do
        template_path = File.join(template_dir, "item.erb")
        File.write(template_path, "- <%= @name %>")

        Rubymap::Templates.registry.register(:llm, :item, template_path)

        items = [{name: "First"}, {name: "Second"}]
        result = renderer.render_collection(:item, items, "\n")

        expect(result).to eq("- First\n- Second")
      end

      it "returns empty string for empty collection" do
        result = renderer.render_collection(:any, [], "\n")
        expect(result).to eq("")
      end
    end

    describe "#render_partial" do
      it "renders a partial template" do
        partial_path = File.join(template_dir, "_header.erb")
        File.write(partial_path, "## <%= @title %>")

        Rubymap::Templates.registry.register(:llm, :_header, partial_path)

        result = renderer.render_partial(:header, {title: "Section"})
        expect(result).to eq("## Section")
      end
    end
  end

  describe Rubymap::Templates::Context do
    let(:context) { Rubymap::Templates::Context.new({name: "Test", count: 5}) }

    describe "data access" do
      it "makes data available as instance variables" do
        expect(context.instance_variable_get(:@name)).to eq("Test")
        expect(context.instance_variable_get(:@count)).to eq(5)
      end

      it "provides binding for ERB evaluation" do
        template = ERB.new("Name: <%= @name %>, Count: <%= @count %>")
        result = template.result(context.get_binding)
        expect(result).to eq("Name: Test, Count: 5")
      end
    end

    describe "helper methods" do
      describe "#format_method_signature" do
        it "formats instance methods" do
          method = {name: "test", scope: "instance", parameters: []}
          expect(context.format_method_signature(method)).to eq("#test()")
        end

        it "formats class methods" do
          method = {name: "create", scope: "class", parameters: []}
          expect(context.format_method_signature(method)).to eq(".create()")
        end
      end

      describe "#format_parameters" do
        it "formats various parameter types" do
          params = [
            {type: "required", name: "arg"},
            {type: "optional", name: "opt", default: "nil"},
            {type: "keyword", name: "key"}
          ]

          expect(context.format_parameters(params)).to eq("(arg, opt = nil, key:)")
        end
      end

      describe "#complexity_label" do
        it "returns appropriate labels for complexity scores" do
          expect(context.complexity_label(2)).to eq("low")
          expect(context.complexity_label(5)).to eq("medium")
          expect(context.complexity_label(10)).to eq("high")
        end
      end

      describe "#present? and #blank?" do
        it "checks for presence and blankness" do
          expect(context.present?("value")).to be true
          expect(context.present?(nil)).to be false
          expect(context.present?([])).to be false

          expect(context.blank?(nil)).to be true
          expect(context.blank?("")).to be true
          expect(context.blank?("value")).to be false
        end
      end

      describe "#truncate" do
        it "truncates long text" do
          long_text = "a" * 200
          result = context.truncate(long_text, 50)

          expect(result.length).to eq(50)
          expect(result).to end_with("...")
        end
      end

      describe "#to_sentence" do
        it "joins arrays with proper grammar" do
          expect(context.to_sentence(["one"])).to eq("one")
          expect(context.to_sentence(["one", "two"])).to eq("one and two")
          expect(context.to_sentence(["one", "two", "three"])).to eq("one, two, and three")
        end
      end
    end
  end

  describe Rubymap::Templates::Presenters::ClassPresenter do
    let(:class_data) {
      {
        name: "User",
        fqname: "Models::User",
        superclass: "ApplicationRecord",
        documentation: "User model",
        location: {file: "app/models/user.rb", line: 10},
        metrics: {complexity_score: 5},
        instance_methods: ["save", "validate"],
        class_methods: ["find", "create"],
        mixins: [
          {module: "Validatable", type: "include"},
          {module: "Searchable", type: "extend"}
        ]
      }
    }

    let(:presenter) { Rubymap::Templates::Presenters::ClassPresenter.new(class_data) }

    describe "name methods" do
      it "provides various name formats" do
        expect(presenter.full_name).to eq("Models::User")
        expect(presenter.simple_name).to eq("User")
        expect(presenter.namespace).to eq("Models")
      end
    end

    describe "boolean queries" do
      it "answers boolean queries about the class" do
        expect(presenter.has_superclass?).to be true
        expect(presenter.has_documentation?).to be true
        expect(presenter.has_metrics?).to be true
        expect(presenter.has_instance_methods?).to be true
        expect(presenter.has_class_methods?).to be true
        expect(presenter.has_mixins?).to be true
      end
    end

    describe "metrics" do
      it "provides metrics information" do
        expect(presenter.complexity_score).to eq(5)
        expect(presenter.complexity_label).to eq("medium")
      end
    end

    describe "location" do
      it "provides formatted location" do
        expect(presenter.formatted_location).to eq("app/models/user.rb:10")
      end
    end

    describe "methods" do
      it "wraps methods in presenters" do
        expect(presenter.instance_methods).to all(be_a(Rubymap::Templates::Presenters::MethodPresenter))
        expect(presenter.instance_methods.map(&:name)).to eq(["save", "validate"])

        expect(presenter.class_methods).to all(be_a(Rubymap::Templates::Presenters::MethodPresenter))
        expect(presenter.class_methods.map(&:name)).to eq(["find", "create"])
      end
    end

    describe "mixins" do
      it "categorizes mixins by type" do
        expect(presenter.included_modules.map(&:name)).to eq(["Validatable"])
        expect(presenter.extended_modules.map(&:name)).to eq(["Searchable"])
        expect(presenter.prepended_modules).to be_empty
      end
    end

    describe "Rails detection" do
      it "detects Rails patterns" do
        expect(presenter.is_rails_model?).to be true
        expect(presenter.is_rails_controller?).to be false
      end
    end
  end
end
