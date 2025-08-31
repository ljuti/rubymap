# frozen_string_literal: true

require "spec_helper"

# This spec demonstrates why .not_to matchers are anti-patterns
RSpec.describe "Testing Anti-patterns: .not_to matchers" do
  # Example class to demonstrate the issue
  let(:user_service_class) do
    Class.new do
      def create_user(name)
        return nil if name.nil?
        return nil if name.empty?
        return nil if name.length > 100
        return nil if /[^a-zA-Z ]/.match?(name)

        {id: 1, name: name}
      end
    end
  end

  describe "Why .not_to is problematic" do
    let(:service) { user_service_class.new }

    context "BAD: Using .not_to matchers" do
      it "does not return nil for valid input" do
        # This is BAD - it passes for ANY non-nil value
        result = service.create_user("John")
        expect(result).not_to be_nil

        # The problem: If the implementation returns the wrong data like
        # {error: "Something went wrong"} instead of {id: 1, name: "John"},
        # this test would still pass!
      end

      it "does not raise error" do
        # This is BAD - it passes even if the method returns wrong data
        expect { service.create_user("John") }.not_to raise_error

        # The problem: This tells us nothing about what the method
        # actually does. It could return nil, false, or wrong data.
      end
    end

    context "GOOD: Using positive assertions" do
      it "returns user hash with id and name for valid input" do
        # This is GOOD - it checks for the exact expected outcome
        result = service.create_user("John")
        expect(result).to eq({id: 1, name: "John"})

        # Now if the implementation returns anything else, the test fails
      end

      it "returns nil for nil input" do
        # This is GOOD - explicitly testing the nil case
        result = service.create_user(nil)
        expect(result).to be_nil
      end

      it "returns nil for empty input" do
        # This is GOOD - explicitly testing another edge case
        result = service.create_user("")
        expect(result).to be_nil
      end
    end
  end

  describe "Common .not_to anti-patterns and their fixes" do
    context "Anti-pattern: expect(...).not_to be_nil" do
      it "should be replaced with positive assertion" do
        value = "test"

        # BAD
        # expect(value).not_to be_nil

        # GOOD - be specific about what you expect
        expect(value).to eq("test")
        # or
        expect(value).to be_a(String)
      end
    end

    context "Anti-pattern: expect { ... }.not_to raise_error" do
      it "should be replaced with assertion on the result" do
        # BAD
        # expect { 1 + 1 }.not_to raise_error

        # GOOD - test what it should do, not what it shouldn't
        result = 1 + 1
        expect(result).to eq(2)
      end
    end

    context "Anti-pattern: expect(array).not_to be_empty" do
      it "should be replaced with size or content assertion" do
        array = [1, 2, 3]

        # BAD
        # expect(array).not_to be_empty

        # GOOD - be specific about the content
        expect(array).to eq([1, 2, 3])
        # or at least
        expect(array.size).to eq(3)
      end
    end

    context "Anti-pattern: expect(object).not_to be(other)" do
      it "should verify specific properties instead" do
        obj1 = {name: "Test"}
        obj2 = obj1.dup

        # BAD - just checking they're different objects
        # expect(obj2).not_to be(obj1)

        # GOOD - verify they have different object_ids
        expect(obj2.equal?(obj1)).to be false
        # And verify the content is what we expect
        expect(obj2).to eq({name: "Test"})
      end
    end
  end

  describe "Why positive assertions are better" do
    it "provides better failure messages" do
      # When this fails:
      # expect(result).not_to be_nil
      # Message: "expected: not nil, got: nil"

      # When this fails:
      # expect(result).to eq({id: 1, name: "John"})
      # Message: "expected: {id: 1, name: 'John'}, got: {id: 2, name: 'Jane'}"
      # Much more informative!
    end

    it "catches more bugs" do
      # .not_to matchers only check what something ISN'T
      # They can pass for infinite wrong values

      # Positive matchers check what something IS
      # They only pass for the correct value
    end

    it "makes test intent clearer" do
      # BAD: expect(user.admin?).not_to be false
      # What does this even mean? Is it true? nil?

      # GOOD: expect(user.admin?).to be true
      # Clear intent: we expect the user to be an admin
    end

    it "prevents false positives" do
      # Example: Testing a method that should return a number
      def calculate_price_with_bug
        # Bug: returns string instead of number
        "10.99"
      end

      def calculate_price_fixed
        10.99
      end

      # BAD: This passes even with the bug!
      expect(calculate_price_with_bug).to satisfy { |v| !v.nil? }

      # GOOD: This would catch the bug (uncommenting would fail)
      # expect(calculate_price_with_bug).to eq(10.99)

      # GOOD: With the fixed version
      expect(calculate_price_fixed).to eq(10.99)
    end
  end

  describe "Legitimate uses of negation (rare)" do
    it "can use include matcher negation for exclusion tests" do
      allowed_values = [:read, :write, :delete]

      # This is OK - testing explicit exclusion
      expect(allowed_values).not_to include(:admin)

      # But even better would be:
      expect(allowed_values).to eq([:read, :write, :delete])
    end

    it "can use change matcher negation for immutability tests" do
      array = [1, 2, 3].freeze

      # This is OK - testing that something doesn't change
      expect { array.dup }.not_to change { array.size }

      # But better would be to test what DOES happen:
      duplicate = array.dup
      expect(duplicate).to eq([1, 2, 3])
      expect(duplicate.equal?(array)).to be false
    end
  end

  describe "Summary" do
    it "demonstrates the key principle" do
      # The golden rule: Test what your code SHOULD do, not what it SHOULDN'T do

      # Every .not_to matcher is a missed opportunity to make a stronger assertion
      # about what the correct behavior actually is.

      expect("Always use positive assertions").to be_a(String)
    end
  end
end
