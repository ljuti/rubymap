# frozen_string_literal: true

require "spec_helper"
require "prism"

RSpec.describe Rubymap::Extractor::CallExtractor do
  let(:context) { Rubymap::Extractor::ExtractionContext.new }
  let(:result) { Rubymap::Extractor::Result.new }
  let(:extractor) { described_class.new(context, result) }

  # Helper: parse Ruby code and find all CallNodes matching a given name
  def find_call_nodes(code, method_name = nil)
    parse_result = Prism.parse(code)
    raise "Parse error: #{parse_result.errors.map(&:message).join(", ")}" unless parse_result.success?

    nodes = []
    find_nodes(parse_result.value, Prism::CallNode) do |node|
      if method_name.nil? || node.name.to_s == method_name
        nodes << node
      end
    end
    nodes
  end

  # Recursive node finder
  def find_nodes(node, type, &block)
    return unless node

    if node.is_a?(type)
      block.call(node)
    end

    if node.respond_to?(:child_nodes)
      node.child_nodes.compact.each { |child| find_nodes(child, type, &block) }
    elsif node.respond_to?(:body)
      find_nodes(node.body, type, &block)
    end
  end

  # Helper: extract patterns from code (with current_class set)
  def extract_patterns(code, class_name = "TestClass")
    context.with_class(class_name) do
      find_call_nodes(code).each { |node| extractor.extract(node) }
    end
    result.patterns
  end

  # Helper: extract without current_class set
  def extract_patterns_without_class(code)
    find_call_nodes(code).each { |node| extractor.extract(node) }
    result.patterns
  end

  # ── Rails DSL Detection ────────────────────────────────────────────────

  describe "Rails association macros" do
    it "detects has_many" do
      code = "has_many :posts"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.type).to eq("rails_dsl")
      expect(patterns.first.method).to eq("has_many")
      expect(patterns.first.target).to eq("User")
      expect(patterns.first.indicators).to include("posts")
    end

    it "detects has_one" do
      code = "has_one :profile"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("has_one")
      expect(patterns.first.target).to eq("User")
      expect(patterns.first.indicators).to include("profile")
    end

    it "detects belongs_to" do
      code = "belongs_to :author"
      patterns = extract_patterns(code, "Post")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("belongs_to")
      expect(patterns.first.target).to eq("Post")
      expect(patterns.first.indicators).to include("author")
    end

    it "detects has_and_belongs_to_many" do
      code = "has_and_belongs_to_many :tags"
      patterns = extract_patterns(code, "Post")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("has_and_belongs_to_many")
      expect(patterns.first.target).to eq("Post")
      expect(patterns.first.indicators).to include("tags")
    end

    it "records arguments as indicators" do
      code = "has_many :posts, through: :user_posts, dependent: :destroy"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.indicators).to include("posts")
      expect(patterns.first.indicators).to include("through")
      expect(patterns.first.indicators).to include("dependent")
    end

    it "records the correct target class name" do
      code = "has_many :comments"
      patterns = extract_patterns(code, "Article")
      expect(patterns.first.target).to eq("Article")
    end
  end

  describe "validates macros" do
    it "detects validates" do
      code = "validates :email, presence: true"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates")
      expect(patterns.first.type).to eq("rails_dsl")
    end

    it "detects validates_presence_of" do
      code = "validates_presence_of :name"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_presence_of")
    end

    it "detects validates_length_of" do
      code = "validates_length_of :password, minimum: 8"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_length_of")
    end

    it "detects validates_inclusion_of" do
      code = "validates_inclusion_of :status, in: %w[active inactive]"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_inclusion_of")
    end

    it "detects validates_format_of" do
      code = "validates_format_of :email, with: /@/"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_format_of")
    end

    it "detects validates_numericality_of" do
      code = "validates_numericality_of :age"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_numericality_of")
    end

    it "detects validates_acceptance_of" do
      code = "validates_acceptance_of :terms"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_acceptance_of")
    end

    it "detects validates_confirmation_of" do
      code = "validates_confirmation_of :password"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_confirmation_of")
    end

    it "detects validates_associated" do
      code = "validates_associated :posts"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_associated")
    end

    it "detects validates_each" do
      code = "validates_each :name, :email do |record, attr, value| end"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("validates_each")
    end
  end

  describe "controller action macros" do
    it "detects before_action" do
      code = "before_action :authenticate_user"
      patterns = extract_patterns(code, "UsersController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("before_action")
      expect(patterns.first.target).to eq("UsersController")
    end

    it "detects after_action" do
      code = "after_action :cleanup"
      patterns = extract_patterns(code, "UsersController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("after_action")
    end

    it "detects around_action" do
      code = "around_action :wrap_transaction"
      patterns = extract_patterns(code, "UsersController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("around_action")
    end

    it "detects skip_before_action" do
      code = "skip_before_action :authenticate_user"
      patterns = extract_patterns(code, "PublicController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_before_action")
    end

    it "detects skip_after_action" do
      code = "skip_after_action :cleanup"
      patterns = extract_patterns(code, "PublicController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_after_action")
    end

    it "detects skip_around_action" do
      code = "skip_around_action :wrap_transaction"
      patterns = extract_patterns(code, "PublicController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_around_action")
    end

    # Filter variants (older Rails naming)
    it "detects before_filter" do
      code = "before_filter :set_locale"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("before_filter")
    end

    it "detects after_filter" do
      code = "after_filter :log_request"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("after_filter")
    end

    it "detects around_filter" do
      code = "around_filter :profile"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("around_filter")
    end

    it "detects skip_before_filter" do
      code = "skip_before_filter :set_locale"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_before_filter")
    end

    it "detects skip_after_filter" do
      code = "skip_after_filter :log_request"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_after_filter")
    end

    it "detects skip_around_filter" do
      code = "skip_around_filter :profile"
      patterns = extract_patterns(code, "LegacyController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("skip_around_filter")
    end
  end

  describe "other Rails DSL macros" do
    it "detects scope" do
      code = "scope :active, -> { where(active: true) }"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("scope")
      expect(patterns.first.type).to eq("rails_dsl")
    end

    it "detects default_scope" do
      code = "default_scope -> { order(:created_at) }"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("default_scope")
    end

    it "detects rescue_from" do
      code = "rescue_from ActiveRecord::RecordNotFound, with: :not_found"
      patterns = extract_patterns(code, "UsersController")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("rescue_from")
    end

    it "detects delegate" do
      code = "delegate :name, :email, to: :profile"
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.method).to eq("delegate")
    end
  end

  # ── Guard: no record without current_class ─────────────────────────────

  describe "when current_class is nil" do
    it "does not record Rails DSL patterns outside a class/module" do
      code = "has_many :posts"
      patterns = extract_patterns_without_class(code)
      expect(patterns).to be_empty
    end

    it "does not record validates patterns outside a class/module" do
      code = "validates :email, presence: true"
      patterns = extract_patterns_without_class(code)
      expect(patterns).to be_empty
    end

    it "does not record before_action outside a class/module" do
      code = "before_action :authenticate"
      patterns = extract_patterns_without_class(code)
      expect(patterns).to be_empty
    end
  end

  # ── Non-Rails classes ──────────────────────────────────────────────────

  describe "non-Rails classes" do
    it "produces no Rails DSL patterns for a plain Ruby class" do
      code = <<~RUBY
        class PlainClass
          def initialize
            @data = []
          end

          def add(item)
            @data << item
          end
        end
      RUBY

      context.with_class("PlainClass") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.patterns).to be_empty
    end

    it "produces no Rails DSL patterns for non-Rails DSL calls" do
      code = "puts 'hello'"
      patterns = extract_patterns(code, "AnyClass")
      # puts is not a Rails DSL call
      expect(patterns).to be_empty
    end
  end

  # ── Regression: existing patterns still work ───────────────────────────

  describe "existing CallExtractor patterns (non-Rails)" do
    it "continues to detect attr_reader alongside Rails DSL calls" do
      code = <<~RUBY
        class User
          attr_reader :name, :email
          has_many :posts
        end
      RUBY

      context.with_class("User") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      # Should have both patterns and attributes
      expect(result.patterns.size).to eq(1) # has_many
      expect(result.patterns.first.method).to eq("has_many")
      expect(result.attributes.size).to eq(2) # name, email
      expect(result.attributes.map(&:name)).to contain_exactly("name", "email")
    end

    it "continues to detect attr_accessor alongside Rails DSL calls" do
      code = <<~RUBY
        class Product
          attr_accessor :price, :stock
          validates :price, presence: true
        end
      RUBY

      context.with_class("Product") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.attributes.size).to eq(2)
      expect(result.attributes.map(&:name)).to contain_exactly("price", "stock")
      expect(result.attributes.map(&:type)).to all(eq("accessor"))
      expect(result.patterns.size).to eq(1) # validates
    end

    it "continues to detect attr_writer alongside Rails DSL calls" do
      code = <<~RUBY
        class Config
          attr_writer :debug
          has_one :settings
        end
      RUBY

      context.with_class("Config") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.attributes.size).to eq(1)
      expect(result.attributes.first.name).to eq("debug")
      expect(result.attributes.first.type).to eq("writer")
      expect(result.patterns.size).to eq(1) # has_one
    end

    it "continues to detect include" do
      code = <<~RUBY
        class User
          include Enumerable
          has_many :posts
        end
      RUBY

      context.with_class("User") do
        context.push_namespace("User")
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.mixins.size).to eq(1)
      expect(result.mixins.first.type).to eq("include")
      expect(result.mixins.first.module_name).to eq("Enumerable")
      expect(result.patterns.size).to eq(1) # has_many
    end

    it "continues to detect extend" do
      code = <<~RUBY
        class User
          extend ActiveSupport::Concern
          has_many :posts
        end
      RUBY

      context.with_class("User") do
        context.push_namespace("User")
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.mixins.size).to eq(1)
      expect(result.mixins.first.type).to eq("extend")
      expect(result.mixins.first.module_name).to eq("ActiveSupport::Concern")
      expect(result.patterns.size).to be >= 1 # concern pattern + has_many
    end

    it "continues to detect require" do
      code = 'require "json"'
      context.with_class("AnyClass") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.dependencies.size).to eq(1)
      expect(result.dependencies.first.type).to eq("require")
      expect(result.dependencies.first.path).to eq("json")
    end

    it "continues to detect require_relative" do
      code = 'require_relative "helper"'
      context.with_class("AnyClass") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.dependencies.size).to eq(1)
      expect(result.dependencies.first.type).to eq("require_relative")
      expect(result.dependencies.first.path).to eq("helper")
    end

    it "continues to detect private/protected/public visibility changes" do
      code = "private"
      expect { extractor.extract(find_call_nodes(code).first) }.not_to raise_error
      # Visibility changes don't add to patterns, they change context
    end
  end

  # ── Multiple patterns in one class ─────────────────────────────────────

  describe "with multiple Rails DSL calls in one class" do
    it "records all patterns" do
      code = <<~RUBY
        class User
          has_many :posts
          has_one :profile
          belongs_to :organization
          validates :name, presence: true
          validates_presence_of :email
          before_action :authenticate
          scope :active, -> { where(active: true) }
        end
      RUBY

      context.with_class("User") do
        find_call_nodes(code).each { |node| extractor.extract(node) }
      end

      expect(result.patterns.size).to eq(7)
      expect(result.patterns.map(&:method)).to contain_exactly(
        "has_many", "has_one", "belongs_to",
        "validates", "validates_presence_of",
        "before_action", "scope"
      )
      expect(result.patterns.map(&:target).uniq).to eq(["User"])
    end
  end

  # ── Edge cases ─────────────────────────────────────────────────────────

  describe "edge cases" do
    it "handles Rails DSL calls with no arguments" do
      code = "has_many" # unlikely but possible
      context.with_class("User") do
        node = find_call_nodes(code).first
        expect(node).not_to be_nil
        extractor.extract(node)
      end
      expect(result.patterns.size).to eq(1)
      expect(result.patterns.first.method).to eq("has_many")
      expect(result.patterns.first.indicators).to eq([])
    end

    it "handles validates with keyword arguments" do
      code = "validates :title, presence: true, length: { minimum: 5 }"
      patterns = extract_patterns(code, "Post")
      expect(patterns.size).to eq(1)
      expect(patterns.first.indicators).to include("title")
      expect(patterns.first.indicators).to include("presence")
      expect(patterns.first.indicators).to include("length")
    end

    it "handles string arguments in Rails DSL calls" do
      code = 'has_many "posts"'
      patterns = extract_patterns(code, "User")
      expect(patterns.size).to eq(1)
      expect(patterns.first.indicators).to include("posts")
    end

    it "records location information" do
      code = "has_many :posts"
      patterns = extract_patterns(code, "User")
      expect(patterns.first.location).not_to be_nil
    end
  end
end
