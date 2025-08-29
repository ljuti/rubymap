# frozen_string_literal: true

require_relative "../../support/emitter_test_data"

RSpec.shared_examples "a security-conscious emitter" do
  include EmitterTestData
  describe "security and redaction features" do
    let(:sensitive_data) { EmitterTestData.with_sensitive_information }

    context "when configured with redaction rules" do
      let(:redaction_config) do
        {
          patterns: [/password/i, /secret/i, /token/i],
          replacement: "[REDACTED]"
        }
      end

      before do
        subject.configure_redaction(redaction_config)
      end

      it "redacts sensitive patterns in method names" do
        output = subject.emit(sensitive_data)

        expect(output).to include("[REDACTED]")
        expect(output.include?("set_password")).to be false
        expect(output.include?("api_secret")).to be false
      end

      it "redacts sensitive patterns in documentation" do
        output = subject.emit(sensitive_data)

        expect(output.include?("Contains user password")).to be false
        expect(output).to include("Contains user [REDACTED]")
      end

      it "preserves non-sensitive information" do
        output = subject.emit(sensitive_data)

        expect(output).to include("User")
        expect(output).to include("save")
        expect(output).to include("validate")
      end
    end

    context "when configured for different security levels" do
      it "supports minimal redaction for internal use" do
        subject.configure_security_level(:internal)
        output = subject.emit(sensitive_data)

        # Internal level might redact only critical secrets
        expect(output.include?("database_password")).to be false
        expect(output).to include("user_token") # Less critical, kept for internal docs
      end

      it "supports aggressive redaction for external documentation" do
        subject.configure_security_level(:external)
        output = subject.emit(sensitive_data)

        # External level redacts all potentially sensitive information
        expect(output.include?("database_password")).to be false
        expect(output.include?("user_token")).to be false
        expect(output.include?("internal_api")).to be false
      end
    end

    context "when handling file paths" do
      it "sanitizes absolute file paths to relative paths" do
        data_with_paths = EmitterTestData.with_absolute_paths
        output = subject.emit(data_with_paths)

        expect(output.include?("/Users/")).to be false
        expect(output.include?("/home/")).to be false
        expect(output).to include("app/models/")
      end

      it "removes system-specific path separators" do
        output = subject.emit(sensitive_data)

        # Should normalize to forward slashes regardless of OS
        expect(output =~ %r{\\}).to be_nil
        expect(output).to match(%r{app/models/user\.rb})
      end
    end
  end
end
