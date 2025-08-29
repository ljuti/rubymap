# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Normalizer Deduplication Mutation Killing" do
  describe Rubymap::Normalizer::Deduplication::Deduplicator do
    let(:provenance_tracker) { Rubymap::Normalizer::ProvenanceTracker.new }
    let(:visibility_normalizer) { Rubymap::Normalizer::Normalizers::VisibilityNormalizer.new }
    let(:merge_strategy) { Rubymap::Normalizer::Deduplication::MergeStrategy.new(provenance_tracker, visibility_normalizer) }
    let(:deduplicator) { described_class.new(merge_strategy) }

    describe "#deduplicate" do
      it "returns empty array for nil input" do
        expect(deduplicator.deduplicate(nil)).to eq([])
      end

      it "returns empty array for empty input" do
        expect(deduplicator.deduplicate([])).to eq([])
      end

      it "returns single symbol unchanged" do
        symbol = { symbol_id: "1", name: "User" }
        result = deduplicator.deduplicate([symbol])
        expect(result).to eq([symbol])
      end

      it "deduplicates symbols with same id" do
        symbol1 = { symbol_id: "1", name: "User", doc: "First" }
        symbol2 = { symbol_id: "1", name: "User", doc: "Second" }
        
        result = deduplicator.deduplicate([symbol1, symbol2])
        expect(result.size).to eq(1)
        expect(result.first[:symbol_id]).to eq("1")
      end

      it "preserves symbols with different ids" do
        symbol1 = { symbol_id: "1", name: "User" }
        symbol2 = { symbol_id: "2", name: "Post" }
        
        result = deduplicator.deduplicate([symbol1, symbol2])
        expect(result.size).to eq(2)
      end

      it "groups and merges duplicates correctly" do
        symbols = [
          { symbol_id: "1", name: "User", source: "static" },
          { symbol_id: "1", name: "User", source: "runtime" },
          { symbol_id: "2", name: "Post", source: "static" },
          { symbol_id: "2", name: "Post", source: "runtime" },
          { symbol_id: "3", name: "Comment", source: "static" }
        ]
        
        result = deduplicator.deduplicate(symbols)
        expect(result.size).to eq(3)
        expect(result.map { |s| s[:symbol_id] }.sort).to eq(["1", "2", "3"])
      end

      it "handles symbols without symbol_id" do
        symbol1 = { name: "User" }
        symbol2 = { name: "Post" }
        
        result = deduplicator.deduplicate([symbol1, symbol2])
        expect(result.size).to eq(2)
      end

      it "uses merge strategy for duplicates" do
        symbol1 = { symbol_id: "1", name: "User", visibility: "public" }
        symbol2 = { symbol_id: "1", name: "User", visibility: "private" }
        
        allow(deduplicator).to receive(:merge_strategy).and_return(merge_strategy)
        expect(merge_strategy).to receive(:merge).and_call_original
        
        deduplicator.deduplicate([symbol1, symbol2])
      end
    end
  end

  describe Rubymap::Normalizer::Deduplication::MergeStrategy do
    let(:provenance_tracker) { Rubymap::Normalizer::ProvenanceTracker.new }
    let(:visibility_normalizer) { Rubymap::Normalizer::Normalizers::VisibilityNormalizer.new }
    let(:strategy) { described_class.new(provenance_tracker, visibility_normalizer) }

    describe "#merge" do
      it "returns single element unchanged" do
        symbol = { symbol_id: "1", name: "User" }
        result = strategy.merge([symbol])
        expect(result).to eq(symbol)
      end

      it "merges multiple symbols with precedence" do
        duplicates = [
          { symbol_id: "1", name: "User", doc: "First", sources: ["static"] },
          { symbol_id: "1", name: "User", doc: "Second", sources: ["runtime"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:symbol_id]).to eq("1")
        expect(result[:sources]).to include("static", "runtime")
      end

      it "uses highest precedence source for conflicts" do
        duplicates = [
          { symbol_id: "1", visibility: "public", sources: ["inferred"] },
          { symbol_id: "1", visibility: "private", sources: ["rbs"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:visibility]).to eq("private")  # RBS has higher precedence
      end

      it "merges arrays correctly" do
        duplicates = [
          { symbol_id: "1", methods: ["save"], sources: ["static"] },
          { symbol_id: "1", methods: ["destroy"], sources: ["runtime"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:methods]).to include("save", "destroy")
      end

      it "merges hashes correctly" do
        duplicates = [
          { symbol_id: "1", metadata: { a: 1 }, sources: ["static"] },
          { symbol_id: "1", metadata: { b: 2 }, sources: ["runtime"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:metadata]).to eq({ a: 1, b: 2 })
      end

      it "handles nil values in merge" do
        duplicates = [
          { symbol_id: "1", doc: nil, sources: ["static"] },
          { symbol_id: "1", doc: "Documentation", sources: ["runtime"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:doc]).to eq("Documentation")
      end

      it "preserves non-nil over nil" do
        duplicates = [
          { symbol_id: "1", visibility: "public", sources: ["static"] },
          { symbol_id: "1", visibility: nil, sources: ["runtime"] }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:visibility]).to eq("public")
      end

      it "merges provenance correctly" do
        duplicates = [
          { symbol_id: "1", provenance: { sources: ["static"], confidence: 0.8 } },
          { symbol_id: "1", provenance: { sources: ["runtime"], confidence: 0.9 } }
        ]
        
        result = strategy.merge(duplicates)
        expect(result[:provenance][:sources]).to include("static", "runtime")
        expect(result[:provenance][:confidence]).to eq(0.9)  # Takes highest
      end
    end

    describe "#calculate_precedence" do
      it "returns 0 for nil sources" do
        symbol = { name: "User" }
        expect(strategy.send(:calculate_precedence, symbol)).to eq(0)
      end

      it "returns 0 for empty sources" do
        symbol = { sources: [] }
        expect(strategy.send(:calculate_precedence, symbol)).to eq(0)
      end

      it "returns highest precedence from sources" do
        symbol = { sources: ["inferred", "static", "rbs"] }
        expect(strategy.send(:calculate_precedence, symbol)).to eq(4)  # RBS = 4
      end

      it "handles unknown sources" do
        symbol = { sources: ["unknown"] }
        expect(strategy.send(:calculate_precedence, symbol)).to eq(0)
      end
    end

    describe "#merge_provenance" do
      it "merges sources from all duplicates" do
        duplicates = [
          { provenance: { sources: ["static"] } },
          { provenance: { sources: ["runtime"] } }
        ]
        
        result = strategy.send(:merge_provenance, duplicates)
        expect(result[:sources]).to include("static", "runtime")
      end

      it "takes highest confidence" do
        duplicates = [
          { provenance: { confidence: 0.7 } },
          { provenance: { confidence: 0.9 } },
          { provenance: { confidence: 0.8 } }
        ]
        
        result = strategy.send(:merge_provenance, duplicates)
        expect(result[:confidence]).to eq(0.9)
      end

      it "uses current timestamp" do
        duplicates = [{ provenance: {} }]
        
        result = strategy.send(:merge_provenance, duplicates)
        expect(result[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      it "handles missing provenance" do
        duplicates = [
          { name: "User" },
          { provenance: { sources: ["static"] } }
        ]
        
        result = strategy.send(:merge_provenance, duplicates)
        expect(result[:sources]).to eq(["static"])
      end
    end
  end

  describe Rubymap::Normalizer::Resolvers::NamespaceResolver do
    let(:resolver) { described_class.new }
    let(:result) do
      r = Rubymap::Normalizer::NormalizedResult.new
      r.classes = [
        { symbol_id: "1", name: "User", fqname: "MyApp::User", namespace_path: ["MyApp"] },
        { symbol_id: "2", name: "Profile", fqname: "MyApp::User::Profile", namespace_path: ["MyApp", "User"] },
        { symbol_id: "3", name: "Post", fqname: "Post", namespace_path: [] }
      ]
      r.modules = [
        { symbol_id: "4", name: "MyApp", fqname: "MyApp", namespace_path: [] },
        { symbol_id: "5", name: "Helpers", fqname: "MyApp::Helpers", namespace_path: ["MyApp"] }
      ]
      r
    end

    describe "#resolve" do
      it "builds parent-child relationships" do
        resolver.resolve(result, {})
        
        myapp = result.modules.find { |m| m[:name] == "MyApp" }
        expect(myapp[:children]).to include("MyApp::User", "MyApp::Helpers")
        
        user = result.classes.find { |c| c[:name] == "User" }
        expect(user[:children]).to include("MyApp::User::Profile")
      end

      it "handles symbols without namespace" do
        resolver.resolve(result, {})
        
        post = result.classes.find { |c| c[:name] == "Post" }
        expect(post[:children]).to eq([])
      end

      it "handles empty result" do
        empty_result = Rubymap::Normalizer::NormalizedResult.new
        expect { resolver.resolve(empty_result, {}) }.not_to raise_error
      end

      it "preserves existing children arrays" do
        result.classes.first[:children] = ["ExistingChild"]
        
        resolver.resolve(result, {})
        
        user = result.classes.find { |c| c[:name] == "User" }
        expect(user[:children]).to include("ExistingChild", "MyApp::User::Profile")
      end
    end
  end

  describe Rubymap::Normalizer::Resolvers::InheritanceResolver do
    let(:resolver) { described_class.new }
    let(:symbol_index) do
      index = Rubymap::Normalizer::SymbolIndex.new
      index.add(double(symbol_id: "1", fqname: "ApplicationRecord"))
      index.add(double(symbol_id: "2", fqname: "ActiveRecord::Base"))
      index.add(double(symbol_id: "3", fqname: "Object"))
      index
    end
    let(:context) { { symbol_index: symbol_index } }
    let(:result) do
      r = Rubymap::Normalizer::NormalizedResult.new
      r.classes = [
        { symbol_id: "10", name: "User", superclass: "ApplicationRecord" },
        { symbol_id: "11", name: "ApplicationRecord", superclass: "ActiveRecord::Base" },
        { symbol_id: "12", name: "ActiveRecord::Base", superclass: "Object" }
      ]
      r
    end

    describe "#resolve" do
      it "builds inheritance chains" do
        resolver.resolve(result, context)
        
        user = result.classes.find { |c| c[:name] == "User" }
        expect(user[:inheritance_chain]).to eq(["ApplicationRecord", "ActiveRecord::Base", "Object"])
      end

      it "handles missing superclass" do
        result.classes << { symbol_id: "13", name: "Orphan", superclass: nil }
        
        resolver.resolve(result, context)
        
        orphan = result.classes.find { |c| c[:name] == "Orphan" }
        expect(orphan[:inheritance_chain]).to eq([])
      end

      it "prevents infinite loops in inheritance" do
        result.classes = [
          { symbol_id: "20", name: "A", superclass: "B" },
          { symbol_id: "21", name: "B", superclass: "A" }
        ]
        
        expect { resolver.resolve(result, context) }.not_to raise_error
        
        a = result.classes.find { |c| c[:name] == "A" }
        expect(a[:inheritance_chain].size).to be <= 10  # Some reasonable limit
      end

      it "handles unknown superclass" do
        result.classes = [
          { symbol_id: "30", name: "Custom", superclass: "UnknownClass" }
        ]
        
        resolver.resolve(result, context)
        
        custom = result.classes.find { |c| c[:name] == "Custom" }
        expect(custom[:inheritance_chain]).to eq(["UnknownClass"])
      end
    end
  end

  describe Rubymap::Normalizer::Resolvers::CrossReferenceResolver do
    let(:resolver) { described_class.new }
    let(:result) do
      r = Rubymap::Normalizer::NormalizedResult.new
      r.classes = [
        { symbol_id: "1", name: "User", fqname: "User" }
      ]
      r.methods = [
        { symbol_id: "10", name: "save", owner: "User", scope: "instance" },
        { symbol_id: "11", name: "find", owner: "User", scope: "class" }
      ]
      r
    end

    describe "#resolve" do
      it "links methods to their owners" do
        resolver.resolve(result, {})
        
        user = result.classes.first
        expect(user[:instance_methods]).to include("save")
        expect(user[:class_methods]).to include("find")
      end

      it "handles methods without valid owner" do
        result.methods << { symbol_id: "12", name: "orphan", owner: "NonExistent" }
        
        expect { resolver.resolve(result, {}) }.not_to raise_error
      end

      it "handles empty result" do
        empty_result = Rubymap::Normalizer::NormalizedResult.new
        expect { resolver.resolve(empty_result, {}) }.not_to raise_error
      end

      it "preserves existing method arrays" do
        result.classes.first[:instance_methods] = ["existing"]
        
        resolver.resolve(result, {})
        
        user = result.classes.first
        expect(user[:instance_methods]).to include("existing", "save")
      end
    end
  end

  describe Rubymap::Normalizer::Resolvers::MixinMethodResolver do
    let(:resolver) { described_class.new }
    let(:symbol_index) do
      index = Rubymap::Normalizer::SymbolIndex.new
      validatable = double(
        symbol_id: "100",
        fqname: "Validatable",
        instance_methods: ["validate", "valid?"]
      )
      index.add(validatable)
      index
    end
    let(:context) { { symbol_index: symbol_index } }
    let(:result) do
      r = Rubymap::Normalizer::NormalizedResult.new
      r.classes = [
        {
          symbol_id: "1",
          name: "User",
          mixins: [{ type: "include", module: "Validatable" }],
          instance_methods: ["save"]
        }
      ]
      r.modules = [
        {
          symbol_id: "100",
          name: "Validatable",
          instance_methods: ["validate", "valid?"]
        }
      ]
      r
    end

    describe "#resolve" do
      it "adds mixin methods to including class" do
        resolver.resolve(result, context)
        
        user = result.classes.first
        expect(user[:available_instance_methods]).to include("save", "validate", "valid?")
      end

      it "handles extend mixins for class methods" do
        result.classes.first[:mixins] = [{ type: "extend", module: "Validatable" }]
        result.classes.first[:class_methods] = ["find"]
        
        resolver.resolve(result, context)
        
        user = result.classes.first
        expect(user[:available_class_methods]).to include("find", "validate", "valid?")
      end

      it "handles prepend mixins" do
        result.classes.first[:mixins] = [{ type: "prepend", module: "Validatable" }]
        
        resolver.resolve(result, context)
        
        user = result.classes.first
        expect(user[:available_instance_methods]).to include("validate", "valid?")
      end

      it "handles unknown mixin modules" do
        result.classes.first[:mixins] = [{ type: "include", module: "NonExistent" }]
        
        expect { resolver.resolve(result, context) }.not_to raise_error
        
        user = result.classes.first
        expect(user[:available_instance_methods]).to eq(["save"])
      end

      it "handles classes without mixins" do
        result.classes.first[:mixins] = []
        
        resolver.resolve(result, context)
        
        user = result.classes.first
        expect(user[:available_instance_methods]).to eq(["save"])
      end
    end
  end
end