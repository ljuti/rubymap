# Architecture Standards

These standards govern architectural decisions in the Rubymap codebase. They
apply during Technical Design (TD) and Verify (VR) phases.

## System Structure

Rubymap is a pipeline-based Ruby gem organized into five sequential stages. Each
stage is a top-level module under `Rubymap` with its own subdirectory in
`lib/rubymap/`.

```
CLI (Thor/TTY) / API (Rubymap.map)
        │
        ▼
    Pipeline (orchestrator)
        │
   ┌────┼────┬────┬────┐
   ▼    ▼    ▼    ▼    ▼
Extract → Index → Normalize → Enrich → Emit
```

- Each stage depends only on the data contract from the previous stage, never on
  internal details of other stages.
- The Pipeline class (`lib/rubymap/pipeline.rb`) is the sole orchestrator. No
  stage calls another stage directly.
- The public API entry point is `Rubymap.map`. All external consumers go through
  this method or the CLI, never directly to pipeline stages.

## Module Boundaries

### Stage organization

Each pipeline stage lives in its own namespace under `Rubymap`:

| Stage | Module | Directory |
|-------|--------|-----------|
| Extract | `Rubymap::Extractor` | `lib/rubymap/extractor/` |
| Index | `Rubymap::Indexer` | `lib/rubymap/indexer/` |
| Normalize | `Rubymap::Normalizer` | `lib/rubymap/normalizer/` |
| Enrich | `Rubymap::Enricher` | `lib/rubymap/enricher/` |
| Emit | `Rubymap::Emitter` | `lib/rubymap/emitter/` |

- Each stage owns a single domain concern. Do not merge stage responsibilities
  into one file.
- Cross-stage data flows through defined result objects (e.g.,
  `Normalizer::NormalizedResult`, `Enricher::EnrichmentResult`,
  `Indexer::IndexedResult`). Do not pass raw hashes between stages without an
  adapter.
- Support infrastructure (`ErrorCollector`, `RetryHandler`, `Configuration`)
  lives at the `Rubymap` module level, not inside any stage.

### Ownership

- Only the `Pipeline` orchestrates stage execution order. No other class may
  sequence stages.
- Only `Rubymap::Configuration` owns configuration state. Stages accept
  configuration at construction; they do not read config files or environment
  variables directly.
- Only `Rubymap::ErrorCollector` collects and categorizes errors. Individual
  stages report errors through the collector; they do not maintain their own
  error state.

## Interface Design

### Constructor injection

All pipeline stages accept dependencies through their constructors. Use keyword
arguments or configuration hashes, never global state.

```ruby
# Consumer defines the dependencies it needs
class Rubymap::Enricher
  def initialize(config = {})
    @config = default_config.merge(config)
    @registry = EnricherRegistry.new
    @component_factory = Factories::ComponentFactory.new(registry, @config)
  end
end
```

### Result objects as contracts

Each stage returns a specific result object that the next stage consumes. Do not
leak internal structures across stage boundaries.

```ruby
# Stage returns a defined result type
class Rubymap::Normalizer
  def normalize(raw_data)
    @processing_pipeline.execute(raw_data)  # returns NormalizedResult
  end
end
```

### Strategy and factory patterns

- Use the Strategy pattern for swappable behaviors (processors, resolvers,
  formatters). Define a base class in the stage's namespace and concrete
  implementations as subclasses.
- Use the Factory pattern for creating components with configuration. See
  `Normalizer::ProcessorFactory`, `Enricher::Converters::ConverterFactory`.

## Dependency Direction

- Upper pipeline stages (Enrich, Emit) depend on lower stages' result objects,
  never the reverse.
- The `lib/rubymap.rb` entry point requires all stages. Individual stage files
  require only their own components.
- External dependencies are declared in `rubymap.gemspec` for runtime deps and
  `Gemfile` for development deps. Do not add runtime dependencies to the
  Gemfile.

## New Stage Checklist

When adding a new pipeline stage:

1. Define its single responsibility clearly — one stage, one transformation
2. Create a module under `Rubymap` with its own subdirectory under
   `lib/rubymap/`
3. Define a result object for the stage's output
4. Accept configuration via constructor, not global state
5. Register the stage in `Pipeline#run` at the correct position
6. Add requires to `lib/rubymap.rb`

## Error Handling Philosophy

- Errors are collected, not raised. Each stage reports errors to the
  `ErrorCollector` rather than raising exceptions that abort the pipeline.
- The pipeline continues processing remaining files when individual files fail
  (extraction, indexing). Only fatal errors (output directory unwritable,
  critical configuration errors) stop the pipeline.
- Use `RetryHandler` with exponential backoff for transient failures (file I/O,
  resource contention). Do not retry parse errors or configuration errors.
- All errors carry a severity level: `:critical`, `:error`, `:warning`, `:info`.
- Return errors to callers via the `ErrorCollector`. Do not log-and-continue
  without recording the error.
