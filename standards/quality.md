# Quality Standards

These standards govern coding conventions, testing, and code quality. They apply
during Implementation (IM), Review (RV), Verify (VR), and Refactor (RF) phases.

## Ruby Conventions

- Follow standard Ruby conventions with **Standard Ruby** (`standardrb`). The
  project uses Ruby 3.2 as the target version.
- Run `bundle exec standardrb` to lint, `bundle exec standardrb --fix` to
  auto-correct.
- All Ruby files start with `# frozen_string_literal: true`.
- Use double quotes for strings that contain interpolation or special characters;
  single quotes otherwise. StandardRB enforces this.
- The project requires Ruby >= 3.2.0. Do not use features from newer Ruby
  versions.

## Naming

- **Modules and classes**: PascalCase (`Rubymap`, `ErrorCollector`,
  `NormalizedResult`).
- **Methods and variables**: snake_case (`extract_from_file`, `error_collector`,
  `max_retries`).
- **Constants**: SCREAMING_SNAKE_CASE (`SCHEMA_VERSION`, `DEFAULT_RETRYABLE_ERRORS`).
- **File names**: snake_case matching the class/module name
  (`error_collector.rb` for `ErrorCollector`).
- **Test files**: `*_spec.rb` suffix in `spec/` mirroring the `lib/` structure.
- **Boolean methods**: end with `?` (`any?`, `critical?`, `limit_reached?`).
- **Destructive methods**: end with `!` when a non-destructive variant exists
  (`merge!`, `validate!`).
- **Predicate methods**: use `is_` prefix only to avoid ambiguity with noun
  methods.
- **Acronyms**: keep as all-caps in PascalCase names (`LLM`, `CLI`, `JSON`,
  `YAML`), but lowercase in snake_case (`llm_emitter`, `json_formatter`).

## Linting

The project enforces the following:

- **Standard Ruby (`standardrb`)**: Style and formatting. Configured in
  `.standard.yml` targeting Ruby 3.2.
- **RSpec**: Test style conventions (no monkey-patching, documentation format
  output). Configured in `.rspec`.

Run `bundle exec standardrb` before declaring code complete. The default rake
task runs both specs and linting: `bundle exec rake`.

## Error Handling

- Use custom error classes under `Rubymap::Error`: `Rubymap::ConfigurationError`,
  `Rubymap::NotFoundError`, `Rubymap::CriticalError`. Do not raise generic
  `StandardError` directly.
- Errors carry structured context (file path, line number, category) via
  `ErrorInfo` structs, not string interpolation into messages.
- Validate at system boundaries (file paths in `extract_from_file`, format
  arguments in `Emitter.emit`). Trust internal function contracts.
- Use `ErrorCollector#add_error` for recoverable errors that should be recorded
  but not raised. Use `raise` only for truly unrecoverable states
  (missing output directory, invalid format).
- Use sentinel categories from `ErrorCollector::CATEGORIES`
  (`:parse`, `:filesystem`, `:config`, `:runtime`, `:output`) to classify
  errors. Do not use uncategorized errors.

## Testing

### Structure

- Tests live in `spec/`, mirroring `lib/` structure. `spec/rubymap_spec.rb`
  tests `lib/rubymap.rb`.
- Use `spec/spec_helper.rb` for RSpec configuration. Use `--require spec_helper`
  in `.rspec`.
- Test fixtures live in `spec/fixtures/`. Keep fixtures minimal — one concept
  per fixture file.
- Use RSpec's documentation format (`--format documentation`).

### Test pattern

```ruby
RSpec.describe Rubymap::Extractor do
  describe "#extract_from_file" do
    it "extracts classes from a Ruby file" do
      result = subject.extract_from_file("spec/fixtures/sample.rb")
      expect(result.classes).not_to be_empty
    end

    it "raises ArgumentError when file does not exist" do
      expect { subject.extract_from_file("nonexistent.rb") }
        .to raise_error(ArgumentError, /File not found/)
    end
  end
end
```

### Mocking

- Prefer real objects over mocks. Use test fixtures for file-based tests.
- When mocking is necessary, use RSpec's built-in doubles. Do not add mocking
  frameworks.
- Mock at module boundaries, not internal implementation details.

### Coverage

- Run `bundle exec rspec` to execute the full test suite.
- Run `bundle exec mutant run` for mutation testing. The project targets high
  mutation coverage, particularly for the Normalizer (100% mutation coverage).
- New code must have tests. Bug fixes must include a regression test that fails
  before the fix.
- Use `bin/mutant` as a convenience script for mutation testing.

### Test Commands

```bash
bundle exec rspec                              # Run all tests
bundle exec rspec spec/rubymap_spec.rb         # Single test file
bundle exec rspec spec/rubymap_spec.rb:4       # Single test at line
bundle exec mutant run                         # Mutation testing
bin/mutant                                     # Convenience mutation testing
```

## Code Organization

- One class or module per file. Exceptions for small, tightly-coupled helper
  classes.
- Stage-specific code lives in subdirectories: `lib/rubymap/extractor/`,
  `lib/rubymap/normalizer/`, etc.
- Keep files focused. If a file exceeds ~300 lines, consider splitting by
  responsibility.
- Order within a file: `require_relative` statements, module/class definition,
  constants, `attr_*` declarations, `initialize`, public methods, private
  methods.
- Group related constants together. Use `freeze` on all constant arrays and
  hashes.

## Dependencies

- Runtime dependencies are declared in `rubymap.gemspec` only.
- Development dependencies are declared in `Gemfile`.
- Approved runtime dependencies: `prism` (parsing), `anyway_config`
  (configuration), `thor` (CLI), `tty-prompt`, `tty-progressbar`,
  `tty-spinner`, `tty-table`, `pastel` (TTY toolkit).
- Minimize external dependencies. Prefer standard library solutions.
- Run `bundle install` to synchronize dependencies.

## Documentation

- Public classes and methods use YARD-style documentation comments with
  `@rubymap` tags for the custom documentation emitter.
- Doc comments describe behavior and usage, not implementation.
- Include `@example` blocks for non-trivial public methods.
- Document parameters with `@param`, return values with `@return`, and raised
  errors with `@raise`.
- Private methods do not require doc comments unless the logic is non-obvious.
- Comments explain *why*, not *what*. The code should be self-explanatory for
  *what*.

```ruby
# Extracts symbols from a Ruby file on disk.
#
# @param file_path [String] Path to the Ruby file to analyze
# @return [Result] Extraction result containing all discovered symbols
# @raise [ArgumentError] if the file does not exist
def extract_from_file(file_path)
  # ...
end
```
