# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer, type: :integration do
  subject(:normalizer) { described_class.new }

  describe "complete normalization workflow behavior" do
    context "when processing a realistic Ruby application codebase" do
      let(:complex_raw_data) do
        {
          classes: [
            {
              name: "User",
              type: "class",
              namespace: "App::Models",
              superclass: "ApplicationRecord",
              location: { file: "app/models/user.rb", line: 1 },
              source: "static",
              mixins: [
                { type: "include", module: "Searchable" },
                { type: "extend", module: "ClassMethods" }
              ]
            },
            {
              name: "User",  # Duplicate with different source
              type: "class", 
              namespace: "App::Models",
              superclass: "ApplicationRecord",
              location: { file: "app/models/user.rb", line: 1 },
              source: "runtime"
            },
            {
              name: "Admin",
              type: "class",
              namespace: "App::Models",
              superclass: "User",
              location: { file: "app/models/admin.rb", line: 1 },
              source: "static"
            }
          ],
          modules: [
            {
              name: "Searchable",
              type: "module",
              namespace: "App::Concerns",
              location: { file: "app/models/concerns/searchable.rb", line: 1 },
              source: "static"
            },
            {
              name: "ClassMethods",
              type: "module",
              namespace: "App::Models::User",
              location: { file: "app/models/user.rb", line: 15 },
              source: "static"
            }
          ],
          methods: [
            {
              name: "find_by_email",
              class: "App::Models::User",
              owner: "App::Models::User",
              scope: "class",
              visibility: "public",
              parameters: [
                { name: "email", type: "required" }
              ],
              source: "static",
              location: { file: "app/models/user.rb", line: 25 }
            },
            {
              name: "find_by_email",  # Duplicate with runtime source
              class: "App::Models::User",
              owner: "App::Models::User",
              scope: "class",
              visibility: "public",
              parameters: [
                { name: "email", type: "required" }
              ],
              source: "runtime"
            },
            {
              name: "full_name",
              class: "App::Models::User",
              owner: "App::Models::User",
              scope: "instance",
              visibility: "public",
              parameters: [],
              source: "static"
            },
            {
              name: "_encrypt_password",
              class: "App::Models::User",
              owner: "App::Models::User",
              scope: "instance",
              visibility: "private",
              parameters: [
                { name: "password", type: "required" }
              ],
              source: "static"
            }
          ],
          method_calls: [
            {
              from: "App::Controllers::UsersController#create",
              to: "App::Models::User.find_by_email",
              type: "method_call"
            },
            {
              from: "App::Controllers::UsersController#show",
              to: "App::Models::User#full_name",
              type: "method_call"
            }
          ],
          mixins: [
            {
              type: "include",
              module: "App::Concerns::Searchable",
              target: "App::Models::User"
            }
          ]
        }
      end

      it "processes all symbol types and returns complete normalized result" do
        result = normalizer.normalize(complex_raw_data)
        
        expect(result).to be_a(Rubymap::Normalizer::NormalizedResult)
        expect(result.schema_version).to eq(1)
        expect(result.normalizer_version).to eq("1.0.0")
        expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "deduplicates classes from multiple sources correctly" do
        result = normalizer.normalize(complex_raw_data)
        
        user_classes = result.classes.select { |c| c.name == "User" }
        expect(user_classes.size).to eq(1)
        
        user_class = user_classes.first
        expect(user_class.fqname).to eq("App::Models::User")
        expect(user_class.superclass).to eq("ApplicationRecord")
        expect(user_class.mixins.size).to eq(2)
        expect(user_class.provenance.sources).to include("static", "runtime")
      end

      it "deduplicates methods from multiple sources correctly" do
        result = normalizer.normalize(complex_raw_data)
        
        find_by_email_methods = result.methods.select { |m| m.name == "find_by_email" }
        expect(find_by_email_methods.size).to eq(1)
        
        method = find_by_email_methods.first
        expect(method.fqname).to eq("App::Models::User.find_by_email")
        expect(method.scope).to eq("class")
        expect(method.arity).to eq(1)
        expect(method.provenance.sources).to include("static", "runtime")
        expect(method.provenance.confidence).to be > 0.75  # Should have high confidence
      end

      it "processes all method types with correct visibility inference" do
        result = normalizer.normalize(complex_raw_data)
        
        private_method = result.methods.find { |m| m.name == "_encrypt_password" }
        expect(private_method).not_to be_nil
        expect(private_method.visibility).to eq("private")
        expect(private_method.inferred_visibility).to eq("private")
        expect(private_method.scope).to eq("instance")
        
        public_method = result.methods.find { |m| m.name == "full_name" }
        expect(public_method).not_to be_nil
        expect(public_method.visibility).to eq("public")
        expect(public_method.inferred_visibility).to eq("public")
      end

      it "processes modules with correct namespace resolution" do
        result = normalizer.normalize(complex_raw_data)
        
        searchable_module = result.modules.find { |m| m.name == "Searchable" }
        expect(searchable_module).not_to be_nil
        expect(searchable_module.fqname).to eq("App::Concerns::Searchable")
        expect(searchable_module.namespace_path).to eq(["App", "Concerns"])
        
        class_methods_module = result.modules.find { |m| m.name == "ClassMethods" }
        expect(class_methods_module).not_to be_nil
        expect(class_methods_module.fqname).to eq("App::Models::User::ClassMethods")
        expect(class_methods_module.namespace_path).to eq(["App", "Models", "User"])
      end

      it "processes method calls and maintains referential integrity" do
        result = normalizer.normalize(complex_raw_data)
        
        expect(result.method_calls.size).to eq(2)
        
        create_call = result.method_calls.find { |c| c.from.include?("create") }
        expect(create_call).not_to be_nil
        expect(create_call.from).to eq("App::Controllers::UsersController#create")
        expect(create_call.to).to eq("App::Models::User.find_by_email")
        expect(create_call.type).to eq("method_call")
      end

      it "applies confidence calculations based on source and completeness" do
        result = normalizer.normalize(complex_raw_data)
        
        # Methods with location should have boosted confidence
        method_with_location = result.methods.find { |m| m.name == "find_by_email" }
        expect(method_with_location.provenance.confidence).to be >= 0.80
        
        # Classes with complete information should have high confidence
        user_class = result.classes.find { |c| c.name == "User" }
        expect(user_class.provenance.confidence).to be >= 0.80
      end

      it "generates deterministic symbol IDs for identical symbols" do
        result1 = normalizer.normalize(complex_raw_data)
        result2 = normalizer.normalize(complex_raw_data)
        
        user_class_1 = result1.classes.find { |c| c.name == "User" }
        user_class_2 = result2.classes.find { |c| c.name == "User" }
        expect(user_class_1.symbol_id).to eq(user_class_2.symbol_id)
        
        method_1 = result1.methods.find { |m| m.name == "find_by_email" }
        method_2 = result2.methods.find { |m| m.name == "find_by_email" }
        expect(method_1.symbol_id).to eq(method_2.symbol_id)
      end

      it "maintains data integrity across all processing stages" do
        result = normalizer.normalize(complex_raw_data)
        
        # No data should be lost during processing
        expect(result.classes.size).to be >= 2  # At least User and Admin after deduplication
        expect(result.modules.size).to eq(2)    # Searchable and ClassMethods
        expect(result.methods.size).to be >= 3  # At least 3 unique methods after deduplication
        expect(result.method_calls.size).to eq(2)
        
        # All processed symbols should have required fields
        result.classes.each do |klass|
          expect(klass.symbol_id).not_to be_nil
          expect(klass.name).not_to be_nil
          expect(klass.fqname).not_to be_nil
          expect(klass.provenance).not_to be_nil
        end
        
        result.methods.each do |method|
          expect(method.symbol_id).not_to be_nil
          expect(method.name).not_to be_nil
          expect(method.fqname).not_to be_nil
          expect(method.visibility).not_to be_nil
          expect(method.provenance).not_to be_nil
        end
      end
    end

    context "when processing edge cases and error conditions" do
      let(:problematic_data) do
        {
          classes: [
            { name: nil, type: "class" },  # Invalid - no name
            { name: "", type: "class" },   # Edge case - empty name
            { name: "ValidClass", type: "class", namespace: "App" }  # Valid
          ],
          modules: [
            { name: nil },  # Invalid - no name
            { name: "ValidModule", namespace: "App" }  # Valid
          ],
          methods: [
            { name: nil, class: "TestClass" },  # Invalid - no name
            { name: "valid_method", class: "TestClass", parameters: "malformed" },  # Edge case
            { name: "another_method", scope: "unknown", visibility: "invalid" }  # Edge case
          ]
        }
      end

      it "handles validation errors gracefully and continues processing" do
        result = normalizer.normalize(problematic_data)
        
        expect(result.errors).not_to be_empty
        
        # Should have validation errors for nil names
        name_errors = result.errors.select { |e| e.message.include?("missing required field: name") }
        expect(name_errors.size).to be >= 3  # At least 3 nil name errors
        
        # Should still process valid symbols
        expect(result.classes.size).to be >= 1  # ValidClass should be processed
        expect(result.modules.size).to be >= 1  # ValidModule should be processed
        expect(result.methods.size).to be >= 1  # At least one method should be processed
      end

      it "applies default values for missing optional fields" do
        minimal_data = {
          classes: [{ name: "MinimalClass" }],
          methods: [{ name: "minimal_method" }]
        }
        
        result = normalizer.normalize(minimal_data)
        
        klass = result.classes.first
        expect(klass.kind).to eq("class")
        expect(klass.superclass).to be_nil
        expect(klass.namespace_path).to eq([])
        expect(klass.children).to eq([])
        expect(klass.mixins).to eq([])
        
        method = result.methods.first
        expect(method.scope).to eq("instance")
        expect(method.visibility).to eq("public")
        expect(method.parameters).to eq([])
        expect(method.arity).to eq(0)
      end

      it "handles completely empty input gracefully" do
        result = normalizer.normalize({})
        
        expect(result.classes).to be_empty
        expect(result.modules).to be_empty
        expect(result.methods).to be_empty
        expect(result.method_calls).to be_empty
        expect(result.errors).to be_empty
        
        expect(result.schema_version).to eq(1)
        expect(result.normalizer_version).to eq("1.0.0")
        expect(result.normalized_at).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/)
      end

      it "maintains state isolation between normalization runs" do
        first_result = normalizer.normalize({ classes: [{ name: "FirstClass" }] })
        second_result = normalizer.normalize({ classes: [{ name: "SecondClass" }] })
        
        expect(first_result.classes.size).to eq(1)
        expect(first_result.classes.first.name).to eq("FirstClass")
        
        expect(second_result.classes.size).to eq(1)
        expect(second_result.classes.first.name).to eq("SecondClass")
        
        # Results should not contaminate each other
        expect(second_result.classes).not_to include(first_result.classes.first)
      end
    end

    context "when processing complex duplication and merging scenarios" do
      let(:duplication_heavy_data) do
        {
          classes: [
            { name: "DuplicatedClass", source: "static", superclass: nil },
            { name: "DuplicatedClass", source: "runtime", superclass: "BaseClass" },
            { name: "DuplicatedClass", source: "yard", superclass: "OtherClass" },
            { name: "DuplicatedClass", source: "rbs", superclass: "BaseClass" }
          ],
          methods: [
            { name: "duplicated_method", class: "Test", visibility: "public", source: "static" },
            { name: "duplicated_method", class: "Test", visibility: "private", source: "runtime" },
            { name: "duplicated_method", class: "Test", visibility: "protected", source: "yard" }
          ]
        }
      end

      it "applies source precedence rules correctly during deduplication" do
        result = normalizer.normalize(duplication_heavy_data)
        
        # Should have only one class after deduplication
        expect(result.classes.size).to eq(1)
        duplicated_class = result.classes.first
        
        # Should select superclass from highest precedence source (RBS > runtime > static > YARD)
        expect(duplicated_class.superclass).to eq("BaseClass")  # From RBS source
        
        # Should merge provenance from all sources
        expect(duplicated_class.provenance.sources).to include("static", "runtime", "yard", "rbs")
      end

      it "applies visibility precedence rules during method merging" do
        result = normalizer.normalize(duplication_heavy_data)
        
        # Should have only one method after deduplication
        expect(result.methods.size).to eq(1)
        duplicated_method = result.methods.first
        
        # Should select most restrictive visibility (private > protected > public)
        expect(duplicated_method.visibility).to eq("private")
        
        # Should merge provenance from all sources
        expect(duplicated_method.provenance.sources).to include("static", "runtime", "yard")
      end

      it "maintains deterministic ordering in output" do
        result1 = normalizer.normalize(duplication_heavy_data)
        result2 = normalizer.normalize(duplication_heavy_data)
        
        # Results should be identical across runs
        expect(result1.classes.map(&:symbol_id)).to eq(result2.classes.map(&:symbol_id))
        expect(result1.methods.map(&:symbol_id)).to eq(result2.methods.map(&:symbol_id))
      end
    end

    context "when processing real-world Rails application patterns" do
      let(:rails_application_data) do
        {
          classes: [
            {
              name: "ApplicationRecord",
              type: "class",
              namespace: "App::Models",
              superclass: "ActiveRecord::Base",
              source: "static"
            },
            {
              name: "User",
              type: "class",
              namespace: "App::Models",
              superclass: "ApplicationRecord",
              source: "static",
              mixins: [
                { type: "include", module: "Devise::DatabaseAuthenticatable" },
                { type: "include", module: "App::Concerns::Searchable" },
                { type: "extend", module: "FriendlyId" }
              ]
            },
            {
              name: "UsersController",
              type: "class", 
              namespace: "App::Controllers",
              superclass: "ApplicationController",
              source: "static"
            }
          ],
          methods: [
            # ActiveRecord methods
            { name: "find", class: "App::Models::User", scope: "class", source: "runtime" },
            { name: "where", class: "App::Models::User", scope: "class", source: "runtime" },
            { name: "save", class: "App::Models::User", scope: "instance", source: "runtime" },
            
            # Controller actions
            { name: "index", class: "App::Controllers::UsersController", scope: "instance", visibility: "public", source: "static" },
            { name: "show", class: "App::Controllers::UsersController", scope: "instance", visibility: "public", source: "static" },
            { name: "create", class: "App::Controllers::UsersController", scope: "instance", visibility: "public", source: "static" },
            
            # Private controller methods
            { name: "user_params", class: "App::Controllers::UsersController", scope: "instance", visibility: "private", source: "static" },
            { name: "set_user", class: "App::Controllers::UsersController", scope: "instance", visibility: "private", source: "static" }
          ],
          method_calls: [
            { from: "App::Controllers::UsersController#index", to: "App::Models::User.where", type: "method_call" },
            { from: "App::Controllers::UsersController#show", to: "App::Models::User.find", type: "method_call" },
            { from: "App::Controllers::UsersController#create", to: "App::Models::User#save", type: "method_call" }
          ]
        }
      end

      it "processes Rails inheritance patterns correctly" do
        result = normalizer.normalize(rails_application_data)
        
        application_record = result.classes.find { |c| c.name == "ApplicationRecord" }
        expect(application_record.superclass).to eq("ActiveRecord::Base")
        
        user_model = result.classes.find { |c| c.name == "User" }
        expect(user_model.superclass).to eq("ApplicationRecord")
        
        controller = result.classes.find { |c| c.name == "UsersController" }
        expect(controller.superclass).to eq("ApplicationController")
      end

      it "processes Rails mixin patterns correctly" do
        result = normalizer.normalize(rails_application_data)
        
        user_model = result.classes.find { |c| c.name == "User" }
        expect(user_model.mixins.size).to eq(3)
        
        devise_mixin = user_model.mixins.find { |m| m[:module] == "Devise::DatabaseAuthenticatable" }
        expect(devise_mixin[:type]).to eq("include")
        
        friendly_id_mixin = user_model.mixins.find { |m| m[:module] == "FriendlyId" }
        expect(friendly_id_mixin[:type]).to eq("extend")
      end

      it "processes Rails method patterns with correct scoping" do
        result = normalizer.normalize(rails_application_data)
        
        class_methods = result.methods.select { |m| m.scope == "class" }
        instance_methods = result.methods.select { |m| m.scope == "instance" }
        
        expect(class_methods.map(&:name)).to include("find", "where")
        expect(instance_methods.map(&:name)).to include("save", "index", "show", "create", "user_params", "set_user")
        
        # Controller actions should be public
        public_actions = result.methods.select { |m| m.owner&.include?("UsersController") && m.visibility == "public" }
        expect(public_actions.map(&:name)).to include("index", "show", "create")
        
        # Helper methods should be private
        private_methods = result.methods.select { |m| m.owner&.include?("UsersController") && m.visibility == "private" }
        expect(private_methods.map(&:name)).to include("user_params", "set_user")
      end

      it "maintains method call relationships for Rails patterns" do
        result = normalizer.normalize(rails_application_data)
        
        # Controller should call model methods
        model_calls = result.method_calls.select { |c| c.to.include?("Models") }
        expect(model_calls.size).to eq(3)
        
        # Different call types (class vs instance)
        class_method_calls = result.method_calls.select { |c| c.to.include?(".") }
        instance_method_calls = result.method_calls.select { |c| c.to.include?("#") }
        
        expect(class_method_calls.size).to eq(2)  # .where and .find
        expect(instance_method_calls.size).to eq(1)  # #save
      end
    end
  end

  describe "performance and scalability behavior" do
    context "when processing large datasets", :performance do
      let(:large_dataset) do
        {
          classes: (1..100).map do |i|
            {
              name: "Class#{i}",
              type: "class",
              namespace: "App::Models",
              source: ["static", "runtime", "yard"].sample
            }
          end,
          methods: (1..500).map do |i|
            {
              name: "method_#{i}",
              class: "Class#{rand(1..100)}",
              scope: ["instance", "class"].sample,
              visibility: ["public", "private", "protected"].sample,
              parameters: (1..rand(5)).map { |j| { name: "param#{j}", type: "required" } },
              source: ["static", "runtime", "yard"].sample
            }
          end
        }
      end

      it "processes large datasets efficiently" do
        expect_performance_within(5.0) do  # Should complete within 5 seconds
          result = normalizer.normalize(large_dataset)
          
          expect(result.classes.size).to be <= 100  # May have some duplicates
          expect(result.methods.size).to be <= 500  # May have some duplicates
          expect(result.errors.size).to be >= 0     # May have some validation errors
        end
      end

      it "maintains memory efficiency during processing" do
        initial_memory = `ps -o rss= -p #{Process.pid}`.to_i
        
        result = normalizer.normalize(large_dataset)
        
        final_memory = `ps -o rss= -p #{Process.pid}`.to_i
        memory_increase = final_memory - initial_memory
        
        # Memory increase should be reasonable (less than 50MB for this dataset)
        expect(memory_increase).to be < 50_000  # 50MB in KB
      end
    end

    context "when processing deeply nested namespaces" do
      let(:nested_data) do
        {
          classes: (1..10).map do |i|
            {
              name: "Class#{i}",
              type: "class",
              namespace: "Level1::Level2::Level3::Level4::Level5",
              source: "static"
            }
          end
        }
      end

      it "handles deep namespace hierarchies correctly" do
        result = normalizer.normalize(nested_data)
        
        result.classes.each do |klass|
          expect(klass.fqname).to start_with("Level1::Level2::Level3::Level4::Level5::")
          expect(klass.namespace_path).to eq(["Level1", "Level2", "Level3", "Level4", "Level5"])
        end
      end
    end
  end
end