# Compliance Standards

These standards govern audit trails, traceability, determinism guarantees, and
compliance verification. They apply during the Verify (VR) phase only.

## Traceability Chain

Every artifact in a Rubymap run must be traceable through a complete chain:

```
Source files → Extraction → Indexing → Normalization → Enrichment → Output files
     │              │           │            │              │            │
     ▼              ▼           ▼            ▼              ▼            ▼
  File paths   Parse results  Symbol     Normalized    Enrichment    Generated
                + errors     index      result + IDs   result       documentation
```

### Required Records

- **Extraction records**: File path, parse success/failure, extracted symbols
  count, parse errors with line numbers.
- **Index records**: Symbol count, graph node/edge counts, detected circular
  dependencies, missing references.
- **Normalization records**: Schema version (`SCHEMA_VERSION`), normalizer
  version (`NORMALIZER_VERSION`), deduplication count, resolution errors.
- **Enrichment records**: Metrics calculated, patterns detected, Rails
  conventions identified, issues flagged.
- **Emission records**: Output format, output directory, files generated,
  file sizes.

### Timeline

- All pipeline metadata includes timestamps. The `extracted_at`, `normalized_at`,
  and `enriched_at` fields capture ordered events across the lifecycle.
- Pipeline progress is logged at each stage transition when `verbose` or
  `progress` is enabled.

## Audit Trail

### Error Collection

- The `ErrorCollector` is append-only by design. It supports `add_error()`,
  `add_warning()`, `add_info()`, `add_critical()` — there is no delete or
  update.
- Every pipeline event that diverges from expected behavior generates an audit
  entry with:
  - Category (one of `ErrorCollector::CATEGORIES`: `:parse`, `:config`,
    `:filesystem`, `:runtime`, `:output`, etc.)
  - Severity (`:critical`, `:error`, `:warning`, `:info`)
  - File path and line number (when applicable)
  - Context hash with additional structured data
  - Timestamp (ISO 8601)

### Error Summary

- The pipeline produces a structured error summary (`ErrorCollector#summary`)
  with:
  - Total error count
  - Breakdown by severity
  - Breakdown by category
  - Critical flag
  - Limit-reached flag
- This summary is included in the pipeline result hash and displayed to the
  operator.

## Determinism and Reproducibility

### Content-Addressed Output

- Symbol IDs are deterministic — they are SHA-256 hashes of symbol content
  (FQN, kind, parameters). The same codebase analyzed twice produces identical
  symbol IDs.
- The `Normalizer::DeterministicFormatter` ensures stable ordering in output:
  symbols are sorted by symbol ID, guaranteeing identical output for identical
  input.

### Reproducibility

- The pipeline is deterministic: same inputs produce identical output
  (verified by SHA-256 symbol IDs and sorted emission).
- Parallel processing (`Configuration#parallel`) may change processing order
  but must not change output content. Symbols are sorted during normalization,
  neutralizing ordering differences.
- Symbol ID generation is pure — no randomness, no timestamps, no sequence
  numbers.

## Pipeline Completeness

### Stage Verification

Each pipeline stage records its execution status:

- **Extraction**: Number of files processed, number of files skipped, number
  of parse errors.
- **Indexing**: Number of symbols indexed, number of graph edges, circular
  dependencies detected.
- **Normalization**: Schema version, normalizer version, deduplication count.
- **Enrichment**: Stages executed (metrics, analysis, Rails, scoring, issue
  identification).
- **Emission**: Output format, output directory, files generated.

### Hard Gates

- The output directory must be writable before the pipeline starts. If the
  directory cannot be created, the pipeline raises `ConfigurationError` and
  aborts — this is a hard gate, not a warning.
- The format must be `:llm`. Any other format raises `ConfigurationError`
  and aborts.
- Individual file failures (parse errors, extraction failures) do not abort
  the pipeline. They are recorded in the `ErrorCollector` and the pipeline
  continues.

## State Recovery

### Error Resilience

- The pipeline does not checkpoint intermediate state. It is designed to run
  to completion in a single invocation.
- On extraction failure for an individual file, the pipeline continues with
  the next file. The failed file is recorded in the `ErrorCollector`.
- On stage-level failure (indexing, normalization, enrichment exceptions),
  the pipeline returns degraded results rather than crashing — it passes
  original or partial data to the next stage.

### Retry Handling

- `RetryHandler` retries transient I/O failures up to `max_retries` times
  (default: 3) with exponential backoff.
- Retried operations get fresh attempts — no stale state carried over from
  failed attempts.
- After exhausting retries, the error is recorded and the pipeline continues
  to the next file.

## Evidence Preservation

- Error records (`ErrorCollector#to_h`, `ErrorCollector#to_json`) are
  preserved in the pipeline result for post-hoc analysis.
- The pipeline result hash includes `error_summary` and optionally `errors`
  (when `verbose` is enabled).
- Generated documentation files persist in the output directory beyond the
  run for consumption by other tools and agents.

## Data Classification

- **Source code**: The project's own code. Analyzed but never executed
  (static analysis only). Included in output only when
  `output.include_source` is enabled.
- **Configuration data**: Project settings from `.rubymap.yml` and
  environment variables. Environment variables containing secrets are NOT
  included in output (redacted).
- **Analysis metadata**: Extracted symbols, metrics, graphs. These are the
  primary output — designed for sharing and review.
- **Error records**: Pipeline errors and warnings. May include file paths
  but never include source code or secrets.
