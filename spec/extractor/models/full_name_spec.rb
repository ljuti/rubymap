# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Model #full_name methods" do
  describe Rubymap::Extractor::ClassInfo do
    describe "#full_name" do
      it "returns just name when namespace is nil" do
        info = described_class.new(name: "User")
        expect(info.full_name).to eq("User")
      end

      it "returns namespace::name when namespace is present" do
        info = described_class.new(name: "User", namespace: "Models")
        expect(info.full_name).to eq("Models::User")
      end

      it "handles empty namespace as falsy" do
        info = described_class.new(name: "User", namespace: "")
        info.namespace = ""
        expect(info.full_name).to eq("::User")
      end

      it "handles deeply nested namespaces" do
        info = described_class.new(name: "User", namespace: "MyApp::Models::Admin")
        expect(info.full_name).to eq("MyApp::Models::Admin::User")
      end

      it "handles false namespace as falsy" do
        info = described_class.new(name: "User", namespace: false)
        expect(info.full_name).to eq("User")
      end

      it "handles numeric namespace" do
        info = described_class.new(name: "User", namespace: 123)
        expect(info.full_name).to eq("123::User")
      end
    end
  end

  describe Rubymap::Extractor::ModuleInfo do
    describe "#full_name" do
      it "returns just name when namespace is nil" do
        info = described_class.new(name: "Enumerable")
        expect(info.full_name).to eq("Enumerable")
      end

      it "returns namespace::name when namespace is present" do
        info = described_class.new(name: "Enumerable", namespace: "Utils")
        expect(info.full_name).to eq("Utils::Enumerable")
      end

      it "handles empty namespace as falsy" do
        info = described_class.new(name: "Enumerable")
        info.namespace = ""
        expect(info.full_name).to eq("::Enumerable")
      end

      it "preserves exact namespace format" do
        info = described_class.new(name: "Mod", namespace: "A::B::C")
        expect(info.full_name).to eq("A::B::C::Mod")
      end
    end
  end

  describe Rubymap::Extractor::ConstantInfo do
    describe "#full_name" do
      it "returns just name when namespace is nil" do
        info = described_class.new(name: "VERSION", value: "1.0")
        expect(info.full_name).to eq("VERSION")
      end

      it "returns namespace::name when namespace is present" do
        info = described_class.new(name: "VERSION", value: "1.0", namespace: "MyApp")
        expect(info.full_name).to eq("MyApp::VERSION")
      end

      it "handles empty namespace as falsy" do
        info = described_class.new(name: "VERSION", value: "1.0")
        info.namespace = ""
        expect(info.full_name).to eq("::VERSION")
      end

      it "handles single character names" do
        info = described_class.new(name: "X", value: "1", namespace: "Math")
        expect(info.full_name).to eq("Math::X")
      end
    end
  end

  describe Rubymap::Extractor::MethodInfo do
    describe "#full_name" do
      context "with instance methods" do
        it "returns just name when neither namespace nor owner is present" do
          info = described_class.new(name: "calculate", location: nil)
          expect(info.full_name).to eq("calculate")
        end

        it "uses namespace with # separator for instance methods" do
          info = described_class.new(name: "calculate", location: nil, namespace: "Calculator")
          expect(info.full_name).to eq("Calculator#calculate")
        end

        it "uses namespace when owner is not set" do
          info = described_class.new(name: "calculate", location: nil, namespace: "Calc")
          expect(info.full_name).to eq("Calc#calculate")
        end

        it "handles empty namespace as falsy" do
          info = described_class.new(name: "calculate", location: nil, namespace: "")
          expect(info.full_name).to eq("#calculate")
        end
      end

      context "with class methods" do
        it "uses . separator for class methods" do
          info = described_class.new(name: "new", location: nil, namespace: "User")
          info.receiver_type = "class"
          expect(info.full_name).to eq("User.new")
        end

        it "uses owner with . separator for class methods" do
          info = described_class.new(name: "find", location: nil)
          info.owner = "User"
          info.receiver_type = "class"
          expect(info.full_name).to eq("User.find")
        end

        it "returns just name when no prefix for class method" do
          info = described_class.new(name: "find", location: nil)
          info.receiver_type = "class"
          expect(info.full_name).to eq("find")
        end
      end

      context "with singleton methods" do
        it "uses . separator for singleton methods" do
          info = described_class.new(name: "instance", location: nil, namespace: "Logger")
          info.receiver_type = "singleton"
          expect(info.full_name).to eq("Logger.instance")
        end
      end

      context "edge cases" do
        it "handles false as owner (falsy)" do
          info = described_class.new(name: "test", location: nil)
          info.owner = false
          expect(info.full_name).to eq("test")
        end

        it "uses namespace when owner is empty string (falsy)" do
          info = described_class.new(name: "test", location: nil, namespace: "MyClass")
          info.owner = ""
          expect(info.full_name).to eq("MyClass#test")
        end

        it "handles numeric namespace" do
          info = described_class.new(name: "test", location: nil, namespace: 42)
          expect(info.full_name).to eq("42#test")
        end
      end
    end
  end
end
