# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rubymap is a Ruby codebase mapping tool that creates a comprehensive knowledge graph of code structure, relationships, and metadata. It uses fast static parsing with Prism to map classes, modules, methods, constants, attributes, and their relationships. The tool includes Rails pattern detection and is optimized for generating LLM-friendly documentation with customizable templates.

## Common Development Commands

### Testing
- Run all tests: `rake spec` or `bundle exec rspec`
- Run a specific test file: `bundle exec rspec spec/rubymap_spec.rb`
- Run tests with specific line number: `bundle exec rspec spec/rubymap_spec.rb:4`
- Run mutation testing: `bundle exec mutant run` or `bin/mutant`
- Test self-mapping: `ruby test_self_mapping.rb`

### Linting
- Run Standard Ruby linter: `rake standard` or `bundle exec standardrb`
- Auto-fix linting issues: `bundle exec standardrb --fix`

### Build and Install
- Install dependencies: `bundle install` or `bin/setup`
- Build gem: `gem build rubymap.gemspec`
- Install gem locally: `bundle exec rake install`
- Release new version: `bundle exec rake release` (creates git tag, pushes to git and RubyGems)

### Development Tools
- Interactive console with gem loaded: `bin/console`
- Run default tasks (specs + linting): `rake` or `rake default`
- Generate documentation: `ruby generate_rubymap_docs.rb`

## Codebase Architecture

This is a Ruby gem project structured following standard Ruby gem conventions with a modular pipeline architecture:

### Core Structure
- **lib/rubymap.rb**: Main module entry point that defines the `Rubymap` module namespace and loads dependencies
- **lib/rubymap/**: Directory for all gem implementation code
- **lib/rubymap/version.rb**: Defines the gem version constant (VERSION)
- **spec/**: RSpec test suite with spec_helper.rb configuration and test files

### Pipeline Components
- **lib/rubymap/extractor/**: Static code parsing using Prism, extracts symbols and relationships
  - Pattern matchers for metaprogramming detection
  - Parallel file processing capabilities
  - YARD and annotation parsing
- **lib/rubymap/normalizer/**: Data standardization and deduplication
  - Configurable processing pipeline with steps
  - Priority-based symbol merging
  - Confidence scoring system
  - 100% mutation test coverage
- **lib/rubymap/enricher/**: Metadata enhancement and analysis
  - Analyzers for patterns and metrics
  - Converters for data transformation
  - Rails-specific pattern detection
  - Configurable processor pipeline
- **lib/rubymap/indexer/**: Symbol graph and relationship management
  - Multiple graph types (inheritance, dependencies, mixins, etc.)
  - O(1) lookup with caching
  - Circular dependency detection
- **lib/rubymap/emitter/**: Output generation with multiple formats
  - JSON, YAML, LLM markdown, GraphViz DOT formats
  - Template-based rendering system
  - Progress reporting with TTY components

### Template System
- **lib/rubymap/templates/**: ERB-based template system
  - Default templates for each format
  - Template presenters for data transformation
  - User-overridable templates via configuration
  - Context and registry management

### CLI and Configuration
- **lib/rubymap/cli.rb**: Thor-based command-line interface with TTY components
- **lib/rubymap/configuration.rb**: Anyway Config-based configuration management
- **lib/rubymap/pipeline.rb**: Main orchestration for the analysis pipeline
- **lib/rubymap/documentation_emitter.rb**: Specialized emitter for documentation generation

### Configuration
- **rubymap.gemspec**: Gem specification with dependencies (Prism, Thor, TTY suite, Anyway Config)
- **Gemfile**: Development dependencies including RSpec, Standard, Mutant
- **Rakefile**: Defines rake tasks combining RSpec and Standard
- **.standard.yml**: Standard Ruby linter configuration targeting Ruby 3.2
- **.rspec**: RSpec configuration for documentation format and colored output
- **.rubymap.yml**: Optional project configuration file

### Key Implementation Notes
- Ruby version requirement: >= 3.2.0
- Testing framework: RSpec 3.x with documentation format output
- Mutation testing: Mutant for ensuring test quality
- Linting: Standard Ruby (built on RuboCop) for code style consistency
- The gem follows Ruby's frozen string literal convention for performance
- Uses dependency injection and strategy patterns throughout
- Modular architecture allows easy extension and customization
- Default rake task runs both specs and linting to ensure code quality