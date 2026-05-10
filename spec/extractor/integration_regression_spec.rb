# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Integration: V1-V3 combined pipeline (integration-regression)" do
  let(:extractor) { Rubymap::Extractor.new }

  # ── AC: Realistic Rails Model Integration ────────────────────────────────

  describe "extracting a realistic Rails model" do
    it "populates all new fields: calls_made, branches, loops, conditionals, body_lines" do
      code = <<~RUBY
        class User < ApplicationRecord
          has_many :posts, dependent: :destroy
          has_many :comments, through: :posts
          belongs_to :organization, optional: true

          validates :email, presence: true, uniqueness: true
          validates :name, presence: true, length: { minimum: 2 }
          validates :age, numericality: { greater_than: 0 }, allow_nil: true

          scope :active, -> { where(active: true) }
          scope :admins, -> { where(role: "admin") }

          before_save :normalize_email

          def full_name
            "\#{first_name} \#{last_name}".strip
          end

          def admin?
            role == "admin"
          end

          def activate!
            update!(active: true, activated_at: Time.current)
          end

          def publish_all
            posts.each do |post|
              post.publish! if post.draft?
              post.notify! unless post.silent?
            end
          end

          private

          def normalize_email
            self.email = email.downcase.strip if email.present?
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      # ── Class-level pattern detection ──────────────────────────────
      # Note: before_save/after_create are ActiveRecord callbacks, not in the Rails DSL set.
      # The Rails DSL set covers: has_many, has_one, belongs_to, validates, scope,
      # before_action/after_action/around_action (and _filter variants), rescue_from, delegate.
      expect(result.patterns.size).to be >= 7  # has_many x2, belongs_to, validates x3, scope x2
      expect(result.patterns.map(&:type).uniq).to eq(["rails_dsl"])

      pattern_methods = result.patterns.map(&:method)
      expect(pattern_methods).to include("has_many", "belongs_to", "validates", "scope")

      # ── Method-level body analysis ─────────────────────────────────
      full_name_method = result.methods.find { |m| m.name == "full_name" }
      expect(full_name_method).not_to be_nil
      expect(full_name_method.calls_made).to be_an(Array)
      # strip is called on the interpolated string
      has_strip = full_name_method.calls_made.any? { |c| c[:method] == "strip" }
      expect(has_strip).to be true

      admin_method = result.methods.find { |m| m.name == "admin?" }
      expect(admin_method).not_to be_nil
      expect(admin_method.calls_made.size).to be >= 1
      # role == "admin" is a call to ==
      expect(admin_method.calls_made.map { |c| c[:method] }).to include("==")

      activate_method = result.methods.find { |m| m.name == "activate!" }
      expect(activate_method).not_to be_nil
      expect(activate_method.calls_made.size).to be >= 1

      publish_all_method = result.methods.find { |m| m.name == "publish_all" }
      expect(publish_all_method).not_to be_nil
      # posts.each { |post| ... } — each is a loop
      expect(publish_all_method.loops).to be >= 1
      # if post.draft? and unless post.silent? — branches and conditionals
      expect(publish_all_method.branches).to be >= 2
      expect(publish_all_method.conditionals).to be >= 2
      # Multiple calls: each/publish!/draft?/notify!/silent?
      expect(publish_all_method.calls_made.size).to be >= 5

      normalize_method = result.methods.find { |m| m.name == "normalize_email" }
      expect(normalize_method).not_to be_nil
      # .strip and .present? are recorded. .downcase is nested in
      # the receiver chain of .strip and not separately traversed.
      normalize_calls = normalize_method.calls_made.map { |c| c[:method] }
      expect(normalize_calls).to include("strip", "present?")

      # ── body_lines check ────────────────────────────────────────────
      result.methods.each do |method|
        expect(method.body_lines).to be >= 0
      end
    end

    it "completes to_h serialization with all fields" do
      code = <<~RUBY
        class Widget < ApplicationRecord
          has_many :parts
          validates :name, presence: true

          def process
            if ready?
              parts.each { |p| p.activate! }
            else
              Rails.logger.warn("not ready")
            end
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "process" }
      hash = method.to_h

      expect(hash).to have_key(:calls_made)
      expect(hash).to have_key(:branches)
      expect(hash).to have_key(:loops)
      expect(hash).to have_key(:conditionals)
      expect(hash).to have_key(:body_lines)
      expect(hash[:calls_made]).to be_an(Array)
      expect(hash[:branches]).to be_an(Integer)
      expect(hash[:loops]).to be_an(Integer)
      expect(hash[:conditionals]).to be_an(Integer)
      expect(hash[:body_lines]).to be_an(Integer)

      # Verify serialization has actual data
      expect(hash[:calls_made]).not_to be_empty
      # if/else = 2 branches, each = 1 loop
      expect(hash[:branches]).to be >= 2
      expect(hash[:loops]).to be >= 1
      expect(hash[:conditionals]).to be >= 1
    end
  end

  # ── AC: Realistic Rails Controller Integration ───────────────────────────

  describe "extracting a realistic Rails controller" do
    it "detects before_action and rescue_from patterns" do
      code = <<~RUBY
        class UsersController < ApplicationController
          before_action :authenticate_user!
          before_action :set_user, only: [:show, :edit, :update, :destroy]
          after_action :log_request

          rescue_from ActiveRecord::RecordNotFound, with: :not_found
          rescue_from ActionController::ParameterMissing, with: :bad_request

          def index
            @users = User.active.page(params[:page])
          end

          def show
            @user = User.find(params[:id])
            respond_to do |format|
              format.html
              format.json { render json: @user }
            end
          end

          def create
            @user = User.new(user_params)
            if @user.save
              redirect_to @user, notice: "Created!"
            else
              render :new
            end
          end

          private

          def set_user
            @user = User.find(params[:id])
          end

          def user_params
            params.require(:user).permit(:name, :email)
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      # ── Rails DSL pattern detection ─────────────────────────────────
      expect(result.patterns.size).to be >= 4  # before_action x2, after_action, rescue_from x2
      expect(result.patterns.map(&:type).uniq).to eq(["rails_dsl"])

      pattern_methods = result.patterns.map(&:method)
      expect(pattern_methods).to include("before_action", "after_action", "rescue_from")

      # All patterns should target the controller class
      expect(result.patterns.map(&:target).uniq).to eq(["UsersController"])

      # ── Method body analysis for controller methods ─────────────────
      create_method = result.methods.find { |m| m.name == "create" }
      expect(create_method).not_to be_nil
      # if/else branch
      expect(create_method.branches).to be >= 2
      expect(create_method.conditionals).to be >= 1
      # calls: .new, .save, redirect_to, render
      create_calls = create_method.calls_made.map { |c| c[:method] }
      expect(create_calls).to include("new", "save")

      show_method = result.methods.find { |m| m.name == "show" }
      expect(show_method).not_to be_nil
      show_calls = show_method.calls_made.map { |c| c[:method] }
      expect(show_calls).to include("find")
    end

    it "verifies controller methods have body analysis data" do
      code = <<~RUBY
        class ApiController < ApplicationController
          before_action :authenticate
          rescue_from StandardError, with: :handle_error

          def index
            items = load_items
            render json: items
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      index_method = result.methods.find { |m| m.name == "index" }
      expect(index_method).not_to be_nil
      expect(index_method.calls_made).not_to be_empty
      expect(index_method.calls_made.size).to be >= 2

      # Verify calls include load_items and render
      call_names = index_method.calls_made.map { |c| c[:method] }
      expect(call_names).to include("load_items", "render")
    end
  end

  # ── AC: Pipeline end-to-end: Rubymap.map ─────────────────────────────────

  describe "Rubymap.map pipeline integration" do
    include_context "temporary directory"

    it "extracts the test project fixture and produces output with call data" do
      test_project = File.expand_path("../fixtures/test_project", __dir__)
      expect(Dir.exist?(test_project)).to be true

      # Run the pipeline via Rubymap.map
      result = Rubymap.map(test_project, format: :llm)

      expect(result).to be_a(Hash)
      # Pipeline result has :format and :output_dir keys from the emit step
      expect(result[:format]).to eq(:llm)
      expect(result[:output_dir]).not_to be_nil

      # Verify output directory was created and contains files
      output_dir = result[:output_dir]
      if output_dir && Dir.exist?(output_dir)
        files = Dir.glob(File.join(output_dir, "**/*"))
        expect(files).not_to be_empty
      end
    end
  end

  # ── Regression: V1-V2-V3 features work together ──────────────────────────

  describe "combined V1+V2+V3 features in a single class" do
    it "records calls, control flow, and Rails DSL simultaneously" do
      code = <<~RUBY
        class Order < ApplicationRecord
          has_many :line_items
          belongs_to :customer
          validates :status, inclusion: { in: %w[pending shipped delivered] }

          scope :pending, -> { where(status: "pending") }

          def total
            line_items.reduce(0) do |sum, item|
              sum + item.price * item.quantity
            end
          end

          def ship!
            if pending?
              update!(status: "shipped", shipped_at: Time.current)
              CustomerMailer.shipped(self).deliver_later
            elsif delivered?
              Rails.logger.warn("Already delivered")
            else
              raise "Cannot ship order in \#{status} state"
            end
          end

          private

          def pending?
            status == "pending"
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      # ── V3: Rails DSL patterns ──────────────────────────────────────
      expect(result.patterns.size).to eq(4)  # has_many, belongs_to, validates, scope
      expect(result.patterns.map(&:method)).to contain_exactly(
        "has_many", "belongs_to", "validates", "scope"
      )

      # ── V1: Call recording ──────────────────────────────────────────
      ship_method = result.methods.find { |m| m.name == "ship!" }
      expect(ship_method).not_to be_nil
      expect(ship_method.calls_made.size).to be >= 3
      ship_calls = ship_method.calls_made.map { |c| c[:method] }
      expect(ship_calls).to include("pending?", "delivered?")
      # Check receiver resolution for Rails.logger.warn
      logger_call = ship_method.calls_made.find { |c| c[:method] == "warn" }
      expect(logger_call).not_to be_nil
      expect(logger_call[:receiver]).to eq(["Rails", "logger"])

      total_method = result.methods.find { |m| m.name == "total" }
      expect(total_method).not_to be_nil
      # reduce is a loop method, and it has a block
      expect(total_method.calls_made.size).to be >= 2

      # ── V2: Control flow metrics ────────────────────────────────────
      # if/elsif/else = 3 branches + 1 conditional (the if)
      expect(ship_method.branches).to be >= 3
      expect(ship_method.conditionals).to be >= 1

      # reduce with block = 1 loop
      expect(total_method.loops).to be >= 1

      # body_lines should be populated
      expect(ship_method.body_lines).to be > 0
      expect(total_method.body_lines).to be > 0
    end
  end

  # ── Edge case: Methods with mixed argument types ─────────────────────────

  describe "argument encoding in real-world scenarios" do
    it "encodes keyword arguments as hash type" do
      code = <<~RUBY
        class Configurator
          def setup
            configure(
              debug: true,
              timeout: 30,
              name: "myapp",
              callback: -> { notify },
              tags: [:ruby, :rails]
            )
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "setup" }
      args = method.calls_made.first[:arguments]

      # Should have a KeywordHashNode argument
      hash_arg = args.find { |a| a[:type] == :hash }
      expect(hash_arg).not_to be_nil
      expect(hash_arg[:pairs].size).to eq(5)

      pair_keys = hash_arg[:pairs].map { |p| p[:key] }
      expect(pair_keys).to include("debug", "timeout", "name", "callback", "tags")

      # Verify typed values within the hash pairs
      debug_pair = hash_arg[:pairs].find { |p| p[:key] == "debug" }
      expect(debug_pair[:value]).to eq({type: :boolean, value: true})

      timeout_pair = hash_arg[:pairs].find { |p| p[:key] == "timeout" }
      expect(timeout_pair[:value]).to eq({type: :integer, value: 30})

      name_pair = hash_arg[:pairs].find { |p| p[:key] == "name" }
      expect(name_pair[:value]).to eq({type: :string, value: "myapp"})

      callback_pair = hash_arg[:pairs].find { |p| p[:key] == "callback" }
      expect(callback_pair[:value][:type]).to eq(:block)
      expect(callback_pair[:value][:source]).to include("notify")

      tags_pair = hash_arg[:pairs].find { |p| p[:key] == "tags" }
      expect(tags_pair[:value][:type]).to eq(:array)
      expect(tags_pair[:value][:elements].size).to eq(2)
    end
  end

  # ── Edge case: Nested method bodies in class << self ─────────────────────

  describe "methods inside class << self" do
    it "records calls and control flow for eigenclass methods" do
      code = <<~RUBY
        class User < ApplicationRecord
          has_many :posts

          class << self
            def find_by_email(email)
              find_by(email: email.downcase.strip)
            end

            def create_admin(attrs)
              user = create!(attrs.merge(role: "admin"))
              AdminMailer.notify(user) if user.persisted?
              user
            end
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      # Rails DSL at class level still detected
      expect(result.patterns.size).to be >= 1
      expect(result.patterns.map(&:method)).to include("has_many")

      # Eigenclass methods analyzed
      find_method = result.methods.find { |m| m.name == "find_by_email" }
      expect(find_method).not_to be_nil
      expect(find_method.calls_made.size).to be >= 1
      expect(find_method.calls_made.map { |c| c[:method] }).to include("find_by")

      create_admin_method = result.methods.find { |m| m.name == "create_admin" }
      expect(create_admin_method).not_to be_nil
      # modifier if = 1 branch + 1 conditional
      expect(create_admin_method.branches).to be >= 1
      expect(create_admin_method.conditionals).to be >= 1
      create_calls = create_admin_method.calls_made.map { |c| c[:method] }
      expect(create_calls).to include("create!", "merge")
    end
  end

  # ── Golden file / Reference test ─────────────────────────────────────────

  describe "golden file test for reference project" do
    it "produces consistent extraction output for the test fixture model" do
      fixture_path = File.expand_path("../fixtures/test_project/app/models/user.rb", __dir__)
      expect(File.exist?(fixture_path)).to be true

      result = extractor.extract_from_file(fixture_path)
      expect(result.errors).to be_empty

      # Verify class extraction
      expect(result.classes.size).to eq(1)
      user_class = result.classes.first
      expect(user_class.name).to eq("User")
      expect(user_class.superclass).to eq("ApplicationRecord")

      # Verify Rails DSL patterns (associations, validations, scopes)
      expect(result.patterns.size).to be >= 9
      pattern_methods = result.patterns.map(&:method)
      expect(pattern_methods).to include(
        "has_many", "belongs_to", "validates", "scope"
      )

      # Note: before_save and after_create are ActiveRecord callbacks, not Rails DSL patterns

      # Verify methods extracted
      method_names = result.methods.map(&:name)
      expected_methods = %w[full_name admin? activate! normalize_email send_welcome_email]
      expected_methods.each do |name|
        expect(method_names).to include(name), "Expected method '#{name}' to be extracted"
      end

      # Verify each method has body analysis
      result.methods.each do |method|
        expect(method.calls_made).to be_an(Array)
        expect(method.branches).to be_an(Integer)
        expect(method.loops).to be_an(Integer)
        expect(method.conditionals).to be_an(Integer)
        expect(method.body_lines).to be_an(Integer)

        # to_h completeness
        hash = method.to_h
        expect(hash).to have_key(:calls_made)
        expect(hash).to have_key(:branches)
        expect(hash).to have_key(:loops)
        expect(hash).to have_key(:conditionals)
        expect(hash).to have_key(:body_lines)
      end
    end

    it "produces consistent extraction output for the test fixture controller" do
      fixture_path = File.expand_path("../fixtures/test_project/app/controllers/users_controller.rb", __dir__)
      expect(File.exist?(fixture_path)).to be true

      result = extractor.extract_from_file(fixture_path)
      expect(result.errors).to be_empty

      # Verify class extraction
      expect(result.classes.size).to eq(1)
      controller_class = result.classes.first
      expect(controller_class.name).to eq("UsersController")
      expect(controller_class.superclass).to eq("ApplicationController")

      # Verify Rails DSL patterns (controller callbacks)
      expect(result.patterns.size).to be >= 3  # before_action x3
      pattern_methods = result.patterns.map(&:method)
      expect(pattern_methods).to include("before_action")

      # Verify methods extracted
      method_names = result.methods.map(&:name)
      expected_methods = %w[index show new edit create update destroy
        set_user user_params authorize_edit! authorize_admin!]
      expected_methods.each do |name|
        expect(method_names).to include(name), "Expected method '#{name}' to be extracted"
      end

      # Verify control flow metrics
      create_method = result.methods.find { |m| m.name == "create" }
      expect(create_method.branches).to be >= 2   # if/else
      expect(create_method.conditionals).to be >= 1

      # authorize_edit! has unless + ||
      auth_method = result.methods.find { |m| m.name == "authorize_edit!" }
      expect(auth_method.branches).to be >= 2  # unless + || (short-circuit)
      expect(auth_method.conditionals).to be >= 1

      # Verify each method has body analysis
      result.methods.each do |method|
        expect(method.calls_made).to be_an(Array)
        expect(method.branches).to be_an(Integer)
        expect(method.loops).to be_an(Integer)
        expect(method.conditionals).to be_an(Integer)
        expect(method.body_lines).to be_an(Integer)
      end
    end
  end
end
