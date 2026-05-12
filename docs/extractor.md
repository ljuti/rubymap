Think of the Extractor as the "facts harvester." Its only job is to walk source and (optionally) a sandboxed runtime, and emit raw, lossless, minimally-interpreted events about what it sees—fast, safely, and with rich provenance. Everything smarter (merging, precedence, scoring) happens later in the Normalizer/Enricher.

## Why an Extractor?

- Separation of concerns: keep "read & record" apart from "decide & merge." This lets you optimize I/O and parsing without entangling policy.

- Performance envelope: a lean, streaming Extractor can hit your <1s / 1k files goal. Normalization can run concurrently or later.

- Repeatability: raw events are append-only and order-insensitive, perfect for golden tests and debugging ("what exactly did we see?").

- Provenance: attach exact "where/when/how" to every fact so downstream can justify decisions.

## What the Extractor does (scope)

Core outputs (static):

- **module_defined, class_defined** (fqname, path, line, superclass)

- **method_defined** (owner, name, receiver: instance|class, visibility, params w/ kinds, line)
  - NEW: **Method body analysis** — every call inside the method body is recorded with receiver chain, method name, and typed arguments.
  - NEW: **Control flow metrics** — branch count, loop count, conditional count, and body line count are computed per method.

- **mixin_added** (include|extend|prepend, into, mod, line)

- **constant_assigned** (name, fqname, value_kind: scalar|struct|unknown)

- **require_edge** (from file → required path)

- **attr_macro** (attr_reader|writer|accessor|cattr_*, generated names)

- **alias_method / undef_method** sightings

- **comment_block** (YARD doc raw text + anchor)

- NEW: **Rails DSL pattern detection** — class-level calls like `has_many`, `validates`, `before_action`, `scope`, `rescue_from`, and `delegate` are captured as structured `PatternInfo` entries on their parent class/module.

Optional outputs (plugins):

- YARD: doc tags (@param/@return/@raise), summary.

- RBS/Sorbet: type signatures for methods/consts from .rbs/.rbi.

- SCM: git churn/lightweight blame per file.

- Rails runtime (opt-in): models (columns/assocs), routes, controllers, jobs, mailers.

- Frameworks (opt-in): GraphQL schema, Sidekiq queue opts, ActionCable channels, etc.

