# Rubymap

[![Gem Version](https://badge.fury.io/rb/rubymap.svg)](https://badge.fury.io/rb/rubymap)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-red.svg)](https://www.ruby-lang.org)

> 🗺️ A comprehensive Ruby codebase analysis tool that maps your code's structure, relationships, and architecture

Rubymap creates a searchable, LLM-friendly knowledge graph of your Ruby application. It uses fast static analysis to capture your code's structure - from class hierarchies to method definitions, preparing for future runtime introspection capabilities.

## ✨ Key Features

### Currently Implemented
- **🚀 Static analysis** - Lightning-fast parsing using Prism with comprehensive symbol extraction
- **🤖 LLM-optimized** - Generates perfectly chunked documentation for AI assistants with template system
- **📝 Template system** - Customizable ERB templates with user overrides and format-specific options
- **⚡ Performance focused** - Sub-second analysis for thousands of files with parallel processing
- **📊 Code structure mapping** - Classes, modules, methods, constants, attributes, and their relationships
- **🔧 Modular pipeline** - Extractor → Normalizer → Enricher → Indexer → Emitter
- **🎯 Smart deduplication** - Intelligent merging of duplicate symbols with priority-based resolution
- **🔍 Pattern detection** - Identifies design patterns, Rails conventions, Ruby idioms, and metaprogramming
- **📈 Code metrics** - Complexity, cohesion, coupling, hotspot analysis, and quality metrics
- **🏗️ Clean architecture** - SOLID principles with dependency injection, strategy patterns, and 100% mutation test coverage
- **📁 Multiple output formats** - JSON, YAML, LLM-optimized markdown, and GraphViz DOT formats
- **🔄 Enrichment pipeline** - Configurable processors, analyzers, and converters for metadata enhancement
- **📍 Advanced indexing** - Multiple graph types with O(1) lookup and circular dependency detection

### Coming Soon
- **🛤️ Rails-aware** - Deep understanding of ActiveRecord associations, routes, and jobs (partial support)
- **🔮 Runtime introspection** - Capture dynamically defined methods and runtime code (configuration exists)
- **🔒 Security controls** - Sandboxed runtime analysis with configurable safety
- **🌐 Web UI** - Interactive exploration of code maps
- **👀 File watching** - Real-time updates as code changes

## 🚀 Quick Start

```bash
# Install the gem
gem install rubymap

# Map your Ruby project
rubymap

# Generate LLM-friendly code map (default format)
rubymap --output docs/ai-map

# Specify different output formats
rubymap --format json
rubymap --format yaml
rubymap --format graphviz
```

### Quick Example

Map a Ruby application:

```bash
cd my_ruby_app
rubymap

# View the generated map
ls -la .rubymap/
# ├── index.md          # Navigation index
# ├── overview.md       # Project overview
# ├── chunks/           # LLM-optimized documentation chunks
# ├── relationships/    # Relationship graphs
# └── manifest.json     # Metadata and chunk index
```

## 📦 Installation

Add to your Gemfile:

```ruby
# Gemfile
group :development do
  gem 'rubymap'
end
```

Then install:

```bash
bundle install
```

Or install globally:

```bash
gem install rubymap
```

## 🎯 Usage

### Basic Commands

```bash
# Map current directory
rubymap

# Map specific paths
rubymap app/models lib/services

# Custom output directory
rubymap --output ./documentation/map

# Specify output format (default: llm)
rubymap --format json      # Structured JSON
rubymap --format yaml      # YAML format
rubymap --format graphviz  # Dependency diagrams
rubymap --format llm       # LLM-optimized markdown
```

### Rails-Specific Mapping (Coming Soon)

```bash
# These features are in development:
# Full Rails mapping (models, routes, jobs)
# rubymap --runtime

# Map specific Rails components with runtime
# rubymap app/models --runtime
# rubymap app/controllers app/jobs

# Currently, Rails apps can be mapped with static analysis:
rubymap app/
```

### Configuration

Create `.rubymap.yml` in your project root:

```yaml
# Basic configuration
paths: [app/, lib/]
exclude: [vendor/, node_modules/, spec/, test/]

output:
  format: llm  # Options: llm, json, yaml, graphviz
  directory: .rubymap
  include_source: false
  redact_sensitive: true

# Template customization (new!)
templates:
  directory: ./my_templates  # Custom template directory
  format_options:
    llm:
      chunk_size: 2000
      include_metrics: true

# Runtime configuration (experimental)
runtime:
  enabled: false  # Not yet fully implemented
  safe_mode: true
  timeout: 30
  environment: development
```

See [full configuration documentation](docs/rubymap.md#configuration) for all options.

## 🏗️ How It Works

Rubymap uses a modular pipeline approach to build a complete picture of your codebase:

```
┌──────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│ Extract  ├──▶│ Normalize  ├──▶│ Enrich   ├──▶│ Index   ├──▶│ Emit     │
│ (Prism)  │   │ & Dedupe   │   │ Metadata │   │ Symbols │   │ (LLM)    │
└──────────┘   └────────────┘   └──────────┘   └─────────┘   └──────────┘
```

### Current Pipeline Components

**Extractor** - Fast static parsing using Prism
- Extracts classes, modules, methods, constants, attributes, mixins, and class variables
- Tracks inheritance chains, dependencies, method calls, and require statements
- Captures documentation comments, YARD tags, and @rubymap annotations
- Detects metaprogramming patterns (define_method, attr_accessor, delegate, etc.)
- Parallel file processing with configurable thread pools

**Normalizer** - Data standardization with advanced processing
- Configurable processing pipeline with pluggable steps
- Smart deduplication using priority-based symbol merging
- Full namespace resolution and cross-reference validation
- Mixin method resolution with proper inheritance chain building
- Confidence scoring for symbol reliability
- 100% mutation test coverage ensuring reliability

**Enricher** - Comprehensive metadata enhancement  
- Rails pattern detection (models, controllers, concerns, jobs, mailers)
- Design pattern identification (singleton, factory, observer, strategy, decorator)
- Code metrics calculation (cyclomatic complexity, ABC metrics, cohesion, coupling)
- Ruby idiom detection (memoization, delegation, DSLs, metaprogramming)
- Hotspot analysis for frequently modified code
- Configurable analyzer and converter pipeline
- Type inference and coercion support

**Indexer** - Advanced symbol graph creation
- Multiple specialized graphs (inheritance, dependencies, method calls, mixins, constants)
- O(1) symbol lookup with multi-level caching
- Circular dependency detection with cycle reporting
- Missing reference identification and validation
- Query interface with fuzzy search and filtering
- Relationship tracking with bidirectional references
- Graph traversal utilities for analysis

**Emitter** - Flexible output generation with templates
- ERB-based template system with format-specific templates
- User template overrides via configuration or custom directories
- LLM-optimized chunking with context-aware content splitting
- Multiple output formats: JSON, YAML, LLM markdown, GraphViz DOT
- Progress reporting with TTY components
- Security redaction for sensitive data
- Deterministic output for clean version control diffs
- Template presenters for clean separation of concerns

## 📊 Output Examples

### Class Information
```json
{
  "name": "User",
  "type": "class",
  "superclass": "ApplicationRecord",
  "methods": ["full_name", "active?", "send_welcome_email"],
  "associations": ["posts", "comments", "organization"],
  "location": "app/models/user.rb:1"
}
```

### LLM-Friendly Output
```markdown
## Class: User < ApplicationRecord
Location: app/models/user.rb
Used by: UsersController, UserSerializer

### Purpose
User account with authentication and profile.

### Key Methods
- #full_name - Returns formatted name
- #active? - Checks if account is active
```

## 🆚 Why Rubymap?

| Feature | Rubymap | YARD | Solargraph | RDoc |
|---------|---------|------|------------|------|
| Static mapping | ✅ | ✅ | ✅ | ✅ |
| LLM optimized | ✅ | ❌ | ❌ | ❌ |
| Modular pipeline | ✅ | ❌ | ❌ | ❌ |
| Deduplication | ✅ | ❌ | ❌ | ❌ |
| Runtime mapping | 🚧 | ❌ | ❌ | ❌ |
| Rails aware | 🚧 | Partial | Partial | ❌ |
| Metaprogramming | 🚧 | Limited | Limited | ❌ |

✅ = Implemented, 🚧 = In Development

## 📚 Documentation

- [**Complete Documentation**](docs/rubymap.md) - Comprehensive guide with all features
- [**Configuration Reference**](docs/rubymap.md#configuration) - All configuration options
- [**Integration Examples**](docs/rubymap.md#integration-examples) - CI/CD, IDE, and API usage
- [**Architecture Details**](docs/rubymap.md#architecture) - How Rubymap works internally

## 🛠️ Development

After checking out the repo:

```bash
# Install dependencies
bin/setup

# Run tests
rake spec

# Run linter
rake standard

# Install gem locally
bundle exec rake install

# Run console for experimentation
bin/console
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/rubymap_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Code Style

This project uses [Standard Ruby](https://github.com/standardrb/standard) for code formatting:

```bash
# Check code style
bundle exec standardrb

# Auto-fix issues
bundle exec standardrb --fix
```

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ljuti/rubymap.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please make sure to:
- Add tests for new functionality
- Update documentation as needed
- Follow the existing code style (Standard Ruby)
- Keep commits focused and atomic

## 📄 License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## 🙏 Acknowledgments

Rubymap is built on top of these excellent tools:
- [Prism](https://github.com/ruby/prism) - Ruby's new parser
- [YARD](https://yardoc.org) - Documentation extraction
- [Standard](https://github.com/standardrb/standard) - Ruby style guide

## 🔮 Roadmap

- [ ] Web UI for exploring code maps
- [ ] Real-time file watching
- [ ] GitHub integration for PR analysis
- [ ] Support for more frameworks (Sinatra, Hanami)

See the [full roadmap](docs/rubymap.md#roadmap--future-features) for more planned features.

---

**Need help?** Open an issue on [GitHub](https://github.com/ljuti/rubymap/issues) or check the [documentation](docs/rubymap.md).