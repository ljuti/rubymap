# Normalizer: The Contract Enforcer

The Normalizer is where raw, messy facts become a canonical, deterministic model. Without it, every downstream piece (enricher, indexer, emitters, CI checks) must re-solve Ruby's quirks—and you'll get noisy diffs and brittle consumers.

## Why a Normalizer?

### 1. Multiple sources, one shape
You'll ingest facts from Prism (static), Rails runtime, YARD, RBS/Sorbet, and Git. Each speaks a slightly different dialect. The Normalizer reconciles them into a single schema with stable enums, field names, and defaults.

### 2. Ruby's reopenings & meta
Classes are reopened across files; methods can be redefined; modules are included/prepended/extended; singleton methods vs instance methods; aliases. The Normalizer decides identity and precedence and merges duplicates into one symbol.

### 3. Determinism for diffability & RAG
Stable IDs, stable ordering, and consistent field defaults mean clean PR diffs and stable "chunks" for LLM retrieval. If the order changes every run, your index and embeddings churn.

### 4. Policy lives in one place
Precedence like "RBS types > Sorbet RBI > YARD tags > inferred" or "runtime-discovered methods are marked dynamic but don't override signatures" belongs in one layer (not copy-pasted into emitters/queries).

### 5. Quality gates
Validate, fill gaps, and flag uncertainty (e.g., confidence, source, dynamic: true). Strip secrets, normalize paths/encodings, and attach provenance before anything is published.

## Current Implementation

### Core Features

#### 1. Canonical Identity
- **Symbol IDs**: Deterministic SHA256-based IDs using `hash(kind/fqname/receiver/arity)`
- **Normalized FQNames**: Consistent `::` paths with Zeitwerk awareness
- **Normalized Paths**: Root-relative, POSIX format, UTF-8 encoding

```ruby
symbol_id = @symbol_id_generator.generate_method_id(
  fqname: "User#save",
  receiver: "instance", 
  arity: 0
) # => "c4f3d2e1a5b6789c" (stable across runs)
```

#### 2. Merge & Precedence System
- **Smart Deduplication**: Combines partial data for the same symbol across files/passes
- **Precedence Matrix** (implemented):
  - **Types**: RBS (4) > Sorbet (3) > YARD (2) > Runtime (5) > Static (6) > Inferred (1)
  - **Visibility**: Most restrictive wins if explicit; tracks provenance
  - **Methods**: Newest definition wins for location; history preserved
  - **Docs**: Prefer non-empty YARD; first line as summary

```ruby
SOURCE_PRECEDENCE = {
  "inferred" => 1,   # Lowest
  "yard" => 2,
  "sorbet" => 3,
  "rbs" => 4,        # Highest for types
  "runtime" => 5,    # High for discovered behavior
  "static" => 6      # High for AST analysis
}
```

#### 3. Parameter Normalization
- **Ruby Param Kinds**: Mapped to enum: `req|opt|rest|keyreq|keyopt|keystar|block`
- **Default Values**: Normalized strings (no ASTs)
- **Arity Computation**: Calculated from parameter structure

#### 4. Relationship Shaping
- **Dedup Edges**: Inheritance, mixins, method calls
- **Mixin Details**: Tracks `include|extend|prepend` with resolution
- **Namespace Hierarchies**: Parent-child relationships built
- **Inheritance Chains**: Full superclass traversal

#### 5. Flags & Confidence
- **Provenance Tracking**: Every symbol tracks its sources
- **Confidence Scores**: 0.0–1.0 based on source reliability
- **Dynamic Flagging**: Marks define_method/method_missing patterns
- **Timestamps**: When each piece of data was processed

```ruby
provenance = Provenance.new(
  sources: ["rbs", "static"],
  confidence: 0.95,
  timestamp: "2024-01-15T10:30:00.123Z"
)
```

#### 6. Quality & Hygiene
- **Validation**: Input validation with detailed error reporting
- **Deterministic Output**: Sorted collections for stable output
- **Schema Versioning**: Tracks schema_version and normalizer_version
- **Error Collection**: Structured error reporting

## Architecture

```
Normalizer
├── SymbolIdGenerator      # Generates stable IDs
├── ProvenanceTracker      # Tracks data sources & confidence
├── Processing Pipeline    # Type-specific processing
│   ├── process_classes
│   ├── process_modules  
│   ├── process_methods
│   └── process_method_calls
├── Resolution Pipeline    # Relationship building
│   ├── build_namespace_hierarchies
│   ├── resolve_inheritance_chains
│   ├── resolve_cross_references
│   └── resolve_mixin_methods
├── Normalization Core     # Data standardization
│   ├── normalize_class
│   ├── normalize_module
│   ├── normalize_method
│   └── normalize_visibility
└── Output Pipeline
    ├── deduplicate_symbols
    └── ensure_deterministic_output
```

### Data Flow

```
Extractor(s) ──► RAW Data ──► NORMALIZER ──► Canonical Output
                               │              ├── symbol_id indexed
                               │              ├── provenance tracked
                               │              ├── conflicts resolved
                               │              └── deterministic order
                               └──► errors.log / validation report
```

## Data Structures

