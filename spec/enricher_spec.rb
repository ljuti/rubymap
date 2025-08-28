# frozen_string_literal: true

RSpec.describe "Rubymap::Enricher" do
  let(:enricher) { Rubymap::Enricher.new }

  describe "metrics calculation" do
    describe "#enrich" do
      context "when calculating code complexity metrics" do
        let(:normalized_data) do
          {
            methods: [
              {
                name: "simple_method",
                owner: "User",
                body_lines: 3,
                branches: 0,
                loops: 0
              },
              {
                name: "complex_method",
                owner: "User",
                body_lines: 25,
                branches: 5,
                loops: 2,
                conditionals: ["if", "case", "unless"]
              }
            ]
          }
        end

        it "calculates cyclomatic complexity for methods" do
          # Given: Normalized method data with control flow information
          # When: Enriching with complexity metrics
          # Then: Methods should have cyclomatic complexity scores
          result = enricher.enrich(normalized_data)

          simple_method = result.methods.find { |m| m.name == "simple_method" }
          complex_method = result.methods.find { |m| m.name == "complex_method" }

          expect(simple_method.cyclomatic_complexity).to eq(1)  # Base complexity
          expect(complex_method.cyclomatic_complexity).to be > 5  # Multiple branches add complexity
        end

        it "assigns complexity categories" do
          result = enricher.enrich(normalized_data)

          simple_method = result.methods.find { |m| m.name == "simple_method" }
          complex_method = result.methods.find { |m| m.name == "complex_method" }

          expect(simple_method.complexity_category).to eq("simple")
          expect(complex_method.complexity_category).to eq("complex")
        end

        it "calculates method length metrics" do
          result = enricher.enrich(normalized_data)

          simple_method = result.methods.find { |m| m.name == "simple_method" }
          expect(simple_method.lines_of_code).to eq(3)
        end
      end

      context "when calculating dependency metrics" do
        let(:dependency_data) do
          {
            classes: [
              {name: "User", dependencies: ["ApplicationRecord", "Validator", "Mailer"]},
              {name: "ApplicationRecord", dependencies: ["ActiveRecord::Base"]},
              {name: "Validator", dependencies: []}
            ],
            method_calls: [
              {from: "User#save", to: "User#validate"},
              {from: "User#validate", to: "Validator.validate_email"},
              {from: "OrderController#create", to: "User#save"}
            ]
          }
        end

        it "calculates fan-in and fan-out metrics" do
          result = enricher.enrich(dependency_data)

          user_class = result.classes.find { |c| c.name == "User" }

          expect(user_class.fan_out).to eq(3)  # User depends on 3 other classes
          expect(user_class.fan_in).to eq(1)   # 1 other class depends on User
        end

        it "calculates coupling strength" do
          result = enricher.enrich(dependency_data)

          user_class = result.classes.find { |c| c.name == "User" }
          expect(user_class.coupling_strength).to be_a(Float)
          expect(user_class.coupling_strength).to be > 0
        end

        it "identifies tightly coupled components" do
          result = enricher.enrich(dependency_data)

          expect(result.coupling_hotspots).to include(
            have_attributes(class: "User", reason: "high_fan_out")
          )
        end
      end

      context "when calculating inheritance depth metrics" do
        let(:inheritance_data) do
          {
            classes: [
              {name: "Object", superclass: nil, inheritance_chain: ["Object"]},
              {name: "ApplicationRecord", superclass: "ActiveRecord::Base", inheritance_chain: ["ApplicationRecord", "ActiveRecord::Base", "Object"]},
              {name: "User", superclass: "ApplicationRecord", inheritance_chain: ["User", "ApplicationRecord", "ActiveRecord::Base", "Object"]},
              {name: "AdminUser", superclass: "User", inheritance_chain: ["AdminUser", "User", "ApplicationRecord", "ActiveRecord::Base", "Object"]}
            ]
          }
        end

        it "calculates inheritance depth for each class" do
          result = enricher.enrich(inheritance_data)

          object_class = result.classes.find { |c| c.name == "Object" }
          user_class = result.classes.find { |c| c.name == "User" }
          admin_class = result.classes.find { |c| c.name == "AdminUser" }

          expect(object_class.inheritance_depth).to eq(0)
          expect(user_class.inheritance_depth).to eq(3)
          expect(admin_class.inheritance_depth).to eq(4)
        end

        it "identifies deep inheritance hierarchies" do
          result = enricher.enrich(inheritance_data)

          deep_hierarchies = result.design_issues.select { |issue| issue.type == "deep_inheritance" }
          expect(deep_hierarchies).to include(
            have_attributes(class: "AdminUser", depth: 4)
          )
        end
      end

      context "when analyzing public API surface" do
        let(:api_data) do
          {
            classes: [
              {
                name: "User",
                instance_methods: ["save", "update", "destroy", "find"],
                class_methods: ["create", "find_by_email"],
                visibility: {"save" => "public", "update" => "public", "destroy" => "public", "find" => "private"}
              }
            ],
            modules: [
              {
                name: "Searchable",
                instance_methods: ["search", "filter"],
                visibility: {"search" => "public", "filter" => "public"}
              }
            ]
          }
        end

        it "calculates public API surface area" do
          result = enricher.enrich(api_data)

          user_class = result.classes.find { |c| c.name == "User" }
          expect(user_class.public_api_surface).to eq(5)  # 3 public instance + 2 class methods
        end

        it "identifies classes with large public APIs" do
          result = enricher.enrich(api_data)

          large_apis = result.design_issues.select { |issue| issue.type == "large_public_api" }
          expect(large_apis).to include(
            have_attributes(class: "User", api_size: 5)
          )
        end
      end
    end

    describe "code quality heuristics" do
      context "when analyzing test coverage" do
        let(:coverage_data) do
          {
            methods: [
              {name: "well_tested_method", owner: "User", test_coverage: 95.0},
              {name: "untested_method", owner: "User", test_coverage: 0.0},
              {name: "partially_tested_method", owner: "User", test_coverage: 60.0}
            ]
          }
        end

        it "categorizes methods by test coverage" do
          result = enricher.enrich(coverage_data)

          well_tested = result.methods.find { |m| m.name == "well_tested_method" }
          untested = result.methods.find { |m| m.name == "untested_method" }

          expect(well_tested.coverage_category).to eq("well_covered")
          expect(untested.coverage_category).to eq("untested")
        end

        it "identifies testing gaps" do
          result = enricher.enrich(coverage_data)

          expect(result.quality_issues).to include(
            have_attributes(type: "low_test_coverage", method: "untested_method")
          )
        end
      end

      context "when analyzing git churn data" do
        let(:churn_data) do
          {
            classes: [
              {name: "StableClass", file: "lib/stable.rb", git_commits: 3, last_modified: Time.now - (6 * 30 * 24 * 60 * 60)},
              {name: "ChurnClass", file: "app/models/churn.rb", git_commits: 47, last_modified: Time.now - (2 * 24 * 60 * 60)}
            ]
          }
        end

        it "calculates churn metrics" do
          result = enricher.enrich(churn_data)

          stable_class = result.classes.find { |c| c.name == "StableClass" }
          churn_class = result.classes.find { |c| c.name == "ChurnClass" }

          expect(stable_class.churn_score).to be < churn_class.churn_score
        end

        it "identifies hotspot classes" do
          result = enricher.enrich(churn_data)

          hotspots = result.hotspots.select { |h| h.type == "high_churn" }
          expect(hotspots).to include(
            have_attributes(class: "ChurnClass", commits: 47)
          )
        end
      end

      context "when calculating stability scores" do
        let(:stability_data) do
          {
            classes: [
              {
                name: "MatureClass",
                age_in_days: 365,
                test_coverage: 90.0,
                documentation_coverage: 85.0,
                churn_score: 0.1
              },
              {
                name: "NewClass",
                age_in_days: 7,
                test_coverage: 20.0,
                documentation_coverage: 10.0,
                churn_score: 0.8
              }
            ]
          }
        end

        it "calculates composite stability scores" do
          result = enricher.enrich(stability_data)

          mature_class = result.classes.find { |c| c.name == "MatureClass" }
          new_class = result.classes.find { |c| c.name == "NewClass" }

          expect(mature_class.stability_score).to be > new_class.stability_score
        end

        it "identifies stable vs unstable components" do
          result = enricher.enrich(stability_data)

          expect(result.stability_analysis.stable_classes).to include("MatureClass")
          expect(result.stability_analysis.unstable_classes).to include("NewClass")
        end
      end
    end

    describe "pattern detection" do
      context "when detecting design patterns" do
        let(:pattern_data) do
          {
            classes: [
              {
                name: "UserFactory",
                methods: ["create", "build", "create_with_defaults"],
                superclass: nil
              },
              {
                name: "DatabaseConnection",
                methods: ["instance", "new"],
                visibility: {"new" => "private"},
                class_methods: ["instance"]
              },
              {
                name: "EmailObserver",
                methods: ["update", "notify"],
                implements: ["Observer"]
              }
            ]
          }
        end

        it "detects factory patterns" do
          result = enricher.enrich(pattern_data)

          expect(result.design_patterns).to include(
            have_attributes(
              pattern: "Factory",
              class: "UserFactory",
              confidence: be > 0.8
            )
          )
        end

        it "detects singleton patterns" do
          result = enricher.enrich(pattern_data)

          expect(result.design_patterns).to include(
            have_attributes(
              pattern: "Singleton",
              class: "DatabaseConnection"
            )
          )
        end

        it "detects observer patterns" do
          result = enricher.enrich(pattern_data)

          expect(result.design_patterns).to include(
            have_attributes(
              pattern: "Observer",
              class: "EmailObserver"
            )
          )
        end
      end

      context "when detecting Ruby idioms" do
        let(:idiom_data) do
          {
            methods: [
              {name: "to_s", owner: "User", implements_protocol: "String conversion"},
              {name: "each", owner: "Collection", yields: true, implements_protocol: "Enumerable"},
              {name: "[]", owner: "HashLike", parameters: ["key"], implements_protocol: "Hash-like access"}
            ]
          }
        end

        it "identifies Ruby protocol implementations" do
          result = enricher.enrich(idiom_data)

          expect(result.ruby_idioms).to include(
            have_attributes(idiom: "String conversion protocol", class: "User"),
            have_attributes(idiom: "Enumerable protocol", class: "Collection"),
            have_attributes(idiom: "Hash-like access protocol", class: "HashLike")
          )
        end
      end
    end
  end

  describe "Rails-specific enrichment" do
    context "when analyzing ActiveRecord models" do
      let(:activerecord_data) do
        {
          classes: [
            {
              name: "User",
              superclass: "ApplicationRecord",
              associations: [
                {type: "has_many", name: "posts", class: "Post"},
                {type: "belongs_to", name: "organization", class: "Organization"}
              ],
              validations: [
                {attribute: "email", type: "presence"},
                {attribute: "email", type: "uniqueness"}
              ],
              scopes: ["active", "recent", "with_posts"]
            }
          ]
        }
      end

      it "enriches with ActiveRecord-specific metrics" do
        result = enricher.enrich(activerecord_data)

        user_class = result.classes.find { |c| c.name == "User" }

        expect(user_class.activerecord_metrics).to have_attributes(
          associations_count: 2,
          validations_count: 2,
          scopes_count: 3
        )
      end

      it "analyzes model complexity" do
        result = enricher.enrich(activerecord_data)

        user_class = result.classes.find { |c| c.name == "User" }
        expect(user_class.model_complexity_score).to be_a(Float)
      end
    end

    context "when analyzing controllers" do
      let(:controller_data) do
        {
          classes: [
            {
              name: "UsersController",
              superclass: "ApplicationController",
              actions: ["index", "show", "create", "update", "destroy"],
              filters: ["authenticate_user!", "authorize_user"],
              rescue_handlers: ["ActiveRecord::RecordNotFound"]
            }
          ]
        }
      end

      it "calculates controller complexity" do
        result = enricher.enrich(controller_data)

        controller = result.classes.find { |c| c.name == "UsersController" }

        expect(controller.controller_metrics).to have_attributes(
          actions_count: 5,
          filters_count: 2,
          rescue_handlers_count: 1
        )
      end
    end
  end

  describe "performance and scalability" do
    context "when enriching large codebases" do
      it "processes thousands of classes efficiently" do
        # Generate a large dataset
        large_data = {
          classes: 1000.times.map do |i|
            {
              name: "Class#{i}",
              superclass: (i > 0) ? "Class#{i - 1}" : nil,
              instance_methods: %w[method1 method2 method3],
              dependencies: ["Dependency#{i}"]
            }
          end,
          methods: 3000.times.map do |i|
            {
              name: "method#{i}",
              owner: "Class#{i / 3}",
              body_lines: rand(1..50),
              branches: rand(0..5)
            }
          end
        }

        start_time = Time.now
        result = enricher.enrich(large_data)
        elapsed_time = Time.now - start_time

        expect(result.classes.size).to eq(1000)
        expect(result.methods.size).to eq(3000)
        expect(elapsed_time).to be < 5.0  # Should complete within 5 seconds
      end

      it "uses memory efficiently during enrichment" do
        # Generate moderate dataset
        data = {
          classes: 100.times.map do |i|
            {name: "Class#{i}", superclass: "BaseClass"}
          end,
          methods: 500.times.map do |i|
            {name: "method#{i}", owner: "Class#{i / 5}"}
          end
        }

        # Measure memory before
        GC.start
        memory_before = `ps -o rss= -p #{Process.pid}`.to_i

        # Enrich the data
        result = enricher.enrich(data)

        # Measure memory after
        GC.start
        memory_after = `ps -o rss= -p #{Process.pid}`.to_i

        # Memory increase should be reasonable (less than 100MB for this dataset)
        memory_increase_mb = (memory_after - memory_before) / 1024.0

        expect(result.classes.size).to eq(100)
        expect(memory_increase_mb).to be < 100
      end
    end

    context "when calculating complex metrics" do
      it "handles deeply recursive analysis without stack overflow" do
        # Create a deeply nested inheritance chain
        deep_data = {
          classes: 100.times.map do |i|
            {
              name: "DeepClass#{i}",
              superclass: (i > 0) ? "DeepClass#{i - 1}" : nil,
              inheritance_chain: (0..i).map { |j| "DeepClass#{j}" }
            }
          end,
          method_calls: 200.times.map do |i|
            {
              from: "DeepClass#{i % 100}#method",
              to: "DeepClass#{(i + 1) % 100}#method"
            }
          end
        }

        # This should not raise a stack overflow
        expect { enricher.enrich(deep_data) }.not_to raise_error

        result = enricher.enrich(deep_data)

        # Verify deep inheritance was calculated correctly
        deepest_class = result.classes.find { |c| c.name == "DeepClass99" }
        expect(deepest_class.inheritance_depth).to eq(100)  # 100 classes in chain (0-99)
      end
    end
  end
end
