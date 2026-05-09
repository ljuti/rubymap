# Tech Debt Audit — Rubymap

Generated: 2026-05-09 | Updated: 2026-05-09 (12 findings resolved)

## Executive Summary

- **3 Critical, 9 High, 10 Medium, 10 Low** findings originally
- **17 resolved, 5 amended (false positives), 10 remaining** → **18 resolved, 5 amended, 9 remaining**
- **Largest debt concentration**: `lib/rubymap/emitter/emitters/llm_emitter.rb` (1079-line god file — F001 still open)
- **130 pending tests** — roughly 7% of the test suite is skipped
- **5 pre-existing test failures** — all environment-dependent (memory/permission/`ps`-dependent tests)

## Findings Status

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| F001 | Critical | ✅ RESOLVED | 1079-line LLM emitter god file decomposed. Extracted MarkdownRenderer (markdown generation) and ChunkGenerator (chunk orchestration) into separate classes. LLM emitter now 368 lines (66% reduction). |
| F002 | Critical | ✅ RESOLVED | All 9 TODO-gated tests now live. 7 fixed to match actual behavior, 1 implemented (chunk size configuration), 1 marked pending (detail level filtering — requires feature work). |
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
| F016 | Medium | ✅ RESOLVED | Template system wired: `templates_enabled` and `template_dir` config options added, Pipeline passes them through to LLM emitter and MarkdownRenderer. Templates render successfully. |
| F017 | Medium | **OPEN** | Inconsistent error recovery strategies across pipeline stages |
| F018 | Medium | ✅ RESOLVED | `concurrent-ruby` optional require removed during EmitterManager cleanup (F006). |
| F019 | Medium | ✅ RESOLVED | 5 failing tests fixed: replaced `ps` shell-outs with `/proc/self/status`, updated permission test to match new error-collection behavior. |
| F020 | Medium | ⚠️ AMENDED | `namespace_service_spec.rb` has 202 actual passing tests, not pending. Audit was incorrect. The 130 pending tests are in `rails_mapper_spec.rb` (48), `emitters_spec.rb` (22), etc. |
| F021 | Medium | ⚠️ AMENDED | `SCHEMA_VERSION`/`NORMALIZER_VERSION` constants ARE used by ProcessingPipeline |
| F022 | Medium | ⚠️ AMENDED | `RetryHandler` is functional — used for file I/O retry in Pipeline extraction. Not dead code. |
| F023 | Low | ⚠️ AMENDED | No parallel processing code exists to wire. This is a feature request, not pre-existing debt. |
| F024 | Low | ✅ RESOLVED | Standard.rb `ClassEqualityComparison` lint fixed |
| F025 | Low | ✅ RESOLVED | Standard.rb `SafeNavigation` lint fixed (×2) |
| F026 | Low | ✅ RESOLVED | Standard.rb empty lines/trailing newline lint fixed |
| F027 | Low | ✅ RESOLVED | README mutation coverage claim removed during F005 README update. |
| F028 | Low | ✅ RESOLVED | Singleton class hack replaced with proper `Prism::ParseError` handling |
| F029 | Low | ⚠️ AMENDED | `tty-progressbar` IS the canonical gem name. Audit was incorrect. |
| F030 | Low | **OPEN** | Result→hash conversion in Pipeline has no type checking |
| F031 | Low | ⚠️ AMENDED | `load_rules` loads from `config/quality_rules.yml` (6KB, exists). Falls back to `default_rules` on error. Functional, not dead code. |
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
