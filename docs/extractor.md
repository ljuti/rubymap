Think of the Extractor as the “facts harvester.” Its only job is to walk source and (optionally) a sandboxed runtime, and emit raw, lossless, minimally-interpreted events about what it sees—fast, safely, and with rich provenance. Everything smarter (merging, precedence, scoring) happens later in the Normalizer/Enricher.

## Why an Extractor?

- Separation of concerns: keep “read & record” apart from “decide & merge.” This lets you optimize I/O and parsing without entangling policy.

- Performance envelope: a lean, streaming Extractor can hit your <1s / 1k files goal. Normalization can run concurrently or later.

- Repeatability: raw events are append-only and order-insensitive, perfect for golden tests and debugging (“what exactly did we see?”).

- Provenance: attach exact “where/when/how” to every fact so downstream can justify decisions.

## What the Extractor does (scope)

Core outputs (static):

- module_defined, class_defined (fqname, path, line, superclass?)

- method_defined (owner, name, receiver: instance|class, visibility, params w/ kinds, line)

- mixin_added (include|extend|prepend, into, mod, line)

- constant_assigned (name, fqname, value_kind: scalar|struct|unknown)

- require_edge (from file → required path)

- attr_macro (attr_reader|writer|accessor|cattr_*, generated names)

- alias_method / undef_method sightings

- comment_block (YARD doc raw text + anchor)

Optional outputs (plugins):

- YARD: doc tags (@param/@return/@raise), summary.

- RBS/Sorbet: type signatures for methods/consts from .rbs/.rbi.

- SCM: git churn/lightweight blame per file.

- Rails runtime (opt-in): models (columns/assocs), routes, controllers, jobs, mailers.

- Frameworks (opt-in): GraphQL schema, Sidekiq queue opts, ActionCable channels, etc.

What it explicitly does not do:
- No merging of reopenings, no precedence decisions, no confidence scoring. (That’s the Normalizer.)

## Design principles

- Streaming & bounded memory: emit NDJSON (one JSON per line) as you go; never accumulate the whole repo in RAM.

- Process-parallel by default: a worker pool over file paths; each worker parses & writes its own shard (to avoid lock contention).

- Lossless + minimal: capture exactly what you see; don’t paraphrase (e.g., store original param spellings, raw doc block).

- Deterministic emissions: stable field ordering, stable enums, normalized paths/encodings.

- Provenance-rich: every line has source, extractor, version, path, line, timestamps, and (for runtime) a session_id.