What it explicitly does not do:
- No merging of reopenings, no precedence decisions, no confidence scoring. (That's the Normalizer.)
- No runtime introspection (`define_method` detection, dynamic method capture — deferred to Phase 6).

## Architecture

### Component Overview

The extractor is built around a **NodeVisitor** that traverses the Prism AST, dispatching to specialized extractors by node type via a **NodeHandlerRegistry**. Each extractor is responsible for one category of symbol.

```
┌─────────────────────────────────────────────────┐
│                   NodeVisitor                    │
│                                                  │
│  visit(node) ──→ handler_for(node) ──→ extract  │
│                                                  │
│  handle_class    → ClassExtractor               │
│  handle_module   → ModuleExtractor              │
│  handle_method   → MethodExtractor              │
│                  → MethodBodyVisitor (NEW)       │
│  handle_call     → CallExtractor                │
│  handle_constant → ConstantExtractor            │
│  handle_cvar     → ClassVariableExtractor       │
│  handle_alias    → AliasExtractor               │
└─────────────────────────────────────────────────┘
```

### Intra-Method Analysis (NEW)

When the NodeVisitor encounters a method definition, it now performs **two-phase extraction**:

1. **Signature extraction** (MethodExtractor): Records the method name, parameters, visibility, receiver type, documentation, and namespace — exactly as before.

2. **Body analysis** (MethodBodyVisitor): Recursively walks the method body AST and records:
   - Every `CallNode` with receiver chain, method name, typed arguments, and block presence
   - Control flow counts: branches, loops, conditionals
   - Body line count: `end_line - start_line` from the DefNode location

The results are attached to the `MethodInfo` object that was just added by the signature extraction.

### MethodBodyVisitor

**File:** `lib/rubymap/extractor/extractors/method_body_visitor.rb`

A recursive AST walker that dispatches on Prism node type:

| Node Type | Action |
|-----------|--------|
| `CallNode` | Record `{receiver:, method:, arguments:, has_block:}`. If name is in `LOOP_METHODS` and a block is present → increment loops |
| `IfNode` | If `if_keyword_loc` is nil → branch only (ternary). Else → branch + conditional |
| `UnlessNode` | Branch + conditional |
| `CaseNode` | Branch per clause (case + each when + else) |
| `WhileNode`, `UntilNode`, `ForNode` | Branch + loop |
| `AndNode`, `OrNode` | Branch |
| `RescueModifierNode` | Branch |
| `BeginNode` | Traverse children (no extra counting) |
| `StatementsNode`, `BlockNode`, `LambdaNode`, etc. | Recurse into children only |
| Leaf nodes (Symbol, String, Integer, etc.) | No-op — terminal |

**LOOP_METHODS:** `each`, `map`, `collect`, `select`, `reject`, `find`, `detect`, `reduce`, `inject`, `times`, `upto`, `downto`, `step`, `each_with_index`, `each_with_object`, `group_by`, `partition`, `sort_by`, `flat_map`.

These are methods that, when called with a block, indicate iteration over a collection. They increment the `loops` counter.

### MethodBodyResult

**File:** `lib/rubymap/extractor/method_body_result.rb`

A value object holding the complete results of body analysis:

```ruby
class MethodBodyResult
  attr_accessor :calls        # Array<Hash> — recorded call data
  attr_accessor :branches     # Integer — branch points
  attr_accessor :loops        # Integer — loop constructs
  attr_accessor :conditionals # Integer — conditional expressions
  attr_accessor :body_lines   # Integer — line count
end
```

### Call Recording Format

Each recorded call is a Hash with these keys:

```ruby
{
  receiver: ["Rails", "logger"],  # Array<String> or nil for self-calls
  method: "info",                  # String — the method name
  arguments: [                     # Array<Hash> — typed arguments
    {type: :string, value: "hello"},
    {type: :hash, pairs: [{key: "level", value: {type: :symbol, value: "debug"}}]}
  ],
  has_block: false                 # Boolean — whether a block was passed
}
```

### Argument Encoding

Arguments are encoded with type information preserved. The `extract_args` helper maps each Prism argument node to a `{type:, value:}` hash:

| Prism Node Type | Encoded As |
|----------------|------------|
| `SymbolNode` | `{type: :symbol, value: "name"}` |
| `StringNode` | `{type: :string, value: "content"}` |
| `IntegerNode` | `{type: :integer, value: 42}` |
| `FloatNode` | `{type: :float, value: 3.14}` |
| `TrueNode` / `FalseNode` | `{type: :boolean, value: true/false}` |
| `NilNode` | `{type: :nil, value: nil}` |
| `KeywordHashNode` | `{type: :hash, pairs: [{key:, value:}, ...]}` |
| `HashNode` | `{type: :hash, pairs: [...]}` |
| `LambdaNode` | `{type: :block, source: "-> { ... }"}` |
| `ArrayNode` | `{type: :array, elements: [...]}` |
| `CallNode` | `{type: :call, receiver:, method:, arguments:, has_block:}` |
| `ConstantReadNode` | `{type: :constant, value: "Name"}` |
| `ConstantPathNode` | `{type: :constant, value: "A::B"}` |
| `LocalVariableReadNode` | `{type: :local_variable, value: "name"}` |
| `InstanceVariableReadNode` | `{type: :instance_variable, value: "@name"}` |
| `ClassVariableReadNode` | `{type: :class_variable, value: "@@name"}` |
| `GlobalVariableReadNode` | `{type: :global_variable, value: "$name"}` |
| `SelfNode` | `{type: :self, value: "self"}` |
| `SplatNode` | `{type: :splat, value: <inner>}` |
| `BlockArgumentNode` | `{type: :block_pass, value: <inner>}` |
| `AssocSplatNode` | `{type: :hash_splat, value: <inner>}` |
| `ParenthesesNode` | Delegates to inner expression |
| Other / unknown | `{type: :unknown, value: "<source>"}` |

### Receiver Chain Resolution

The `resolve_chain` helper walks up a receiver's AST to build an array of component names:

- `nil` → `nil` (self-call, implicit receiver)
- `SelfNode` → `nil` (`self.foo` treated as implicit receiver)
- `ConstantReadNode` → `["Rails"]`
- `ConstantPathNode` → resolve parent, append child name: `["ActiveSupport", "Concern"]`
- `CallNode` → resolve receiver, append method name: `Rails.logger.info` → `["Rails", "logger"]`
- Other types → `[node.slice]` (local variables, instance variables, etc.)

### Rails DSL Detection

The `CallExtractor` (in `lib/rubymap/extractor/extractors/call_extractor.rb`) has been extended to detect Rails DSL calls at the class body level. When `context.current_class` is set (i.e., we are inside a class/module body but NOT inside a method), the following calls are recorded as `PatternInfo` entries with `type: "rails_dsl"`:

**Association macros:**
- `has_many`, `has_one`, `belongs_to`, `has_and_belongs_to_many`

**Validation macros:**
- `validates` and all `validates_*` variants (matched via `start_with?("validates")`)

**Controller action filters:**
- `before_action`, `after_action`, `around_action`
- `skip_before_action`, `skip_after_action`, `skip_around_action`
- `before_filter`, `after_filter`, `around_filter` (legacy aliases)
- `skip_before_filter`, `skip_after_filter`, `skip_around_filter` (legacy aliases)

**Other Rails DSL:**
- `scope`, `default_scope`
- `rescue_from`
- `delegate`

Each pattern records the method name, target class, arguments (as indicators), and source location.

**Guard:** Rails DSL patterns are only recorded when `context.current_class` is set AND `context.current_method` is nil. This ensures DSL calls inside method bodies are treated as regular calls (recorded by MethodBodyVisitor), not as class-level patterns.

### ExtractionContext

The `ExtractionContext` tracks the current position in the AST traversal:

- `current_namespace` — the fully qualified namespace (e.g., `"App::Models"`)
- `current_visibility` — current method visibility (`:public`, `:private`, `:protected`)
- `current_class` — the name of the class/module currently being traversed (for Rails DSL attribution)
- `current_method` — the name of the method currently being traversed (to prevent DSL detection inside methods)

Scope methods (`with_namespace`, `with_visibility`, `with_class`, `with_method`) save the current value, set a new one, yield, and restore the original on ensure.

### MethodInfo Model

The `MethodInfo` model now includes five new fields populated by body analysis:

```ruby
class MethodInfo
  attr_accessor :calls_made    # Array<Hash> — every call in the method body
  attr_accessor :branches      # Integer — branch points (if/unless/case/&&/||/rescue)
  attr_accessor :loops         # Integer — loops (while/until/for + block iteration)
  attr_accessor :conditionals  # Integer — conditional expressions (if/unless)
  attr_accessor :body_lines    # Integer — line count of the method
end
```

All five fields are included in `MethodInfo#to_h` serialization and default to `[]` (calls_made) or `0` (counts) when no extraction occurs.

### Data Flow

The new data survives serialization and flows through the pipeline:

```
Extractor
  └─ NodeVisitor#handle_method
       ├─ MethodExtractor#extract (signature)
       └─ MethodBodyVisitor#visit (body)
            └─ MethodBodyResult → attached to MethodInfo
                 └─ MethodInfo#to_h → includes calls_made, branches, loops,
                                      conditionals, body_lines
                      └─ Result#to_h → includes methods with full data
                           └─ Pipeline → Normalizer → Enricher → Emitter
```

The `Result#to_h` output includes `patterns` (Rails DSL PatternInfo entries) and each `MethodInfo#to_h` includes all five body analysis fields, ensuring downstream consumers receive the data.

### Control Flow Counting Rules

**What counts as a branch:**
- `if` / `elsif` / `else` clauses in an IfNode (ternary `?:` counts as 1 branch)
- `unless` clauses
- `case` statement itself + each `when` clause + `else` clause
- `&&` / `||` / `and` / `or` operators (AndNode, OrNode)
- `while` / `until` / `for` loops
- Inline `rescue` modifier (RescueModifierNode)

**What counts as a conditional:**
- `if` with `if_keyword_loc` present (not ternary `?:`)
- `unless`
- Note: `elsif` is part of the same IfNode — only the top-level `if` increments the conditional counter

**What counts as a loop:**
- `while` / `until` / `for` structural loops
- Block iteration calls: any `CallNode` whose name is in `LOOP_METHODS` AND has a block attached

**Ternary handling:** `a ? b : c` is an `IfNode` with `if_keyword_loc` set to nil. It counts as 1 branch but 0 conditionals.

**Body lines:** Computed as `def_node.location.end_line - def_node.location.start_line`. This includes the `def` and `end` lines, providing the total line span of the method.

## Design principles

- Streaming & bounded memory: emit NDJSON (one JSON per line) as you go; never accumulate the whole repo in RAM.

- Process-parallel by default: a worker pool over file paths; each worker parses & writes its own shard (to avoid lock contention).

- Lossless + minimal: capture exactly what you see; don't paraphrase (e.g., store original param spellings, raw doc block).

- Deterministic emissions: stable field ordering, stable enums, normalized paths/encodings.

- Provenance-rich: every line has source, extractor, version, path, line, timestamps, and (for runtime) a session_id.

- Additive, not destructive: new features extend existing extractors without modifying their core logic. The handler registry dispatch mechanism is untouched.

- Pure static analysis: the extractor never executes Ruby code. All introspection is AST-based via the Prism parser.