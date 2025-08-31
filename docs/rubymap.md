# Rubymap Documentation

## Overview

Rubymap is a comprehensive Ruby codebase mapping tool that extracts, indexes, and visualizes the structure of Ruby applications. It creates a searchable, LLM-friendly knowledge graph of your code including classes, modules, methods, relationships, and metadata.

### Current Features

- **Static Analysis**: Fast parsing using Prism with parallel processing for comprehensive code extraction
- **LLM-Optimized Output**: Generates perfectly chunked documentation with customizable ERB templates
- **Multiple Output Formats**: JSON, YAML, LLM markdown, and GraphViz DOT formats
- **Modular Pipeline**: Extractor → Normalizer → Enricher → Indexer → Emitter
- **Smart Deduplication**: Priority-based merging of duplicate symbols with confidence scoring
- **Pattern Detection**: Identifies design patterns, Rails conventions, and Ruby idioms
- **Code Metrics**: Cyclomatic complexity, ABC metrics, cohesion, coupling, and hotspot analysis
- **Template System**: User-overridable ERB templates with format-specific options
- **Advanced Indexing**: Multiple graph types with O(1) lookup and circular dependency detection
- **Deterministic Output**: Stable IDs and ordering for clean diffs

### Coming Soon

- **Runtime Introspection**: Capture dynamically defined methods and runtime code (configuration exists)
- **Rails Deep Integration**: Enhanced ActiveRecord models, routes, jobs mapping (partial support)
- **Web UI**: Interactive code exploration interface
- **File Watching**: Real-time updates as code changes
- **GitHub Integration**: PR analysis and code review support

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
# Map current directory
rubymap

# Output to specific directory
rubymap --output ./docs/map

# Map specific paths
rubymap app/models lib/
```

### Current CLI Commands

```
rubymap map [OPTIONS] [PATHS...]    # Create code map

Options:
  --format FORMAT    Output format: json, yaml, llm, graphviz (default: llm)
  --output PATH      Output directory (default: .rubymap)
  --exclude PATTERNS Patterns to exclude from mapping
  --verbose          Enable verbose logging
  --no-progress      Disable progress indicators

rubymap init                        # Initialize .rubymap.yml configuration
rubymap version                     # Show version information
rubymap formats                     # List available output formats
```

## Configuration

Create a `.rubymap.yml` file in your project root:

```yaml
# Path configuration
paths:
  - app/
  - lib/
exclude:
  - vendor/
  - node_modules/
  - spec/
  - test/

# Output settings
output:
  format: llm  # Options: llm, json, yaml, graphviz
  directory: .rubymap
  include_source: false
  redact_sensitive: true

# Template settings
templates:
  directory: ./my_templates  # Custom template directory
  format_options:
    llm:
      chunk_size: 2000
      include_metrics: true

# Runtime settings (experimental)
runtime:
  enabled: false
  safe_mode: true
  timeout: 30
```

## Architecture

### Pipeline Components

```
┌──────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐   ┌──────────┐
│ Extract  ├──▶│ Normalize  ├──▶│ Enrich   ├──▶│ Index    ├──▶│ Emit     │
│ (Prism)  │   │ & Dedupe   │   │ Metadata │   │ Symbols  │   │ (LLM)    │
└──────────┘   └────────────┘   └──────────┘   └─────────┘   └──────────┘
```

#### Extractor
- Uses Prism parser for fast, accurate Ruby parsing
- Extracts classes, modules, methods, constants, attributes, class variables
- Captures inheritance, mixins, documentation, YARD tags, @rubymap annotations
- Detects metaprogramming patterns (define_method, attr_accessor, delegate)
- Parallel file processing with configurable thread pools

#### Normalizer
- Configurable processing pipeline with pluggable steps
- Priority-based deduplication with confidence scoring
- Full namespace resolution and cross-reference validation
- Mixin method resolution with inheritance chain building
- Generates deterministic symbol IDs
- 100% mutation test coverage

#### Enricher
- Comprehensive metadata enhancement with configurable pipeline
- Calculates complexity scores (cyclomatic, ABC metrics)
- Identifies design patterns (singleton, factory, observer, strategy)
- Rails pattern detection (models, controllers, concerns, jobs, mailers)
- Ruby idiom detection (memoization, delegation, DSLs)
- Type inference and coercion support
- Hotspot analysis for frequently modified code

#### Indexer
- Builds multiple specialized graphs (inheritance, dependencies, mixins, constants)
- O(1) symbol lookup with multi-level caching
- Circular dependency detection with cycle reporting
- Missing reference identification and validation
- Query interface with fuzzy search and filtering
- Bidirectional relationship tracking

#### Emitter
- Multiple format support: JSON, YAML, LLM markdown, GraphViz DOT
- ERB-based template system with user overrides
- Context-aware chunking for LLM optimization
- Progress reporting with TTY components
- Security redaction for sensitive data
- Deterministic output for version control

## Output Format

### LLM-Optimized Output (Default)

The current output format is optimized for Large Language Models:

```
.rubymap/
├── index.md           # Navigation index
├── overview.md        # Project statistics
├── chunks/            # Documentation chunks
│   ├── user.md
│   ├── userscontroller.md
│   └── ...
├── relationships/     # Relationship documentation
│   ├── hierarchy.md
│   └── dependencies.md
└── manifest.json      # Metadata and chunk index
```

Each chunk includes:
- Class/module documentation
- Method signatures and descriptions
- File locations
- Relationships to other symbols
- Metadata for AI processing

### Example Chunk

```markdown
# Class: User

