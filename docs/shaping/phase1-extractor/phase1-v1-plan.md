# V1 Plan: Call Recording

**Slice:** V1 of [slices.md](slices.md)
**Requirements:** R0, R4, R5, R8
**Depends on:** Nothing (first slice)
**Demo:** Extract a Ruby method, inspect `result.methods.first.calls_made` — shows real call data with receiver, method name, and typed arguments.

---

## Scope

Build the core infrastructure: MethodBodyVisitor that walks method bodies and records every `CallNode`, extract_args helper that encodes arguments in a type-safe hash format, and wire it into NodeVisitor so MethodInfo carries call data through to_h.

Control flow counting (branches, loops, conditionals) is explicitly OUT — that's V2. Rails DSL patterns are OUT — that's V3.

---

## Affordances to Build

| ID | Affordance | What to build |
|----|-----------|---------------|
| N1 | `MethodBodyResult` | New value object class. Fields: `calls` (empty array), `branches` (Integer, default 0), `loops` (default 0), `conditionals` (default 0), `body_lines` (default 0). All counters initialized to 0 but not populated in V1. |
| N2 | `MethodBodyVisitor` (basic) | New class: `lib/rubymap/extractor/extractors/method_body_visitor.rb`. `initialize`, `visit(node)` that recursively walks the body. Dispatches: `CallNode` → N3. All other node types → recurse into children (no counting). Uses the confirmed node type map from [spike-b2.md](spike-b2.md) for all structural nodes. |
| N3 | `handle_call` | Inside MethodBodyVisitor. For each CallNode: records `{receiver: resolve_chain(node.receiver), method: node.name.to_s, arguments: extract_args(node.arguments), has_block: !!node.block}`. Appends to calls list. Also: if `node.name` is in LOOP_METHODS and `node.block` is present → increment loops counter (this is the ONE counting rule in V1 since it comes for free with call recording). |
| N13 | `extract_args` | Private method on MethodBodyVisitor. Maps each element of `node.arguments.arguments` to `{type:, value:}` hash. Handles: SymbolNode, StringNode, IntegerNode, FloatNode, TrueNode, FalseNode, NilNode, KeywordHashNode, LambdaNode, CallNode (shallow), ConstantReadNode, ArrayNode. Full mapping table in [shaping.md](shaping.md#argument-encoding-extract_args--b8). For block arguments: LambdaNode → `{type: :block, source: node.slice}`. |
| N8 (partial) | `MethodInfo` | Add `attr_accessor :calls_made` to existing MethodInfo class. No other new fields yet (V2 adds branches/loops/conditionals/body_lines). |
| N9 (partial) | `MethodInfo#to_h` | Add `calls_made: calls_made` to the existing to_h hash output. |
| N10 (partial) | `ExtractionContext` | Add `current_method` attribute (String), `with_method(name, &block)` method that saves/restores current_method around the block. |
| N14 | `NodeVisitor#handle_method` | Modify existing method. After `@extractors[:method].extract(node)`: call `context.with_method(method_name)`, create MethodBodyVisitor, visit `node.body`, attach returned MethodBodyResult to the last MethodInfo in result.methods. |
| — | `resolve_chain` | Private helper on MethodBodyVisitor for receiver resolution. Walk up receiver chain: nil→nil, ConstantReadNode→[name], ConstantPathNode→resolve(parent)+[name], CallNode→resolve(node.receiver)+[name], SelfNode→["self"]. |
| — | `LOOP_METHODS` | Constant on MethodBodyVisitor: `%w[each map collect select reject find detect reduce inject times upto downto step each_with_index each_with_object group_by partition sort_by flat_map]`. |

## Files Created/Modified

**New files:**
- `lib/rubymap/extractor/extractors/method_body_visitor.rb`

**Modified files:**
- `lib/rubymap/extractor/models/method_info.rb` — add calls_made, update to_h
- `lib/rubymap/extractor/extraction_context.rb` — add current_method, with_method
- `lib/rubymap/extractor/node_visitor.rb` — modify handle_method
- `lib/rubymap/extractor.rb` — require method_body_visitor

**Test files:**
- `spec/extractor/method_body_visitor_spec.rb` — new
- `spec/extractor/models/method_info_spec.rb` — update for calls_made
- `spec/extractor/extraction_context_spec.rb` — update for current_method

## Test Plan

### spec/extractor/method_body_visitor_spec.rb

```ruby
RSpec.describe Rubymap::Extractor::MethodBodyVisitor do
  describe "#visit" do
    it "records calls with no receiver as self-call" do
      code = "def foo; bar; end"
      result = extract_and_inspect(code)
      expect(result.calls).to contain_exactly(
        hash_including(receiver: nil, method: "bar")
      )
    end

    it "records calls with simple receiver" do
      code = "def foo; user.save; end"
      result = extract_and_inspect(code)
      expect(result.calls).to contain_exactly(
        hash_including(receiver: ["user"], method: "save")
      )
    end

    it "records chained calls with full receiver chain" do
      code = "def foo; Rails.logger.info('hello'); end"
      result = extract_and_inspect(code)
      expect(result.calls).to contain_exactly(
        hash_including(receiver: ["Rails", "logger"], method: "info")
      )
    end

    it "records multiple calls in order" do
      code = "def foo; user.save!; user.notify; end"
      result = extract_and_inspect(code)
      expect(result.calls.size).to eq(2)
      expect(result.calls[0][:method]).to eq("save!")
      expect(result.calls[1][:method]).to eq("notify")
    end

    it "records calls with symbol arguments" do
      code = "def foo; scope :active; end"
      result = extract_and_inspect(code)
      expect(result.calls.first[:arguments]).to contain_exactly(
        hash_including(type: :symbol, value: "active")
      )
    end

    it "records calls with string arguments" do
      code = 'def foo; log("hello"); end'
      result = extract_and_inspect(code)
      expect(result.calls.first[:arguments]).to contain_exactly(
        hash_including(type: :string, value: "hello")
      )
    end

    it "records calls with keyword arguments as hash" do
      code = "def foo; has_many :posts, dependent: :destroy; end"
      result = extract_and_inspect(code)
      args = result.calls.first[:arguments]
      expect(args).to include(hash_including(type: :symbol, value: "posts"))
      expect(args).to include(hash_including(type: :hash))
    end

    it "records lambda/block arguments with source text" do
      code = "def foo; scope :active, -> { where(active: true) }; end"
      result = extract_and_inspect(code)
      block_arg = result.calls.first[:arguments].last
      expect(block_arg[:type]).to eq(:block)
      expect(block_arg[:source]).to include("where")
    end

    it "marks calls with attached blocks" do
      code = "def foo; items.each { |i| process(i) }; end"
      result = extract_and_inspect(code)
      expect(result.calls.first[:has_block]).to be true
    end

    it "marks calls without blocks as has_block: false" do
      code = "def foo; user.save; end"
      result = extract_and_inspect(code)
      expect(result.calls.first[:has_block]).to be false
    end

    it "counts .each calls as loops" do
      code = "def foo; items.each { |i| process(i) }; end"
      result = extract_and_inspect(code)
      expect(result.loops).to eq(1)
    end

    it "handles empty method bodies" do
      code = "def foo; end"
      result = extract_and_inspect(code)
      expect(result.calls).to be_empty
      expect(result.branches).to eq(0)
    end

    it "handles methods returning a single value without calls" do
      code = "def foo; 42; end"
      result = extract_and_inspect(code)
      expect(result.calls).to be_empty
    end
  end
end
```

### spec/extractor/models/method_info_spec.rb

Add to existing spec:
- `it "includes calls_made in to_h output"`
- `it "to_h handles nil calls_made"`

### Integration check

After V1:
- `bundle exec rspec spec/extractor_spec.rb` — all existing extraction tests pass
- `bundle exec rspec spec/rubymap_spec.rb` — Rubymap.map still works

## Completion Criteria

- [ ] MethodBodyVisitor class exists and is required by Extractor
- [ ] Every CallNode in a method body is recorded with receiver, method, arguments, has_block
- [ ] Symbol arguments → `{type: :symbol, value: "name"}`
- [ ] String arguments → `{type: :string, value: "content"}`
- [ ] Keyword arguments → `{type: :hash, pairs: [...]}`
- [ ] Lambda/block arguments → `{type: :block, source: "-> { ... }"}`
- [ ] Chained receivers resolved: `Rails.logger.info` → `["Rails", "logger"]`
- [ ] Self-calls (no receiver) → `receiver: nil`
- [ ] MethodInfo.calls_made populated after extraction
- [ ] MethodInfo#to_h includes calls_made
- [ ] .each/.map block calls counted as loops
- [ ] All new tests pass
- [ ] All existing extractor tests pass (no regression)