```ruby
NormalizedResult
├── classes: [NormalizedClass]
├── modules: [NormalizedModule]
├── methods: [NormalizedMethod]
├── method_calls: [NormalizedMethodCall]
├── errors: [NormalizedError]
├── schema_version: 1
├── normalizer_version: "1.0.0"
└── normalized_at: "2024-01-15T10:30:00.123Z"

NormalizedClass/Module
├── symbol_id: String           # "c4f3d2e1a5b6789c"
├── name: String               # "User"
├── fqname: String             # "MyApp::Models::User"
├── kind: String               # "class" | "module"
├── superclass: String         # "ApplicationRecord"
├── location: NormalizedLocation
├── namespace_path: [String]   # ["MyApp", "Models"]
├── children: [String]         # FQNames of nested classes
├── inheritance_chain: [String] # Full chain to Object
├── instance_methods: [String]
├── class_methods: [String]
├── available_instance_methods: [String] # Including inherited
├── available_class_methods: [String]
├── mixins: [{type, module}]
└── provenance: Provenance

NormalizedMethod
├── symbol_id: String          # "m4f3d2e1a5b6789d"
├── name: String              # "save"
├── fqname: String            # "User#save"
├── visibility: String        # "public|private|protected"
├── owner: String             # "User"
├── scope: String             # "instance|class"
├── parameters: [Parameter]
├── arity: Integer
├── canonical_name: String    # snake_case version
├── available_in: [String]    # Classes where available
├── inferred_visibility: String
├── source: String            # Original source
└── provenance: Provenance

Provenance
├── sources: [String]         # ["rbs", "static", "yard"]
├── confidence: Float         # 0.95
└── timestamp: String         # ISO8601
```

## Example: Raw → Normalized

### Raw Input (Multiple Sources)
```json
// From static analysis
{"kind":"method", "owner":"User", "name":"full_name", 
 "receiver":"instance", "params":[{"name":"style","kind":"keyreq"}],
 "returns":{"type":"String","source":"yard"}, 
 "defined_in":{"path":"app/models/user.rb","line":42}, "source":"static"}

// From runtime discovery  
{"kind":"method", "owner":"User", "name":"full_name",
 "receiver":"instance", "params":[{"name":"style","kind":"keyreq"}],
 "returns":{"type":"::String"}, 
 "defined_in":{"path":"app/models/user.rb","line":44}, 
 "source":"runtime", "dynamic":true}
```

### Normalized Output
```json
{
  "symbol_id": "8a7f3d2c1b5e9642",
  "kind": "method",
  "name": "full_name",
  "fqname": "User#full_name",
  "owner": "User",
  "scope": "instance",
  "visibility": "public",
  "parameters": [{"name":"style","kind":"keyreq"}],
  "arity": -1,
  "canonical_name": "full_name",
  "returns": {"type":"String","confidence":0.9},
  "location": {"file":"app/models/user.rb","line":42},
  "dynamic": true,
  "provenance": {
    "sources": ["static","runtime","yard"],
    "confidence": 0.85,
    "timestamp": "2024-01-15T10:30:00.123Z"
  },
  "available_in": ["User", "AdminUser"],
  "schema_version": 1
}
```

## Design Principles

### Pure, Idempotent, Deterministic
Given the same raw rows (order-independent), output is byte-identical. Makes testing easy and CI diffs meaningful.

### Provenance-First
Keep provenance on every symbol. You can answer "why is the return type String?" later.

### Minimal Intelligence  
Normalizer doesn't infer business semantics (that's Enricher's job). It only resolves identity, shape, and precedence.

### Future-Ready Architecture
While currently processing in-memory, the architecture supports:
- **Streaming/Sharding**: NDJSON processing with LRU cache or SQLite
- **Incremental Updates**: Process only changed symbols
- **Parallel Processing**: Thread-safe design for concurrent normalization

## Testing Strategy

### Current Test Coverage
- ✅ **21 tests passing** covering all major functionality
- ✅ **Deterministic output** verified through shuffle tests
- ✅ **Deduplication** correctly merging duplicates
- ✅ **Precedence system** properly resolving conflicts
- ✅ **Validation** catching and reporting errors

### Test Types
1. **Golden-file tests**: Raw → normalized fixtures
2. **Fuzz reopenings**: Same class across N files
3. **Conflict matrices**: Types/docs/visibility precedence
4. **Determinism tests**: Shuffle input → identical output
5. **Edge cases**: Empty data, malformed input, circular references

## What Breaks Without It

- ❌ Duplicate/contradictory methods after reopenings
- ❌ Inconsistent fqnames/paths (Rails roots, engines)
- ❌ Unstable JSON order → noisy diffs, churn in indices/embeddings
- ❌ Emitters each re-implementing reconciliation logic (bugs multiplied)
- ❌ Harder CI policies ("public API changed") because identity is fuzzy

## Future Enhancements

### Near-term (v1.1)
- [ ] Streaming/sharding for large codebases
- [ ] Redaction rules for secrets in comments/initializers
- [ ] Path normalization for Rails engines
- [ ] Incremental normalization for changed files only

### Long-term (v2.0)
- [ ] Multi-threaded processing with work stealing
- [ ] SQLite-backed symbol cache for persistence
- [ ] Custom precedence rules per project
- [ ] Integration with LSP for real-time updates

## API Usage

```ruby
# Basic usage
normalizer = Rubymap::Normalizer.new
result = normalizer.normalize(raw_data)

# Access normalized data
result.classes.each do |klass|
  puts "#{klass.symbol_id}: #{klass.fqname}"
  puts "  Confidence: #{klass.provenance.confidence}"
  puts "  Sources: #{klass.provenance.sources.join(', ')}"
end

# Check for errors
if result.errors.any?
  result.errors.each do |error|
    puts "#{error.type}: #{error.message}"
  end
end

# Verify determinism
result1 = normalizer.normalize(data)
result2 = normalizer.normalize(data.shuffle)
result1 == result2 # => true
```

## Summary

The Normalizer is your **contract enforcer**. It centralizes identity, precedence, and cleanliness so everything downstream is simpler, faster, and stable. With deterministic symbol IDs, provenance tracking, and intelligent conflict resolution, it transforms the chaos of multi-source Ruby analysis into a reliable, queryable knowledge graph.