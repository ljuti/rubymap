# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rubymap is a Ruby codebase mapping tool that creates a comprehensive knowledge graph of code structure, relationships, and metadata. It uses both static parsing and optional runtime introspection to map classes, methods, constants, and their relationships. The tool is especially powerful for Rails applications, with built-in understanding of ActiveRecord models, routes, and Rails conventions.

## Common Development Commands

### Testing
- Run all tests: `rake spec` or `bundle exec rspec`
- Run a specific test file: `bundle exec rspec spec/rubymap_spec.rb`
- Run tests with specific line number: `bundle exec rspec spec/rubymap_spec.rb:4`

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

## Codebase Architecture

This is a Ruby gem project structured following standard Ruby gem conventions:

### Core Structure
- **lib/rubymap.rb**: Main module entry point that defines the `Rubymap` module namespace and loads dependencies
- **lib/rubymap/**: Directory for all gem implementation code
- **lib/rubymap/version.rb**: Defines the gem version constant (VERSION)
- **spec/**: RSpec test suite with spec_helper.rb configuration and test files

### Configuration
- **rubymap.gemspec**: Gem specification defining metadata, dependencies, and packaging details
- **Gemfile**: Development dependencies including RSpec for testing and Standard for linting
- **Rakefile**: Defines rake tasks combining RSpec and Standard (default task runs both)
- **.standard.yml**: Standard Ruby linter configuration targeting Ruby 3.2
- **.rspec**: RSpec configuration for documentation format and colored output

### Key Implementation Notes
- Ruby version requirement: >= 3.2.0
- Testing framework: RSpec 3.x with documentation format output
- Linting: Standard Ruby (built on RuboCop) for code style consistency
- The gem follows Ruby's frozen string literal convention for performance
- Default rake task runs both specs and linting to ensure code quality