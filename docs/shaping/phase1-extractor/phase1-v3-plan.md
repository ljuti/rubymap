# V3 Plan: Rails DSL Detection + Receiver Resolution

**Slice:** V3 of [slices.md](slices.md)
**Requirements:** R2, R6
**Depends on:** V1 (ExtractionContext changes, basic infrastructure)
**Demo:** Extract a Rails model file containing `has_many :posts`, `validates :name, presence: true`, `scope :active, -> { where(active: true) }`. Inspect `result.patterns` — three `PatternInfo` entries with type `"rails_dsl"`, method name matching, and target class.

---

## Scope

Extend CallExtractor to recognize Rails DSL patterns at class body level. Add current_class tracking to ExtractionContext. Add receiver resolution helper for Rails DSL calls. Wire NodeVisitor#handle_class and #handle_module to wrap children in with_class context.

This slice is independent of V2 (control flow counting). It only depends on V1 for the ExtractionContext modifications.

---

## Affordances to Build/Modify

| ID | Affordance | What to build |
|----|-----------|---------------|
| N10 | `ExtractionContext` (extended) | Add `current_class` attribute (String). Add `with_class(name, &block)` method that saves/restores current_class (and pushes namespace). |
| N11 | `CallExtractor#extract` (extended) | Add `when` clauses to the existing `case node.name` statement for Rails DSL patterns. Each records `PatternInfo.new(type: "rails_dsl", method: node.name.to_s, target: context.current_class, arguments: extract_call_arguments(node), location: node.location)`. |
| N12 | `resolve_constant_path` | New private method on CallExtractor (or shared module). Same logic as MethodBodyVisitor's resolve_chain. Walks receiver: nil→nil, ConstantReadNode→[name], ConstantPathNode→resolve(parent)+[name], CallNode→resolve(node.receiver)+[name], SelfNode→["self"]. |
| N15 | `NodeVisitor#handle_class` (modified) | Wrap existing `visit_children(node)` in `context.with_class(class_name) do ... end`. |
| — | `NodeVisitor#handle_module` (modified) | Same as handle_class — wrap visit_children in `context.with_class(module_name)`. |

## Rails DSL Patterns to Add

Add these `when` clauses to CallExtractor#extract's existing `case node.name`:

```ruby
# Associations
when :has_many, :has_one, :belongs_to, :has_and_belongs_to_many
  record_rails_dsl(node)

# Validations
when :validates, :validates_presence_of, :validates_uniqueness_of,
     :validates_length_of, :validates_format_of, :validates_inclusion_of,
     :validates_exclusion_of, :validates_numericality_of, :validates_acceptance_of,
     :validates_confirmation_of, :validates_associated, :validates_each, :validate
  record_rails_dsl(node)

# Controller filters
when :before_action, :after_action, :around_action,
     :skip_before_action, :skip_after_action, :skip_around_action,
     :before_filter, :after_filter, :around_filter
  record_rails_dsl(node)

# Scopes
when :scope, :default_scope
  record_rails_dsl(node)

# Error handling
when :rescue_from
  record_rails_dsl(node)

# Delegation
when :delegate
  record_rails_dsl(node)
```

Where `record_rails_dsl` is:

```ruby
def record_rails_dsl(node)
  pattern = PatternInfo.new(
    type: "rails_dsl",
    method: node.name.to_s,
    target: context.current_class,
    location: node.location,
    arguments: extract_call_arguments(node),
    receiver: resolve_constant_path(node.receiver)
  )
  result.patterns << pattern
end
```

And `extract_call_arguments` is:

```ruby
def extract_call_arguments(node)
  return [] unless node.arguments&.arguments
  
  node.arguments.arguments.map do |arg|
    case arg
    when Prism::SymbolNode then {type: :symbol, value: arg.unescaped}
    when Prism::StringNode then {type: :string, value: arg.unescaped}
    when Prism::IntegerNode then {type: :integer, value: arg.value}
    when Prism::TrueNode then {type: :boolean, value: true}
    when Prism::FalseNode then {type: :boolean, value: false}
    when Prism::NilNode then {type: :nil, value: nil}
    when Prism::LambdaNode then {type: :block, source: arg.slice}
    else {type: :unknown, value: arg.slice}
    end
  end
end
```

## ExtractionContext Changes (N10)

