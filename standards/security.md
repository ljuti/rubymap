# Security Standards

These standards govern security practices for credentials, input validation, and
data integrity. They apply during Review (RV) and Verify (VR) phases.

## Credentials and Secrets

### Secret Storage

- API keys and tokens are stored in environment variables, never in code or
  committed configuration files.
- Configuration references secrets via environment variable names, not inline
  values. The `Configuration#expand_env_vars` method resolves `${VAR}`
  patterns at runtime.
- The `.rubymap.yml` configuration file is for project settings only. Do not
  store credentials, tokens, or API keys in it.
- Local development overrides (`.rubymap.local.yml`) must be listed in
  `.gitignore` and never committed.

### Credential Handling Rules

- Never log credentials or API keys at any log level.
- Never include credentials in error messages, audit entries, or
  `ErrorCollector` records.
- The `output.redact_sensitive` configuration flag (default: `true`) enables
  redaction of sensitive values in generated output. Do not disable redaction
  for production documentation.

## Content Integrity

### Hashing and Verification

- Symbol IDs are generated using SHA-256 via `Digest::SHA256`:

```ruby
Digest::SHA256.hexdigest(content)[0..15]
```

- Use SHA-256 for all content addressing. Do not use MD5, SHA-1, or other
  weakened algorithms for content integrity.
- `Normalizer::SymbolIdGenerator` is the authority for symbol ID generation.
  All symbol IDs must be generated through this class.
- Cache keys are derived from file content hashes to detect changes.

### Immutability

- `ErrorCollector` audit entries are append-only. There is no update or delete
  operation on collected errors.
- Generated output files in the output directory are written once per run.
  The output directory is recreated on each run; do not modify existing output
  files in place.
- Symbol IDs are content-derived and stable — the same input produces the same
  ID (deterministic output).

## Input Validation

### System Boundaries

- Validate all external input:
  - File paths (existence, readability)
  - Configuration values (format, type, ranges)
  - YAML configuration files (safe_load only)
  - Ruby source files (parseable by Prism)
- Use structured parsing rather than string manipulation for configuration.
  `YAML.safe_load` with `permitted_classes: [Symbol]` — never use
  `YAML.load` (unsafe).
- Validate `.rubymap.yml` configuration files before execution. The
  `Configuration#validate!` method checks format, writability, and path
  existence.
- Required configuration fields (`output_dir`, `format`) are checked
  explicitly with clear error messages.

### Path Traversal Prevention

- Resolve relative paths against the project root using `File.expand_path`.
- Use `File.fnmatch?` with `File::FNM_PATHNAME` for glob pattern exclusion
  matching. This prevents bypass via crafted paths.
- Do not trust user-supplied paths without resolution. The `Configuration`
  always expands paths via `resolve_path`.
- Ruby source files are loaded from explicitly enumerated directories. Do not
  follow symlinks outside the project root when `follow_symlinks` is `false`
  (the default).
- Exclude patterns are matched against resolved absolute paths, not relative
  paths, to prevent traversal bypass.

### Configuration Validation

- Configuration files validate input before processing:
  - `format` must be `:llm` (only supported format)
  - `output_dir` parent must be writable
  - `runtime.timeout` must be a positive integer
  - `runtime.environment` must be one of: development, test, staging, production
  - `static.paths` must exist on disk
- Validation failures are signaled with `Rubymap::ConfigurationError` with a
  descriptive message listing all errors.

## Command Execution

- Rubymap does not execute shell commands or the code it analyzes. Static
  analysis via Prism is safe by design — no code is evaluated.
- The runtime analysis mode (`runtime.enabled`) evaluates application code.
  It defaults to `false` and must be explicitly enabled. When enabled,
  `runtime.safe_mode` (default: `true`) restricts available operations.
- Never execute user-provided code without explicit opt-in via runtime
  configuration.

## File Permissions

- Configuration files in the project root (`.rubymap.yml`) should be readable
  by the project owner.
- The cache directory (`.rubymap_cache`) contains intermediate artifacts —
  no secrets, but restricted permissions recommended.
- The output directory (`.rubymap` by default) contains generated
  documentation. Permissions should match the project's documentation
  conventions.
- Temporary files created during extraction should be cleaned up on completion
  or failure. The `CLI#clean` command removes all generated files.

## Dependency Security

- The project minimizes external dependencies to reduce attack surface.
  Runtime dependencies: Prism, Anyway Config, Thor, TTY toolkit components,
  Pastel.
- Gems are installed via Bundler with `bundle install`. No script execution
  occurs during installation beyond standard gem installation.
- The `Gemfile.lock` is committed to version control and should be reviewed
  for dependency changes.
- RubyGems package signatures (when implemented) should be verified before
  installation.

## Sensitive Data in Output

- The `output.redact_sensitive` flag controls whether potentially sensitive
  data (environment variable values, file paths with usernames) is redacted
  from generated documentation.
- When generating documentation for external consumption, always enable
  redaction.
- Source code inclusion in output is controlled by `output.include_source`
  (default: `false`). Do not include full source code in public documentation
  without review.
