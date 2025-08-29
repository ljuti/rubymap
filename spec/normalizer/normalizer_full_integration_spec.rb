# frozen_string_literal: true

require "spec_helper"

# Full integration tests for the Normalizer to kill mutations
RSpec.describe "Normalizer Full Integration" do
  describe Rubymap::Normalizer do
    let(:normalizer) { described_class.new }

    describe "#normalize" do
      context "with nil input" do
        it "returns a valid NormalizedResult" do
          result = normalizer.normalize(nil)
          expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
          expect(result.classes).to eq([])
          expect(result.modules).to eq([])
          expect(result.methods).to eq([])
          expect(result.method_calls).to eq([])
        end
      end

      context "with empty hash input" do
        it "returns a valid NormalizedResult" do
          result = normalizer.normalize({})
          expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
          expect(result.schema_version).to eq(1)
          expect(result.normalizer_version).to eq("1.0.0")
        end
      end

      context "with valid class data" do
        let(:class_data) do
          {
            classes: [{
              name: "User",
              location: {file: "app/models/user.rb", line: 5},
              superclass: "ApplicationRecord",
              namespace: "MyApp::Models"
            }]
          }
        end

        it "processes and normalizes class data" do
          result = normalizer.normalize(class_data)

          expect(result.classes.size).to eq(1)

          user_class = result.classes.first
          expect(user_class.name).to eq("User")
          expect(user_class.fqname).to eq("MyApp::Models::User")
          expect(user_class.superclass).to eq("ApplicationRecord")
          expect(user_class.namespace_path).to eq(["MyApp", "Models"])
          expect(user_class.symbol_id).to be_truthy
        end
      end

      context "with module data" do
        let(:module_data) do
          {
            modules: [{
              name: "Trackable",
              location: {file: "app/models/concerns/trackable.rb", line: 1}
            }]
          }
        end

        it "processes module data" do
          result = normalizer.normalize(module_data)

          expect(result.modules.size).to eq(1)

          mod = result.modules.first
          expect(mod.name).to eq("Trackable")
          expect(mod.kind).to eq("module")
          expect(mod.symbol_id).to be_truthy
        end
      end

      context "with method data" do
        let(:method_data) do
          {
            methods: [{
              name: "save",
              owner: "User",
              receiver: "instance",
              visibility: "public",
              parameters: [
                {kind: "req", name: "validate"}
              ],
              location: {file: "app/models/user.rb", line: 25}
            }]
          }
        end

        it "processes method data" do
          result = normalizer.normalize(method_data)

          expect(result.methods.size).to eq(1)

          method = result.methods.first
          expect(method.name).to eq("save")
          expect(method.owner).to eq("User")
          expect(method.scope).to eq("instance")
          expect(method.visibility).to eq("public")
          expect(method.arity).to eq(1)
          expect(method.fqname).to eq("User#save")
        end
      end

      context "with mixins" do
        let(:mixin_data) do
          {
            classes: [{
              name: "User",
              location: {file: "user.rb", line: 1},
              included_modules: ["Trackable", "Timestampable"],
              extended_modules: ["ClassMethods"],
              prepended_modules: ["Overridable"]
            }]
          }
        end

        it "processes mixin data correctly" do
          result = normalizer.normalize(mixin_data)

          user_class = result.classes.first
          expect(user_class.mixins).to include(
            {type: "include", module: "Trackable"},
            {type: "include", module: "Timestampable"},
            {type: "extend", module: "ClassMethods"},
            {type: "prepend", module: "Overridable"}
          )
        end
      end

      context "with method calls" do
        let(:method_call_data) do
          {
            method_calls: [{
              method: "save",
              receiver: "user",
              location: {file: "controller.rb", line: 10}
            }]
          }
        end

        it "processes method call data" do
          result = normalizer.normalize(method_call_data)

          expect(result.method_calls.size).to eq(1)

          call = result.method_calls.first
          expect(call.to).to eq("save")
          expect(call.from).to be_nil # No caller context provided
        end
      end

      context "with invalid data" do
        let(:invalid_data) do
          {
            classes: [
              {name: "", location: {file: "bad.rb", line: 1}},  # Empty name
              {name: "ValidClass", location: {file: "good.rb", line: 1}}
            ]
          }
        end

        it "skips invalid entries and records errors" do
          result = normalizer.normalize(invalid_data)

          expect(result.classes.size).to eq(1)
          expect(result.classes.first.name).to eq("ValidClass")
          expect(result.errors.size).to be > 0
        end
      end

      context "with complex nested namespaces" do
        let(:namespace_data) do
          {
            classes: [
              {
                name: "User",
                namespace: "MyApp::Models::Admin",
                location: {file: "user.rb", line: 1}
              },
              {
                name: "Profile",
                namespace: "MyApp::Models::Admin::User",
                location: {file: "profile.rb", line: 1}
              }
            ]
          }
        end

        it "builds correct namespace paths and relationships" do
          result = normalizer.normalize(namespace_data)

          user = result.classes.find { |c| c.name == "User" }
          profile = result.classes.find { |c| c.name == "Profile" }

          expect(user.fqname).to eq("MyApp::Models::Admin::User")
          expect(user.namespace_path).to eq(["MyApp", "Models", "Admin"])

          expect(profile.fqname).to eq("MyApp::Models::Admin::User::Profile")
          expect(profile.namespace_path).to eq(["MyApp", "Models", "Admin", "User"])
        end
      end

      context "with duplicate symbols" do
        let(:duplicate_data) do
          {
            classes: [
              {name: "User", location: {file: "user1.rb", line: 1}, superclass: "ActiveRecord::Base"},
              {name: "User", location: {file: "user2.rb", line: 1}, superclass: "ApplicationRecord"}
            ]
          }
        end

        it "deduplicates symbols with the same name" do
          result = normalizer.normalize(duplicate_data)

          # Should be deduplicated to one User class
          expect(result.classes.size).to eq(1)

          user = result.classes.first
          expect(user.name).to eq("User")
          # Should merge provenance from both sources
          expect(user.provenance).to be_truthy
        end
      end

      context "deterministic output ordering" do
        let(:unordered_data) do
          {
            classes: [
              {name: "Zebra", location: {file: "z.rb", line: 1}},
              {name: "Apple", location: {file: "a.rb", line: 1}},
              {name: "Monkey", location: {file: "m.rb", line: 1}}
            ]
          }
        end

        it "returns symbols in deterministic order" do
          result1 = normalizer.normalize(unordered_data)
          result2 = normalizer.normalize(unordered_data)

          names1 = result1.classes.map(&:name)
          names2 = result2.classes.map(&:name)

          expect(names1).to eq(names2)
          # Should be alphabetically sorted
          expect(names1).to eq(["Apple", "Monkey", "Zebra"])
        end
      end

      context "with inheritance chains" do
        let(:inheritance_data) do
          {
            classes: [
              {name: "User", superclass: "ApplicationRecord", location: {file: "user.rb", line: 1}},
              {name: "ApplicationRecord", superclass: "ActiveRecord::Base", location: {file: "app_record.rb", line: 1}},
              {name: "AdminUser", superclass: "User", location: {file: "admin.rb", line: 1}}
            ]
          }
        end

        it "resolves inheritance chains" do
          result = normalizer.normalize(inheritance_data)

          admin = result.classes.find { |c| c.name == "AdminUser" }
          expect(admin.inheritance_chain).to include("User", "ApplicationRecord", "ActiveRecord::Base")
        end
      end

      context "with class and instance methods" do
        let(:method_owner_data) do
          {
            classes: [
              {name: "User", location: {file: "user.rb", line: 1}}
            ],
            methods: [
              {name: "save", owner: "User", receiver: "instance", location: {file: "user.rb", line: 10}},
              {name: "find", owner: "User", receiver: "self", location: {file: "user.rb", line: 20}},
              {name: "all", owner: "User", receiver: "singleton", location: {file: "user.rb", line: 30}}
            ]
          }
        end

        it "correctly associates methods with their owners" do
          result = normalizer.normalize(method_owner_data)

          user = result.classes.first
          expect(user.instance_methods).to include("save")
          expect(user.class_methods).to include("find", "all")
        end
      end

      context "edge cases" do
        it "handles string input gracefully" do
          result = normalizer.normalize("not a hash")
          expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
          expect(result.classes).to eq([])
        end

        it "handles array input gracefully" do
          result = normalizer.normalize([1, 2, 3])
          expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
          expect(result.classes).to eq([])
        end

        it "handles numeric input gracefully" do
          result = normalizer.normalize(42)
          expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
          expect(result.classes).to eq([])
        end
      end

      context "performance and efficiency" do
        let(:large_dataset) do
          {
            classes: (1..100).map { |i|
              {name: "Class#{i}", location: {file: "class#{i}.rb", line: i}}
            },
            methods: (1..500).map { |i|
              {name: "method#{i}", owner: "Class#{i % 100 + 1}", receiver: "instance", location: {file: "file.rb", line: i}}
            }
          }
        end

        it "handles large datasets efficiently" do
          result = normalizer.normalize(large_dataset)

          expect(result.classes.size).to eq(100)
          expect(result.methods.size).to eq(500)

          # Verify methods are properly associated
          result.classes.each do |klass|
            expect(klass.instance_methods).to be_an(Array)
          end
        end
      end
    end
  end
end
