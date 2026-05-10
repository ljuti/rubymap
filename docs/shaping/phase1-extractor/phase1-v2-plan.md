# V2 Plan: Control Flow Metrics

**Slice:** V2 of [slices.md](slices.md)
**Requirements:** R1
**Depends on:** V1 (MethodBodyVisitor must exist)
**Demo:** Extract methods with if/while/each/rescue/ternary. Inspect `branches`, `loops`, `conditionals`, `body_lines` — correct integer counts.

---

## Scope

Extend the MethodBodyVisitor built in V1 with counting logic. Also extend MethodInfo with the four count fields. The visitor already dispatches on node type and recurses into children — V2 adds increment operations at the right dispatch points.

Rails DSL patterns and receiver resolution are OUT — those are V3.

---

## Affordances to Build/Modify

| ID | Affordance | What to build |
|----|-----------|---------------|
| N4 | `count_branches` | Add increment logic inside MethodBodyVisitor#visit for these node types: `IfNode` (all forms including ternary), `UnlessNode`, `CaseNode`, `AndNode`, `OrNode`, `RescueModifierNode`, `BeginNode` (when `rescue_clause` is present). Increment `@branches` by 1 for each. |
| N5 | `count_conditionals` | Add increment logic for: `IfNode` (only when `if_keyword_loc` is NOT nil — skip ternary), `UnlessNode`, `CaseNode`. Increment `@conditionals` by 1 for each. |
| N6 | `count_loops` | V1 already counts block-based loops (.each etc.). Add increment logic for: `WhileNode`, `UntilNode`, `ForNode`. Increment `@loops` by 1 for each. |
| N7 | `count_body_lines` | Compute during visit: `@body_lines = def_node.location.end_line - def_node.location.start_line`. The visitor receives the body node, but we need the DefNode for line counting. Pass `def_node` to the visitor or compute in NodeVisitor and inject. |
| N8 | `MethodInfo` (extended) | Add `attr_accessor :branches, :loops, :conditionals, :body_lines` (all Integer). |
| N9 | `MethodInfo#to_h` (extended) | Add all four fields to the to_h hash. |

## Node Type Dispatch (full map after V2)

The complete `visit` method dispatches:

```ruby
def visit(node)
  return unless node.is_a?(Prism::Node)
  
  case node
  when Prism::CallNode
    record_call(node)
  when Prism::IfNode
    @branches += 1
    @conditionals += 1 unless node.if_keyword_loc.nil?  # skip ternary
    recurse_children(node)
  when Prism::UnlessNode
    @branches += 1
    @conditionals += 1
    recurse_children(node)
  when Prism::CaseNode
    @branches += 1
    @conditionals += 1
    recurse_children(node)
  when Prism::WhileNode, Prism::UntilNode, Prism::ForNode
    @loops += 1
    recurse_children(node)
  when Prism::AndNode, Prism::OrNode
    @branches += 1
    recurse_children(node)
  when Prism::RescueModifierNode
    @branches += 1
    recurse_children(node)
  when Prism::BeginNode
    @branches += 1 if node.rescue_clause
    recurse_children(node)
  else
    # All structural nodes (StatementsNode, ArgumentsNode, ElseNode,
    # WhenNode, BlockNode, LambdaNode, etc.) and leaf nodes
    recurse_children(node)
  end
  
  @result
end
```

## Files Modified

- `lib/rubymap/extractor/extractors/method_body_visitor.rb` — add counting dispatch
- `lib/rubymap/extractor/models/method_info.rb` — add branches, loops, conditionals, body_lines
- `lib/rubymap/extractor/node_visitor.rb` — pass def_node for body_lines calculation, attach all count fields

## Test Plan

### Extend spec/extractor/method_body_visitor_spec.rb

