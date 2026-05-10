# frozen_string_literal: true

require "spec_helper"
require "prism"

RSpec.describe Rubymap::Extractor::MethodBodyVisitor do
  let(:visitor) { described_class.new }

  # Helper: parse Ruby code and find a specific DefNode by method name
  def find_def_node(code, method_name)
    parse_result = Prism.parse(code)
    raise "Parse error: #{parse_result.errors.map(&:message).join(', ')}" unless parse_result.success?

    result = nil
    find_node(parse_result.value, Prism::DefNode) do |node|
      if node.name.to_s == method_name
        result = node
        :stop
      end
    end
    result
  end

  # Recursive node finder
  def find_node(node, type, &block)
    return unless node

    if node.is_a?(type)
      result = block.call(node)
      return if result == :stop
    end

    if node.respond_to?(:child_nodes)
      node.child_nodes.compact.each { |child| find_node(child, type, &block) }
    elsif node.respond_to?(:body)
      find_node(node.body, type, &block)
    end
  end

  # Helper: visit a method body and get the result
  def visit_method(code, method_name)
    def_node = find_def_node(code, method_name)
    raise "Method '#{method_name}' not found in:\n#{code}" unless def_node

    visitor.visit(def_node.body, def_node)
  end

  describe "#visit" do
    context "with no calls (empty method)" do
      it "returns empty calls and zero counters" do
        code = <<~RUBY
          def nothing
          end
        RUBY
        result = visit_method(code, "nothing")
        expect(result.calls).to eq([])
        expect(result.loops).to eq(0)
      end

      it "returns body_lines from the def node" do
        code = <<~RUBY
          def empty
          end
        RUBY
        result = visit_method(code, "empty")
        expect(result.body_lines).to be >= 0
      end
    end

    context "with a simple call (no receiver)" do
      it "records a call with nil receiver" do
        code = <<~RUBY
          def greet
            save
          end
        RUBY
        result = visit_method(code, "greet")
        expect(result.calls.size).to eq(1)
        call = result.calls.first
        expect(call[:receiver]).to be_nil
        expect(call[:method]).to eq("save")
        expect(call[:arguments]).to eq([])
        expect(call[:has_block]).to be false
      end
    end

    context "with a call with arguments" do
      it "records typed arguments" do
        code = <<~RUBY
          def configure
            set_config(:timeout, 30, true, nil, "hello")
          end
        RUBY
        result = visit_method(code, "configure")
        expect(result.calls.size).to eq(1)
        args = result.calls.first[:arguments]
        expect(args[0]).to eq({type: :symbol, value: "timeout"})
        expect(args[1]).to eq({type: :integer, value: 30})
        expect(args[2]).to eq({type: :boolean, value: true})
        expect(args[3]).to eq({type: :nil, value: nil})
        expect(args[4]).to eq({type: :string, value: "hello"})
      end
    end

    context "with a constant receiver chain" do
      it "resolves Rails.logger.info to [\"Rails\", \"logger\"]" do
        code = <<~RUBY
          def log_message
            Rails.logger.info("hello")
          end
        RUBY
        result = visit_method(code, "log_message")
        expect(result.calls.size).to eq(1)
        call = result.calls.first
        expect(call[:receiver]).to eq(["Rails", "logger"])
        expect(call[:method]).to eq("info")
      end
    end

    context "with a self-call (explicit self receiver)" do
      it "records self.foo as nil receiver" do
        code = <<~RUBY
          def process
            self.save
          end
        RUBY
        result = visit_method(code, "process")
        expect(result.calls.size).to eq(1)
        call = result.calls.first
        expect(call[:receiver]).to be_nil
        expect(call[:method]).to eq("save")
      end
    end

    context "with keyword arguments" do
      it "encodes keyword args as hash pairs" do
        code = <<~RUBY
          def validate
            validates(:email, presence: true, uniqueness: true)
          end
        RUBY
        result = visit_method(code, "validate")
        expect(result.calls.size).to eq(1)
        args = result.calls.first[:arguments]
        # First arg: symbol :email
        expect(args[0]).to eq({type: :symbol, value: "email"})
        # Second arg: keyword hash
        keyword = args[1]
        expect(keyword[:type]).to eq(:hash)
        expect(keyword[:pairs]).to be_an(Array)
        expect(keyword[:pairs].size).to eq(2)
        expect(keyword[:pairs].first).to match(
          key: "presence", value: {type: :boolean, value: true}
        )
        expect(keyword[:pairs].last).to match(
          key: "uniqueness", value: {type: :boolean, value: true}
        )
      end
    end

    context "with a block argument" do
      it "records has_block: true for calls with blocks" do
        code = <<~RUBY
          def iterate
            users.each { |u| u.save }
          end
        RUBY
        result = visit_method(code, "iterate")
        expect(result.calls.size).to be >= 1
        outer_call = result.calls.first
        expect(outer_call[:method]).to eq("each")
        expect(outer_call[:has_block]).to be true
      end
    end

    context "with block iteration loops" do
      it "counts .each with a block as a loop" do
        code = <<~RUBY
          def iterate
            items.each { |i| puts i }
          end
        RUBY
        result = visit_method(code, "iterate")
        expect(result.loops).to be >= 1
      end

      it "counts .map with a block as a loop" do
        code = <<~RUBY
          def transform
            items.map { |i| i.to_s }
          end
        RUBY
        result = visit_method(code, "transform")
        expect(result.loops).to be >= 1
      end

      it "counts .select with a block as a loop" do
        code = <<~RUBY
          def filter
            items.select { |i| i.active? }
          end
        RUBY
        result = visit_method(code, "filter")
        expect(result.loops).to be >= 1
      end

      it "does not count a non-loop method with a block" do
        code = <<~RUBY
          def with_transaction
            ActiveRecord::Base.transaction { do_work }
          end
        RUBY
        result = visit_method(code, "with_transaction")
        # .transaction is not a loop method, so loops should not increment from it
        # (but there may be other calls)
        expect(result.loops).to eq(0)
      end
    end

    context "with nested calls as arguments" do
      it "encodes nested calls" do
        code = <<~RUBY
          def nested
            process(fetch_data, format_result)
          end
        RUBY
        result = visit_method(code, "nested")
        expect(result.calls.size).to eq(3) # process, fetch_data, format_result
        process_call = result.calls.first
        expect(process_call[:method]).to eq("process")
        expect(process_call[:arguments].size).to eq(2)
        expect(process_call[:arguments][0][:type]).to eq(:call)
        expect(process_call[:arguments][0][:method]).to eq("fetch_data")
      end
    end

    context "with multiple calls" do
      it "records all top-level calls in order" do
        code = <<~RUBY
          def multi(a, b)
            first_call
            second_call(a)
            third_call(a, b)
          end
        RUBY
        result = visit_method(code, "multi")
        expect(result.calls.size).to eq(3)
        expect(result.calls[0][:method]).to eq("first_call")
        expect(result.calls[1][:method]).to eq("second_call")
        expect(result.calls[2][:method]).to eq("third_call")
      end
    end

    context "with nil body" do
      it "returns empty result" do
        result = visitor.visit(nil)
        expect(result.calls).to eq([])
        expect(result.loops).to eq(0)
      end
    end

    # ── Control Flow Counting ──────────────────────────────────────────

    context "with IfNode (regular if)" do
      it "counts as both branch and conditional" do
        code = <<~RUBY
          def check
            if active?
              do_work
            end
          end
        RUBY
        result = visit_method(code, "check")
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(1)
        expect(result.loops).to eq(0)
      end

      it "counts if/elsif/else as multiple branches but single conditional" do
        code = <<~RUBY
          def multi_branch(x)
            if x == 1
              one
            elsif x == 2
              two
            elsif x == 3
              three
            else
              other
            end
          end
        RUBY
        result = visit_method(code, "multi_branch")
        # if + 2 elsifs + else = 4 branches, but only 1 conditional (the top-level if)
        expect(result.branches).to eq(4)
        expect(result.conditionals).to eq(1)
      end
    end

    context "with IfNode ternary (?:)" do
      it "counts as branch only, not conditional" do
        code = <<~RUBY
          def pick
            active? ? do_work : skip
          end
        RUBY
        result = visit_method(code, "pick")
        expect(result.branches).to be >= 1  # ternary is an IfNode with nil if_keyword_loc
        expect(result.conditionals).to eq(0)
      end

      it "ternary inside regular if is counted correctly" do
        code = <<~RUBY
          def complex(a, b)
            if a
              b ? yes : no
            end
          end
        RUBY
        result = visit_method(code, "complex")
        # if = 1 branch + 1 conditional; ternary = 1 branch
        expect(result.branches).to eq(2)
        expect(result.conditionals).to eq(1)
      end
    end

    context "with UnlessNode" do
      it "counts as both branch and conditional" do
        code = <<~RUBY
          def process
            unless valid?
              raise_error
            end
          end
        RUBY
        result = visit_method(code, "process")
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(1)
      end

      it "modifier unless is also branch + conditional" do
        code = <<~RUBY
          def guard
            run unless stopped?
          end
        RUBY
        result = visit_method(code, "guard")
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(1)
      end
    end

    context "with WhileNode" do
      it "counts as loop and branch" do
        code = <<~RUBY
          def repeat
            while running?
              tick
            end
          end
        RUBY
        result = visit_method(code, "repeat")
        expect(result.branches).to eq(1)
        expect(result.loops).to eq(1)
        expect(result.conditionals).to eq(0)
      end
    end

    context "with UntilNode" do
      it "counts as loop and branch" do
        code = <<~RUBY
          def retry_until
            until success?
              attempt
            end
          end
        RUBY
        result = visit_method(code, "retry_until")
        expect(result.branches).to eq(1)
        expect(result.loops).to eq(1)
      end
    end

    context "with ForNode" do
      it "counts as loop and branch" do
        code = <<~RUBY
          def iterate
            for item in items do
              process(item)
            end
          end
        RUBY
        result = visit_method(code, "iterate")
        expect(result.branches).to eq(1)
        expect(result.loops).to eq(1)
      end
    end

    context "with CaseNode" do
      it "counts each branch (case, when, else)" do
        code = <<~RUBY
          def classify(x)
            case x
            when 1
              :one
            when 2
              :two
            when 3
              :three
            else
              :other
            end
          end
        RUBY
        result = visit_method(code, "classify")
        # case + 3 whens + else = 5 branches
        expect(result.branches).to eq(5)
        expect(result.conditionals).to eq(0)
      end

      it "case without else counts correctly" do
        code = <<~RUBY
          def short_case(x)
            case x
            when :a then 1
            when :b then 2
            end
          end
        RUBY
        result = visit_method(code, "short_case")
        # case + 2 whens = 3 branches
        expect(result.branches).to eq(3)
      end
    end

    context "with AndNode (&&)" do
      it "counts as branch" do
        code = <<~RUBY
          def guard_clause
            process if valid? && authorized?
          end
        RUBY
        result = visit_method(code, "guard_clause")
        # modifier if = 1 branch + 1 conditional; && = 1 branch
        expect(result.branches).to eq(2)
        expect(result.conditionals).to eq(1)
      end
    end

    context "with OrNode (||)" do
      it "counts as branch" do
        code = <<~RUBY
          def fallback
            result = primary || secondary
          end
        RUBY
        result = visit_method(code, "fallback")
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(0)
      end
    end

    context "with RescueModifierNode" do
      it "counts inline rescue as branch" do
        code = <<~RUBY
          def safe_parse
            value = Integer(input) rescue nil
          end
        RUBY
        result = visit_method(code, "safe_parse")
        expect(result.branches).to eq(1)
      end
    end

    context "with BeginNode" do
      it "does not add extra branch counts for begin/ensure" do
        code = <<~RUBY
          def with_ensure
            begin
              do_work
            ensure
              cleanup
            end
          end
        RUBY
        result = visit_method(code, "with_ensure")
        # BeginNode adds no branch itself — only traverses children
        expect(result.branches).to eq(0)
      end
    end

    # ── Nested Structures ──────────────────────────────────────────────

    context "with nested structures" do
      it "loop inside conditional produces correct additive counts" do
        code = <<~RUBY
          def nested_loop_in_if
            if active?
              items.each { |i| process(i) }
            end
          end
        RUBY
        result = visit_method(code, "nested_loop_in_if")
        # if = 1 branch + 1 conditional; each with block = 1 loop
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(1)
        expect(result.loops).to eq(1)
      end

      it "conditional inside loop produces correct additive counts" do
        code = <<~RUBY
          def conditional_in_loop
            items.each do |item|
              process(item) if item.valid?
            end
          end
        RUBY
        result = visit_method(code, "conditional_in_loop")
        # each with block = 1 loop; modifier if = 1 branch + 1 conditional
        expect(result.branches).to eq(1)
        expect(result.conditionals).to eq(1)
        expect(result.loops).to eq(1)
      end

      it "handles deep nesting (if inside each inside if)" do
        code = <<~RUBY
          def deep_nesting
            if outer?
              items.each do |item|
                if inner?(item)
                  process(item)
                end
              end
            end
          end
        RUBY
        result = visit_method(code, "deep_nesting")
        # outer if = 1 branch + 1 conditional
        # each = 1 loop
        # inner if = 1 branch + 1 conditional
        expect(result.branches).to eq(2)
        expect(result.conditionals).to eq(2)
        expect(result.loops).to eq(1)
      end

      it "matches Example 2 from spec: if/while/elsif/rescue" do
        code = <<~RUBY
          def foo
            if x
              while y
                z
              end
            elsif w
              a rescue b
            end
          end
        RUBY
        result = visit_method(code, "foo")
        # if = 1 branch + 1 conditional
        # while = 1 branch + 1 loop
        # elsif = 1 branch
        # rescue modifier = 1 branch
        # Total: 4 branches, 1 conditional, 1 loop
        expect(result.branches).to eq(4)
        expect(result.conditionals).to eq(1)
        expect(result.loops).to eq(1)
      end

      it "handles combined structural loops and block-iteration loops" do
        code = <<~RUBY
          def combined_loops
            while condition?
              items.each { |i| work(i) }
            end
            list.map { |x| transform(x) }
          end
        RUBY
        result = visit_method(code, "combined_loops")
        # while = 1 branch + 1 loop
        # each with block = 1 loop
        # map with block = 1 loop
        expect(result.branches).to eq(1)
        expect(result.loops).to eq(3)
      end

    end

    context "with interpolated string arguments" do
      it "reconstructs interpolated strings" do
        code = <<~RUBY
          def greeting
            log("Hello \#{name}, welcome!")
          end
        RUBY
        result = visit_method(code, "greeting")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:string)
        expect(args[0][:value]).to include("Hello")
      end
    end

    context "with array arguments" do
      it "encodes array literal arguments" do
        code = <<~RUBY
          def with_array
            process([1, 2, 3])
          end
        RUBY
        result = visit_method(code, "with_array")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:array)
        expect(args[0][:elements]).to be_an(Array)
        expect(args[0][:elements].size).to eq(3)
      end
    end

    context "with lambda argument" do
      it "encodes lambda as block type" do
        code = <<~RUBY
          def with_lambda
            execute(-> { do_stuff })
          end
        RUBY
        result = visit_method(code, "with_lambda")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:block)
        expect(args[0][:source]).to include("do_stuff")
      end
    end

    context "with constant reference as argument" do
      it "encodes constant references" do
        code = <<~RUBY
          def with_const
            include(ActiveSupport::Concern)
          end
        RUBY
        result = visit_method(code, "with_const")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:constant)
        expect(args[0][:value]).to eq("ActiveSupport::Concern")
      end
    end

    context "with local variable read as argument" do
      it "encodes local variable reads" do
        code = <<~RUBY
          def with_var(name, age)
            process(name, age)
          end
        RUBY
        result = visit_method(code, "with_var")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:local_variable)
        expect(args[0][:value]).to eq("name")
        expect(args[1][:type]).to eq(:local_variable)
        expect(args[1][:value]).to eq("age")
      end
    end

    context "with instance variable as argument" do
      it "encodes instance variable reads" do
        code = <<~RUBY
          def use_ivar
            process(@data)
          end
        RUBY
        result = visit_method(code, "use_ivar")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:instance_variable)
        expect(args[0][:value]).to eq("@data")
      end
    end

    context "with splat argument" do
      it "encodes splat arguments" do
        code = <<~RUBY
          def splat_args(*args)
            process(*args)
          end
        RUBY
        result = visit_method(code, "splat_args")
        args = result.calls.first[:arguments]
        expect(args[0][:type]).to eq(:splat)
      end
    end
  end
end
