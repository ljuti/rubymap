# Rubymap

[![Gem Version](https://badge.fury.io/rb/rubymap.svg)](https://badge.fury.io/rb/rubymap)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-red.svg)](https://www.ruby-lang.org)

> 🗺️ A Ruby codebase analysis tool that generates LLM-optimized documentation from your code's structure

Rubymap uses fast static analysis with Prism to extract classes, modules, methods, and their relationships, then emits LLM-friendly markdown documentation for AI-assisted development.

## ✨ Key Features

- **🚀 Static analysis** — Fast parsing using Prism with comprehensive symbol extraction
- **🤖 LLM-optimized output** — Generates chunked markdown documentation optimized for AI assistants
- **📊 Code structure mapping** — Classes, modules, methods, constants, attributes, and their relationships
- **🔧 Modular pipeline** — Extractor → Indexer → Normalizer → Enricher → Emitter
- **🎯 Smart deduplication** — Intelligent merging of duplicate symbols with priority-based resolution
- **🔍 Pattern detection** — Identifies design patterns, Rails conventions, and Ruby idioms
- **📈 Code metrics** — Complexity, cohesion, coupling, and quality metrics
- **📍 Advanced indexing** — Multiple graph types with O(1) lookup and circular dependency detection

### Roadmap

- **📝 Template system** — Customizable ERB templates for output customization (infrastructure exists, not yet activated)
- **🛤️ Rails-aware enrichment** — Deep understanding of ActiveRecord associations, routes, and jobs (partial support)
- **🔮 Runtime introspection** — Capture dynamically defined methods and runtime code (not yet implemented)
- **🌐 Web UI** — Interactive exploration of code maps
- **👀 File watching** — Real-time updates as code changes

## 🚀 Quick Start

```bash
# Install the gem
gem install rubymap

# Map your Ruby project (generates LLM-optimized docs)
rubymap

# Specify custom output directory
rubymap --output docs/ai-map
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

Or install globally:

```bash
gem install rubymap
```

## 🎯 Usage

```bash
# Map current directory
rubymap

# Map specific paths
rubymap app/models lib/services

# Custom output directory
rubymap --output ./documentation/map

# Verbose output
rubymap --verbose
```

### Configuration

Create `.rubymap.yml` in your project root:

```yaml
# Basic configuration
output_dir: .rubymap
format: llm

# Static analysis paths
static:
  paths: [app/, lib/]
  exclude: [vendor/, node_modules/]

# Filter patterns to exclude
filter:
  exclude_patterns:
    - "**/spec/**"
    - "**/test/**"
    - "**/vendor/**"
    - "**/node_modules/**"
```

See [configuration documentation](docs/rubymap.md#configuration) for all options.

## 🏗️ How It Works

Rubymap uses a modular pipeline:

```
┌──────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐
│ Extract  ├──▶│ Index    ├──▶│ Normalize  ├──▶│ Enrich   ├──▶│ Emit     │
│ (Prism)  │   │ Graphs   │   │ & Dedupe   │   │ Metadata │   │ (LLM)    │
└──────────┘   └──────────┘   └────────────┘   └──────────┘   └──────────┘
```

### Pipeline Components

**Extractor** — Fast static parsing using Prism
- Extracts classes, modules, methods, constants, attributes, mixins, and class variables
- Tracks inheritance chains, dependencies, method calls, and require statements
- Captures documentation comments and annotations

**Indexer** — Symbol graph creation
- Multiple specialized graphs (inheritance, dependencies, method calls, mixins)
- O(1) symbol lookup with caching
- Circular dependency detection
- Query interface with fuzzy search and filtering

**Normalizer** — Data standardization
- Configurable processing pipeline with pluggable steps
- Smart deduplication using priority-based symbol merging
- Full namespace resolution and cross-reference validation
- Mixin method resolution with inheritance chain building

**Enricher** — Metadata enhancement
- Rails pattern detection (models, controllers, concerns)
- Design pattern identification
- Code metrics (cyclomatic complexity, cohesion, coupling)
- Ruby idiom detection
- Hotspot analysis

**Emitter** — LLM-optimized output generation
- Chunked markdown documentation optimized for AI consumption
- Context-aware content splitting
- Progress reporting with TTY components
- Deterministic output for clean version control diffs

## 📊 Output Example

### LLM-Friendly Output
```markdown
## Class: User < ApplicationRecord
Location: app/models/user.rb

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
| Rails aware | 🚧 | Partial | Partial | ❌ |
| Runtime mapping | 🚧 | ❌ | ❌ | ❌ |

✅ = Implemented, 🚧 = In Development

## 📚 Documentation

- [**Architecture Details**](docs/rubymap.md) — How Rubymap works internally
- [**Configuration Reference**](docs/rubymap.md#configuration) — All configuration options
- [**Pipeline Components**](docs/rubymap.md#architecture) — Component-level documentation

## 🛠️ Development

```bash
# Install dependencies
bin/setup

# Run tests
bundle exec rspec

# Run linter
bundle exec standardrb

# Run tests + lint
rake
```

### Code Style

This project uses [Standard Ruby](https://github.com/standardrb/standard):

```bash
bundle exec standardrb        # Check
bundle exec standardrb --fix  # Auto-fix
```

## 🤝 Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ljuti/rubymap.

Please:
- Add tests for new functionality
- Update documentation as needed
- Follow Standard Ruby code style
- Keep commits focused and atomic

## 📄 License

MIT License. See [LICENSE.txt](LICENSE.txt).

## 🙏 Acknowledgments

Built on:
- [Prism](https://github.com/ruby/prism) — Ruby parser
- [Standard](https://github.com/standardrb/standard) — Ruby style guide
- [TTY Toolkit](https://ttytoolkit.org) — Terminal components
- [Anyway Config](https://github.com/palkan/anyway_config) — Configuration management

## 🔮 Roadmap

- [ ] Template system activation for customizable output
- [ ] Web UI for exploring code maps
- [ ] Real-time file watching
- [ ] GitHub integration for PR analysis
- [ ] Support for more frameworks (Sinatra, Hanami)

---

**Need help?** Open an issue on [GitHub](https://github.com/ljuti/rubymap/issues).
