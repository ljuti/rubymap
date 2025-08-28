# rubymap

## Overview

Rubymap is a comprehensive Ruby codebase mapping tool that extracts, indexes, and visualizes the structure of Ruby applications. It creates a searchable, LLM-friendly knowledge graph of your code including classes, modules, methods, relationships, and metadata. With special Rails awareness, it can map ActiveRecord models, routes, jobs, and more through both static analysis and optional runtime introspection.

### Why rubymap?

- **Dual-pass mapping**: Combines fast static parsing with optional runtime introspection for complete coverage
- **Rails-aware**: Deep understanding of Rails conventions, ActiveRecord models, routes, and background jobs
- **LLM-optimized output**: Generates chunked, retrieval-friendly documentation perfect for AI assistants
- **Metaprogramming handling**: Captures dynamically defined methods and runtime-generated code
- **Performance focused**: Sub-second mapping for thousands of files with incremental updates
- **Security-first**: Sandboxed runtime mapping with configurable safety controls

## Installation & Usage

### Installation

```bash
gem install rubymap
```

Or add to your Gemfile:

```ruby
gem 'rubymap', group: :development
```

### Quick Start

```bash
# Map current directory (static pass only)
rubymap

# Include runtime mapping (Rails apps)
rubymap --runtime

# Output to specific directory
rubymap --output ./docs/map

# Map specific paths
rubymap app/models lib/

# Generate LLM-friendly code map
rubymap --format llm
```

### CLI Commands & Options

```
rubymap [OPTIONS] [PATHS...]        # Create code map (default command)
rubymap update [OPTIONS]             # Update existing map incrementally
rubymap view SYMBOL                  # View information about a symbol
rubymap serve [--port PORT]          # Start web UI server (future)
rubymap clean                        # Remove cache and output files

Options:
  --runtime          Enable runtime introspection pass
  --output PATH      Output directory (default: .rubymap)
  --format FORMAT    Output format: json, yaml, llm, graphviz (default: json)
  --config FILE      Configuration file path
  --verbose          Enable verbose logging
  --no-cache         Disable caching
  --skip-initializer Skip specific initializer during runtime
```

## Configuration

Create a `.rubymap.yml` file in your project root:

```yaml
# Static mapping settings
static:
  paths:
    - app/
    - lib/
  exclude:
    - vendor/
    - node_modules/
  follow_requires: true
  parse_yard: true
  parse_rbs: true

# Runtime mapping settings  
runtime:
  enabled: false
  environment: development
  safe_mode: true
  timeout: 30
  disable_initializers:
    - sidekiq
    - delayed_job
  env_vars:
    DISABLE_SIDE_EFFECTS: "1"
    RAILS_ENV: "map"

# Output settings
output:
  format: json
  directory: ./rubymap_output
  chunk_size: 4096
  include_private: false
  include_source: false
  
# Performance settings
performance:
  max_file_size: 1048576  # 1MB
  max_files: 10000
  parallel_workers: 4
  cache_enabled: true
  cache_directory: .rubymap_cache
```

## Architecture

### Two-pass mapping (fast & safe):

