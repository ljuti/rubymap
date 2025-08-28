# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Deduplication::MergeStrategy do
  let(:provenance_tracker) { instance_double(Rubymap::Normalizer::ProvenanceTracker) }
  let(:visibility_normalizer) { instance_double(Rubymap::Normalizer::Normalizers::VisibilityNormalizer) }

  subject(:merge_strategy) do
    described_class.new(provenance_tracker, visibility_normalizer)
  end

  describe "behavior when merging methods" do
    let(:static_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static]],
        confidence: 0.75
      )
    end

    let(:runtime_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    let(:merged_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static], Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    context "when merging methods with different source precedence" do
      let(:static_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "find",
          fqname: "User#find",
          visibility: "public",
          provenance: static_provenance
        )
      end

      let(:runtime_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "find",
          fqname: "User#find",
          visibility: "private",
          provenance: runtime_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
        allow(visibility_normalizer).to receive(:get_most_restrictive).with(["public", "private"]).and_return("private")
      end

      it "selects primary method based on highest source precedence" do
        merged_method = merge_strategy.merge_methods([static_method, runtime_method])

        # Runtime has higher precedence (5) than static (6 in SOURCE_PRECEDENCE but -6 for sorting)
        expect(merged_method.name).to eq("find")
        expect(merged_method.fqname).to eq("User#find")
      end

      it "merges provenance from all methods" do
        merge_strategy.merge_methods([static_method, runtime_method])

        expect(provenance_tracker).to have_received(:merge_provenance).with(
          runtime_provenance, static_provenance
        )
      end

      it "updates merged method with combined provenance" do
        merged_method = merge_strategy.merge_methods([static_method, runtime_method])

        expect(merged_method.provenance).to eq(merged_provenance)
      end

      it "applies most restrictive visibility from all methods" do
        merged_method = merge_strategy.merge_methods([static_method, runtime_method])

        expect(visibility_normalizer).to have_received(:get_most_restrictive).with(["public", "private"])
        expect(merged_method.visibility).to eq("private")
      end

      it "creates a copy of primary method rather than modifying original" do
        original_runtime_method = runtime_method.dup
        merged_method = merge_strategy.merge_methods([static_method, runtime_method])

        expect(runtime_method).to eq(original_runtime_method)  # Original unchanged
        expect(merged_method).not_to be(runtime_method)  # Different object
      end
    end

    context "when merging methods with same source precedence" do
      let(:method1) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "process",
          visibility: "public",
          provenance: static_provenance
        )
      end

      let(:method2) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "process",
          visibility: "protected",
          provenance: static_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
        allow(visibility_normalizer).to receive(:get_most_restrictive).with(["public", "protected"]).and_return("protected")
      end

      it "selects first method as primary when precedence is equal" do
        merged_method = merge_strategy.merge_methods([method1, method2])

        expect(merged_method.name).to eq("process")
      end

      it "still applies most restrictive visibility" do
        merged_method = merge_strategy.merge_methods([method1, method2])

        expect(merged_method.visibility).to eq("protected")
      end
    end

    context "when merging methods with nil visibilities" do
      let(:method_with_visibility) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "find",
          visibility: "private",
          provenance: static_provenance
        )
      end

      let(:method_without_visibility) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "find",
          visibility: nil,
          provenance: runtime_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
        allow(visibility_normalizer).to receive(:get_most_restrictive).with(["private"]).and_return("private")
      end

      it "filters out nil visibilities before determining most restrictive" do
        merge_strategy.merge_methods([method_with_visibility, method_without_visibility])

        expect(visibility_normalizer).to have_received(:get_most_restrictive).with(["private"])
      end
    end

    context "when merging single method" do
      let(:single_method) do
        Rubymap::Normalizer::NormalizedMethod.new(
          symbol_id: "method123",
          name: "single",
          visibility: "public",
          provenance: static_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(static_provenance)
        allow(visibility_normalizer).to receive(:get_most_restrictive).with(["public"]).and_return("public")
      end

      it "returns the single method as primary with merged provenance" do
        merged_method = merge_strategy.merge_methods([single_method])

        expect(merged_method.name).to eq("single")
        expect(merged_method.visibility).to eq("public")
        expect(merged_method.provenance).to eq(static_provenance)
      end
    end
  end

  describe "behavior when merging classes" do
    let(:static_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static]],
        confidence: 0.75
      )
    end

    let(:runtime_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    let(:merged_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static], Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    context "when merging classes with different superclass information" do
      let(:inferred_class) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "User",
          fqname: "App::User",
          superclass: nil,
          provenance: Rubymap::Normalizer::Provenance.new(
            sources: [Rubymap::Normalizer::DATA_SOURCES[:inferred]],
            confidence: 0.5
          )
        )
      end

      let(:static_class) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "User",
          fqname: "App::User",
          superclass: "ApplicationRecord",
          provenance: static_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
      end

      it "selects primary class based on highest source precedence" do
        merged_class = merge_strategy.merge_classes([inferred_class, static_class])

        # Static has higher precedence than inferred
        expect(merged_class.name).to eq("User")
        expect(merged_class.fqname).to eq("App::User")
      end

      it "merges provenance from all classes" do
        merge_strategy.merge_classes([inferred_class, static_class])

        expect(provenance_tracker).to have_received(:merge_provenance)
      end

      it "selects most reliable superclass from highest precedence source" do
        merged_class = merge_strategy.merge_classes([inferred_class, static_class])

        expect(merged_class.superclass).to eq("ApplicationRecord")
      end

      it "creates a copy of primary class rather than modifying original" do
        original_static_class = static_class.dup
        merged_class = merge_strategy.merge_classes([inferred_class, static_class])

        expect(static_class).to eq(original_static_class)
        expect(merged_class).not_to be(static_class)
      end
    end

    context "when merging classes where all have nil superclass" do
      let(:class1) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "SimpleClass",
          superclass: nil,
          provenance: static_provenance
        )
      end

      let(:class2) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "SimpleClass",
          superclass: nil,
          provenance: runtime_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
      end

      it "results in nil superclass when no superclass information is available" do
        merged_class = merge_strategy.merge_classes([class1, class2])

        expect(merged_class.superclass).to be_nil
      end
    end

    context "when merging classes with multiple different superclasses" do
      let(:class_with_super1) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "User",
          superclass: "BaseClass",
          provenance: Rubymap::Normalizer::Provenance.new(
            sources: [Rubymap::Normalizer::DATA_SOURCES[:yard]],
            confidence: 0.8
          )
        )
      end

      let(:class_with_super2) do
        Rubymap::Normalizer::NormalizedClass.new(
          symbol_id: "class123",
          name: "User",
          superclass: "ApplicationRecord",
          provenance: static_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
      end

      it "selects superclass from highest precedence source" do
        merged_class = merge_strategy.merge_classes([class_with_super1, class_with_super2])

        # Static (precedence 6) beats YARD (precedence 2)
        expect(merged_class.superclass).to eq("ApplicationRecord")
      end
    end
  end

  describe "behavior when merging modules" do
    let(:static_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static]],
        confidence: 0.75
      )
    end

    let(:runtime_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    let(:merged_provenance) do
      Rubymap::Normalizer::Provenance.new(
        sources: [Rubymap::Normalizer::DATA_SOURCES[:static], Rubymap::Normalizer::DATA_SOURCES[:runtime]],
        confidence: 0.85
      )
    end

    context "when merging modules with different source precedence" do
      let(:static_module) do
        Rubymap::Normalizer::NormalizedModule.new(
          symbol_id: "module123",
          name: "Searchable",
          fqname: "App::Searchable",
          provenance: static_provenance
        )
      end

      let(:runtime_module) do
        Rubymap::Normalizer::NormalizedModule.new(
          symbol_id: "module123",
          name: "Searchable",
          fqname: "App::Searchable",
          provenance: runtime_provenance
        )
      end

      before do
        allow(provenance_tracker).to receive(:merge_provenance).and_return(merged_provenance)
      end

      it "selects primary module based on highest source precedence" do
        merged_module = merge_strategy.merge_modules([static_module, runtime_module])

        expect(merged_module.name).to eq("Searchable")
        expect(merged_module.fqname).to eq("App::Searchable")
      end

      it "merges provenance from all modules" do
        merge_strategy.merge_modules([static_module, runtime_module])

        expect(provenance_tracker).to have_received(:merge_provenance)
      end

      it "updates merged module with combined provenance" do
        merged_module = merge_strategy.merge_modules([static_module, runtime_module])

        expect(merged_module.provenance).to eq(merged_provenance)
      end

      it "creates a copy of primary module rather than modifying original" do
        original_runtime_module = runtime_module.dup
        merged_module = merge_strategy.merge_modules([static_module, runtime_module])

        expect(runtime_module).to eq(original_runtime_module)
        expect(merged_module).not_to be(runtime_module)
      end
    end
  end

  describe "source precedence calculation behavior" do
    subject(:precedence_calculation) { merge_strategy.send(:get_highest_source_precedence, provenance) }

    context "when provenance has valid sources" do
      let(:provenance) do
        Rubymap::Normalizer::Provenance.new(
          sources: [Rubymap::Normalizer::DATA_SOURCES[:static], Rubymap::Normalizer::DATA_SOURCES[:yard]],
          confidence: 0.8
        )
      end

      it "returns highest precedence among sources" do
        # Static has precedence 6, YARD has precedence 2
        expect(precedence_calculation).to eq(6)
      end
    end

    context "when provenance has unknown sources" do
      let(:provenance) do
        Rubymap::Normalizer::Provenance.new(
          sources: ["unknown_source", Rubymap::Normalizer::DATA_SOURCES[:runtime]],
          confidence: 0.8
        )
      end

      it "ignores unknown sources and returns known source precedence" do
        expect(precedence_calculation).to eq(5)  # Runtime precedence
      end
    end

    context "when provenance has only unknown sources" do
      let(:provenance) do
        Rubymap::Normalizer::Provenance.new(
          sources: ["unknown1", "unknown2"],
          confidence: 0.8
        )
      end

      it "returns 0 when all sources are unknown" do
        expect(precedence_calculation).to eq(0)
      end
    end

    context "when provenance is nil" do
      let(:provenance) { nil }

      it "returns 0 for nil provenance" do
        expect(precedence_calculation).to eq(0)
      end
    end

    context "when provenance sources are nil" do
      let(:provenance) do
        Rubymap::Normalizer::Provenance.new(
          sources: nil,
          confidence: 0.8
        )
      end

      it "returns 0 when sources are nil" do
        expect(precedence_calculation).to eq(0)
      end
    end

    context "when provenance sources are empty" do
      let(:provenance) do
        Rubymap::Normalizer::Provenance.new(
          sources: [],
          confidence: 0.8
        )
      end

      it "returns 0 for empty sources array" do
        expect(precedence_calculation).to eq(0)
      end
    end
  end

  describe "superclass selection behavior" do
    subject(:superclass_selection) { merge_strategy.send(:get_most_reliable_superclass, classes) }

    context "when classes have different superclasses" do
      let(:classes) do
        [
          Rubymap::Normalizer::NormalizedClass.new(
            superclass: "BaseClass",
            provenance: Rubymap::Normalizer::Provenance.new(sources: [Rubymap::Normalizer::DATA_SOURCES[:yard]])
          ),
          Rubymap::Normalizer::NormalizedClass.new(
            superclass: "ApplicationRecord",
            provenance: Rubymap::Normalizer::Provenance.new(sources: [Rubymap::Normalizer::DATA_SOURCES[:static]])
          )
        ]
      end

      it "selects superclass from class with highest precedence" do
        expect(superclass_selection).to eq("ApplicationRecord")
      end
    end

    context "when no classes have superclass" do
      let(:classes) do
        [
          Rubymap::Normalizer::NormalizedClass.new(superclass: nil),
          Rubymap::Normalizer::NormalizedClass.new(superclass: nil)
        ]
      end

      it "returns nil when no superclass information is available" do
        expect(superclass_selection).to be_nil
      end
    end

    context "when classes array is empty" do
      let(:classes) { [] }

      it "returns nil for empty classes array" do
        expect(superclass_selection).to be_nil
      end
    end

    context "when some classes have nil superclass" do
      let(:classes) do
        [
          Rubymap::Normalizer::NormalizedClass.new(
            superclass: nil,
            provenance: Rubymap::Normalizer::Provenance.new(sources: [Rubymap::Normalizer::DATA_SOURCES[:static]])
          ),
          Rubymap::Normalizer::NormalizedClass.new(
            superclass: "ApplicationRecord",
            provenance: Rubymap::Normalizer::Provenance.new(sources: [Rubymap::Normalizer::DATA_SOURCES[:yard]])
          )
        ]
      end

      it "selects first non-nil superclass from highest precedence class" do
        expect(superclass_selection).to eq("ApplicationRecord")
      end
    end
  end
end
