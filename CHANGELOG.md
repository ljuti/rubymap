## [Unreleased]

### Added
- Template system with ERB-based customizable output templates
- Multiple output format support (JSON, YAML, LLM markdown, GraphViz DOT)
- Advanced enrichment pipeline with configurable processors and analyzers
- Comprehensive code metrics (complexity, cohesion, coupling, hotspot analysis)
- Smart deduplication with priority-based symbol merging
- Confidence scoring system for symbol reliability
- Pattern detection for design patterns and Ruby idioms
- Rails-specific pattern recognition (models, controllers, concerns, jobs, mailers)
- Advanced indexing with multiple graph types and O(1) lookup
- Circular dependency detection with cycle reporting
- CLI with Thor and TTY components for better user experience
- Configuration management with Anyway Config
- Mutation testing with 100% coverage for critical components
- Parallel file processing for improved performance
- Template presenters for clean separation of concerns
- Documentation emitter with specialized documentation generation

### Changed
- Refactored normalizer with configurable processing pipeline
- Enhanced extractor with metaprogramming pattern detection
- Improved enricher with type inference and coercion support
- Updated emitter architecture to support multiple formats
- Better error handling and progress reporting throughout pipeline

### Technical Improvements
- SOLID principles implementation throughout codebase
- Dependency injection and strategy patterns
- Modular architecture for easy extension
- Deterministic output for version control
- Security redaction for sensitive data

## [0.1.0] - 2025-08-28

- Initial release with basic static analysis capabilities
- Core pipeline structure (Extractor → Normalizer → Enricher → Indexer → Emitter)
- Basic Ruby symbol extraction using Prism parser
- Foundation for modular architecture
