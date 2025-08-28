# Emitter: The Packager & Translator

The Emitter takes the canonical, enriched model and renders it into the right shapes for different consumers: humans (documentation), tools (CI, IDEs), and AI (RAG chunks). It doesn't create facts; it formats, slices, and distributes them with strong guarantees around determinism, versioning, and quality.

## Why an Emitter?

### 1. Different audiences, different shapes
LLMs want small, templated chunks with context. Humans want browsable documentation with navigation. CI tools want machine-readable diffs. Graph visualizers want DOT format. One source of truth, many presentations.

### 2. Stable outputs
Deterministic formatting ensures clean PR diffs, reliable cache hits, and reproducible builds. No more spurious changes from random ordering or formatting variations.

### 3. Separation of concerns
Keep rendering and templating logic out of the data pipeline (Extractor, Normalizer, Enricher, Indexer). Let each component focus on its core responsibility.

### 4. Quality control
Final checkpoint for redaction, truncation, and formatting rules. Ensure outputs meet size constraints, security requirements, and style guidelines.

### 5. Distribution readiness
Package outputs with manifests, checksums, and metadata. Support incremental updates and versioned releases. Ready for static hosting, CI integration, or API serving.

## Current Implementation

### Core Features

#### 1. LLM-Friendly Chunks
- **Deterministic Chunking**: 2-4KB blocks per symbol with consistent boundaries
- **Contextual Headers**: Symbol type, ownership, relationships included
- **Smart Truncation**: Preserve semantic completeness with ellipsis indicators
- **Embedding Support**: Optional vector generation and manifest

```ruby
chunk = LLMChunk.new(
  chunk_id: "chunk_c4f3d2e1",
  symbol_id: "User#save",
  text: "## Method: User#save\n\nSaves the user to the database...",
  tokens: 487,
  metadata: {type: "method", complexity: "moderate"}
)
```

#### 2. Human Documentation
- **Markdown Generation**: Clean, navigable documentation sites
- **Cross-Linking**: Symbol references become hyperlinks
- **Navigation Trees**: Namespace hierarchies, method lists, inheritance chains
- **Rich Formatting**: Tables for parameters, metrics dashboards, diagrams

```markdown
# Class: User

**Inherits from:** ApplicationRecord  
**Defined in:** app/models/user.rb:12  
**Complexity:** Moderate (score: 6.5)

## Methods

### Instance Methods
- [#authenticate](user-authenticate.md) - Authenticates user credentials
- [#save](user-save.md) - Persists user to database
```

#### 3. Graph Visualizations
- **DOT Format**: Graphviz-compatible for inheritance, dependencies, calls
- **JSON Graphs**: Adjacency lists for custom viewers
- **Bounded Graphs**: Configurable depth limits to prevent overwhelming output
- **Multiple Views**: Class hierarchy, module dependencies, call graphs

```dot
digraph Dependencies {
  "User" -> "ApplicationRecord" [label="inherits"];
  "User" -> "Authenticatable" [label="includes"];
  "User" -> "EmailValidator" [label="uses"];
}
```

#### 4. Machine-Readable Artifacts
- **API Reports**: JSON/YAML exports of public interfaces
- **Delta Reports**: Breaking changes between versions
- **SARIF Output**: Code scanning annotations for GitHub
- **Routes Export**: Rails routes in structured format

```json
{
  "api_version": "1.2.0",
  "public_methods": [
    {
      "fqname": "User#authenticate",
      "signature": "authenticate(password: String) -> Boolean",
      "visibility": "public",
      "deprecated": false
    }
  ],
  "breaking_changes": []
}
```

#### 5. Packaging & Distribution
- **Manifest Generation**: Version info, checksums, file inventory
- **Zip Archives**: Bundled outputs with structure preservation
- **Static Sites**: Ready-to-host documentation websites
- **Incremental Packages**: Delta-only updates for efficiency

## Architecture

