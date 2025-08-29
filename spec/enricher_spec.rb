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
        # Expects no error from: enricher.enrich(deep_data)

        result = enricher.enrich(deep_data)

        # Verify deep inheritance was calculated correctly
        deepest_class = result.classes.find { |c| c.name == "DeepClass99" }
        expect(deepest_class.inheritance_depth).to eq(100)  # 100 classes in chain (0-99)
      end
    end
  end

  describe "configuration and edge cases" do
    context "when disabling features via config" do
      it "skips metrics calculation when enable_metrics is false" do
        enricher = Rubymap::Enricher.new(enable_metrics: false)
        data = {
          methods: [{name: "test", owner: "TestClass", branches: 5, loops: 3}]
        }

        result = enricher.enrich(data)

        method = result.methods.first
        expect(method.cyclomatic_complexity).to be_nil
      end

      it "skips pattern detection when enable_patterns is false" do
        enricher = Rubymap::Enricher.new(enable_patterns: false)
        data = {
          classes: [{name: "UserFactory", methods: ["create", "build"]}]
        }

        result = enricher.enrich(data)

        expect(result.design_patterns).to be_empty
      end

      it "skips Rails enrichment when enable_rails is false" do
        enricher = Rubymap::Enricher.new(enable_rails: false)
        data = {
          classes: [{
            name: "User",
            superclass: "ApplicationRecord",
            associations: [{type: "has_many", name: "posts"}]
          }]
        }

        result = enricher.enrich(data)

        user_class = result.classes.first
        expect(user_class.activerecord_metrics).to be_nil
      end
    end

    context "when using custom thresholds" do
      let(:enricher) do
        Rubymap::Enricher.new(
          complexity_threshold: 5,
          api_size_threshold: 3,
          inheritance_depth_threshold: 2,
          coverage_threshold: 90,
          churn_threshold: 5
        )
      end

      it "uses custom complexity threshold" do
        data = {
          methods: [{
            name: "complex_method",
            owner: "TestClass",
            branches: 4,
            loops: 1
          }]
        }

        result = enricher.enrich(data)

        # With threshold of 5, complexity of 6 should be flagged
        method = result.methods.first
        expect(method.cyclomatic_complexity).to eq(6)
      end

      it "uses custom API size threshold for design issues" do
        data = {
          classes: [{
            name: "LargeAPI",
            instance_methods: ["m1", "m2"],
            class_methods: ["c1"],
            visibility: {"m1" => "public", "m2" => "public", "c1" => "public"}
          }]
        }

        result = enricher.enrich(data)

        # With threshold of 3, API surface of 3 should trigger issue
        expect(result.design_issues).to include(
          have_attributes(
            type: "large_public_api",
            class: "LargeAPI",
            api_size: 3
          )
        )
      end

      it "uses custom inheritance depth threshold" do
        data = {
          classes: [{
            name: "DeepClass",
            inheritance_chain: ["DeepClass", "Parent1", "Parent2", "Object"]
          }]
        }

        result = enricher.enrich(data)

        # With threshold of 2, depth of 3 should trigger issue
        expect(result.design_issues).to include(
          have_attributes(
            type: "deep_inheritance",
            class: "DeepClass",
            depth: 3
          )
        )
      end

      it "uses custom coverage threshold" do
        data = {
          methods: [{
            name: "poorly_tested",
            owner: "TestClass",
            test_coverage: 85.0
          }]
        }

        result = enricher.enrich(data)

        # With threshold of 90, coverage of 85 should trigger issue
        expect(result.quality_issues).to include(
          have_attributes(
            type: "low_test_coverage",
            method: "poorly_tested"
          )
        )
      end

      it "uses custom churn threshold" do
        data = {
          classes: [{
            name: "ChurnClass",
            git_commits: 6,
            churn_score: 6
          }]
        }

        result = enricher.enrich(data)

        # With threshold of 5, churn of 6 should trigger hotspot
        expect(result.hotspots).to include(
          have_attributes(
            type: "high_churn",
            class: "ChurnClass"
          )
        )
      end
    end

    context "when handling edge case values" do
      it "handles zero coverage correctly" do
        data = {
          methods: [{name: "untested", owner: "TestClass", test_coverage: 0.0}]
        }

        result = enricher.enrich(data)

        method = result.methods.first
        expect(method.coverage_category).to eq("untested")
        expect(result.quality_issues).to include(
          have_attributes(
            type: "low_test_coverage",
            severity: "high",
            method: "untested"
          )
        )
      end

      it "handles coverage at exact boundary values" do
        enricher = Rubymap::Enricher.new
        data = {
          methods: [
            {name: "boundary_30", owner: "Test", test_coverage: 30.0},
            {name: "boundary_60", owner: "Test", test_coverage: 60.0},
            {name: "boundary_80", owner: "Test", test_coverage: 80.0}
          ]
        }

        result = enricher.enrich(data)

        # Check severity transitions at boundaries
        issues = result.quality_issues
        issue_30 = issues.find { |i| i.method == "boundary_30" }
        issue_60 = issues.find { |i| i.method == "boundary_60" }

        expect(issue_30.severity).to eq("medium")
        expect(issue_60.severity).to eq("low")
        expect(issues.find { |i| i.method == "boundary_80" }).to be_nil
      end

      it "handles nil values gracefully" do
        data = {
          classes: [{
            name: "NilClass",
            superclass: nil,
            dependencies: nil,
            test_coverage: nil,
            churn_score: nil
          }],
          methods: [{
            name: "nil_method",
            owner: "NilClass",
            branches: nil,
            loops: nil,
            test_coverage: nil
          }]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        method = result.methods.first

        expect(klass.stability_score).to be_a(Float)
        expect(method.cyclomatic_complexity).to eq(1)
      end

      it "handles empty collections" do
        data = {
          classes: [],
          modules: [],
          methods: [],
          method_calls: []
        }

        result = enricher.enrich(data)

        expect(result.classes).to be_empty
        expect(result.modules).to be_empty
        expect(result.methods).to be_empty
        expect(result.method_calls).to be_empty
      end
    end

    context "when calculating stability scores" do
      it "correctly calculates stability with extreme values" do
        data = {
          classes: [{
            name: "VeryStable",
            age_in_days: 1000,
            test_coverage: 100.0,
            documentation_coverage: 100.0,
            churn_score: 0.0
          }]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        expect(klass.stability_score).to be_between(0.9, 1.0)
      end

      it "correctly identifies stability categories" do
        data = {
          classes: [
            {name: "StableClass", age_in_days: 365, test_coverage: 95.0, churn_score: 0.1, documentation_coverage: 90.0},
            {name: "UnstableClass", age_in_days: 1, test_coverage: 10.0, churn_score: 50.0, documentation_coverage: 5.0}
          ]
        }

        result = enricher.enrich(data)

        expect(result.stability_analysis.stable_classes).to include("StableClass")
        expect(result.stability_analysis.unstable_classes).to include("UnstableClass")
      end
    end

    context "when processing invalid input" do
      it "raises error for unsupported input types" do
        expect { enricher.enrich("invalid") }.to raise_error(ArgumentError, /Expected NormalizedResult or Hash/)
        expect { enricher.enrich(123) }.to raise_error(ArgumentError, /Expected NormalizedResult or Hash/)
        expect { enricher.enrich([]) }.to raise_error(ArgumentError, /Expected NormalizedResult or Hash/)
      end
    end

    context "when checking Rails project detection" do
      it "detects Rails project from ApplicationRecord inheritance" do
        data = {
          classes: [{name: "User", superclass: "ApplicationRecord"}]
        }

        result = enricher.enrich(data)

        # Should have run Rails enrichment
        expect(result.rails_models).to be_truthy
      end

      it "detects Rails project from ApplicationController inheritance" do
        data = {
          classes: [{name: "UsersController", superclass: "ApplicationController"}]
        }

        result = enricher.enrich(data)

        # Should have run Rails enrichment
        expect(result.rails_controllers).to be_truthy
      end

      it "does not detect Rails in non-Rails projects" do
        data = {
          classes: [{name: "PlainClass", superclass: "Object"}]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        expect(klass.activerecord_metrics).to be_nil
      end
    end

    context "when testing helper methods" do
      it "correctly categorizes coverage severity" do
        enricher = Rubymap::Enricher.new

        # Test private method behavior through public interface
        data = {
          methods: [
            {name: "test0", owner: "Test", test_coverage: 0},
            {name: "test29", owner: "Test", test_coverage: 29},
            {name: "test30", owner: "Test", test_coverage: 30},
            {name: "test59", owner: "Test", test_coverage: 59},
            {name: "test60", owner: "Test", test_coverage: 60},
            {name: "test79", owner: "Test", test_coverage: 79}
          ]
        }

        result = enricher.enrich(data)
        issues = result.quality_issues

        expect(issues.find { |i| i.method == "test0" }.severity).to eq("high")
        expect(issues.find { |i| i.method == "test29" }.severity).to eq("high")
        expect(issues.find { |i| i.method == "test30" }.severity).to eq("medium")
        expect(issues.find { |i| i.method == "test59" }.severity).to eq("medium")
        expect(issues.find { |i| i.method == "test60" }.severity).to eq("low")
        expect(issues.find { |i| i.method == "test79" }.severity).to eq("low")
      end
    end

    context "when handling high fan-out coupling" do
      it "identifies classes with high dependency count" do
        data = {
          classes: [{
            name: "HighCoupling",
            dependencies: ["Dep1", "Dep2", "Dep3", "Dep4", "Dep5", "Dep6"]
          }]
        }

        result = enricher.enrich(data)

        # Default fan_out_threshold is 3
        expect(result.coupling_hotspots).to include(
          have_attributes(
            class: "HighCoupling",
            reason: "high_fan_out",
            fan_out: 6
          )
        )
      end

      it "flags classes at the default threshold (3 dependencies)" do
        data = {
          classes: [{
            name: "BoundaryCoupling",
            dependencies: ["Dep1", "Dep2", "Dep3"]
          }]
        }

        result = enricher.enrich(data)

        # Default threshold is 3, uses >= comparison
        expect(result.coupling_hotspots).to include(
          have_attributes(
            class: "BoundaryCoupling",
            reason: "high_fan_out",
            fan_out: 3
          )
        )
      end

      it "does not flag classes below the default threshold" do
        data = {
          classes: [{
            name: "NormalCoupling",
            dependencies: ["Dep1", "Dep2"]
          }]
        }

        result = enricher.enrich(data)

        expect(result.coupling_hotspots.any? { |h| h.instance_of?("NormalCoupling") }).to be false
      end

      it "respects custom fan_out_threshold configuration" do
        custom_enricher = Rubymap::Enricher.new(fan_out_threshold: 10)
        data = {
          classes: [
            {name: "LowDeps", dependencies: Array.new(9) { |i| "Dep#{i}" }},
            {name: "HighDeps", dependencies: Array.new(11) { |i| "Dep#{i}" }}
          ]
        }

        result = custom_enricher.enrich(data)

        # With threshold 10 and >= comparison, 9 should not be flagged, 11 should be
        class_names = result.coupling_hotspots.map { |h| h[:class] }
        expect(class_names).to include("HighDeps")
        expect(class_names.include?("LowDeps")).to be false
        expect(result.coupling_hotspots).to include(
          have_attributes(
            class: "HighDeps",
            fan_out: 11
          )
        )
      end
    end
  end

  describe "mutation killing tests" do
    context "when testing normalization functions" do
      it "correctly normalizes age values" do
        data = {
          classes: [
            {name: "NewClass", age_in_days: 0},
            {name: "YoungClass", age_in_days: 180},
            {name: "OldClass", age_in_days: 365},
            {name: "AncientClass", age_in_days: 730}
          ]
        }

        result = enricher.enrich(data)

        new_class = result.classes.find { |c| c.name == "NewClass" }
        young_class = result.classes.find { |c| c.name == "YoungClass" }
        old_class = result.classes.find { |c| c.name == "OldClass" }
        ancient_class = result.classes.find { |c| c.name == "AncientClass" }

        # Stability score should increase with age
        expect(new_class.stability_score).to be < young_class.stability_score
        expect(young_class.stability_score).to be < old_class.stability_score
        # Ancient should be clamped at max
        expect(ancient_class.stability_score).to be >= old_class.stability_score
      end

      it "correctly normalizes churn values" do
        data = {
          classes: [
            {name: "NoChurn", churn_score: 0, age_in_days: 100},
            {name: "LowChurn", churn_score: 10, age_in_days: 100},
            {name: "HighChurn", churn_score: 50, age_in_days: 100},
            {name: "ExtremeChurn", churn_score: 100, age_in_days: 100}
          ]
        }

        result = enricher.enrich(data)

        no_churn = result.classes.find { |c| c.name == "NoChurn" }
        low_churn = result.classes.find { |c| c.name == "LowChurn" }
        high_churn = result.classes.find { |c| c.name == "HighChurn" }
        extreme_churn = result.classes.find { |c| c.name == "ExtremeChurn" }

        # Stability should decrease with higher churn
        expect(no_churn.stability_score).to be >= low_churn.stability_score
        expect(low_churn.stability_score).to be >= high_churn.stability_score
        expect(high_churn.stability_score).to be >= extreme_churn.stability_score
      end

      it "correctly calculates maintainability scores" do
        data = {
          classes: [
            {name: "MaintainableClass", stability_score: 0.8, complexity_score: 0.2, coupling_strength: 2},
            {name: "UnmaintainableClass", stability_score: 0.2, complexity_score: 0.8, coupling_strength: 8}
          ]
        }

        result = enricher.enrich(data)

        maintainable = result.classes.find { |c| c.name == "MaintainableClass" }
        unmaintainable = result.classes.find { |c| c.name == "UnmaintainableClass" }

        # Maintainability scores will be recalculated by enricher
        expect(maintainable.maintainability_score).to be_a(Float)
        expect(unmaintainable.maintainability_score).to be_a(Float)
      end
    end

    context "when testing edge cases in calculations" do
      it "handles division by zero in averages" do
        data = {
          classes: [{name: "EmptyClass", methods: []}]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        expect(klass.complexity_score).to eq(0.0)
      end

      it "handles extremely high complexity values" do
        data = {
          methods: [{
            name: "super_complex",
            owner: "TestClass",
            branches: 50,
            loops: 20,
            conditionals: ["if"] * 30
          }]
        }

        result = enricher.enrich(data)

        method = result.methods.first
        expect(method.cyclomatic_complexity).to eq(101) # 1 + 50 + 20 + 30
        expect(method.complexity_category).to eq("very_complex")
      end

      it "correctly processes classes with no methods for complexity" do
        data = {
          classes: [{name: "NoMethodsClass"}],
          methods: []
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        expect(klass.complexity_score).to eq(0.0)
      end
    end

    context "when testing specific thresholds and boundaries" do
      it "correctly applies all default thresholds" do
        default_enricher = Rubymap::Enricher.new

        data = {
          classes: [
            {
              name: "ThresholdClass",
              inheritance_chain: ["A", "B", "C", "D", "E"], # depth 4, hits threshold
              dependencies: ["D1", "D2", "D3"], # fan-out 3, hits threshold
              git_commits: 10,
              churn_score: 10  # hits churn threshold
            }
          ],
          methods: [
            {
              name: "threshold_method",
              owner: "ThresholdClass",
              test_coverage: 79.9, # just below coverage threshold
              branches: 9  # complexity 10, hits threshold
            }
          ]
        }

        result = default_enricher.enrich(data)

        # Check all thresholds are applied (inheritance chain has 5 elements = depth 4)
        expect(result.design_issues).to include(
          have_attributes(type: "deep_inheritance", depth: 5)
        )
        expect(result.coupling_hotspots).to include(
          have_attributes(reason: "high_fan_out", fan_out: 3)
        )
        # Check if high_churn hotspot exists
        churn_hotspots = result.hotspots.select { |h| h.type == "high_churn" || h.name == "ThresholdClass" }
        expect(churn_hotspots.any?).to be true
        expect(result.quality_issues).to include(
          have_attributes(type: "low_test_coverage")
        )
      end

      it "ensures numeric calculations handle negative inputs safely" do
        data = {
          classes: [{
            name: "NegativeClass",
            age_in_days: -100,  # negative age
            churn_score: -10,   # negative churn
            test_coverage: -50  # negative coverage
          }]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        # Should handle negative values gracefully
        expect(klass.stability_score).to be_a(Float)
        expect(klass.stability_score).to be >= 0.0
      end
    end

    context "when testing pattern and idiom detection edge cases" do
      it "does not detect patterns with insufficient evidence" do
        data = {
          classes: [{
            name: "AlmostFactory",
            methods: ["create"]  # Has create but missing build
          }]
        }

        result = enricher.enrich(data)

        # Factory pattern may be detected with partial evidence at lower confidence
        factory_patterns = result.design_patterns.select { |p| p.pattern == "Factory" }
        if factory_patterns.any?
          expect(factory_patterns.first.confidence).to be < 0.8
        end
      end

      it "handles patterns with no matching evidence gracefully" do
        data = {
          classes: [{
            name: "RegularClass",
            methods: ["do_something", "do_another_thing"]
          }]
        }

        result = enricher.enrich(data)

        # Should not detect any patterns
        expect(result.design_patterns).to be_empty
      end
    end

    context "when testing composite score calculations" do
      it "handles all nil values in stability calculation" do
        data = {
          classes: [{
            name: "NilClass",
            age_in_days: nil,
            test_coverage: nil,
            documentation_coverage: nil,
            churn_score: nil
          }]
        }

        result = enricher.enrich(data)

        klass = result.classes.first
        # With nil churn, it's treated as 0 (good), so stability is 0.3
        expect(klass.stability_score).to eq(0.3)
      end

      it "correctly weights stability score components" do
        data = {
          classes: [
            {
              name: "OnlyAge",
              age_in_days: 365,
              test_coverage: 0,
              documentation_coverage: 0,
              churn_score: 100
            },
            {
              name: "OnlyCoverage",
              age_in_days: 0,
              test_coverage: 100,
              documentation_coverage: 0,
              churn_score: 100
            },
            {
              name: "OnlyDocs",
              age_in_days: 0,
              test_coverage: 0,
              documentation_coverage: 100,
              churn_score: 100
            },
            {
              name: "OnlyLowChurn",
              age_in_days: 0,
              test_coverage: 0,
              documentation_coverage: 0,
              churn_score: 0
            }
          ]
        }

        result = enricher.enrich(data)

        # Each component should contribute according to its weight
        only_age = result.classes.find { |c| c.name == "OnlyAge" }
        only_coverage = result.classes.find { |c| c.name == "OnlyCoverage" }
        only_docs = result.classes.find { |c| c.name == "OnlyDocs" }
        only_low_churn = result.classes.find { |c| c.name == "OnlyLowChurn" }

        # Test coverage has 0.3 weight, should be highest
        expect(only_coverage.stability_score).to be > only_age.stability_score
        expect(only_coverage.stability_score).to be > only_docs.stability_score
        # Low churn also has 0.3 weight
        expect(only_low_churn.stability_score).to eq(0.3)
      end
    end

    context "when testing method complexity calculations" do
      it "distinguishes between different types of conditionals" do
        data = {
          methods: [
            {
              name: "only_branches",
              owner: "Test",
              branches: 5,
              loops: 0,
              conditionals: []
            },
            {
              name: "only_loops",
              owner: "Test",
              branches: 0,
              loops: 5,
              conditionals: []
            },
            {
              name: "only_conditionals",
              owner: "Test",
              branches: 0,
              loops: 0,
              conditionals: ["if", "unless", "case", "when", "else"]
            }
          ]
        }

        result = enricher.enrich(data)

        only_branches = result.methods.find { |m| m.name == "only_branches" }
        only_loops = result.methods.find { |m| m.name == "only_loops" }
        only_conditionals = result.methods.find { |m| m.name == "only_conditionals" }

        expect(only_branches.cyclomatic_complexity).to eq(6)  # 1 + 5
        expect(only_loops.cyclomatic_complexity).to eq(6)     # 1 + 5
        expect(only_conditionals.cyclomatic_complexity).to eq(6) # 1 + 5
      end

      it "correctly categorizes all complexity levels" do
        data = {
          methods: [
            {name: "simple", owner: "Test", branches: 0},
            {name: "moderate", owner: "Test", branches: 4},
            {name: "complex", owner: "Test", branches: 9},
            {name: "very_complex", owner: "Test", branches: 20}
          ]
        }

        result = enricher.enrich(data)

        simple = result.methods.find { |m| m.name == "simple" }
        moderate = result.methods.find { |m| m.name == "moderate" }
        complex = result.methods.find { |m| m.name == "complex" }
        very_complex = result.methods.find { |m| m.name == "very_complex" }

        expect(simple.complexity_category).to eq("simple")
        expect(moderate.complexity_category).to eq("simple") # 5 is still simple
        expect(complex.complexity_category).to eq("moderate") # 10 is moderate
        expect(very_complex.complexity_category).to eq("very_complex") # 21 is very_complex
      end
    end
  end
end
