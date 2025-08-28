# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Normalizers::VisibilityNormalizer do
  subject(:visibility_normalizer) { described_class.new }

  describe "behavior when normalizing visibility values" do
    let(:errors) { [] }

    context "when processing valid visibility symbols" do
      it "normalizes :public symbol to public string" do
        result = visibility_normalizer.normalize(:public, errors)

        expect(result).to eq("public")
        expect(errors).to be_empty
      end

      it "normalizes :private symbol to private string" do
        result = visibility_normalizer.normalize(:private, errors)

        expect(result).to eq("private")
        expect(errors).to be_empty
      end

      it "normalizes :protected symbol to protected string" do
        result = visibility_normalizer.normalize(:protected, errors)

        expect(result).to eq("protected")
        expect(errors).to be_empty
      end
    end

    context "when processing valid visibility strings" do
      it "normalizes public string to public string" do
        result = visibility_normalizer.normalize("public", errors)

        expect(result).to eq("public")
        expect(errors).to be_empty
      end

      it "normalizes private string to private string" do
        result = visibility_normalizer.normalize("private", errors)

        expect(result).to eq("private")
        expect(errors).to be_empty
      end

      it "normalizes protected string to protected string" do
        result = visibility_normalizer.normalize("protected", errors)

        expect(result).to eq("protected")
        expect(errors).to be_empty
      end
    end

    context "when processing nil visibility" do
      it "defaults nil visibility to public" do
        result = visibility_normalizer.normalize(nil, errors)

        expect(result).to eq("public")
        expect(errors).to be_empty
      end

      it "handles nil visibility without errors array" do
        result = visibility_normalizer.normalize(nil)

        expect(result).to eq("public")
      end
    end

    context "when processing invalid visibility values" do
      it "normalizes unknown string to public and adds error" do
        result = visibility_normalizer.normalize("invalid", errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("invalid visibility: invalid")
        expect(errors.first.data).to eq({visibility: "invalid"})
      end

      it "normalizes unknown symbol to public and adds error" do
        result = visibility_normalizer.normalize(:unknown, errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("invalid visibility: unknown")
        expect(errors.first.data).to eq({visibility: :unknown})
      end

      it "handles non-string non-symbol types and adds error when errors array provided" do
        result = visibility_normalizer.normalize(123, errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("invalid visibility: 123")
        expect(errors.first.data).to eq({visibility: 123})
      end

      it "handles array input and adds error when errors array provided" do
        result = visibility_normalizer.normalize(["public"], errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.type).to eq("validation")
        expect(errors.first.message).to eq("invalid visibility: [\"public\"]")
        expect(errors.first.data).to eq({visibility: ["public"]})
      end

      it "handles hash input and adds error when errors array provided" do
        result = visibility_normalizer.normalize({visibility: "public"}, errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility: {:visibility=>\"public\"}")
      end
    end

    context "when errors array is not provided" do
      it "handles invalid visibility without errors array gracefully" do
        result = visibility_normalizer.normalize("invalid")

        expect(result).to eq("public")
        # No errors array means no error recording, but still graceful handling
      end

      it "handles nil errors array gracefully" do
        result = visibility_normalizer.normalize("invalid", nil)

        expect(result).to eq("public")
      end
    end

    context "when processing edge case visibility values" do
      it "handles empty string visibility" do
        result = visibility_normalizer.normalize("", errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility: ")
      end

      it "handles whitespace-only visibility" do
        result = visibility_normalizer.normalize("   ", errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility:    ")
      end

      it "handles case-sensitive variations" do
        result = visibility_normalizer.normalize("Public", errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility: Public")
      end

      it "handles boolean true" do
        result = visibility_normalizer.normalize(true, errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility: true")
      end

      it "handles boolean false" do
        result = visibility_normalizer.normalize(false, errors)

        expect(result).to eq("public")
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("invalid visibility: false")
      end
    end
  end

  describe "behavior when inferring visibility from method names" do
    context "when processing method names with visibility indicators" do
      it "infers private visibility for names starting with underscore" do
        result = visibility_normalizer.infer_from_name("_private_method")

        expect(result).to eq("private")
      end

      it "infers private visibility for names starting with multiple underscores" do
        result = visibility_normalizer.infer_from_name("__very_private_method")

        expect(result).to eq("private")
      end

      it "infers public visibility for normal method names" do
        result = visibility_normalizer.infer_from_name("public_method")

        expect(result).to eq("public")
      end

      it "infers public visibility for camelCase method names" do
        result = visibility_normalizer.infer_from_name("publicMethod")

        expect(result).to eq("public")
      end

      it "infers public visibility for method names with numbers" do
        result = visibility_normalizer.infer_from_name("method2")

        expect(result).to eq("public")
      end

      it "infers public visibility for method names with special characters (not underscore prefix)" do
        result = visibility_normalizer.infer_from_name("method!")

        expect(result).to eq("public")
      end

      it "infers public visibility for method names with question mark" do
        result = visibility_normalizer.infer_from_name("valid?")

        expect(result).to eq("public")
      end
    end

    context "when processing edge case method names" do
      it "handles nil method name gracefully" do
        result = visibility_normalizer.infer_from_name(nil)

        expect(result).to eq("public")
      end

      it "handles empty string method name" do
        result = visibility_normalizer.infer_from_name("")

        expect(result).to eq("public")
      end

      it "handles symbol method names starting with underscore" do
        result = visibility_normalizer.infer_from_name(:_private_method)

        expect(result).to eq("private")
      end

      it "handles symbol method names not starting with underscore" do
        result = visibility_normalizer.infer_from_name(:public_method)

        expect(result).to eq("public")
      end

      it "handles numeric method names" do
        result = visibility_normalizer.infer_from_name(123)

        expect(result).to eq("public")
      end

      it "handles single underscore as method name" do
        result = visibility_normalizer.infer_from_name("_")

        expect(result).to eq("private")
      end

      it "handles method name that is just underscores" do
        result = visibility_normalizer.infer_from_name("___")

        expect(result).to eq("private")
      end

      it "handles method names with underscore in middle" do
        result = visibility_normalizer.infer_from_name("public_method_name")

        expect(result).to eq("public")
      end

      it "handles method names with underscore at end" do
        result = visibility_normalizer.infer_from_name("method_")

        expect(result).to eq("public")
      end
    end
  end

  describe "behavior when determining most restrictive visibility" do
    context "when comparing different visibility levels" do
      it "selects private as most restrictive when private is present" do
        result = visibility_normalizer.get_most_restrictive(["public", "private", "protected"])

        expect(result).to eq("private")
      end

      it "selects protected as most restrictive when no private is present" do
        result = visibility_normalizer.get_most_restrictive(["public", "protected"])

        expect(result).to eq("protected")
      end

      it "selects public when only public is present" do
        result = visibility_normalizer.get_most_restrictive(["public"])

        expect(result).to eq("public")
      end

      it "selects public when only public visibilities are present" do
        result = visibility_normalizer.get_most_restrictive(["public", "public", "public"])

        expect(result).to eq("public")
      end
    end

    context "when handling edge cases in visibility comparison" do
      it "handles empty visibility array" do
        result = visibility_normalizer.get_most_restrictive([])

        expect(result).to eq("public")
      end

      it "handles array with nil values" do
        result = visibility_normalizer.get_most_restrictive([nil, "public", "private"])

        expect(result).to eq("private")
      end

      it "handles array with only nil values" do
        result = visibility_normalizer.get_most_restrictive([nil, nil, nil])

        expect(result).to eq("public")
      end

      it "filters out duplicate visibilities" do
        result = visibility_normalizer.get_most_restrictive(["private", "private", "public", "private"])

        expect(result).to eq("private")
      end

      it "handles mixed case (though this shouldn't happen after normalization)" do
        result = visibility_normalizer.get_most_restrictive(["Public", "private"])

        # Since "Public" is not recognized as a valid normalized visibility,
        # it won't be included in the restrictiveness check
        expect(result).to eq("private")
      end
    end

    context "when processing complex visibility scenarios" do
      it "handles all visibility levels present" do
        result = visibility_normalizer.get_most_restrictive(["protected", "private", "public"])

        expect(result).to eq("private")
      end

      it "handles reversed order input" do
        result = visibility_normalizer.get_most_restrictive(["private", "protected", "public"])

        expect(result).to eq("private")
      end

      it "handles single protected visibility" do
        result = visibility_normalizer.get_most_restrictive(["protected"])

        expect(result).to eq("protected")
      end

      it "handles single private visibility" do
        result = visibility_normalizer.get_most_restrictive(["private"])

        expect(result).to eq("private")
      end

      it "prioritizes private over protected even when protected comes last" do
        result = visibility_normalizer.get_most_restrictive(["private", "public", "protected"])

        expect(result).to eq("private")
      end

      it "prioritizes protected over public even when public comes last" do
        result = visibility_normalizer.get_most_restrictive(["protected", "public"])

        expect(result).to eq("protected")
      end
    end

    context "when dealing with invalid visibility values" do
      it "ignores invalid visibility values" do
        result = visibility_normalizer.get_most_restrictive(["invalid", "public", "private"])

        expect(result).to eq("private")
      end

      it "defaults to public when all values are invalid" do
        result = visibility_normalizer.get_most_restrictive(["invalid1", "invalid2", "unknown"])

        expect(result).to eq("public")
      end

      it "handles empty strings in visibility array" do
        result = visibility_normalizer.get_most_restrictive(["", "private", "public"])

        expect(result).to eq("private")
      end
    end
  end

  describe "integration behavior across methods" do
    context "when using normalization with visibility inference" do
      let(:errors) { [] }

      it "normalizes explicit visibility and infers from method name consistently" do
        explicit_visibility = visibility_normalizer.normalize(:private, errors)
        inferred_visibility = visibility_normalizer.infer_from_name("_private_method")

        expect(explicit_visibility).to eq("private")
        expect(inferred_visibility).to eq("private")
        expect(errors).to be_empty
      end

      it "handles conflict between explicit and inferred visibility in most restrictive selection" do
        explicit_public = visibility_normalizer.normalize("public", errors)
        inferred_private = visibility_normalizer.infer_from_name("_method")
        most_restrictive = visibility_normalizer.get_most_restrictive([explicit_public, inferred_private])

        expect(most_restrictive).to eq("private")
      end
    end

    context "when processing method visibility workflow" do
      let(:errors) { [] }

      it "handles complete visibility processing workflow" do
        # Simulate a method with ambiguous visibility information
        method_name = "_internal_process"
        explicit_visibility = nil

        # Normalize explicit visibility
        normalized_visibility = visibility_normalizer.normalize(explicit_visibility, errors)

        # Infer from method name
        inferred_visibility = visibility_normalizer.infer_from_name(method_name)

        # Determine most restrictive
        final_visibility = visibility_normalizer.get_most_restrictive([normalized_visibility, inferred_visibility])

        expect(normalized_visibility).to eq("public")  # nil defaults to public
        expect(inferred_visibility).to eq("private")   # underscore prefix infers private
        expect(final_visibility).to eq("private")      # private is most restrictive
        expect(errors).to be_empty
      end
    end
  end
end
