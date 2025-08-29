# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Deduplication::Deduplicator do
  let(:merge_strategy) { instance_double(Rubymap::Normalizer::Deduplication::MergeStrategy) }
  subject(:deduplicator) { described_class.new(merge_strategy) }

  describe "behavior when deduplicating symbols" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }

    context "when deduplicating methods with unique symbol IDs" do
      let(:method1) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "unique_method_1",
          name: "find",
          fqname: "User#find"
        )
      end

      let(:method2) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "unique_method_2",
          name: "save",
          fqname: "User#save"
        )
      end

      before do
        result.methods = [method1, method2]
      end

      it "preserves methods with unique symbol IDs without merging" do
        allow(merge_strategy).to receive(:merge_methods)

        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(2)
        expect(result.methods).to include(method1, method2)
        expect(merge_strategy).not_to have_received(:merge_methods)
      end

      it "maintains original method order for unique methods" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.first.symbol_id).to eq("unique_method_1")
        expect(result.methods.last.symbol_id).to eq("unique_method_2")
      end
    end

    context "when deduplicating methods with duplicate symbol IDs" do
      let(:method1) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "duplicate_method",
          name: "find",
          fqname: "User#find",
          visibility: "public"
        )
      end

      let(:method2) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "duplicate_method",
          name: "find",
          fqname: "User#find",
          visibility: "private"
        )
      end

      let(:merged_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "duplicate_method",
          name: "find",
          fqname: "User#find",
          visibility: "private"  # Most restrictive
        )
      end

      before do
        result.methods = [method1, method2]
        allow(merge_strategy).to receive(:merge_methods).with([method1, method2]).and_return(merged_method)
      end

      it "groups methods by symbol ID and merges duplicates" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first).to eq(merged_method)
        expect(merge_strategy).to have_received(:merge_methods).with([method1, method2])
      end

      it "delegates merging logic to merge strategy" do
        deduplicator.deduplicate_symbols(result)

        expect(merge_strategy).to have_received(:merge_methods).once
      end
    end

    context "when deduplicating classes with unique symbol IDs" do
      let(:class1) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "unique_class_1",
          name: "User",
          fqname: "App::User"
        )
      end

      let(:class2) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "unique_class_2",
          name: "Admin",
          fqname: "App::Admin"
        )
      end

      before do
        result.classes = [class1, class2]
      end

      it "preserves classes with unique symbol IDs without merging" do
        allow(merge_strategy).to receive(:merge_classes)

        deduplicator.deduplicate_symbols(result)

        expect(result.classes.size).to eq(2)
        expect(result.classes).to include(class1, class2)
        expect(merge_strategy).not_to have_received(:merge_classes)
      end
    end

    context "when deduplicating classes with duplicate symbol IDs" do
      let(:class1) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "duplicate_class",
          name: "User",
          fqname: "App::User",
          superclass: nil
        )
      end

      let(:class2) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "duplicate_class",
          name: "User",
          fqname: "App::User",
          superclass: "ApplicationRecord"
        )
      end

      let(:merged_class) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "duplicate_class",
          name: "User",
          fqname: "App::User",
          superclass: "ApplicationRecord"
        )
      end

      before do
        result.classes = [class1, class2]
        allow(merge_strategy).to receive(:merge_classes).with([class1, class2]).and_return(merged_class)
      end

      it "groups classes by symbol ID and merges duplicates" do
        deduplicator.deduplicate_symbols(result)

        expect(result.classes.size).to eq(1)
        expect(result.classes.first).to eq(merged_class)
        expect(merge_strategy).to have_received(:merge_classes).with([class1, class2])
      end
    end

    context "when deduplicating modules with duplicate symbol IDs" do
      let(:module1) do
        Rubymap::Normalizer::NormalizedModule.new(
          symbol_id: "duplicate_module",
          name: "Searchable",
          fqname: "App::Searchable"
        )
      end

      let(:module2) do
        Rubymap::Normalizer::NormalizedModule.new(
          symbol_id: "duplicate_module",
          name: "Searchable",
          fqname: "App::Searchable"
        )
      end

      let(:merged_module) do
        Rubymap::Normalizer::NormalizedModule.new(
          symbol_id: "duplicate_module",
          name: "Searchable",
          fqname: "App::Searchable"
        )
      end

      before do
        result.modules = [module1, module2]
        allow(merge_strategy).to receive(:merge_modules).with([module1, module2]).and_return(merged_module)
      end

      it "groups modules by symbol ID and merges duplicates" do
        deduplicator.deduplicate_symbols(result)

        expect(result.modules.size).to eq(1)
        expect(result.modules.first).to eq(merged_module)
        expect(merge_strategy).to have_received(:merge_modules).with([module1, module2])
      end
    end

    context "when processing mixed symbol types with complex duplication" do
      let(:method1) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_1", name: "find") }
      let(:method2) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_1", name: "find") }
      let(:method3) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_2", name: "save") }
      let(:merged_method) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_1", name: "find") }

      let(:class1) { Rubymap::Normalizer::NormalizedClass.new(symbol_id: "class_1", name: "User") }
      let(:class2) { Rubymap::Normalizer::NormalizedClass.new(symbol_id: "class_1", name: "User") }
      let(:merged_class) { Rubymap::Normalizer::NormalizedClass.new(symbol_id: "class_1", name: "User") }

      before do
        result.methods = [method1, method2, method3]
        result.classes = [class1, class2]

        allow(merge_strategy).to receive(:merge_methods).with([method1, method2]).and_return(merged_method)
        allow(merge_strategy).to receive(:merge_classes).with([class1, class2]).and_return(merged_class)
      end

      it "processes all symbol types independently" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(2)  # 1 merged + 1 unique
        expect(result.classes.size).to eq(1)  # 1 merged

        expect(merge_strategy).to have_received(:merge_methods).once
        expect(merge_strategy).to have_received(:merge_classes).once
      end

      it "preserves symbols that don't have duplicates" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods).to include(method3)  # Unique method preserved
      end
    end

    context "when processing multiple groups of duplicates" do
      let(:method1a) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_1", name: "find") }
      let(:method1b) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_1", name: "find") }
      let(:method2a) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_2", name: "save") }
      let(:method2b) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_2", name: "save") }

      let(:merged_method1) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_1", name: "find") }
      let(:merged_method2) { Rubymap::Normalizer::NormalizedMethod.new(symbol_id: "method_group_2", name: "save") }

      before do
        result.methods = [method1a, method1b, method2a, method2b]

        allow(merge_strategy).to receive(:merge_methods).with([method1a, method1b]).and_return(merged_method1)
        allow(merge_strategy).to receive(:merge_methods).with([method2a, method2b]).and_return(merged_method2)
      end

      it "merges each group of duplicates separately" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(2)
        expect(result.methods).to include(merged_method1, merged_method2)

        expect(merge_strategy).to have_received(:merge_methods).twice
      end
    end
  end

  describe "edge case behavior" do
    let(:result) { Rubymap::Normalizer::NormalizedResult.new }

    context "when processing empty symbol collections" do
      it "handles empty methods collection gracefully" do
        result.methods = []
        result.classes = []
        result.modules = []

        expect { deduplicator.deduplicate_symbols(result) }.not_to raise_error

        expect(result.methods).to be_empty
        expect(result.classes).to be_empty
        expect(result.modules).to be_empty
      end
    end

    context "when processing symbols with nil symbol IDs" do
      let(:method_with_nil_id) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: nil,
          name: "problematic_method"
        )
      end

      before do
        result.methods = [method_with_nil_id]
      end

      it "groups symbols with nil IDs together" do
        # This tests that nil keys are handled properly by group_by
        expect { deduplicator.deduplicate_symbols(result) }.not_to raise_error

        # Should still have one method (no merging for single item group)
        expect(result.methods.size).to eq(1)
        expect(result.methods.first).to eq(method_with_nil_id)
      end
    end

    context "when processing symbols with empty string symbol IDs" do
      let(:method1) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "",
          name: "method1"
        )
      end

      let(:method2) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "",
          name: "method2"
        )
      end

      let(:merged_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "",
          name: "merged"
        )
      end

      before do
        result.methods = [method1, method2]
        allow(merge_strategy).to receive(:merge_methods).with([method1, method2]).and_return(merged_method)
      end

      it "treats empty string symbol IDs as duplicates" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first).to eq(merged_method)
        expect(merge_strategy).to have_received(:merge_methods).with([method1, method2])
      end
    end

    context "when processing large numbers of duplicates" do
      let(:duplicate_methods) do
        (1..100).map do |i|
          Rubymap::Normalizer::NormalizedMethod.new(
            symbol_id: "duplicate_method",
            name: "method_#{i}"
          )
        end
      end

      let(:merged_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "duplicate_method",
          name: "merged_method"
        )
      end

      before do
        result.methods = duplicate_methods
        allow(merge_strategy).to receive(:merge_methods).with(duplicate_methods).and_return(merged_method)
      end

      it "handles large groups of duplicates efficiently" do
        deduplicator.deduplicate_symbols(result)

        expect(result.methods.size).to eq(1)
        expect(result.methods.first).to eq(merged_method)
        expect(merge_strategy).to have_received(:merge_methods).once.with(duplicate_methods)
      end
    end
  end
end
