# Rubymap

[![Gem Version](https://badge.fury.io/rb/rubymap.svg)](https://badge.fury.io/rb/rubymap)
[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-red.svg)](https://www.ruby-lang.org)

> 🗺️ A comprehensive Ruby codebase analysis tool that maps your code's structure, relationships, and architecture

Rubymap creates a searchable, LLM-friendly knowledge graph of your Ruby application. It combines fast static analysis with optional runtime introspection to capture every aspect of your code - from class hierarchies to metaprogrammed methods, from Rails models to background jobs.

## ✨ Key Features

- **🚀 Dual-pass analysis** - Lightning-fast static parsing plus optional runtime introspection
- **🛤️ Rails-aware** - Deep understanding of ActiveRecord, routes, jobs, and Rails conventions
- **🤖 LLM-optimized** - Generates perfectly chunked documentation for AI assistants
- **🔮 Metaprogramming support** - Captures dynamically defined methods and runtime code
- **⚡ Performance focused** - Sub-second analysis for thousands of files
- **🔒 Security-first** - Sandboxed runtime analysis with configurable safety controls
- **📊 Rich metrics** - Code complexity, churn analysis, dependency graphs

## 🚀 Quick Start

```bash
# Install the gem
gem install rubymap

# Map your Ruby project
rubymap

# Include runtime mapping for Rails apps
rubymap --runtime

# Generate LLM-friendly code map
rubymap --format llm --output docs/ai-map
```

### Quick Example

Map a Rails application with full introspection:

```bash
cd my_rails_app
rubymap --runtime

# View the generated map
ls -la .rubymap/
# ├── map.json          # Global metadata
# ├── symbols/          # All classes, modules, methods
# ├── graphs/           # Relationship graphs
# └── rails/            # Rails-specific data
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

# Generate different output formats
rubymap --format json      # Default: structured JSON
rubymap --format llm       # LLM-optimized chunks
rubymap --format yaml      # YAML format
rubymap --format graphviz  # Dependency diagrams

# Update existing map (incremental)
rubymap update

# Custom output directory
rubymap --output ./documentation/map
```

### Rails-Specific Mapping

```bash
# Full Rails mapping (models, routes, jobs)
rubymap --runtime

# Map specific Rails components with runtime
rubymap app/models --runtime
rubymap app/controllers app/jobs

# Skip certain initializers during runtime mapping
rubymap --runtime --skip-initializer sidekiq
```

### Configuration

Create `.rubymap.yml` in your project root:

```yaml
# Basic configuration
static:
  paths: [app/, lib/]
  exclude: [vendor/, node_modules/]

runtime:
  enabled: true
  safe_mode: true
  timeout: 30

output:
  format: json
  directory: .rubymap
```

See [full configuration documentation](docs/rubymap.md#configuration) for all options.

## 🏗️ How It Works

Rubymap uses a two-pass approach to build a complete picture of your codebase:

```
┌─────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│ Static  ├──▶│ Normalize  ├──▶│ Enrich   ├──▶│ Index    ├──▶│ Output   │
│ Parse   │   │ Data       │   │ Metrics  │   │ Graph    │   │ Format   │
└─────────┘   └────────────┘   └──────────┘   └─────────┘   └──────────┘
     +
┌─────────┐
│Runtime  │ (Optional: ActiveRecord models, routes, dynamic methods)
│Analysis │
└─────────┘
```

### Static Mapping (Always runs)
- Parses Ruby files using Prism for speed and accuracy
- Extracts classes, modules, methods, constants
- Tracks inheritance, mixins, and dependencies
- Reads YARD documentation and type signatures

### Runtime Mapping (Optional, Rails-aware)
- Safely boots your application in a sandboxed environment
- Discovers ActiveRecord attributes and associations
- Maps routes to controllers and actions
- Finds dynamically defined methods
- Captures actual type information

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
| Runtime mapping | ✅ | ❌ | ❌ | ❌ |
| Rails aware | ✅ | Partial | Partial | ❌ |
| LLM optimized | ✅ | ❌ | ❌ | ❌ |
| Metaprogramming | ✅ | Limited | Limited | ❌ |

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
- [ ] Cloud-hosted analysis service

See the [full roadmap](docs/rubymap.md#roadmap--future-features) for more planned features.

---

**Need help?** Open an issue on [GitHub](https://github.com/ljuti/rubymap/issues) or check the [documentation](docs/rubymap.md).