**File:** app/models/user.rb:1
**Type:** class
**Inherits from:** ApplicationRecord

## Description
Represents a user in the system

## Methods

### Instance Methods
- `#full_name` - Returns the user's full name
- `#active?` - Checks if the user is active

### Class Methods
- `.find_by_email(email)` - Finds a user by email address
```

## API Usage

### Ruby API

```ruby
require 'rubymap'

# Map specific paths
result = Rubymap.map(['app/models', 'lib/'])

# Access the output
result[:format]     # => :llm
result[:output_dir] # => ".rubymap"

# Configure options
Rubymap.configure do |config|
  config.output_dir = 'docs/map'
  config.exclude = ['vendor/', 'node_modules/']
end
```

## Testing

Rubymap has comprehensive test coverage:

```bash
# Run all tests
bundle exec rspec

# Run specific component tests
bundle exec rspec spec/normalizer_spec.rb
bundle exec rspec spec/unit/
bundle exec rspec spec/integration/

# Run with coverage
COVERAGE=true bundle exec rspec
```

### Test Organization

- `spec/unit/` - Unit tests for individual components
- `spec/integration/` - Integration tests for component interactions
- `spec/emitters/` - Emitter-specific tests
- `spec/` - High-level functionality tests

## Development

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/ljuti/rubymap.git
cd rubymap

# Install dependencies
bin/setup

# Run tests
bundle exec rspec

# Run linter
bundle exec standardrb

# Install gem locally for testing
bundle exec rake install
```

### Architecture Principles

1. **Modular Pipeline**: Each component has a single responsibility
2. **Deterministic Output**: Same input always produces same output
3. **Smart Deduplication**: Merges information from multiple sources
4. **Extensibility**: Easy to add new extractors, emitters, or processors
5. **Performance**: Optimized for large codebases

### Adding New Components

#### Adding a New Processor

```ruby
module Rubymap
  class Normalizer
    module Processors
      class MyProcessor < BaseProcessor
        def process(data, result, errors)
          # Process data and add to result
        end
        
        def validate(data, errors)
          # Validate data, add errors if invalid
        end
      end
    end
  end
end
```

#### Adding a New Emitter

```ruby
module Rubymap
  module Emitters
    class MyEmitter
      def emit(indexed_data)
        # Generate output from indexed data
      end
      
      def emit_to_directory(indexed_data, output_dir)
        # Write output to files
      end
    end
  end
end
```

## Troubleshooting

### Common Issues

#### No output generated
- Check that Ruby files exist in the specified paths
- Verify paths are not in the exclude list
- Run with `--verbose` for detailed logging

#### Large memory usage
- Process directories individually rather than entire codebase
- Exclude vendor and node_modules directories
- Consider breaking up very large projects

#### Parse errors
- Ensure Ruby files have valid syntax
- Check Ruby version compatibility (3.2+)
- Report parsing issues with example code

## Roadmap & Future Features

### Near Term (v1.0)
- [x] Static analysis with Prism
- [x] LLM-optimized output
- [x] Smart deduplication
- [ ] JSON output format
- [ ] YAML output format
- [ ] Basic web UI

### Medium Term (v2.0)
- [ ] Runtime introspection
- [ ] Rails deep integration
- [ ] GraphViz visualization
- [ ] Incremental updates
- [ ] File watching

### Long Term
- [ ] IDE integrations
- [ ] GitHub PR analysis
- [ ] Cloud-hosted service
- [ ] Support for other Ruby frameworks
- [ ] Multi-language support

## Contributing

We welcome contributions! Please see our [Contributing Guide](../CONTRIBUTING.md) for details.

### Development Process

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Update documentation
6. Submit a pull request

### Code Style

We use Standard Ruby for code formatting:

```bash
bundle exec standardrb --fix
```

## License

MIT License - see [LICENSE.txt](../LICENSE.txt) for details.

## Support

- GitHub Issues: https://github.com/ljuti/rubymap/issues
- Documentation: https://github.com/ljuti/rubymap/docs

## Acknowledgments

Built with:
- [Prism](https://github.com/ruby/prism) - Ruby parser
- [Standard](https://github.com/standardrb/standard) - Ruby style guide