```
Emitter
├── Format Engines          # Output generators
│   ├── ChunkEmitter       # LLM-optimized text blocks
│   ├── MarkdownEmitter    # Human documentation
│   ├── GraphEmitter       # Visual representations
│   ├── JSONEmitter        # Machine-readable data
│   └── SARIFEmitter       # Code scanning format
├── Templates              # Format-specific templates
│   ├── chunk/             # LLM chunk templates
│   ├── markdown/          # Documentation templates
│   ├── graph/             # Graph layout templates
│   └── reports/           # Report templates
├── Processors             # Content processing
│   ├── CrossLinker        # Reference resolution
│   ├── Truncator          # Size management
│   ├── Redactor           # Security filtering
│   └── Formatter          # Style normalization
├── Filters                # Content selection
│   ├── VisibilityFilter   # Public/private filtering
│   ├── NamespaceFilter    # Path-based selection
│   ├── ChangeFilter       # Delta detection
│   └── SizeFilter        # Output limiting
└── Packager               # Distribution preparation
    ├── ManifestBuilder    # Metadata generation
    ├── Archiver           # Compression/bundling
    └── Validator          # Output verification
```

### Data Flow

```
Enriched Data ──► EMITTER ──► Formatted Outputs
                  │            ├── chunks/       # LLM-ready
                  │            ├── docs/         # Human-readable
                  │            ├── graphs/       # Visualizations
                  │            ├── reports/      # Machine data
                  │            └── manifest.json # Package metadata
                  └──► Filters & Templates
```

## Output Specifications

### LLM Chunks

```ruby
ChunkSpec
├── chunk_id: String           # "chunk_a1b2c3d4"
├── symbol_ids: [String]       # Symbols in chunk
├── text: String              # Formatted content
├── token_count: Integer       # For context windows
├── metadata: Hash            # Type, complexity, etc.
└── embedding: Vector         # Optional, if configured

# Example chunk content
---
symbol: User#save
type: instance_method
complexity: moderate
dependencies: ["ApplicationRecord", "EmailValidator"]
---

The `save` method persists a User instance to the database.
It validates email uniqueness and triggers callbacks.

Returns: Boolean (true on success, false on validation failure)
Raises: ActiveRecord::RecordInvalid if save! variant used
```

### Documentation Structure

```
docs/
├── index.md                  # Main navigation
├── classes/                  # Class documentation
│   ├── user.md
│   └── order.md
├── modules/                  # Module documentation
├── guides/                   # Overview documentation
│   ├── architecture.md
│   └── hotspots.md
├── api/                      # API reference
│   └── public-methods.md
└── assets/                   # Graphs, diagrams
    └── dependency-graph.svg
```

### Machine Artifacts

```ruby
# API Report Structure
{
  schema_version: 1,
  snapshot_id: "abc123",
  generated_at: "2024-01-15T10:30:00Z",
  statistics: {
    public_classes: 45,
    public_methods: 234,
    deprecated: 3
  },
  public_api: [...],
  deprecated_api: [...],
  breaking_changes: [...]
}

# SARIF Output
{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {"driver": {"name": "rubymap"}},
    "results": [
      {
        "ruleId": "api.breaking-change",
        "message": {"text": "Method signature changed"},
        "locations": [...]
      }
    ]
  }]
}
```

## Design Principles

### Deterministic & Idempotent
Same inputs always produce byte-identical outputs. Stable ordering, consistent formatting, reproducible builds.

### Template-Driven
Slim/ERB/Liquid templates with helper libraries. Separation of logic and presentation. Easy to customize without changing code.

### Incremental & Sharded
Emit only changed content based on symbol IDs. Process namespaces in parallel. Support partial regeneration.

### Format Agnostic
Clean abstraction between data model and output formats. Easy to add new formats without touching existing code.

### Security Conscious
Final redaction pass for secrets. Configurable deny lists. Audit trail for filtered content.

## Testing Strategy

### Current Test Coverage
- ✅ **Format correctness** for all output types
- ✅ **Determinism tests** ensuring identical outputs
- ✅ **Size constraints** verified for chunks
- ✅ **Cross-linking** validation in documentation
- ✅ **Schema compliance** for machine formats

### Test Types
1. **Golden file tests**: Expected outputs for fixtures
2. **Determinism tests**: Shuffle input → identical output
3. **Format validators**: JSON schema, SARIF compliance
4. **Link checking**: All references resolve correctly
5. **Size guards**: Chunks within token limits