Current fields: `current_namespace` (Array), `current_visibility` (Symbol).
Add: `current_class` (String, nil by default).

```ruby
def with_class(name, &block)
  old_class = @current_class
  @current_class = name
  with_namespace(name, &block)  # Also pushes namespace
ensure
  @current_class = old_class
end
```

## Files Modified

- `lib/rubymap/extractor/extraction_context.rb` — add current_class, with_class
- `lib/rubymap/extractor/extractors/call_extractor.rb` — add Rails DSL when clauses + helpers
- `lib/rubymap/extractor/node_visitor.rb` — modify handle_class and handle_module

## Test Plan

### spec/extractor/extractors/call_extractor_spec.rb

```ruby
describe "Rails DSL detection" do
  before do
    @context = Rubymap::Extractor::ExtractionContext.new
    @result = Rubymap::Extractor::Result.new
  end

  def extract_rails_patterns(code)
    full_code = "class User < ApplicationRecord\n#{code}\nend"
    extractor = Rubymap::Extractor.new
    result = extractor.extract_from_code(full_code)
    result.patterns.select { |p| p.type == "rails_dsl" }
  end

  it "detects has_many with symbol argument" do
    patterns = extract_rails_patterns("has_many :posts")
    expect(patterns).to_not be_empty
    expect(patterns.first.method).to eq("has_many")
    expect(patterns.first.target).to eq("User")
  end

  it "detects belongs_to" do
    patterns = extract_rails_patterns("belongs_to :organization")
    expect(patterns.first.method).to eq("belongs_to")
  end

  it "detects has_one" do
    patterns = extract_rails_patterns("has_one :profile")
    expect(patterns.first.method).to eq("has_one")
  end

  it "detects validates with arguments" do
    patterns = extract_rails_patterns("validates :name, presence: true")
    expect(patterns).to_not be_empty
    expect(patterns.first.method).to eq("validates")
  end

  it "detects scope with name and lambda" do
    patterns = extract_rails_patterns("scope :active, -> { where(active: true) }")
    expect(patterns.first.method).to eq("scope")
  end

  it "detects before_action" do
    patterns = extract_rails_patterns("before_action :set_user")
    expect(patterns.first.method).to eq("before_action")
  end

  it "detects rescue_from" do
    patterns = extract_rails_patterns("rescue_from ActiveRecord::RecordNotFound, with: :not_found")
    expect(patterns.first.method).to eq("rescue_from")
  end

  it "detects delegate" do
    patterns = extract_rails_patterns("delegate :name, to: :user")
    expect(patterns.first.method).to eq("delegate")
  end

  it "captures arguments on the pattern" do
    patterns = extract_rails_patterns("has_many :posts, dependent: :destroy")
    expect(patterns.first.arguments).to_not be_empty
  end

  it "resolves receiver on delegate calls" do
    # delegate :name, to: :user — receiver should be tracked
    # Actually delegate is a class-level call with no explicit receiver (self-call)
    # But the pattern still needs to track it for the enricher
    patterns = extract_rails_patterns("delegate :name, to: :user")
    expect(patterns.first).to_not be_nil
  end

  it "does not detect non-Rails calls as patterns" do
    patterns = extract_rails_patterns("def foo; bar; end")
    expect(patterns).to be_empty
  end

  it "detects multiple patterns in same class" do
    patterns = extract_rails_patterns("has_many :posts\nvalidates :name, presence: true\nscope :active, -> { where(active: true) }")
    expect(patterns.size).to eq(3)
  end

  it "attributes pattern to correct class in namespaced context" do
    # TODO: if nested class defines its own Rails DSL
  end
end
```

### spec/extractor/extraction_context_spec.rb

Add to existing spec:
- `it "tracks current_class with with_class block"`
- `it "restores current_class after with_class block"`
- `it "pushes namespace in with_class"`

## Completion Criteria

- [ ] ExtractionContext tracks current_class via with_class API
- [ ] CallExtractor detects all 25+ Rails DSL patterns listed above
- [ ] Each pattern records type, method, target class, arguments, location
- [ ] NodeVisitor#handle_class wraps children in with_class
- [ ] NodeVisitor#handle_module wraps children in with_class
- [ ] Non-Rails classes produce no Rails DSL patterns
- [ ] Existing CallExtractor behavior unaffected (attr_*, include, require still work)
- [ ] All existing tests pass
- [ ] All new V3 tests pass
