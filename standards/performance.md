# Performance Standards

These standards govern concurrency, resource management, and performance
characteristics. They apply during Review (RV) and Verify (VR) phases.

## Concurrency

Rubymap is primarily single-threaded with optional parallel file processing in
the Extractor stage.

### Parallel Processing Discipline

- The `Configuration#parallel` flag controls whether files are processed
  concurrently. When enabled, use Ruby's thread-based parallelism for I/O-bound
  file reading and parsing.
- Every parallel worker must have a clear completion path. Use `Thread#join` to
  await completion; never leave threads detached.
- Shared state between parallel workers must use `Mutex` for synchronization.
  The `ErrorCollector` is shared across workers — use `Mutex#synchronize` for
  all error collection operations in parallel mode.

```ruby
# Parallel file processing pattern
mutex = Mutex.new
threads = files.map do |file|
  Thread.new do
    result = process_file(file)
    mutex.synchronize { collector.merge!(result) }
  end
end
threads.each(&:join)
```

- Prefer `Mutex` over other synchronization primitives. Do not use
  `ThreadGroup` or low-level `ConditionVariable` unless benchmarked.

## Resource Management

### File Processing

- Stream large files rather than reading them entirely into memory.
  `File.read` is acceptable for Ruby source files (typically < 1MB, enforced
  by `max_file_size` configuration). For any file exceeding the configured
  max, skip with a warning rather than attempting to read it.
- The `Configuration#static.max_file_size` (default: 1,000,000 bytes) caps
  the size of individual files processed. Respect this limit.
- Close file handles explicitly or use block forms (`File.open { }`) that
  auto-close. Do not rely on garbage collection for file handle cleanup.

### Cache Management

- The cache directory (`Configuration#cache.directory`, default:
  `.rubymap_cache`) stores intermediate results. Respect the TTL
  (`Configuration#cache.ttl`, default: 86400 seconds / 24 hours).
- Cache entries older than TTL must be invalidated and regenerated. Do not
  serve stale cache.
- Cache keys are derived from file content hashes. When a file changes, its
  cache entry is automatically invalidated.

### Retry and Backoff

- Use `RetryHandler` with exponential backoff for transient failures (file I/O,
  resource contention). The default configuration: 3 retries, 0.1s base delay,
  5.0s max delay, 2.0x exponential base.
- Do not retry parse errors, configuration errors, or validation failures.
  Only retry errors matching `RetryHandler::DEFAULT_RETRYABLE_ERRORS`
  (`Errno::EAGAIN`, `Errno::ETIMEDOUT`, `Errno::ECONNRESET`, `Errno::EBUSY`,
  `Timeout::Error`, `IOError`).
- Each retry logs an info-level entry to the `ErrorCollector` for
  observability.

### Rate Limiting

- Rubymap does not make external API calls during normal operation. No rate
  limiting is required.

## Memory Management

- Prefer streaming over buffering when processing large codebases. The
  pipeline processes files individually rather than loading all files into
  memory simultaneously.
- Defensive copies of mutable structures returned from shared caches:

```ruby
# Return a copy, not the internal state
def all_names
  @index.keys.dup
end
```

- The `SymbolIndex` uses O(1) hash-based lookup. Do not introduce O(n) linear
  scans over the full symbol set in query paths.
- Avoid unbounded growth of in-memory collections. The `ErrorCollector`
  respects `max_errors` to cap error storage.

## Timeouts

- The `RetryHandler` calculates delays with exponential backoff capped at
  `max_delay` (default: 5.0s). Do not introduce unbounded waits.
- CLI operations use `TTY::Spinner` for progress indication with no timeout —
  the spinner runs until pipeline completion or user interrupt.
- Configuration provides `runtime.timeout` (default: 30s) for runtime analysis
  mode. When runtime analysis is enabled, respect this timeout.

## Startup and Initialization

- Configuration is loaded lazily. `Rubymap.configuration` creates the default
  `Configuration` on first access.
- Validate configuration eagerly at pipeline start (`Configuration#validate!`).
  Fail fast on invalid configuration rather than failing mid-pipeline.
- External dependencies (Prism parser, TTY components) are loaded at require
  time via `lib/rubymap.rb`. Do not defer loading of core dependencies.

## Performance-Sensitive Paths

- **Extraction**: File I/O and Prism parsing dominate. Use parallel processing
  (`Configuration#parallel`) for large codebases.
- **Indexing**: Symbol index builds use hash insertions (O(1) amortized).
  Maintain this complexity — do not introduce sorts or scans during index
  construction.
- **Normalization**: Deduplication and namespace resolution iterate over all
  symbols. Keep these operations O(n) per symbol category.
- **Emission**: Template rendering is I/O-bound. Use buffered writes for large
  output files.

## Benchmarking

- When optimizing pipeline stages, benchmark with a representative codebase
  (the project's own `lib/` directory is the canonical benchmark target).
- Use Ruby's `Benchmark` module for micro-benchmarks. Do not add benchmarking
  gems.
- Profile with `ruby-prof` or `stackprof` before optimizing. Do not optimize
  without profiling data.
