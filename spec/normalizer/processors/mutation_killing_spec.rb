# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Normalizer Processors Mutation Killing" do
  let(:registry) { Rubymap::Normalizer::NormalizerRegistry.new }
  let(:result) { Rubymap::Normalizer::NormalizedResult.new }
  let(:errors) { [] }

  describe Rubymap::Normalizer::Processors::BaseProcessor do
    let(:processor) { described_class.new(registry) }

    describe "#process" do
      it "requires subclass implementation" do
        expect { processor.process({}, result, errors) }.to raise_error(NotImplementedError)
      end
    end

    describe "#validate" do
      it "requires subclass implementation" do
        expect { processor.validate({}, errors) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe Rubymap::Normalizer::Processors::ClassProcessor do
    let(:processor) { described_class.new(registry) }

    describe "#process" do
      it "processes valid class data" do
        data = {
          name: "User",
          location: { file: "user.rb", line: 1 },
          superclass: "ApplicationRecord"
        }
        
        processor.process(data, result, errors)
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.name).to eq("User")
        expect(result.classes.first.superclass).to eq("ApplicationRecord")
      end

      it "handles missing optional fields" do
        data = {
          name: "User",
          location: { file: "user.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        expect(result.classes.size).to eq(1)
        expect(result.classes.first.superclass).to be_nil
      end

      it "normalizes all fields correctly" do
        data = {
          name: "user",  # Should be capitalized
          location: { file: "./app/models/user.rb", line: 1 },
          namespace: "MyApp::Models",
          superclass: "::ActiveRecord::Base"
        }
        
        processor.process(data, result, errors)
        klass = result.classes.first
        expect(klass.name).to eq("User")
        expect(klass.fqname).to eq("MyApp::Models::User")
        expect(klass.superclass).to eq("ActiveRecord::Base")
      end

      it "generates symbol_id deterministically" do
        data = {
          name: "User",
          location: { file: "user.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        id1 = result.classes.first.symbol_id
        
        result2 = Rubymap::Normalizer::NormalizedResult.new
        processor.process(data, result2, errors)
        id2 = result2.classes.first.symbol_id
        
        expect(id1).to eq(id2)
        expect(id1).not_to be_nil
      end

      it "processes mixins correctly" do
        data = {
          name: "User",
          location: { file: "user.rb", line: 1 },
          included_modules: ["Validatable", "Trackable"],
          extended_modules: ["ClassMethods"],
          prepended_modules: ["Overrides"]
        }
        
        processor.process(data, result, errors)
        klass = result.classes.first
        
        expect(klass.mixins).to include(
          { type: "include", module: "Validatable" },
          { type: "include", module: "Trackable" },
          { type: "extend", module: "ClassMethods" },
          { type: "prepend", module: "Overrides" }
        )
      end

      it "builds namespace_path correctly" do
        data = {
          name: "User",
          namespace: "MyApp::Models",
          location: { file: "user.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        klass = result.classes.first
        expect(klass.namespace_path).to eq(["MyApp", "Models"])
      end

      it "handles empty namespace" do
        data = {
          name: "User",
          namespace: "",
          location: { file: "user.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        klass = result.classes.first
        expect(klass.namespace_path).to eq([])
        expect(klass.fqname).to eq("User")
      end
    end

    describe "#validate" do
      it "adds error for missing name" do
        data = { location: { file: "user.rb", line: 1 } }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("name")
      end

      it "adds error for empty name" do
        data = { name: "", location: { file: "user.rb", line: 1 } }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
      end

      it "adds error for missing location" do
        data = { name: "User" }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("location")
      end

      it "passes validation for valid data" do
        data = {
          name: "User",
          location: { file: "user.rb", line: 1 }
        }
        
        processor.validate(data, errors)
        expect(errors).to be_empty
      end
    end
  end

  describe Rubymap::Normalizer::Processors::ModuleProcessor do
    let(:processor) { described_class.new(registry) }

    describe "#process" do
      it "processes valid module data" do
        data = {
          name: "Helpers",
          location: { file: "helpers.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        expect(result.modules.size).to eq(1)
        expect(result.modules.first.name).to eq("Helpers")
      end

      it "sets kind to module" do
        data = {
          name: "Helpers",
          location: { file: "helpers.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        expect(result.modules.first.kind).to eq("module")
      end

      it "handles concern pattern" do
        data = {
          name: "Trackable",
          location: { file: "concerns/trackable.rb", line: 1 },
          extended_modules: ["ActiveSupport::Concern"]
        }
        
        processor.process(data, result, errors)
        mod = result.modules.first
        expect(mod.mixins).to include({ type: "extend", module: "ActiveSupport::Concern" })
      end
    end
  end

  describe Rubymap::Normalizer::Processors::MethodProcessor do
    let(:processor) { described_class.new(registry) }

    describe "#process" do
      it "processes instance method correctly" do
        data = {
          name: "save",
          owner: "User",
          receiver: "instance",
          location: { file: "user.rb", line: 10 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.name).to eq("save")
        expect(method.fqname).to eq("User#save")
        expect(method.scope).to eq("instance")
      end

      it "processes class method correctly" do
        data = {
          name: "find",
          owner: "User",
          receiver: "self",
          location: { file: "user.rb", line: 20 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.fqname).to eq("User.find")
        expect(method.scope).to eq("class")
      end

      it "normalizes visibility correctly" do
        data = {
          name: "validate",
          owner: "User",
          receiver: "instance",
          visibility: "private",
          location: { file: "user.rb", line: 30 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.visibility).to eq("private")
        expect(method.inferred_visibility).to eq("private")
      end

      it "infers visibility from name patterns" do
        data = {
          name: "_internal_method",
          owner: "User",
          receiver: "instance",
          location: { file: "user.rb", line: 40 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.inferred_visibility).to eq("private")
      end

      it "calculates arity correctly" do
        data = {
          name: "process",
          owner: "Handler",
          receiver: "instance",
          parameters: [
            { kind: "req", name: "data" },
            { kind: "opt", name: "options" }
          ],
          location: { file: "handler.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.arity).to eq(-2)
      end

      it "normalizes parameters correctly" do
        data = {
          name: "process",
          owner: "Handler",
          receiver: "instance",
          parameters: [
            { kind: "required", name: "data" },  # Non-standard kind
            { kind: "keyreq", name: "format" }
          ],
          location: { file: "handler.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.parameters).to eq([
          { kind: "req", name: "data", default: nil },
          { kind: "keyreq", name: "format", default: nil }
        ])
      end

      it "generates canonical_name correctly" do
        data = {
          name: "getUserName",  # camelCase
          owner: "User",
          receiver: "instance",
          location: { file: "user.rb", line: 50 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.canonical_name).to eq("get_user_name")
      end

      it "handles singleton methods" do
        data = {
          name: "configure",
          owner: "MyApp",
          receiver: "singleton",
          location: { file: "app.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        method = result.methods.first
        
        expect(method.scope).to eq("class")
        expect(method.fqname).to eq("MyApp.configure")
      end
    end

    describe "#validate" do
      it "adds error for missing name" do
        data = {
          owner: "User",
          location: { file: "user.rb", line: 10 }
        }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("name")
      end

      it "adds error for missing owner" do
        data = {
          name: "save",
          location: { file: "user.rb", line: 10 }
        }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("owner")
      end

      it "adds error for invalid receiver type" do
        data = {
          name: "save",
          owner: "User",
          receiver: "unknown",
          location: { file: "user.rb", line: 10 }
        }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("receiver")
      end
    end
  end

  describe Rubymap::Normalizer::Processors::MethodCallProcessor do
    let(:processor) { described_class.new(registry) }

    describe "#process" do
      it "processes method call correctly" do
        data = {
          method: "save",
          receiver: "user",
          location: { file: "controller.rb", line: 25 }
        }
        
        processor.process(data, result, errors)
        call = result.method_calls.first
        
        expect(call.method).to eq("save")
        expect(call.receiver).to eq("user")
      end

      it "normalizes method name" do
        data = {
          method: "SaveUser",  # Should be snake_case
          receiver: "service",
          location: { file: "controller.rb", line: 30 }
        }
        
        processor.process(data, result, errors)
        call = result.method_calls.first
        
        expect(call.method).to eq("save_user")
      end

      it "handles nil receiver" do
        data = {
          method: "puts",
          receiver: nil,
          location: { file: "script.rb", line: 1 }
        }
        
        processor.process(data, result, errors)
        call = result.method_calls.first
        
        expect(call.receiver).to be_nil
      end

      it "adds caller context" do
        data = {
          method: "save",
          receiver: "user",
          caller_method: "create",
          caller_class: "UsersController",
          location: { file: "controller.rb", line: 35 }
        }
        
        processor.process(data, result, errors)
        call = result.method_calls.first
        
        expect(call.caller_method).to eq("create")
        expect(call.caller_class).to eq("UsersController")
      end
    end

    describe "#validate" do
      it "adds error for missing method name" do
        data = {
          receiver: "user",
          location: { file: "controller.rb", line: 25 }
        }
        
        processor.validate(data, errors)
        expect(errors).not_to be_empty
        expect(errors.first[:message]).to include("method")
      end

      it "passes validation with just method name and location" do
        data = {
          method: "save",
          location: { file: "controller.rb", line: 25 }
        }
        
        processor.validate(data, errors)
        expect(errors).to be_empty
      end
    end
  end
end