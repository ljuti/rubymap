---
name: extractor-intra-method-analysis
type: feature
priority: 1
slices:
  - call-recording
  - control-flow-metrics
  - rails-dsl-detection
  - integration-regression
---

## Problem

The Rubymap extractor captures method signatures (name, parameters, visibility, receiver type) but does not analyze method bodies. The `MethodExtractor` records what a method looks like from the outside but never looks inside. The `CallExtractor` only handles top-level AST patterns (`attr_*`, `include`, `require`, `alias_method`) and silently drops every other `CallNode` — whether it appears at the class body level or inside a method.

This starves every downstream pipeline stage of data:

- **Rails enrichers** (`ModelEnricher`, `ControllerEnricher`) contain sophisticated logic for detecting `has_many`, `validates`, `before_action`, `scope`, and other patterns, but they iterate `method.calls_made` which is never populated. These enrichers are dead code.
- **Method call graphs** are empty. The `InputAdapter` explicitly sets `method_calls: []` with the comment "Extractor doesn't provide method_calls."
- **Complexity and quality metrics** have no data. The `NormalizedMethod` struct defines `branches`, `loops`, `conditionals`, and `body_lines` fields, but the normalizer processors never populate them because the extractor never produces them.
- **Rails DSL calls at class body level** (`has_many :posts`, `validates :name, presence: true`, `scope :active, -> { ... }`, `before_action :set_user`) are not recognized. The `CallExtractor`'s `case node.name` matches only `attr_*`, `include`/`extend`/`prepend`, `private`/`protected`/`public`, `require`/`require_relative`, `autoload`, and `alias_method`. Everything else is silently dropped.

The consequence is that approximately 40% of the features listed in the README as implemented cannot work end-to-end. The architecture is solid and the pipeline skeleton is correct, but the extractor does not produce the data the rest of the pipeline needs.

## Desired Outcome

After all four slices land, extracting any Ruby method produces:

1. **Call recording**: `MethodInfo.calls_made` is populated with every call made inside the method body, including receiver chain (e.g., `Rails.logger.info` → `["Rails", "logger"]`), method name, typed arguments (symbols → `{type: :symbol, value: "active"}`, strings, integers, keywords → `{type: :hash, pairs: [...]}`, lambda blocks → `{type: :block, source: "-> { ... }"}`), and a boolean `has_block` flag.
2. **Control flow metrics**: `MethodInfo.branches`, `.loops`, `.conditionals`, and `.body_lines` are populated with correct integer counts.
3. **Rails DSL patterns**: `Result.patterns` includes `PatternInfo` entries for Rails DSL calls at class body level — `has_many`, `belongs_to`, `has_one`, `validates` and its variants, `before_action`/`after_action`/`around_action`, `scope`, `default_scope`, `rescue_from`, `delegate`. Each pattern records the method name, target class, arguments, and source location.
4. **No regressions**: All existing extractor, normalizer, enricher, indexer, and emitter tests continue to pass. The full `bundle exec rspec` suite runs green.

The new data survives `MethodInfo#to_h` serialization and flows through the pipeline to downstream consumers.

## Context

### Existing codebase locations

- `lib/rubymap/extractor.rb`
  - Main extractor module. Requires all extractor components. The `Extractor` class provides `extract_from_file`, `extract_from_code`, `extract_from_directory`. Stateless — each extraction creates its own `ExtractionContext`.
- `lib/rubymap/extractor/node_visitor.rb`
  - AST traversal engine. `visit(node)` dispatches to handler methods by node type. `handle_method` calls `MethodExtractor#extract(node)` then `visit_children(node)` — body nodes ARE visited but `CallExtractor` silently drops most of them. `handle_class` calls `ClassExtractor#extract` then `visit_children`. `handle_call` dispatches to `CallExtractor#extract`.
- `lib/rubymap/extractor/extractors/call_extractor.rb`
  - Handles `Prism::CallNode`. Current `case node.name` matches: `attr_reader`, `attr_writer`, `attr_accessor` → `AttributeInfo`; `include`, `extend`, `prepend` → `MixinInfo`; `private`, `protected`, `public` → visibility change; `require`, `require_relative` → `DependencyInfo`; `autoload` → `DependencyInfo`; `alias_method` → `AliasInfo`. **No catch-all else clause** — unrecognized calls are silently dropped.
