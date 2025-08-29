# Rubymap

[![Gem Version](https://badge.fury.io/rb/rubymap.svg)](https://badge.fury.io/rb/rubymap)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-red.svg)](https://www.ruby-lang.org)

> 🗺️ A comprehensive Ruby codebase analysis tool that maps your code's structure, relationships, and architecture

Rubymap creates a searchable, LLM-friendly knowledge graph of your Ruby application. It uses fast static analysis to capture your code's structure - from class hierarchies to method definitions, preparing for future runtime introspection capabilities.

## ✨ Key Features

### Currently Implemented
- **🚀 Static analysis** - Lightning-fast parsing using Prism
- **🤖 LLM-optimized** - Generates perfectly chunked documentation for AI assistants
- **⚡ Performance focused** - Sub-second analysis for thousands of files
- **📊 Code structure mapping** - Classes, modules, methods, and their relationships
- **🔧 Modular pipeline** - Extractor → Normalizer → Enricher → Indexer → Emitter

### Coming Soon
- **🛤️ Rails-aware** - Deep understanding of ActiveRecord, routes, jobs (in development)
- **🔮 Runtime introspection** - Capture dynamically defined methods and runtime code
- **🔒 Security controls** - Sandboxed runtime analysis with configurable safety
- **📊 Rich metrics** - Code complexity, churn analysis, dependency graphs

## 🚀 Quick Start

```bash
# Install the gem
gem install rubymap

# Map your Ruby project
rubymap

# Generate LLM-friendly code map (default format)
rubymap --output docs/ai-map

# Specify different output formats (coming soon)
# rubymap --format json
# rubymap --format yaml
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

# Currently, LLM format is the default output
# Additional formats coming soon:
# rubymap --format json      # Structured JSON
# rubymap --format yaml      # YAML format
# rubymap --format graphviz  # Dependency diagrams
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
exclude: [vendor/, node_modules/]

output:
  format: llm  # Currently only LLM format is supported
  directory: .rubymap

# Runtime configuration (coming soon)
# runtime:
#   enabled: true
#   safe_mode: true
#   timeout: 30
```

See [full configuration documentation](docs/rubymap.md#configuration) for all options.

## 🏗️ How It Works

Rubymap uses a modular pipeline approach to build a complete picture of your codebase:

```
┌──────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│ Extract  ├──▶│ Normalize  ├──▶│ Enrich   ├──▶│ Index    ├──▶│ Emit     │
│ (Prism)  │   │ & Dedupe   │   │ Metadata │   │ Symbols  │   │ (LLM)    │
└──────────┘   └────────────┘   └──────────┘   └─────────┘   └──────────┘
```

### Current Pipeline Components

**Extractor** - Fast static parsing using Prism
- Extracts classes, modules, methods, constants
- Tracks inheritance, mixins, and dependencies
- Captures documentation comments

**Normalizer** - Data standardization and deduplication
- Converts raw data to consistent format
- Merges duplicate symbols from multiple sources
- Resolves namespaces and relationships

**Enricher** - Metadata enhancement
- Adds code metrics and complexity scores
- Identifies patterns and conventions
- Prepares data for indexing

**Indexer** - Symbol graph creation
- Builds searchable index of all symbols
- Creates relationship mappings
- Optimizes for fast lookups

**Emitter** - Output generation
- Creates LLM-optimized documentation chunks
- Generates navigation indexes
- Produces manifest with metadata

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