1. **Static mapping** (no code execution)
   - Parse with Prism (Ruby's new parser) for speed & fidelity
   - Collect classes/modules/methods, comments, mixins, constants, requires
   - Read YARD & RBS/Sorbet artifacts if present
   - Zero runtime risk, works on any codebase

2. **Runtime mapping** (optional, sandboxed)
   Boot the app in a controlled environment to extract runtime-only information:
   - ActiveRecord models (attributes via columns_hash, associations via reflect_on_all_associations)
   - Routes via Rails.application.routes
   - Dynamically defined methods via ObjectSpace and Module introspection
   - TracePoint monitoring for method definitions during boot

### Processing Pipeline

```
┌─────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│Extractor├──▶│ Normalizer ├──▶│ Enricher ├──▶│ Indexer ├──▶│ Emitters │
└─────────┘   └────────────┘   └──────────┘   └─────────┘   └──────────┘
     │              │                │              │             │
  Parse AST    Standardize      Add metrics    Build graph   Generate
  Find files    Clean data      Add types      Create index   Output
```

- **Extractor**: Parses Ruby files, finds dependencies
- **Normalizer**: Standardizes data format, resolves references
- **Enricher**: Adds metrics, documentation, type information
- **Indexer**: Builds relationship graphs, creates searchable index
- **Emitters**: Generates output in various formats

## Key Dependencies

- **Prism** (core): Fast parsing with stable AST
- **YARD** (optional): Docstring and tag extraction
- **RBS/Steep/Sorbet** (optional): Type information from .rbs/.rbi files
- **Zeitwerk** (Rails): Reliable constant-to-file mapping
- **Rugged/Git** (optional): Churn metrics and history
- **Graphviz** (optional): Dependency diagram rendering
- **SQLite** (optional): Local index for fast queries

## Core Entities

### Namespaces
- Module, Class definitions
- Ownership hierarchy (parent/child relationships)
- File location and line numbers
- Visibility and access levels

### Inheritance & Mixins
- Superclass chains
- Include/extend/prepend tracking
- Refinements usage
- Module composition analysis

### Methods
- Name, owner, visibility (public/private/protected)
- Receiver type (instance/class/singleton)
- Parameters with types (positional, keyword, splat, block)
- Arity and default values (when statically determinable)
- Abstract methods (from RBI/RBS/Sorbet signatures)
- Deprecation markers and warnings

### Types (when available)
- From RBS/Sorbet type signatures
- Inferred types from usage patterns
- Return type annotations
- Generic type parameters

### Constants
- Name and fully qualified path
- Value type (scalar/structural/class/module)
- References and usage locations
- Autoloaded status (Rails)

### Documentation
- YARD docstrings (sanitized and parsed)
- @param/@return/@raise/@example tags
- Method signatures from documentation
- README and guide references

### File Assets
- Absolute and relative paths
- Require/load dependency graph
- Autoload paths (Zeitwerk/Rails)
- File modification times and checksums

### Rails-Specific Entities

#### ActiveRecord Models
- Table name and database connection
- Attributes with types, nullability, defaults
- Validations with options
- Callbacks (before/after/around)
- Database indexes
- Associations (has_many, belongs_to, has_one, HABTM)
- Scopes and class methods
- STI hierarchies

#### Routes
- HTTP verb and path pattern
- Controller#action mapping
- Constraints and conditions
- Named route helpers
- Mount points for engines

#### Background Jobs
- Job class and queue name
- Retry configuration
- Argument schemas
- Performance settings
- Scheduled vs immediate

#### Controllers & Actions
- Action methods
- Before/after/around filters
- Rescue handlers
- Permitted parameters

## Relationships & Metrics

### Relationship Types
- `inherits`: Class/module inheritance
- `includes/extends/prepends`: Mixin relationships
- `defines`: Method/constant definitions
- `calls`: Method invocations (best-effort static analysis)
- `references`: Constant references
- `routes_to`: HTTP routing connections
- `depends_on`: File-level dependencies

### Code Metrics
- **Fan-in/Fan-out**: Number of dependencies and dependents
- **Dependency depth**: Distance from root namespaces
- **Cyclomatic complexity**: Method complexity scores
- **Churn**: Git commit frequency per file/method
- **Coverage**: Test coverage if available

### Heuristic Scores
- **Public API Surface**: Exposed methods in public namespaces
- **Hotspot Score**: churn × coupling (frequently changed, highly connected code)
- **Stability Score**: age × test coverage × documentation presence
- **Complexity Score**: cyclomatic complexity × method length

## Data Model & Output Formats

### Directory Structure
```
.rubymap/
├── map.json                 # Global metadata and manifest
├── symbols/                 # Sharded symbol definitions
│   ├── classes/
│   ├── modules/
│   └── methods/
├── graphs/                  # Relationship graphs
│   ├── inheritance.json
│   ├── dependencies.json
│   └── calls.json
├── rails/                   # Rails-specific data
│   ├── models/
│   ├── routes.json
│   └── schema.json
└── indexes/                 # Search indexes
    └── symbols.sqlite
```

### JSON Schema Examples

#### Class Entry
```json
{
  "kind": "class",
  "fqname": "User",
  "superclass": "ApplicationRecord",
  "mixins": [
    {"type": "include", "module": "Devise::Models::Authenticatable"},
    {"type": "include", "module": "Searchable"}
  ],
  "defined_in": {"path": "app/models/user.rb", "line": 1},
  "methods": {
    "instance": ["full_name", "active?", "send_welcome_email"],
    "class": ["find_by_email", "recent", "admin"]
  },
  "constants": ["ROLES", "MAX_LOGIN_ATTEMPTS"],
  "doc": "Represents a user account in the system",
  "metrics": {
    "churn": {"commits": 142, "last_touched": "2025-08-28"},
    "complexity": 24,
    "dependencies": 8
  }
}
```

#### Method Entry
```json
{
  "kind": "method",
  "fqname": "User#full_name",
  "owner": "User",
  "visibility": "public",
  "receiver": "instance",
  "params": [
    {"name": "style", "kind": "keyreq", "type": "Symbol", "default": ":formal"}
  ],
  "returns": {"type": "String", "source": "yard"},
  "defined_in": {"path": "app/models/user.rb", "line": 42},
  "doc": "Returns the user's full name in the specified style",
  "calls": ["String#strip", "I18n.t"],
  "called_by": ["UserSerializer#as_json", "WelcomeMailer#welcome"],
  "source": "static",
  "since": "2024-11-03",
  "churn": {"commits": 7, "last_touched": "2025-08-01"}
}
```

#### Rails Model Entry
```json
{
  "kind": "model",
  "class": "User",
  "table": "users",
  "attributes": [
    {"name": "id", "type": "integer", "null": false, "primary": true},
    {"name": "email", "type": "string", "null": false, "index": true},
    {"name": "name", "type": "string", "null": true},
    {"name": "created_at", "type": "datetime", "null": false}
  ],
  "associations": [
    {"type": "has_many", "name": "posts", "class": "Post", "foreign_key": "user_id"},
    {"type": "belongs_to", "name": "organization", "class": "Organization", "optional": true}
  ],
  "validations": [
    {"type": "presence", "attributes": ["email", "name"]},
    {"type": "uniqueness", "attributes": ["email"], "options": {"case_sensitive": false}}
  ],
  "callbacks": [
    {"type": "before_save", "method": "normalize_email"},
    {"type": "after_create", "method": "send_welcome_email"}
  ],
  "indexes": [
    {"columns": ["email"], "unique": true},
    {"columns": ["organization_id", "created_at"]}
  ]
}
```

## Handling Ruby Metaprogramming

### Static Analysis Strategies
- Record `define_method`, `class_eval`, `module_eval` calls
- Track `delegate`, `forwardable` usage
- Mark dynamic methods with `"dynamic": true` flag
- Map `method_missing` and `respond_to_missing?` patterns
- Parse DSLs when patterns are recognizable

### Runtime Reflection (Safe Mode)
```ruby
# Boot with safety controls
ENV['RAILS_ENV'] = 'map'
ENV['DISABLE_SIDE_EFFECTS'] = '1'

# After Rails.application.eager_load!
ActiveRecord::Base.descendants.each do |model|
  # Extract columns, associations, validations
end

Module.constants.each do |const|
  # Inventory all loaded constants
end

ObjectSpace.each_object(Class) do |klass|
  # Find all methods including dynamic ones
end
```

### Confidence Scoring
Every extracted element includes source attribution:
- `"source": "static"` - Found via AST parsing
- `"source": "runtime"` - Discovered during runtime pass
- `"source": "yard"` - Extracted from documentation
- `"source": "inferred"` - Deduced from usage patterns

## LLM-Friendly Output

### Chunking Strategy
- One chunk per symbol (class/module/method)
- 2-4KB optimal chunk size
- Stable, deterministic output ordering
- Include both forward and backward references

### Chunk Format
```markdown
## Class: User < ApplicationRecord
Location: app/models/user.rb:1
Dependencies: [ApplicationRecord, Devise, Searchable]
Used by: [UsersController, UserSerializer, UserMailer]

### Purpose
Represents a user account with authentication and profile information.

### Key Methods
- `#full_name(style: :formal)` - Returns formatted name
- `#active?` - Checks if account is active
- `.find_by_email(email)` - Finds user by email

### Relationships
- Has many: posts, comments, notifications
- Belongs to: organization (optional)

### Metadata
- Table: users
- Attributes: 15 (id, email, name, ...)
- Test coverage: 94%
- Last modified: 2025-08-28
```

## Security & Safety

### Runtime Sandboxing
```yaml
# Safety configuration
runtime:
  safe_mode: true
  disable_initializers:
    - sidekiq
    - action_cable
    - websocket
  block_methods:
    - system
    - exec
    - eval
  timeout: 30
  memory_limit: 512MB
```

### Secret Redaction
- Automatic detection of API keys, tokens, passwords
- Configurable redaction patterns
- Skip sensitive files (credentials, secrets)
- Sanitize environment variables in output

### Monkeypatching for Safety
```ruby
# In map mode, prevent dangerous operations
module Kernel
  def system(*args)
    warn "[RUBYMAP] Blocked system call: #{args.inspect}"
    false
  end
end
```

## Integration Examples

### CI/CD Pipeline
```yaml
# .github/workflows/rubymap.yml
name: Update Code Map
on:
  push:
    branches: [main]
jobs:
  map:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
      - run: gem install rubymap
      - run: rubymap update --output docs/map
      - uses: actions/upload-artifact@v2
        with:
          name: code-map
          path: docs/map
```

### Programmatic Usage
```ruby
require 'rubymap'

# Configure mapper
mapper = Rubymap::Mapper.new(
  paths: ['app/', 'lib/'],
  runtime: true,
  format: :json
)

# Create map
map = mapper.run

# Query the map
user_class = map.find_class('User')
user_methods = user_class.instance_methods
dependencies = map.dependencies_of('User')

# Export for LLM
map.export_llm_chunks('docs/ai-map/')
```

### IDE Integration
```ruby
# VSCode extension endpoint
class RubymapServer
  def initialize(map_path)
    @map = Rubymap::Map.load(map_path)
  end
  
  def find_definition(symbol)
    @map.locate(symbol)
  end
  
  def find_references(symbol)
    @map.references_to(symbol)
  end
  
  def get_documentation(symbol)
    @map.documentation_for(symbol)
  end
end
```

## Testing Strategy

### Test Coverage
- Unit tests for each pipeline component
- Integration tests with fixture repositories
- Performance benchmarks
- Golden file comparisons

### Fixture Repositories
```
spec/fixtures/
├── minimal_gem/        # Basic Ruby gem
├── rails_app/         # Full Rails application
├── metaprogramming/   # Dynamic Ruby patterns
└── large_codebase/    # Performance testing
```

### Performance Targets
- Static mapping: <1s per 1000 files
- Runtime mapping: <30s for typical Rails app
- Incremental updates: <100ms per changed file
- Memory usage: <500MB for 10k files

## Troubleshooting

### Common Issues

#### Runtime pass fails
```bash
# Check for interfering initializers
RUBYMAP_DEBUG=1 rubymap --runtime

# Skip problematic initializers
rubymap --runtime --skip-initializer config/initializers/problematic.rb
```

#### Memory issues with large codebases
```bash
# Increase memory limit
rubymap --memory-limit 2GB

# Use sharding for very large projects
rubymap --shard-size 1000
```

#### Missing dependencies
```bash
# Install runtime dependencies
bundle install --with development test

# Or skip runtime pass
rubymap --no-runtime
```

## Comparison with Similar Tools

| Feature | Rubymap | YARD | Solargraph | RDoc |
|---------|---------|------|------------|------|
| Static mapping | ✅ | ✅ | ✅ | ✅ |
| Runtime mapping | ✅ | ❌ | ❌ | ❌ |
| Rails aware | ✅ | Partial | Partial | ❌ |
| Type inference | ✅ | ❌ | ✅ | ❌ |
| LLM optimized | ✅ | ❌ | ❌ | ❌ |
| Metaprogramming | ✅ | Limited | Limited | ❌ |
| Incremental | ✅ | ❌ | ✅ | ❌ |
| Dependency graph | ✅ | ❌ | Partial | ❌ |

## Roadmap & Future Features

- [ ] Real-time file watching and incremental updates
- [ ] Web UI for exploring code maps
- [ ] GitHub integration for PR analysis
- [ ] Support for other Ruby frameworks (Sinatra, Hanami)
- [ ] Machine learning for better type inference
- [ ] Cross-language support (JavaScript in Rails apps)
- [ ] Cloud-hosted analysis service
- [ ] Custom rule engine for code quality checks

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - See [LICENSE.txt](../LICENSE.txt) for details.