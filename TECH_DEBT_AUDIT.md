# Tech Debt Audit — Rubymap

Generated: 2026-05-09 | Updated: 2026-05-09 (12 findings resolved)

## Executive Summary

- **3 Critical, 9 High, 10 Medium, 10 Low** findings originally
- **12 resolved, 2 amended (false positives), 18 remaining**
- **Largest debt concentration**: `lib/rubymap/emitter/emitters/llm_emitter.rb` (1079-line god file — F001 still open)
- **130 pending tests** — roughly 7% of the test suite is skipped
- **5 pre-existing test failures** — all environment-dependent (memory/permission/`ps`-dependent tests)

## Findings Status

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| F001 | Critical | **OPEN** | 1079-line LLM emitter god file with 48 methods |
| F002 | Critical | **OPEN** | 9 TODO-gated untested behaviors in llm_emitter_spec.rb |
| F003 | Critical | ✅ RESOLVED | Dead JSON/YAML formatters deleted |
| F004 | High | ✅ RESOLVED | Format restriction centralized to `Emitter::SUPPORTED_FORMATS` |
| F005 | High | ✅ RESOLVED | README updated to match actual capabilities |
| F006 | High | ✅ RESOLVED | Dead multi-format emission code removed from EmitterManager |
| F007 | High | ✅ RESOLVED | Output dir config consolidated to single `output_dir` |
| F008 | High | ✅ RESOLVED | Runtime/cache config annotated as experimental |
| F009 | High | **OPEN** | 130 pending tests (including 202 in namespace_service_spec.rb) |
| F010 | High | ✅ RESOLVED | `define_method` monkey-patching replaced with `on_step` observer callback |
| F011 | High | **OPEN** | LLM emitter uses hash access instead of typed DTOs |
| F012 | High | **OPEN** | Pipeline execution order contradicts documentation |
| F013 | Medium | **OPEN** | No pipeline result caching |
| F014 | Medium | ✅ RESOLVED | Duplicate type coercion removed from Configuration |
| F015 | Medium | ✅ RESOLVED | `system()` call removed during EmitterManager cleanup (F006) |
| F016 | Medium | **OPEN** | Dead template system (infrastructure exists, `use_templates?` always false) |
| F017 | Medium | **OPEN** | Inconsistent error recovery strategies across pipeline stages |
| F018 | Medium | **OPEN** | `concurrent-ruby` not in gemspec, used as optional require |
| F019 | Medium | **OPEN** | 5 pre-existing failing tests (environment-dependent) |
| F020 | Medium | **OPEN** | `namespace_service_spec.rb` has 202 pending tests, 0 actual |
| F021 | Medium | ⚠️ AMENDED | `SCHEMA_VERSION`/`NORMALIZER_VERSION` constants ARE used by ProcessingPipeline |
| F022 | Medium | ⚠️ AMENDED | `RetryHandler` is functional — used for file I/O retry in Pipeline extraction. Not dead code. |
| F023 | Low | **OPEN** | Pipeline doesn't use Extractor's parallel processing |
| F024 | Low | ✅ RESOLVED | Standard.rb `ClassEqualityComparison` lint fixed |
| F025 | Low | ✅ RESOLVED | Standard.rb `SafeNavigation` lint fixed (×2) |
| F026 | Low | ✅ RESOLVED | Standard.rb empty lines/trailing newline lint fixed |
| F027 | Low | **OPEN** | README mutation coverage claim removed (F005) |
| F028 | Low | ✅ RESOLVED | Singleton class hack replaced with proper `Prism::ParseError` handling |
| F029 | Low | **OPEN** | TTY dependency naming inconsistency |
| F030 | Low | **OPEN** | Result→hash conversion in Pipeline has no type checking |
| F031 | Low | **OPEN** | QualityRulesEngine has unused `rules_path`/`load_rules` infrastructure |
| F032 | Low | ✅ RESOLVED | GraphViz manifest branch removed |

## Top 5 Remaining

1. **F001 — Decompose llm_emitter.rb** (Critical): Extract ChunkGenerator, MarkdownRenderer, ManifestBuilder, ProgressReporter from the 1079-line god file.
2. **F002 — Implement 9 TODO test cases** (Critical): `spec/emitters/llm_emitter_spec.rb` has 9 TODO markers for unimplemented tests.
3. **F009 — Address 130 pending tests** (High): Delete `namespace_service_spec.rb` (202 pending, 0 actual). Implement or delete remaining pending tests.
4. **F016 — Wire or remove template system** (Medium): ERB templates exist but `use_templates?` always returns false.
5. **F012 — Fix pipeline execution order** (High): Either fix order to match docs or update docs.

## Quick Wins for Next Session

- [ ] **F009**: Delete `spec/extractor/services/namespace_service_spec.rb` (5 minutes)
- [ ] **F018**: Remove `concurrent-ruby` optional require or add to gemspec (5 minutes)
- [ ] **F029**: Standardize TTY dependency names in gemspec (5 minutes)
- [ ] **F031**: Remove unused `rules_path`/`load_rules` from QualityRulesEngine (10 minutes)
- [ ] **F016**: Delete dead template system or wire `use_templates: true` (15 minutes)
- [ ] **F011**: Add typed DTO access between pipeline stages (1 hour)
- [ ] **F001**: Decompose llm_emitter.rb (2-3 hours)

## Open Questions (still open)

1. Is the DocumentationEmitter intended to be the primary emitter, or is it legacy?
2. What was the intention behind the template system?
3. Why is the pipeline execution order Extract → Index → Normalize → Enrich?
4. Are runtime introspection and cache features on the roadmap or abandoned?
5. Should `concurrent-ruby` be added to the gemspec?