- `lib/rubymap/extractor/extractors/method_extractor.rb`
  - Extracts method signatures: name, receiver type, parameters, visibility, documentation. Does NOT look at the method body. Does NOT record any call data.
- `lib/rubymap/extractor/models/method_info.rb`
  - Current fields: `name`, `visibility`, `receiver_type`, `params`, `location`, `doc`, `namespace`, `owner`, `rubymap`. Has `to_h` serialization. Missing: `calls_made`, `branches`, `loops`, `conditionals`, `body_lines`.
- `lib/rubymap/extractor/extraction_context.rb`
  - Tracks `current_namespace` (Array) and `current_visibility` (Symbol). Has `with_namespace` and `with_visibility` scope methods. Missing: `current_class`, `current_method` tracking.
- `lib/rubymap/extractor/result.rb`
  - Aggregates all extracted symbols. Has `patterns` array (Array\<PatternInfo\>) for detected patterns. Rails DSL calls from V3 will append here.
- `lib/rubymap/extractor/models/pattern_info.rb`
  - Struct for detected code patterns. Fields: `type`, `method`, `target`, `location`, `indicators`. Rails DSL patterns will use `type: "rails_dsl"`.
- `lib/rubymap/normalizer/input_adapter.rb`
  - Converts extractor output to normalizer input. Currently sets `method_calls: []` with comment "Extractor doesn't provide method_calls". This comment becomes obsolete after V1.
- `lib/rubymap/enricher/rails/model_enricher.rb`
  - Iterates `method.calls_made` to detect `has_many`, `validates`, `scope` etc. Currently receives empty arrays. Becomes functional after V1+V3.
- `lib/rubymap/enricher/rails/controller_enricher.rb`
  - Iterates `method.calls_made` to detect `before_action`, `rescue_from` etc. Same dependency.
- `lib/rubymap/normalizer.rb`
  - `NormalizedMethod` struct defines `branches`, `loops`, `conditionals`, `body_lines` fields that are never populated. These become populated after V2.

### Shaping reference

- **Shape selected**: B — MethodBodyVisitor + Extend CallExtractor for Rails DSL. Two components, clean separation between "what calls does a method make?" and "what patterns exist at the class body level?"
- **Spike B2 complete**: Prism AST node type mapping confirmed across 20 representative method bodies. Key finding: ternary `?:` is `IfNode` with nil `if_keyword_loc` (same class as regular if). `.each {}` blocks are `CallNode` with `node.block` present. All 30+ node types that appear in method bodies are catalogued.
- **Slice dependency**: V1 (call recording) → V2 (extend with counting) + V3 (Rails DSL, independent of V2) → V4 (all together + regression).
- **Out of scope (Phase 6)**: Runtime introspection, `define_method` detection, dynamic method capture.

## Acceptance Criteria

