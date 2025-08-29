# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rubymap::Extractor::Services::NamespaceService do
  let(:service) { described_class.new }

  describe "#build_fqname" do
    it "builds fully qualified name from parts" do
      expect(service.build_fqname("MyApp", "Models", "User")).to eq("MyApp::Models::User")
    end

    it "handles array of parts" do
      expect(service.build_fqname(["MyApp", "Models", "User"])).to eq("MyApp::Models::User")
    end

    it "filters out nil parts" do
      expect(service.build_fqname("MyApp", nil, "User")).to eq("MyApp::User")
    end

    it "filters out empty string parts" do
      expect(service.build_fqname("MyApp", "", "User")).to eq("MyApp::User")
    end

    it "returns empty string for no valid parts" do
      expect(service.build_fqname(nil, "", nil)).to eq("")
    end

    it "handles nested arrays" do
      expect(service.build_fqname(["MyApp", ["Models", "User"]])).to eq("MyApp::Models::User")
    end
  end

  describe "#extract_namespace_path" do
    it "extracts namespace path from fully qualified name" do
      expect(service.extract_namespace_path("MyApp::Models::User")).to eq(["MyApp", "Models"])
    end

    it "returns empty array for single name" do
      expect(service.extract_namespace_path("User")).to eq([])
    end

    it "returns empty array for nil" do
      expect(service.extract_namespace_path(nil)).to eq([])
    end

    it "handles symbols" do
      expect(service.extract_namespace_path(:"MyApp::User")).to eq(["MyApp"])
    end

    it "returns empty array for empty string" do
      expect(service.extract_namespace_path("")).to eq([])
    end
  end

  describe "#extract_simple_name" do
    it "extracts simple name from fully qualified name" do
      expect(service.extract_simple_name("MyApp::Models::User")).to eq("User")
    end

    it "returns the name itself if no namespace" do
      expect(service.extract_simple_name("User")).to eq("User")
    end

    it "returns nil for nil input" do
      expect(service.extract_simple_name(nil)).to be_nil
    end

    it "handles symbols" do
      expect(service.extract_simple_name(:"MyApp::User")).to eq("User")
    end

    it "returns nil for empty string" do
      expect(service.extract_simple_name("")).to be_nil
    end
  end

  describe "#extract_parent_namespace" do
    it "extracts parent namespace from fully qualified name" do
      expect(service.extract_parent_namespace("MyApp::Models::User")).to eq("MyApp::Models")
    end

    it "returns nil for single name" do
      expect(service.extract_parent_namespace("User")).to be_nil
    end

    it "returns nil for nil input" do
      expect(service.extract_parent_namespace(nil)).to be_nil
    end

    it "handles two-level namespace" do
      expect(service.extract_parent_namespace("MyApp::User")).to eq("MyApp")
    end
  end

  describe "#fully_qualified?" do
    it "returns true for names starting with ::" do
      expect(service.fully_qualified?("::User")).to be true
    end

    it "returns false for regular names" do
      expect(service.fully_qualified?("User")).to be false
    end

    it "returns false for namespaced names without ::" do
      expect(service.fully_qualified?("MyApp::User")).to be false
    end

    it "returns false for nil" do
      expect(service.fully_qualified?(nil)).to be false
    end

    it "handles symbols" do
      expect(service.fully_qualified?(:"::User")).to be true
    end
  end

  describe "#normalize_name" do
    it "removes leading :: from name" do
      expect(service.normalize_name("::User")).to eq("User")
    end

    it "preserves name without leading ::" do
      expect(service.normalize_name("User")).to eq("User")
    end

    it "removes only leading ::" do
      expect(service.normalize_name("::MyApp::User")).to eq("MyApp::User")
    end

    it "returns nil for nil input" do
      expect(service.normalize_name(nil)).to be_nil
    end

    it "handles symbols" do
      expect(service.normalize_name(:"::User")).to eq("User")
    end
  end

  describe "#resolve_in_namespace" do
    it "resolves name within namespace" do
      expect(service.resolve_in_namespace("User", "MyApp::Models")).to eq("MyApp::Models::User")
    end

    it "returns name unchanged if fully qualified" do
      expect(service.resolve_in_namespace("::User", "MyApp::Models")).to eq("::User")
    end

    it "returns name unchanged if namespace is nil" do
      expect(service.resolve_in_namespace("User", nil)).to eq("User")
    end

    it "returns name unchanged if namespace is empty" do
      expect(service.resolve_in_namespace("User", "")).to eq("User")
    end

    it "handles nested namespaces" do
      expect(service.resolve_in_namespace("Profile", "MyApp::Models::User")).to eq("MyApp::Models::User::Profile")
    end

    it "handles symbol names" do
      expect(service.resolve_in_namespace(:User, "MyApp")).to eq("MyApp::User")
    end
  end

  describe "#nested_in?" do
    it "returns true for nested namespace" do
      expect(service.nested_in?("MyApp::Models::User", "MyApp::Models")).to be true
    end

    it "returns true for directly nested namespace" do
      expect(service.nested_in?("MyApp::Models", "MyApp")).to be true
    end

    it "returns false for non-nested namespace" do
      expect(service.nested_in?("OtherApp::User", "MyApp")).to be false
    end

    it "returns false for same namespace" do
      expect(service.nested_in?("MyApp", "MyApp")).to be false
    end

    it "returns false for nil child" do
      expect(service.nested_in?(nil, "MyApp")).to be false
    end

    it "returns false for nil parent" do
      expect(service.nested_in?("MyApp::User", nil)).to be false
    end

    it "returns false for both nil" do
      expect(service.nested_in?(nil, nil)).to be false
    end
  end

  describe "#nesting_level" do
    it "returns 0 for nil namespace" do
      expect(service.nesting_level(nil)).to eq(0)
    end

    it "returns 0 for empty namespace" do
      expect(service.nesting_level("")).to eq(0)
    end

    it "returns 1 for single name" do
      expect(service.nesting_level("User")).to eq(1)
    end

    it "returns 2 for one level of nesting" do
      expect(service.nesting_level("MyApp::User")).to eq(2)
    end

    it "returns 3 for two levels of nesting" do
      expect(service.nesting_level("MyApp::Models::User")).to eq(3)
    end

    it "handles symbols" do
      expect(service.nesting_level(:"MyApp::User")).to eq(2)
    end
  end

  describe "#common_namespace" do
    it "finds common namespace between two names" do
      expect(service.common_namespace("MyApp::Models::User", "MyApp::Models::Post")).to eq("MyApp::Models")
    end

    it "finds partial common namespace" do
      expect(service.common_namespace("MyApp::Models::User", "MyApp::Controllers::UserController")).to eq("MyApp")
    end

    it "returns nil for no common namespace" do
      expect(service.common_namespace("MyApp::User", "OtherApp::User")).to be_nil
    end

    it "returns nil if first name is nil" do
      expect(service.common_namespace(nil, "MyApp::User")).to be_nil
    end

    it "returns nil if second name is nil" do
      expect(service.common_namespace("MyApp::User", nil)).to be_nil
    end

    it "handles symbols" do
      expect(service.common_namespace(:"MyApp::User", :"MyApp::Post")).to eq("MyApp")
    end

    it "handles single name matching" do
      expect(service.common_namespace("User", "User::Profile")).to eq("User")
    end
  end
end