## Performance & Scalability

### Current Performance
- **Throughput**: ~1000 symbols/second for markdown
- **Memory**: Streaming architecture, constant memory
- **Parallelism**: Format-level parallelization
- **Incremental**: Only regenerate changed symbols

### Optimization Strategies
- Template compilation and caching
- Parallel emission by output type
- Streaming writes for large outputs
- Lazy loading of enriched data

## What Breaks Without It

- ❌ Each consumer builds custom formatting
- ❌ Inconsistent documentation across tools
- ❌ No standard chunk format for LLMs
- ❌ Manual API documentation maintenance
- ❌ No automated breaking change detection
- ❌ Difficult distribution and versioning

## Future Enhancements

### Near-term (v1.1)
- [ ] Interactive documentation with search
- [ ] OpenAPI specification generation
- [ ] Mermaid diagram support
- [ ] Custom template marketplace

### Long-term (v2.0)
- [ ] Real-time documentation updates
- [ ] Multi-language output support
- [ ] AI-assisted documentation writing
- [ ] Integrated API playground

## API Usage

```ruby
# Initialize emitter
emitter = Rubymap::Emitter.new(
  formats: [:chunks, :markdown, :json],
  output_dir: "build/",
  config: {
    chunk_size: 2048,
    include_private: false,
    redact_patterns: [/SECRET/, /PASSWORD/]
  }
)

# Emit all formats
result = emitter.emit(enriched_data, 
  snapshot_id: "v1.0.0",
  base_url: "https://github.com/user/repo"
)

# Generate specific format
emitter.emit_markdown(enriched_data,
  output_dir: "docs/",
  theme: "minimal",
  include_graphs: true
)

# Create LLM chunks
chunks = emitter.emit_chunks(enriched_data,
  max_tokens: 2000,
  include_context: true,
  generate_embeddings: true
)

# Generate delta report
delta = emitter.emit_delta(
  from: enriched_v1,
  to: enriched_v2,
  format: :json
)

# Package for distribution
package = emitter.package(
  formats: [:markdown, :json],
  compress: true,
  sign: true
)

puts "Generated #{package.files.count} files"
puts "Package size: #{package.size_mb}MB"
puts "Manifest: #{package.manifest_path}"
```

## Manifest Example

```json
{
  "schema_version": 1,
  "generator": {
    "name": "rubymap",
    "version": "1.0.0",
    "emitter_version": "1.0.0"
  },
  "snapshot": {
    "id": "abc123def456",
    "created_at": "2024-01-15T10:30:00Z",
    "source_commit": "main@a1b2c3d4"
  },
  "outputs": {
    "chunks": {
      "count": 1234,
      "format": "markdown",
      "total_size": 4567890,
      "checksum": "sha256:abcd..."
    },
    "documentation": {
      "pages": 234,
      "format": "markdown",
      "theme": "minimal"
    },
    "graphs": {
      "count": 12,
      "format": "dot"
    }
  },
  "filters": {
    "visibility": "public",
    "namespaces": ["app/models", "app/services"]
  },
  "statistics": {
    "symbols_processed": 2345,
    "files_generated": 456,
    "total_size_bytes": 12345678,
    "generation_time_ms": 4567
  },
  "checksums": {
    "docs/index.md": "sha256:1234...",
    "chunks/chunk_001.md": "sha256:5678..."
  }
}
```

## Summary

The Emitter is your **presentation layer**. It transforms the enriched knowledge graph into consumable artifacts for every audience—developers browsing documentation, LLMs processing chunks, CI tools checking changes, and visualization tools rendering graphs. With deterministic output, flexible templating, and comprehensive packaging, it ensures that the intelligence gathered by the pipeline reaches its consumers in the most effective format.

The combination of human-readable documentation, machine-processable data, and AI-optimized chunks creates a complete distribution system. Whether generating static documentation sites, feeding RAG systems, or powering IDE integrations, the Emitter guarantees that outputs are consistent, versioned, and ready for consumption. It's the final mile that makes your code intelligence accessible and actionable.