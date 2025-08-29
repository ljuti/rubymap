# frozen_string_literal: true

RSpec.describe "Rubymap::Indexer" do
  let(:indexer) { Rubymap::Indexer.new }

  # High-level integration specs focusing on business value
  describe "integration behavior" do
    context "when a developer wants to understand a Ruby codebase" do
      let(:enriched_data) do
        build_enriched_codebase_data
      end

      it "enables quick symbol lookup by name" do
        # Given: An enriched codebase with various symbols
        # When: Building indexes
        result = indexer.build(enriched_data)

        # Then: Should find symbols quickly by name
        user_class = result.find_symbol("User")
        expect(user_class).to have_attributes(
          type: "class",
          fully_qualified_name: "User",
          location: instance_of(String)
        )

        # Performance requirement: lookup should be fast
        expect { result.find_symbol("User") }.to perform_under(10).ms
      end

      it "enables navigation through inheritance hierarchy" do
        result = indexer.build(enriched_data)

        # Should navigate up the inheritance chain
        ancestors = result.ancestors_of("AdminUser")
        expect(ancestors).to eq(["User", "ApplicationRecord", "ActiveRecord::Base", "Object"])

        # Should navigate down to descendants
        descendants = result.descendants_of("User")
        expect(descendants).to include("AdminUser", "GuestUser")
      end

      it "reveals dependencies between components" do
        result = indexer.build(enriched_data)

        # Should show what a class depends on
        user_deps = result.dependencies_of("UsersController")
        expect(user_deps).to include("User", "UserService", "ApplicationController")

        # Should show what depends on a class
        user_dependents = result.dependents_of("User")
        expect(user_dependents).to include("UsersController", "UserService")
      end

      it "tracks how methods are called throughout the codebase" do
        result = indexer.build(enriched_data)

        # Should find all callers of a method
        save_callers = result.callers_of("User#save")
        expect(save_callers).to include("UserService#create_user")

        # Should trace call chains
        call_chain = result.trace_calls_from("UsersController#create")
        expect(call_chain).to include("UserService#create_user", "User#save")
      end
    end

    context "when supporting IDE features" do
      let(:indexed_codebase) { indexer.build(build_enriched_codebase_data) }

      it "supports 'go to definition' functionality" do
        # Should find where a symbol is defined
        definition = indexed_codebase.definition_of("User")
        expect(definition).to have_attributes(
          file: "app/models/user.rb",
          line: 1,
          type: "class_definition"
        )
      end

      it "supports 'find all references' functionality" do
        # Should find all places where a symbol is used
        references = indexed_codebase.references_to("User::STATUSES")
        expect(references).to include(
          have_attributes(file: "app/controllers/users_controller.rb", line: 15),
          have_attributes(file: "app/models/user.rb", line: 23),
          have_attributes(file: "app/serializers/user_serializer.rb", line: 8)
        )
      end

      it "supports 'find implementations' for mixins" do
        # Should find all classes that include a module
        implementers = indexed_codebase.implementers_of("Searchable")
        expect(implementers).to include("User", "Post", "Comment")
      end

      it "enables fuzzy search for symbol names" do
        # Should find symbols with similar names
        suggestions = indexed_codebase.fuzzy_search("usr")
        expect(suggestions.map(&:name)).to include("User", "UserService", "UsersController")

        # Should rank by similarity
        expect(suggestions.first.name).to eq("User")
      end
    end
  end

  # Specific behavioral specs for core functionality
  describe "#build" do
    context "when processing enriched data" do
      it "creates a queryable index from enriched data" do
        enriched_data = {
          classes: [
            build_enriched_class(name: "User", superclass: "ApplicationRecord")
          ],
          methods: [
            build_enriched_method(name: "save", owner: "User")
          ]
        }

        result = indexer.build(enriched_data)

        expect(result).to respond_to(:find_symbol)
        expect(result).to respond_to(:ancestors_of)
        expect(result).to respond_to(:dependencies_of)
      end

      it "handles empty enriched data gracefully" do
        result = indexer.build({classes: [], methods: [], modules: []})

        expect(result.find_symbol("NonExistent")).to be_nil
        expect(result.all_symbols).to be_empty
      end

      it "validates input data structure" do
        invalid_data = {invalid_key: "invalid_value"}

        expect {
          indexer.build(invalid_data)
        }.to raise_error(Rubymap::Indexer::InvalidDataError, /Missing required keys/)
      end
    end

    context "when handling errors and edge cases" do
      it "detects and reports circular dependencies" do
        circular_data = {
          classes: [
            build_enriched_class(name: "A", dependencies: ["B"]),
            build_enriched_class(name: "B", dependencies: ["C"]),
            build_enriched_class(name: "C", dependencies: ["A"])
          ]
        }

        result = indexer.build(circular_data)

        expect(result.circular_dependencies).to include(
          have_attributes(cycle: ["A", "B", "C", "A"])
        )

        # Should still be queryable despite circular dependencies
        expect(result.find_symbol("A")).to be_truthy
      end

      it "handles missing references gracefully" do
        data_with_missing_refs = {
          classes: [
            build_enriched_class(
              name: "User",
              superclass: "NonExistentBase",
              dependencies: ["MissingDependency"]
            )
          ]
        }

        result = indexer.build(data_with_missing_refs)

        expect(result.missing_references).to include(
          have_attributes(
            symbol: "NonExistentBase",
            referenced_by: "User",
            reference_type: "superclass"
          )
        )
      end

      it "manages memory efficiently for large codebases" do
        large_dataset = build_large_enriched_dataset(classes: 10_000, methods: 50_000)

        memory_before = get_memory_usage
        result = indexer.build(large_dataset)
        memory_after = get_memory_usage

        memory_increase_mb = (memory_after - memory_before) / 1024.0 / 1024.0

        # Should use reasonable memory (less than 500MB for 10k classes)
        expect(memory_increase_mb).to be < 500

        # Should still be performant
        expect { result.find_symbol("Class5000") }.to perform_under(10).ms
      end
    end
  end

  describe "graph operations" do
    let(:indexed_data) { indexer.build(build_enriched_codebase_data) }

    context "inheritance graph" do
      it "builds a directed acyclic graph for inheritance" do
        graph = indexed_data.inheritance_graph

        expect(graph).to have_attributes(
          node_count: be > 0,
          edge_count: be > 0,
          is_acyclic: true
        )
      end

      it "calculates inheritance depth for each class" do
        depths = indexed_data.inheritance_depths

        expect(depths["Object"]).to eq(0)
        expect(depths["ApplicationRecord"]).to eq(2)
        expect(depths["User"]).to eq(3)
        expect(depths["AdminUser"]).to eq(4)
      end

      it "identifies classes with deep inheritance" do
        deep_classes = indexed_data.deep_inheritance_classes(threshold: 3)

        expect(deep_classes).to include(
          have_attributes(name: "AdminUser", depth: 4)
        )
      end
    end

    context "dependency graph" do
      it "builds a directed graph of dependencies" do
        graph = indexed_data.dependency_graph

        expect(graph.out_edges_of("UsersController")).to include(
          have_attributes(to: "User", type: "depends_on"),
          have_attributes(to: "UserService", type: "depends_on")
        )
      end

      it "calculates fan-in and fan-out metrics" do
        metrics = indexed_data.dependency_metrics_for("User")

        expect(metrics).to have_attributes(
          fan_in: be >= 2,  # UserController and UserService depend on it
          fan_out: be >= 1  # User depends on ApplicationRecord
        )
      end

      it "identifies dependency hotspots" do
        hotspots = indexed_data.dependency_hotspots

        # With our test data, no class has fan-in > 5
        # User has fan-in of 2 (UsersController, UserService depend on it)
        expect(hotspots).to be_empty
      end
    end

    context "method call graph" do
      it "builds a weighted graph of method calls" do
        graph = indexed_data.method_call_graph

        edge = graph.edge_between("UserService#create_user", "User#save")
        expect(edge).to have_attributes(
          weight: be > 0,  # Call frequency
          type: "calls"
        )
      end

      it "identifies frequently called methods" do
        hot_methods = indexed_data.hot_methods(threshold: 10)

        expect(hot_methods).to include(
          have_attributes(
            method: "User#save",
            total_calls: be > 10
          )
        )
      end

      it "traces complete call paths" do
        path = indexed_data.call_path_from("UsersController#create")

        expect(path).to eq([
          "UsersController#create",
          "UserService#create_user",
          "User#save",
          "User#validate",
          "EmailService#send_welcome"
        ])
      end
    end
  end

  describe "search capabilities" do
    let(:indexed_data) { indexer.build(build_enriched_codebase_data) }

    context "exact matching" do
      it "finds symbols by exact name" do
        result = indexed_data.find_symbol("User")
        expect(result).to have_attributes(name: "User", type: "class")
      end

      it "finds symbols by fully qualified name" do
        result = indexed_data.find_symbol("API::V1::UsersController")
        expect(result).to have_attributes(
          name: "UsersController",
          namespace: ["API", "V1"]
        )
      end

      it "returns nil for non-existent symbols" do
        result = indexed_data.find_symbol("NonExistent")
        expect(result).to be_nil
      end
    end

    context "pattern matching" do
      it "finds symbols matching a pattern" do
        results = indexed_data.search_symbols(/User/)

        expect(results.map(&:name)).to include(
          "User",
          "UserService",
          "UsersController",
          "AdminUser"
        )
      end

      it "supports case-insensitive search" do
        results = indexed_data.search_symbols("user", case_sensitive: false)

        expect(results.map(&:name)).to include("User", "UserService")
      end
    end

    context "fuzzy matching" do
      it "finds symbols with similar names" do
        results = indexed_data.fuzzy_search("usr", threshold: 0.5)

        expect(results).to include(
          have_attributes(name: "User", score: be > 0.6)
        )
      end

      it "ranks results by similarity" do
        results = indexed_data.fuzzy_search("use")

        expect(results.first.name).to eq("User")
        expect(results.map(&:name)).to include("UserService", "UsersController")
      end
    end

    context "filtered searches" do
      it "filters by symbol type" do
        classes = indexed_data.search_symbols("", type: :class)
        expect(classes).to all(have_attributes(type: "class"))

        methods = indexed_data.search_symbols("", type: :method)
        expect(methods).to all(have_attributes(type: "method"))
      end

      it "filters by namespace" do
        api_symbols = indexed_data.search_symbols("", namespace: "API::V1")

        expect(api_symbols).to all(
          have_attributes(namespace: include("API", "V1"))
        )
      end

      it "filters by file location" do
        model_symbols = indexed_data.search_symbols("", file_pattern: /app\/models/)

        expect(model_symbols).to all(
          have_attributes(file: match(/app\/models/))
        )
      end
    end
  end

  describe "query performance", skip: "Performance optimizations pending" do
    let(:large_dataset) { build_large_enriched_dataset(classes: 10_000, methods: 50_000) }
    let(:indexed_data) { indexer.build(large_dataset) }

    it "performs symbol lookup in constant time" do
      # Warm up
      indexed_data.find_symbol("Class1")

      time_for_first = Benchmark.realtime { indexed_data.find_symbol("Class1") }
      time_for_last = Benchmark.realtime { indexed_data.find_symbol("Class9999") }

      # Times should be similar (within 2x) regardless of position
      expect(time_for_last / time_for_first).to be < 2.0
    end

    it "performs ancestry queries efficiently" do
      expect {
        indexed_data.ancestors_of("DeeplyNestedClass")
      }.to perform_under(50).ms
    end

    it "handles complex dependency queries efficiently" do
      expect {
        indexed_data.transitive_dependencies_of("ComplexClass")
      }.to perform_under(100).ms
    end

    it "performs fuzzy search within acceptable time" do
      expect {
        indexed_data.fuzzy_search("usr")
      }.to perform_under(200).ms
    end
  end

  describe "index persistence" do
    let(:enriched_data) { build_enriched_codebase_data }
    let(:indexed_data) { indexer.build(enriched_data) }

    context "serialization" do
      it "can serialize indexes to a file" do
        file_path = "tmp/test_index.rubymap_idx"

        indexed_data.save(file_path)

        expect(File).to exist(file_path)
        expect(File.size(file_path)).to be > 0
      end

      it "can deserialize indexes from a file" do
        file_path = "tmp/test_index.rubymap_idx"
        indexed_data.save(file_path)

        loaded = Rubymap::Indexer.load(file_path)

        # Should have same query capabilities
        expect(loaded.find_symbol("User")).to have_attributes(
          name: "User",
          type: "class"
        )
      end

      it "maintains performance after deserialization" do
        file_path = "tmp/test_index.rubymap_idx"
        indexed_data.save(file_path)
        loaded = Rubymap::Indexer.load(file_path)

        expect {
          loaded.find_symbol("User")
        }.to perform_under(10).ms
      end
    end

    context "incremental updates" do
      it "can add new symbols to existing index" do
        new_class = build_enriched_class(name: "NewFeature")

        indexed_data.add_symbol(new_class)

        expect(indexed_data.find_symbol("NewFeature")).to be_truthy
      end

      it "can update existing symbols" do
        updated_class = build_enriched_class(
          name: "User",
          superclass: "NewBase"
        )

        indexed_data.update_symbol(updated_class)

        user = indexed_data.find_symbol("User")
        expect(user.superclass).to eq("NewBase")
      end

      it "can remove symbols from index" do
        indexed_data.remove_symbol("ObsoleteClass")

        expect(indexed_data.find_symbol("ObsoleteClass")).to be_nil
      end

      it "updates graph relationships on symbol changes" do
        indexed_data.remove_symbol("MiddleClass")

        # Dependencies should be updated
        deps = indexed_data.dependencies_of("DependentClass")
        expect(deps.include?("MiddleClass")).to be false
      end
    end
  end

  # Helper methods for building test data
  def build_enriched_codebase_data
    {
      classes: [
        build_enriched_class(
          name: "Object",
          superclass: nil
        ),
        build_enriched_class(
          name: "ActiveRecord::Base",
          superclass: "Object"
        ),
        build_enriched_class(
          name: "ApplicationRecord",
          superclass: "ActiveRecord::Base"
        ),
        build_enriched_class(
          name: "User",
          superclass: "ApplicationRecord",
          dependencies: ["ApplicationRecord", "Searchable"],
          mixins: [{type: "include", module: "Searchable"}]
        ),
        build_enriched_class(
          name: "AdminUser",
          superclass: "User"
        ),
        build_enriched_class(
          name: "GuestUser",
          superclass: "User"
        ),
        build_enriched_class(
          name: "UsersController",
          superclass: "ApplicationController",
          dependencies: ["User", "UserService", "ApplicationController"]
        ),
        build_enriched_class(
          name: "UserService",
          dependencies: ["User", "EmailService"]
        ),
        build_enriched_class(
          name: "UsersController",
          fqname: "API::V1::UsersController",
          namespace: ["API", "V1"],
          superclass: "ApplicationController",
          dependencies: ["User"]
        ),
        build_enriched_class(
          name: "Post",
          superclass: "ApplicationRecord",
          mixins: [{type: "include", module: "Searchable"}]
        ),
        build_enriched_class(
          name: "Comment",
          superclass: "ApplicationRecord",
          mixins: [{type: "include", module: "Searchable"}]
        )
      ],
      methods: [
        build_enriched_method(name: "save", owner: "User"),
        build_enriched_method(name: "validate", owner: "User"),
        build_enriched_method(name: "create", owner: "UserController"),
        build_enriched_method(name: "create_user", owner: "UserService")
      ],
      method_calls: [
        {from: "UsersController#create", to: "UserService#create_user", frequency: 1},
        {from: "UserService#create_user", to: "User#save", frequency: 15},
        {from: "User#save", to: "User#validate", frequency: 15},
        {from: "User#validate", to: "EmailService#send_welcome", frequency: 1}
      ],
      modules: [
        build_enriched_module(name: "Searchable")
      ]
    }
  end

  def build_enriched_class(attrs = {})
    {
      name: attrs[:name],
      fqname: attrs[:fqname] || attrs[:name],
      namespace: attrs[:namespace],
      type: "class",
      superclass: attrs[:superclass],
      dependencies: attrs[:dependencies] || [],
      mixins: attrs[:mixins] || [],
      file: attrs[:file] || "app/models/#{attrs[:name].downcase}.rb",
      line: attrs[:line] || 1
    }
  end

  def build_enriched_method(attrs = {})
    {
      name: attrs[:name],
      fqname: "#{attrs[:owner]}##{attrs[:name]}",
      owner: attrs[:owner],
      type: "instance_method",
      file: attrs[:file] || "app/models/#{attrs[:owner].downcase}.rb",
      line: attrs[:line] || 10
    }
  end

  def build_enriched_module(attrs = {})
    {
      name: attrs[:name],
      fqname: attrs[:fqname] || attrs[:name],
      type: "module",
      file: attrs[:file] || "app/models/concerns/#{attrs[:name].downcase}.rb",
      line: attrs[:line] || 1
    }
  end

  def build_large_enriched_dataset(classes: 10_000, methods: 50_000)
    {
      classes: (1..classes).map do |i|
        build_enriched_class(
          name: "Class#{i}",
          superclass: (i > 1) ? "Class#{i - 1}" : nil,
          dependencies: (i > 10) ? ["Class#{i - 5}", "Class#{i - 10}"] : []
        )
      end,
      methods: (1..methods).map do |i|
        owner = "Class#{(i % classes) + 1}"
        build_enriched_method(
          name: "method#{i}",
          owner: owner
        )
      end,
      method_calls: (1..10_000).map do |i|
        {
          from: "Class#{i % classes + 1}#method#{i}",
          to: "Class#{(i + 1) % classes + 1}#method#{i + 1}",
          frequency: rand(1..10)
        }
      end
    }
  end

  def get_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i
  end
end

# Performance matchers
RSpec::Matchers.define :perform_under do |expected|
  match do |actual|
    @time = Benchmark.realtime(&actual)
    @time * 1000 < expected  # Convert to milliseconds
  end

  failure_message do
    "expected block to complete in under #{expected}ms, but took #{(@time * 1000).round(2)}ms"
  end

  chain :ms do
    # Just for readability
  end

  supports_block_expectations
end
