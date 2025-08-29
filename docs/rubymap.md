# Rubymap Documentation

## Overview

Rubymap is a comprehensive Ruby codebase mapping tool that extracts, indexes, and visualizes the structure of Ruby applications. It creates a searchable, LLM-friendly knowledge graph of your code including classes, modules, methods, relationships, and metadata.

### Current Features

- **Static Analysis**: Fast parsing using Prism for comprehensive code extraction
- **LLM-Optimized Output**: Generates perfectly chunked documentation for AI assistants
- **Modular Pipeline**: Extractor → Normalizer → Enricher → Indexer → Emitter
- **Smart Deduplication**: Merges duplicate symbols from multiple sources
- **Deterministic Output**: Stable IDs and ordering for clean diffs

### Coming Soon

- **Runtime Introspection**: Capture dynamically defined methods and runtime code
- **Rails Deep Integration**: ActiveRecord models, routes, jobs mapping
- **Multiple Output Formats**: JSON, YAML, GraphViz support
- **Web UI**: Interactive code exploration interface

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
rubymap [OPTIONS] [PATHS...]        # Create code map

Options:
  --output PATH      Output directory (default: .rubymap)
  --verbose          Enable verbose logging
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
  format: llm  # Currently only LLM format is supported
  directory: .rubymap
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
- Extracts classes, modules, methods, constants
- Captures inheritance, mixins, documentation

#### Normalizer
- Standardizes data format across sources
- Deduplicates symbols with smart merging
- Resolves namespaces and relationships
- Generates deterministic symbol IDs

#### Enricher
- Adds metadata and metrics
- Calculates complexity scores
- Identifies patterns and conventions

#### Indexer
- Builds searchable symbol index
- Creates relationship graphs
- Optimizes for fast lookups

#### Emitter
- Generates LLM-optimized chunks
- Creates navigation indexes
- Produces manifest with metadata

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