```ruby
describe "control flow counting" do
  describe "branches" do
    it "counts if/elsif/else as branches" do
      code = "def foo; if a; b; elsif c; d; else; e; end; end"
      result = extract_and_inspect(code)
      # if is 1 branch, elsif is 1 branch (else doesn't add a branch)
      # Actually: if = 1 branch (decision point), elsif = 1 branch. else = no branch.
      # But also there's no AndNode/OrNode here so it should be 2.
      # Let me think again... if is 1, elsif is 1, that's 2 branches.
      expect(result.branches).to eq(2)
    end

    it "counts unless as branch" do
      code = "def foo; unless x; y; end; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end

    it "counts case/when as branches" do
      code = "def foo; case v; when :a; b; when :c; d; else; e; end; end"
      result = extract_and_inspect(code)
      # case = 1, when :a = 1, when :c = 1 = 3 branches
      expect(result.branches).to eq(3)
    end

    it "counts && as branch" do
      code = "def foo; a && b; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end

    it "counts || as branch" do
      code = "def foo; a || b; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end

    it "counts ternary as branch" do
      code = "def foo; a ? b : c; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end

    it "counts inline rescue as branch" do
      code = "def foo; dangerous rescue fallback; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end

    it "counts begin/rescue as branch" do
      code = "def foo; begin; a; rescue; b; end; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)
    end
  end

  describe "conditionals" do
    it "counts if as conditional (not ternary)" do
      code = "def foo; if x; y; end; end"
      result = extract_and_inspect(code)
      expect(result.conditionals).to eq(1)
    end

    it "does NOT count ternary as conditional" do
      code = "def foo; a ? b : c; end"
      result = extract_and_inspect(code)
      expect(result.conditionals).to eq(0)
    end

    it "counts case/when as conditionals" do
      code = "def foo; case v; when :a; b; end; end"
      result = extract_and_inspect(code)
      expect(result.conditionals).to eq(1)
    end
  end

  describe "loops" do
    it "counts while as loop" do
      code = "def foo; while x; y; end; end"
      result = extract_and_inspect(code)
      expect(result.loops).to eq(1)
    end

    it "counts until as loop" do
      code = "def foo; until x; y; end; end"
      result = extract_and_inspect(code)
      expect(result.loops).to eq(1)
    end

    it "each with block = loop (from V1)" do
      code = "def foo; items.each { |i| p(i) }; end"
      result = extract_and_inspect(code)
      expect(result.loops).to eq(1)
    end

    it "map with block = loop" do
      code = "def foo; items.map { |i| i.name }; end"
      result = extract_and_inspect(code)
      expect(result.loops).to eq(1)
    end
  end

  describe "body_lines" do
    it "counts body lines from def to end" do
      code = "def foo\n  bar\n  baz\nend"
      result = extract_and_inspect(code)
      expect(result.body_lines).to eq(3)  # def, bar, baz, end = 4? or body only?
    end
  end

  describe "nested structures" do
    it "counts correctly in nested if-inside-each" do
      code = "def foo; items.each do |i| if i.active?; process(i); end; end; end"
      result = extract_and_inspect(code)
      expect(result.branches).to eq(1)  # if
      expect(result.conditionals).to eq(1)  # if (not ternary)
      expect(result.loops).to eq(1)  # each
    end
  end

  describe "combined metrics" do
    it "counts all metrics for a complex method" do
      code = "def foo
        items.each do |item|
          if item.valid?
            item.save rescue nil
          end
        end
        total || 0
      end"
      result = extract_and_inspect(code)
      expect(result.branches).to be > 0
      expect(result.loops).to eq(1)
      expect(result.conditionals).to be > 0
    end
  end
end
```

## Completion Criteria

- [ ] MethodBodyVisitor dispatches on all control flow node types
- [ ] branches count correct for: if/elsif, unless, case/when, &&, ||, ternary, inline rescue, begin/rescue
- [ ] conditionals count correct for: if (regular/modifier only, not ternary), unless, case
- [ ] loops count correct for: while, until, for, .each/.map/.times block calls
- [ ] body_lines computed from DefNode location
- [ ] MethodInfo has all four count fields
- [ ] MethodInfo#to_h includes all four count fields
- [ ] Nested structures (loop inside conditional, conditional inside loop) counted correctly
- [ ] All existing tests pass (no regression from V1)
- [ ] All new V2 tests pass
