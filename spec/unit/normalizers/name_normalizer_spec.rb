# frozen_string_literal: true

RSpec.describe Rubymap::Normalizer::Normalizers::NameNormalizer do
  subject(:name_normalizer) { described_class.new }

  describe "behavior when generating fully qualified names" do
    context "when namespace is provided" do
      it "combines namespace and name with double colon separator" do
        fqname = name_normalizer.generate_fqname("User", "App")

        expect(fqname).to eq("App::User")
      end

      it "handles nested namespaces correctly" do
        fqname = name_normalizer.generate_fqname("User", "App::Models")

        expect(fqname).to eq("App::Models::User")
      end

      it "handles deeply nested namespaces" do
        fqname = name_normalizer.generate_fqname("Service", "App::Authentication::External::OAuth")

        expect(fqname).to eq("App::Authentication::External::OAuth::Service")
      end

      it "handles namespace with leading double colon" do
        fqname = name_normalizer.generate_fqname("User", "::App")

        expect(fqname).to eq("::App::User")
      end

      it "handles namespace with trailing double colon" do
        fqname = name_normalizer.generate_fqname("User", "App::")

        expect(fqname).to eq("App::::User")  # Preserves the structure as-is
      end
    end

    context "when namespace is nil" do
      it "returns the name unchanged" do
        fqname = name_normalizer.generate_fqname("User", nil)

        expect(fqname).to eq("User")
      end
    end

    context "when namespace is empty string" do
      it "returns the name unchanged" do
        fqname = name_normalizer.generate_fqname("User", "")

        expect(fqname).to eq("User")
      end
    end

    context "when namespace is empty after trimming" do
      it "treats whitespace-only namespace as empty" do
        fqname = name_normalizer.generate_fqname("User", "   ")

        expect(fqname).to eq("User")
      end
    end

    context "when handling edge case inputs" do
      it "handles empty name with namespace" do
        fqname = name_normalizer.generate_fqname("", "App")

        expect(fqname).to eq("App::")
      end

      it "handles nil name gracefully" do
        fqname = name_normalizer.generate_fqname(nil, "App")

        expect(fqname).to eq("App::")
      end

      it "handles both nil name and namespace" do
        fqname = name_normalizer.generate_fqname(nil, nil)

        expect(fqname).to be_nil
      end

      it "handles symbol names" do
        fqname = name_normalizer.generate_fqname(:user, "App")

        expect(fqname).to eq("App::user")
      end

      it "handles numeric names" do
        fqname = name_normalizer.generate_fqname(123, "App")

        expect(fqname).to eq("App::123")
      end
    end
  end

  describe "behavior when extracting namespace paths" do
    context "when name contains namespace separators" do
      it "extracts namespace path from fully qualified name" do
        path = name_normalizer.extract_namespace_path("App::Models::User")

        expect(path).to eq(["App", "Models"])
      end

      it "extracts single namespace component" do
        path = name_normalizer.extract_namespace_path("App::User")

        expect(path).to eq(["App"])
      end

      it "extracts deeply nested namespace path" do
        path = name_normalizer.extract_namespace_path("App::Authentication::OAuth::Google::Service")

        expect(path).to eq(["App", "Authentication", "OAuth", "Google"])
      end

      it "handles leading double colon in global namespace" do
        path = name_normalizer.extract_namespace_path("::App::User")

        expect(path).to eq(["", "App"])  # Empty string represents global namespace
      end

      it "handles multiple consecutive double colons" do
        path = name_normalizer.extract_namespace_path("App::::User")

        expect(path).to eq(["App", "", ""])  # Empty strings represent malformed namespace
      end
    end

    context "when name has no namespace separators" do
      it "returns empty array for simple names" do
        path = name_normalizer.extract_namespace_path("User")

        expect(path).to eq([])
      end

      it "returns empty array for empty string" do
        path = name_normalizer.extract_namespace_path("")

        expect(path).to eq([])
      end

      it "handles single colon (not double colon)" do
        path = name_normalizer.extract_namespace_path("App:User")

        expect(path).to eq([])
      end
    end

    context "when handling edge case inputs" do
      it "handles nil name gracefully" do
        expect { name_normalizer.extract_namespace_path(nil) }.to raise_error(NoMethodError)
      end

      it "handles names that are only double colons" do
        path = name_normalizer.extract_namespace_path("::")

        expect(path).to eq([""])
      end

      it "handles names ending with double colon" do
        path = name_normalizer.extract_namespace_path("App::")

        expect(path).to eq([""])  # Last part after final :: is empty
      end

      it "handles symbol names with namespaces" do
        path = name_normalizer.extract_namespace_path(:"App::Models::user")

        expect(path).to eq(["App", "Models"])
      end
    end

    context "when name has complex namespace structures" do
      it "handles namespace with numbers" do
        path = name_normalizer.extract_namespace_path("V1::Api::User")

        expect(path).to eq(["V1", "Api"])
      end

      it "handles namespace with special characters in component names" do
        path = name_normalizer.extract_namespace_path("App_Config::Models_V2::User")

        expect(path).to eq(["App_Config", "Models_V2"])
      end

      it "preserves case in namespace components" do
        path = name_normalizer.extract_namespace_path("myApp::MyModels::MyUser")

        expect(path).to eq(["myApp", "MyModels"])
      end
    end
  end

  describe "behavior when converting names to snake_case" do
    context "when converting CamelCase names" do
      it "converts simple CamelCase to snake_case" do
        snake_case = name_normalizer.to_snake_case("UserService")

        expect(snake_case).to eq("user_service")
      end

      it "converts PascalCase to snake_case" do
        snake_case = name_normalizer.to_snake_case("XMLHttpRequest")

        expect(snake_case).to eq("xml_http_request")
      end

      it "handles consecutive uppercase letters" do
        snake_case = name_normalizer.to_snake_case("HTTPSConnection")

        expect(snake_case).to eq("https_connection")
      end

      it "handles mixed case with numbers" do
        snake_case = name_normalizer.to_snake_case("OAuth2Provider")

        expect(snake_case).to eq("o_auth2_provider")
      end

      it "handles acronyms followed by lowercase" do
        snake_case = name_normalizer.to_snake_case("URLParser")

        expect(snake_case).to eq("url_parser")
      end
    end

    context "when handling already snake_case names" do
      it "leaves snake_case names unchanged" do
        snake_case = name_normalizer.to_snake_case("user_service")

        expect(snake_case).to eq("user_service")
      end

      it "handles names with numbers in snake_case" do
        snake_case = name_normalizer.to_snake_case("oauth2_provider")

        expect(snake_case).to eq("oauth2_provider")
      end

      it "handles single word names" do
        snake_case = name_normalizer.to_snake_case("user")

        expect(snake_case).to eq("user")
      end
    end

    context "when handling special cases" do
      it "handles empty strings" do
        snake_case = name_normalizer.to_snake_case("")

        expect(snake_case).to eq("")
      end

      it "handles single character names" do
        snake_case = name_normalizer.to_snake_case("A")

        expect(snake_case).to eq("a")
      end

      it "handles lowercase single character names" do
        snake_case = name_normalizer.to_snake_case("a")

        expect(snake_case).to eq("a")
      end

      it "handles names with leading numbers" do
        snake_case = name_normalizer.to_snake_case("2Factor")

        expect(snake_case).to eq("2_factor")
      end

      it "handles names that are all uppercase" do
        snake_case = name_normalizer.to_snake_case("XML")

        expect(snake_case).to eq("xml")
      end

      it "handles names with underscores and CamelCase mixed" do
        snake_case = name_normalizer.to_snake_case("user_XMLService")

        expect(snake_case).to eq("user_xml_service")
      end
    end

    context "when handling edge case inputs" do
      it "handles nil input gracefully" do
        expect { name_normalizer.to_snake_case(nil) }.to raise_error(NoMethodError)
      end

      it "handles symbol input" do
        snake_case = name_normalizer.to_snake_case(:UserService)

        expect(snake_case).to eq("user_service")
      end

      it "handles numeric input" do
        snake_case = name_normalizer.to_snake_case(123)

        expect(snake_case).to eq("123")
      end
    end

    context "when handling complex naming patterns" do
      it "handles names with multiple consecutive uppercase letters" do
        snake_case = name_normalizer.to_snake_case("HTTPSURLParser")

        expect(snake_case).to eq("httpsurl_parser")
      end

      it "handles names with mixed separators" do
        snake_case = name_normalizer.to_snake_case("HTML_XMLParser")

        expect(snake_case).to eq("html_xml_parser")
      end

      it "handles names starting with lowercase" do
        snake_case = name_normalizer.to_snake_case("iPhone")

        expect(snake_case).to eq("i_phone")
      end

      it "handles names with special characters" do
        snake_case = name_normalizer.to_snake_case("User-Service")

        expect(snake_case).to eq("user-service")  # Non-word characters preserved
      end
    end
  end

  describe "integration behavior across methods" do
    context "when processing complex namespace scenarios" do
      it "works correctly with generated fqname and namespace extraction" do
        original_name = "User"
        namespace = "App::Models"

        fqname = name_normalizer.generate_fqname(original_name, namespace)
        extracted_path = name_normalizer.extract_namespace_path(fqname)

        expect(fqname).to eq("App::Models::User")
        expect(extracted_path).to eq(["App", "Models"])
      end

      it "roundtrip processing maintains consistency" do
        test_cases = [
          ["User", "App"],
          ["Service", "App::Authentication"],
          ["Parser", ""],
          ["Handler", nil]
        ]

        test_cases.each do |name, namespace|
          next if namespace.nil? || namespace.empty?

          fqname = name_normalizer.generate_fqname(name, namespace)
          extracted_path = name_normalizer.extract_namespace_path(fqname)
          expected_path = namespace.split("::")

          expect(extracted_path).to eq(expected_path),
            "Failed for name: #{name}, namespace: #{namespace}"
        end
      end
    end

    context "when processing names with mixed conventions" do
      it "handles CamelCase names with namespaces" do
        fqname = name_normalizer.generate_fqname("UserService", "App::Models")
        snake_case = name_normalizer.to_snake_case("UserService")

        expect(fqname).to eq("App::Models::UserService")
        expect(snake_case).to eq("user_service")
      end
    end
  end
end
