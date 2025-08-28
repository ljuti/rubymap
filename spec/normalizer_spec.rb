# frozen_string_literal: true

RSpec.describe "Rubymap::Normalizer" do
  let(:normalizer) { Rubymap::Normalizer.new }

  describe "data standardization" do
    describe "#normalize" do
      context "when processing extracted symbols" do
        let(:raw_extraction_data) do
          {
            classes: [
              {name: "User", superclass: "ApplicationRecord", location: {file: "app/models/user.rb", line: 1}},
              {name: "Admin::User", superclass: "User", location: {file: "app/models/admin/user.rb", line: 3}}
            ],
            methods: [
              {name: "initialize", class: "User", visibility: :public, parameters: ["name", "email"]},
              {name: "full_name", class: "User", visibility: :public, parameters: []},
              {name: "validate_email", class: "User", visibility: :private, parameters: []}
            ]
          }
        end

        it "standardizes class representations" do
          # Given: Raw extraction data with inconsistent formats
          # When: Normalizing the data
          # Then: Classes should have consistent, standardized structure
          result = normalizer.normalize(raw_extraction_data)

          expect(result.classes).to all(have_attributes(
            fqname: be_a(String),
            kind: "class",
            location: have_attributes(file: be_a(String), line: be_a(Integer))
          ))
        end

        it "generates fully qualified names consistently" do
          result = normalizer.normalize(raw_extraction_data)

          user_class = result.classes.find { |c| c.name == "User" }
          admin_user_class = result.classes.find { |c| c.name.include?("Admin") }

          expect(user_class.fqname).to eq("User")
          expect(admin_user_class.fqname).to eq("Admin::User")
        end

        it "standardizes method representations" do
          result = normalizer.normalize(raw_extraction_data)

          expect(result.methods).to all(have_attributes(
            fqname: be_a(String),
            visibility: be_a(String),
            owner: be_a(String),
            parameters: be_an(Array)
          ))
        end
      end

      context "when processing namespace hierarchies" do
        let(:nested_classes_data) do
          {
            classes: [
              {name: "API", type: "module"},
              {name: "API::V1", type: "module"},
              {name: "API::V1::UsersController", superclass: "ApplicationController"}
            ]
          }
        end

        it "builds correct namespace hierarchies" do
          result = normalizer.normalize(nested_classes_data)

          controller_class = result.classes.find { |c| c.name.include?("UsersController") }
          expect(controller_class.namespace_path).to eq(["API", "V1"])
        end

        it "creates parent-child relationships" do
          result = normalizer.normalize(nested_classes_data)

          api_module = result.modules.find { |m| m.fqname == "API" }
          expect(api_module.children).to include("API::V1")
        end
      end

      context "when handling duplicate symbols" do
        let(:duplicate_data) do
          {
            methods: [
              {name: "save", class: "User", visibility: :public, location: {line: 10}},
              {name: "save", class: "User", visibility: :public, location: {line: 20}},  # Duplicate
              {name: "save!", class: "User", visibility: :public, location: {line: 25}}   # Different method
            ]
          }
        end

        it "deduplicates identical symbols" do
          result = normalizer.normalize(duplicate_data)

          save_methods = result.methods.select { |m| m.name == "save" && m.owner == "User" }
          expect(save_methods.size).to eq(1)
        end

        it "preserves genuinely different symbols with same names" do
          result = normalizer.normalize(duplicate_data)

          user_methods = result.methods.select { |m| m.owner == "User" }
          method_names = user_methods.map(&:name)

          expect(method_names).to include("save", "save!")
        end
      end

      context "when resolving symbol references" do
        let(:reference_data) do
          {
            classes: [
              {name: "User", superclass: "ApplicationRecord"},
              {name: "ApplicationRecord", superclass: "ActiveRecord::Base"}
            ],
            method_calls: [
              {caller: "User#initialize", calls: "super"},
              {caller: "User#save", calls: "validate_email"}
            ]
          }
        end

        it "resolves inheritance chains" do
          result = normalizer.normalize(reference_data)

          user_class = result.classes.find { |c| c.fqname == "User" }
          expect(user_class.inheritance_chain).to eq(["User", "ApplicationRecord", "ActiveRecord::Base"])
        end

        it "resolves method call references" do
          result = normalizer.normalize(reference_data)

          expect(result.method_calls).to include(
            have_attributes(
              from: "User#save",
              to: "User#validate_email",
              type: "private_method_call"
            )
          )
        end
      end
    end

    describe "data validation" do
      context "when input data has missing required fields" do
        let(:invalid_data) do
          {
            classes: [
              {superclass: "Object"}  # Missing name
            ]
          }
        end

        it "adds validation errors for incomplete data" do
          result = normalizer.normalize(invalid_data)

          expect(result.errors).to include(
            have_attributes(type: "validation", message: match(/missing required field.*name/i))
          )
        end

        it "excludes invalid entries from normalized output" do
          result = normalizer.normalize(invalid_data)

          expect(result.classes).to be_empty
        end
      end

      context "when input data has inconsistent types" do
        let(:inconsistent_data) do
          {
            methods: [
              {name: "test", visibility: "public"},      # String visibility
              {name: "test2", visibility: :private},     # Symbol visibility
              {name: "test3", visibility: 42}            # Invalid visibility
            ]
          }
        end

        it "standardizes compatible type variations" do
          result = normalizer.normalize(inconsistent_data)

          normalized_methods = result.methods.select { |m| %w[test test2].include?(m.name) }
          expect(normalized_methods).to all(have_attributes(visibility: be_a(String)))
        end

        it "reports errors for incompatible types" do
          result = normalizer.normalize(inconsistent_data)

          expect(result.errors).to include(
            have_attributes(message: match(/invalid visibility.*42/i))
          )
        end
      end
    end

    describe "cross-reference resolution" do
      context "when building method ownership relationships" do
        let(:ownership_data) do
          {
            classes: [
              {name: "User"},
              {name: "AdminUser", superclass: "User"}
            ],
            methods: [
              {name: "save", owner: "User", scope: "instance"},
              {name: "admin?", owner: "AdminUser", scope: "instance"},
              {name: "find_admins", owner: "AdminUser", scope: "class"}
            ]
          }
        end

        it "correctly associates methods with their owner classes" do
          result = normalizer.normalize(ownership_data)

          user_class = result.classes.find { |c| c.fqname == "User" }
          admin_class = result.classes.find { |c| c.fqname == "AdminUser" }

          expect(user_class.instance_methods).to include("save")
          expect(admin_class.instance_methods).to include("admin?")
          expect(admin_class.class_methods).to include("find_admins")
        end

        it "builds complete method inheritance chains" do
          result = normalizer.normalize(ownership_data)

          admin_class = result.classes.find { |c| c.fqname == "AdminUser" }

          # AdminUser should have access to inherited methods from User
          expect(admin_class.available_instance_methods).to include("save", "admin?")
        end
      end

      context "when resolving module inclusion relationships" do
        let(:mixin_data) do
          {
            modules: [
              {name: "Comparable"},
              {name: "Searchable"}
            ],
            classes: [
              {name: "User", mixins: [{type: "include", module: "Comparable"}, {type: "include", module: "Searchable"}]}
            ],
            methods: [
              {name: "<=>", owner: "Comparable", scope: "instance"},
              {name: "search", owner: "Searchable", scope: "class"}
            ]
          }
        end

        it "resolves mixed-in methods correctly" do
          result = normalizer.normalize(mixin_data)

          user_class = result.classes.find { |c| c.fqname == "User" }
          expect(user_class.available_instance_methods).to include("<=>")
          expect(user_class.available_class_methods).to include("search")
        end

        it "tracks mixin sources for methods" do
          result = normalizer.normalize(mixin_data)

          spaceship_method = result.methods.find { |m| m.name == "<=>" && m.available_in.include?("User") }
          expect(spaceship_method.source).to eq("Comparable")
        end
      end
    end
  end

  describe "normalization rules" do
    describe "naming conventions" do
      context "when standardizing symbol names" do
        it "handles snake_case method names consistently" do
          data = {methods: [{name: "getUserName"}, {name: "get_user_name"}]}
          result = normalizer.normalize(data)

          # Both should be normalized to snake_case for Ruby conventions
          expect(result.methods.first.canonical_name).to eq("get_user_name")
        end

        it "preserves intentional naming patterns" do
          data = {methods: [{name: "to_s"}, {name: "[]"}, {name: "=="}]}
          result = normalizer.normalize(data)

          # Special Ruby method names should be preserved exactly
          method_names = result.methods.map(&:name)
          expect(method_names).to contain_exactly("to_s", "[]", "==")
        end
      end
    end

    describe "visibility inference" do
      context "when visibility is not explicitly specified" do
        let(:visibility_data) do
          {
            methods: [
              {name: "initialize", owner: "User"},    # Should default to public
              {name: "_internal_method", owner: "User"},  # Underscore suggests private
              {name: "attr_reader", owner: "User", scope: "class"}  # Class method, likely public
            ]
          }
        end

        it "applies Ruby visibility defaults" do
          result = normalizer.normalize(visibility_data)

          init_method = result.methods.find { |m| m.name == "initialize" }
          expect(init_method.visibility).to eq("public")
        end

        it "infers private visibility from naming conventions" do
          result = normalizer.normalize(visibility_data)

          internal_method = result.methods.find { |m| m.name == "_internal_method" }
          expect(internal_method.inferred_visibility).to eq("private")
        end
      end
    end
  end

  describe "performance and scalability" do
    context "when normalizing large datasets" do
      it "handles thousands of symbols efficiently" do
        # Should normalize 10,000+ symbols in under 1 second
        skip "Implementation pending"
      end

      it "uses memory efficiently during normalization" do
        skip "Implementation pending"
      end
    end

    context "when processing deeply nested namespaces" do
      it "handles complex namespace hierarchies without stack overflow" do
        skip "Implementation pending"
      end
    end
  end
end