- [ ] AC#1: Given a Ruby method body containing calls like `user.save!`, `Rails.logger.info("hello")`, and `items.each { |i| process(i) }`, when extracted via `Extractor#extract_from_code`, then the resulting `MethodInfo` has `calls_made` containing three entries with correct `receiver` chains, `method` names, and typed `arguments`.
- [ ] AC#2: Given a method body with control flow (`if/elsif/else`, `while`, `rescue`, ternary `?:`, `&&`/`||`), when extracted, then `MethodInfo` has `branches`, `loops`, `conditionals`, and `body_lines` populated with correct integer counts matching the actual structure.
- [ ] AC#3: Given a Rails model class body containing `has_many :posts, dependent: :destroy`, `validates :name, presence: true`, and `scope :active, -> { where(active: true) }`, when extracted, then `Result.patterns` contains three `PatternInfo` entries with `type: "rails_dsl"`, correct `method` names, and the target class name.
- [ ] AC#4: Given a Rails controller class body containing `before_action :set_user, only: [:show, :edit]` and `rescue_from ActiveRecord::RecordNotFound, with: :not_found`, when extracted, then `Result.patterns` contains two `PatternInfo` entries with correct method names and arguments.
- [ ] AC#5: Given `bundle exec rspec spec/extractor_spec.rb spec/extractor/**/*_spec.rb`, when run after all four slices, then all existing extractor tests continue to pass with no changed behavior.
- [ ] AC#6: Given `bundle exec rspec`, when run after all four slices, then the full test suite passes. Every failure is investigated as introduced by the changes unless concrete evidence (CI log/link, green commit SHA, or reproducible pre-change failure) proves the failure pre-dated the changes. No unverified "pre-existing" or "environmental" labels are permitted.
- [ ] AC#7: Given a method with keyword arguments (`has_many :posts, dependent: :destroy`) and a lambda argument (`scope :active, -> { where(active: true) }`), when extracted, then arguments are encoded as `{type: :hash, pairs: [...]}` and `{type: :block, source: "-> { where(active: true) }"}` respectively.
- [ ] AC#8: Given nested structures (loop inside conditional, conditional inside loop), when extracted, then branch, loop, and conditional counts are correct for the entire method, not just the top level.
- [ ] AC#9: Given `MethodInfo#to_h` is called on a fully extracted method, then the output hash includes `calls_made`, `branches`, `loops`, `conditionals`, and `body_lines` keys with correct values.

## Technical Direction

Build a new `MethodBodyVisitor` class in `lib/rubymap/extractor/extractors/method_body_visitor.rb` that recursively walks a method's body AST. [AC#1]

The visitor dispatches on Prism node type using the confirmed node type map from the shaping spike (all 30+ types catalogued). For `CallNode`: record `{receiver:, method:, arguments:, has_block:}`. For control flow nodes: increment the appropriate counter. For structural/leaf nodes: recurse into children only. [AC#2]

Use a `MethodBodyResult` value object to collect results: `{calls: [], branches: 0, loops: 0, conditionals: 0, body_lines: 0}`. The visitor mutates this object and returns it. [AC#1]

Modify `NodeVisitor#handle_method` in `lib/rubymap/extractor/node_visitor.rb` to wrap body traversal in `context.with_method(name)`, run `MethodBodyVisitor.new.visit(node.body)`, and attach the returned `MethodBodyResult` to the last `MethodInfo` added by `MethodExtractor`. [AC#1]

Add `calls_made`, `branches`, `loops`, `conditionals`, and `body_lines` accessors to `MethodInfo` in `lib/rubymap/extractor/models/method_info.rb`. Update `MethodInfo#to_h` to include all five fields. [AC#9]

Add `current_method` and `with_method(name, &block)` to `ExtractionContext`. Add `current_class` and `with_class(name, &block)` to `ExtractionContext`. [AC#3]

Extend `CallExtractor#extract`'s existing `case node.name` with Rails DSL patterns. When `context.current_class` is set and the call matches a Rails DSL pattern name, record a `PatternInfo` on `result.patterns`. Use a private `record_rails_dsl(node)` helper. \[AC#3\]\[AC#4\]

The Rails DSL pattern set covers: `has_many`, `has_one`, `belongs_to`, `has_and_belongs_to_many`, `validates` and all `validates_*` variants, `before_action`/`after_action`/`around_action`/`skip_before_action`/`skip_after_action`/`skip_around_action` and their `_filter` aliases, `scope`, `default_scope`, `rescue_from`, `delegate`. \[AC#3\]\[AC#4\]

Implement `resolve_constant_path(node)` as a private method on both `MethodBodyVisitor` and `CallExtractor` (or extract into a shared module). Walk the receiver chain: `nil` → `nil`, `ConstantReadNode` → `[name]`, `ConstantPathNode` → `resolve(parent) + [name]`, `CallNode` → `resolve(receiver) + [name]`. [AC#1]

Implement `extract_args(arguments_node)` as a private method on `MethodBodyVisitor`. Encode each argument as `{type:, value:}`: `SymbolNode` → `{type: :symbol, value: unescaped}`, `StringNode` → `{type: :string, value: unescaped}`, `IntegerNode` → `{type: :integer, value:}`, `KeywordHashNode` → `{type: :hash, pairs:}`, `LambdaNode` → `{type: :block, source: slice}`, and so on for all argument types. [AC#7]

Modify `NodeVisitor#handle_class` and `#handle_module` to wrap `visit_children` in `context.with_class(name)`. This enables `CallExtractor` to attribute Rails DSL calls to their parent class. [AC#3]

Conditional counting must exclude ternary `?:` — check `node.if_keyword_loc` on `IfNode`: if nil, it's a ternary (branch only, not conditional). If populated, it's a regular/modifier if (both branch and conditional). [AC#2]

Loop counting must include both structural loops (`WhileNode`, `UntilNode`, `ForNode`) and block iteration calls (`CallNode` with name in LOOP_METHODS and `node.block` present). LOOP_METHODS: `each`, `map`, `collect`, `select`, `reject`, `find`, `detect`, `reduce`, `inject`, `times`, `upto`, `downto`, `step`, `each_with_index`, `each_with_object`, `group_by`, `partition`, `sort_by`, `flat_map`. [AC#2]

Body lines: compute as `def_node.location.end_line - def_node.location.start_line`. Pass the `DefNode` to the visitor or compute in `NodeVisitor#handle_method` and inject. [AC#2]

Do not modify the existing extractor dispatch mechanism or handler registry. The new components are additive. [AC#5]

Prefer a dedicated `method_body_result.rb` file in `lib/rubymap/extractor/` for the `MethodBodyResult` class. (guidance)

## Domain Rules

- Every `CallNode` inside a method body must be recorded, not just those matching known patterns. The visitor has no filter — it records everything.
- Call arguments must preserve type information, not just string representations. `:active` is `{type: :symbol, value: "active"}`, not `"active"`.
- Control flow counts are additive — nested structures contribute to the total (not just the first level).
- Rails DSL patterns are only recorded when `context.current_class` is set (class body context, not inside a method body).
- The `CallExtractor` continues to handle all existing patterns (`attr_*`, `include`, `require`, etc.) exactly as before. New Rails DSL `when` clauses are additive and must not shadow or conflict with existing ones.
- `MethodInfo` fields default to empty array for `calls_made` and 0 for all count fields when no extraction occurs (empty method body).
- Receiver resolution handles chains of arbitrary depth. `Rails.logger.info` resolves to `["Rails", "logger"]`; `a.b.c.d` resolves to `["a", "b", "c"]`.

## Edge Cases & Failure Modes

- Empty method body (`def foo; end`): `calls_made` is an empty array, all counts are 0, no error raised.
- Method body containing only comments or whitespace: same as empty — all fields default to empty/0 values.
- Method body with a single literal value and no calls (`def foo; 42; end`): `calls_made` is empty, all counts are 0. No crash.
- Deeply nested structures (10+ levels of if-inside-each-inside-if): visitor recurses without stack overflow. Counts are correct at all nesting levels.
- Method defined with `def self.foo` (singleton method): treated identically to instance methods. `receiver_type` is already set correctly by `MethodExtractor`.
- Rails model class with no superclass or a non-Rails superclass: `CallExtractor` still detects Rails DSL calls if the patterns match. No crash if `superclass` is nil.
- Call with a `nil` receiver (self-call like `save`): `receiver` field is `nil` in the recorded call hash. Not `["self"]`.
- DefNode with a nil body (`def foo; end` where Prism produces no body node): visitor handles nil body gracefully, returns empty result.
- `CallExtractor` Rails DSL `when` clause matches a symbol also used by a non-Rails library: the pattern is still recorded. The enricher layer is responsible for filtering by `context.current_class` inheriting from a Rails base class.

## Examples

### Example 1: Simple call recording

- Setup: Ruby code `def foo; user.save!; Rails.cache.write("key", value); end`
- Action: `extractor.extract_from_code(code).methods.first`
- Result: `calls_made` contains two entries. First: `{receiver: ["user"], method: "save!", arguments: [], has_block: false}`. Second: `{receiver: ["Rails", "cache"], method: "write", arguments: [{type: :string, value: "key"}, {type: :call, ...}], has_block: false}`.

### Example 2: Control flow counting

- Setup: `def foo; if x; while y; z; end; elsif w; a rescue b; end; end`
- Action: `extractor.extract_from_code(code).methods.first`
- Result: `branches` is 4 (if, elsif, while, inline rescue), `conditionals` is 1 (if — elsif is part of the same IfNode, while is a loop not a conditional), `loops` is 1 (while), `body_lines` matches `end_line - start_line`.

### Example 3: Rails model DSL detection

- Setup: Ruby code `class User < ApplicationRecord; has_many :posts, dependent: :destroy; validates :name, presence: true; scope :active, -> { where(active: true) }; end`
- Action: `extractor.extract_from_code(code).patterns`
- Result: Three `PatternInfo` entries, all with `type: "rails_dsl"`. First: `method: "has_many"`, target: `"User"`. Second: `method: "validates"`, target: `"User"`. Third: `method: "scope"`, target: `"User"`.

### Example 4: Nested method with both calls and control flow

- Setup: `def publish_all; posts.each do |post| post.publish! if post.draft?; post.notify! unless post.silent?; end; end`
- Action: `extractor.extract_from_code(code).methods.first`
- Result: `calls_made` contains 5+ entries (draft?, publish!, silent?, notify!, and each with block). `branches` is 2 (if modifier, unless modifier). `loops` is 1 (each). `conditionals` is 2.

### Example 5: to_h serialization includes all new fields

- Setup: Any extracted method with calls and control flow
- Action: `method_info.to_h`
- Result: Hash includes `calls_made:` (Array), `branches:` (Integer), `loops:` (Integer), `conditionals:` (Integer), `body_lines:` (Integer) — all present even when values are empty/zero.

## Boundaries

- In scope: Method body call recording, control flow counting, Rails DSL pattern detection at class body level, typed argument encoding, receiver chain resolution, MethodInfo model changes, ExtractionContext changes, NodeVisitor wiring, to_h serialization, full regression test suite passage.
- Out of scope: Runtime introspection (`define_method` detection, dynamic method capture — deferred to Phase 6), changes to normalizer/enricher/indexer/emitter pipeline stages (these consume the data but are not modified), RBS type parsing, YARD annotation parsing beyond what the existing extractor already handles, performance optimization of the visitor.
- Do not modify: The `NodeVisitor` handler registry dispatch mechanism, the `Extractor` public API (`extract_from_file`, `extract_from_code`, `extract_from_directory` signatures), the `ClassExtractor`, `ModuleExtractor`, `MethodExtractor` core logic (only add wiring, don't change extraction logic), the `Pipeline#merge_result!` method or any downstream pipeline stage.

### Slice: call-recording

Deliver the core infrastructure for recording calls inside method bodies. Build the `MethodBodyResult` value object and the `MethodBodyVisitor` class with call recording logic (no counting yet). Add `calls_made` to `MethodInfo` with `to_h` serialization. Add `current_method` and `with_method` to `ExtractionContext`. Wire `NodeVisitor#handle_method` to run the visitor and attach results. Implement `extract_args` for typed argument encoding and `resolve_chain` for receiver resolution.

**Acceptance Criteria:**
- `MethodBodyResult` class exists with `calls`, `branches`, `loops`, `conditionals`, `body_lines` fields (all initialized to empty/0)
- `MethodBodyVisitor` records every `CallNode` in a method body as `{receiver:, method:, arguments:, has_block:}`
- Symbol arguments encoded as `{type: :symbol, value: "name"}`; strings as `{type: :string, value: "content"}`; lambdas as `{type: :block, source: "..."}`
- `Rails.logger.info("hello")` resolves receiver chain to `["Rails", "logger"]`
- Self-calls (no receiver) recorded with `receiver: nil`
- `.each`/`.map` block calls counted toward `loops`
- `MethodInfo.calls_made` populated after extraction
- `MethodInfo#to_h` includes `calls_made` key
- `go test` equivalent: `bundle exec rspec spec/extractor/method_body_visitor_spec.rb spec/extractor/models/method_info_spec.rb` passes
- All existing extractor tests pass (no regression)

### Slice: control-flow-metrics

Extend the `MethodBodyVisitor` built in V1 with counting logic for control flow structures. Add `branches`, `loops`, `conditionals`, and `body_lines` fields to `MethodInfo`. Implement `count_branches`, `count_conditionals`, `count_loops`, and `count_body_lines` inside the visitor. The visitor dispatches on the confirmed Prism node type map and increments the correct counter for each control flow node.

**Acceptance Criteria:**
- `MethodBodyVisitor` dispatches on `IfNode`, `UnlessNode`, `CaseNode`, `WhileNode`, `UntilNode`, `ForNode`, `AndNode`, `OrNode`, `RescueModifierNode`, `BeginNode`
- `IfNode` with nil `if_keyword_loc` (ternary `?:`) counted as branch only, not conditional
- Regular `if` and `unless` counted as both branch and conditional
- `WhileNode`/`UntilNode`/`ForNode` counted as loops
- `.each`/`.map` block calls counted as loops (from V1)
- `MethodInfo.branches`, `.loops`, `.conditionals`, `.body_lines` populated with correct values
- Nested structures (loop inside conditional, conditional inside loop) produce correct additive counts
- `MethodInfo#to_h` includes all four count keys
- `bundle exec rspec spec/extractor/method_body_visitor_spec.rb spec/extractor/models/method_info_spec.rb` passes
- All existing extractor tests pass (no regression from V1)

### Slice: rails-dsl-detection

Extend `CallExtractor` to recognize Rails DSL patterns at class body level. Add `current_class` and `with_class` to `ExtractionContext`. Wire `NodeVisitor#handle_class` and `#handle_module` to wrap children in `with_class`. Add `resolve_constant_path` helper to `CallExtractor`. Records `PatternInfo` entries on `Result.patterns` for all recognized Rails DSL calls.

**Acceptance Criteria:**
- `CallExtractor#extract` detects `has_many`, `has_one`, `belongs_to`, `has_and_belongs_to_many` and records `PatternInfo(type: "rails_dsl", method:, target:, arguments:)`
- `CallExtractor` detects `validates` and all `validates_*` variants
- `CallExtractor` detects `before_action`, `after_action`, `around_action`, and their `skip_` and `_filter` variants
- `CallExtractor` detects `scope`, `default_scope`, `rescue_from`, `delegate`
- Each Rails DSL pattern records the target class name from `context.current_class`
- `ExtractionContext` tracks `current_class` with `with_class(name, &block)` that saves/restores state
- `NodeVisitor#handle_class` wraps children in `context.with_class(clas_name)`
- `NodeVisitor#handle_module` wraps children in `context.with_class(module_name)`
- Existing `CallExtractor` patterns (`attr_*`, `include`, `require`, etc.) continue to work unchanged when Rails DSL calls are also present
- Non-Rails classes produce no Rails DSL patterns
- `bundle exec rspec spec/extractor/extractors/call_extractor_spec.rb spec/extractor/extraction_context_spec.rb` passes
- All existing extractor tests pass (no regression from V1)

### Slice: integration-regression

Run the full test suite and verify that V1-V3 work together correctly with no regressions. Write integration tests that exercise the complete pipeline with realistic Ruby fixtures. Create a gold file test for a reference project. Fix any issues discovered.

**Acceptance Criteria:**
- `bundle exec rspec` — full test suite passes with 0 new failures. Any failure is treated as introduced unless proven pre-existing with concrete evidence (CI log/link or commit SHA demonstrating the failure pre-dated the changes).
- New test files from V1-V3 all pass: `spec/extractor/method_body_visitor_spec.rb`, `spec/extractor/extractors/call_extractor_spec.rb` (Rails DSL section), `spec/extractor/models/method_info_spec.rb` (new fields), `spec/extractor/extraction_context_spec.rb` (current_class, current_method)
- Integration test: extract a realistic Rails model (`User < ApplicationRecord` with `has_many`, `validates`, `scope`, multiple methods with control flow), verify all new fields populated, `to_h` serialization complete
- Integration test: extract a realistic Rails controller (`UsersController < ApplicationController` with `before_action`, `rescue_from`), verify Rails DSL patterns detected
- Integration test: `Rubymap.map("spec/fixtures/test_project", format: :llm)` succeeds and produces output with call data flowing through the pipeline
- `bundle exec standardrb` — no linting violations
