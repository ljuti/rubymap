---
name: pipeline-data-flow-fix
type: feature
priority: 1
---

## Problem

The Rubymap pipeline drops data between stages. After Phase 1 (extractor enhancement), the `Extractor::Result` carries rich data — method `calls_made`, control flow metrics, Rails DSL patterns, mixins, attributes, dependencies, class variables, and aliases. But the pipeline's data flow does not forward this data to downstream stages.

Three specific gaps:

1. **`ResultAdapter` only outputs four keys** (`classes`, `modules`, `methods`, `constants`). After Phase 1, `Result` also carries `mixins`, `attributes`, `dependencies`, `patterns`, `class_variables`, and `aliases` — all dropped. Method-level fields added in Phase 1 (`calls_made`, `branches`, `loops`, `conditionals`, `body_lines`) are also absent from `ResultAdapter#method_hash`.

2. **`InputAdapter` only processes five symbol types** (`classes`, `modules`, `methods`, `method_calls`, `mixins`) and hardcodes `method_calls: []` with the comment "Extractor doesn't provide method_calls." After Phase 1, methods carry `calls_made` arrays — but nothing converts them to the flat `method_calls` format the normalizer expects. And the new data types (`attributes`, `dependencies`, `patterns`, `class_variables`, `aliases`) are never passed through to the normalizer.

3. **No mechanism attaches non-core data to normalized classes/modules.** The normalizer pipeline has `ProcessSymbolsStep` (classes, modules, methods, method_calls) and a separate mixin pass, but no step that attaches patterns, attributes, class variables, or aliases to their parent class/module. These data types arrive in the normalizer input but have no path to the `NormalizedResult`.

The consequence is that all data produced by Phase 1 is lost before it reaches the enricher. The Rails enrichers still receive empty data. The call graph is still empty. Metrics are still unpopulated.

## Desired Outcome

After this spec lands, a full pipeline run (extract → normalize → enrich → emit) carries all data from the extractor through to the emitter. Specifically:

1. **`ResultAdapter` emits all data types**: `classes`, `modules`, `methods`, `constants`, `mixins`, `attributes`, `dependencies`, `patterns`, `class_variables`, `aliases`, and `method_calls` (derived from methods' `calls_made`).
2. **Method hashes include Phase 1 fields**: `calls_made`, `branches`, `loops`, `conditionals`, `body_lines`.
3. **`InputAdapter` derives `method_calls`** from methods' `calls_made` arrays, producing a flat list keyed by `:method_calls` for the normalizer. The derivation is in the adapter, not duplicated elsewhere.
4. **A new normalizer step (`AttachMetadataStep`)** attaches patterns, attributes, class variables, and aliases to already-normalized classes/modules by name lookup. It runs between `ProcessSymbolsStep` and `ResolveRelationshipsStep`.
5. **Pipeline `enrich` method** forwards patterns, attributes, class variables, aliases, and method_calls to the emitter hash alongside existing classes/modules/methods.
6. **No regression**: existing normalizer, enricher, indexer, and emitter behavior is unchanged. All existing tests pass.

## Context

### Existing codebase locations

- `lib/rubymap/result_adapter.rb`
  - Converts `Extractor::Result` → pipeline hash. Currently returns `{classes:, modules:, methods:, constants:}`. Each entity type has a dedicated private method (`class_hash`, `module_hash`, `method_hash`, `constant_hash`). Needs six new entity methods and five new keys in the return hash.
- `lib/rubymap/pipeline.rb`
  - `merge_result!` (line 376) uses `ResultAdapter.adapt(result)` and concatenates the four known keys. After ResultAdapter is extended, this method works without modification — `target` hash needs the new keys initialized in `extract()` so `concat` has arrays to concatenate into.
  - `extract()` (line 137) initializes `all_data` with `{classes: [], modules: [], methods: [], constants: [], metadata: {...}}`. Needs the new keys added to the initial hash.
  - `enrich()` (line 291) converts `EnrichmentResult` to emitter hash. Currently maps `classes`, `modules`, `methods`, `metadata`. Needs to forward `patterns`, `attributes`, `class_variables`, `aliases`, and `method_calls`.
  - `extract_result_to_cache()` (line 217) builds a temp hash for caching. Same pattern as `extract()` — needs new keys.
  - `merge_cached_result!()` (line 223) concatenates cached data. Needs new keys.
- `lib/rubymap/normalizer/input_adapter.rb`
  - Adapts pipeline hash → normalizer input. `SYMBOL_TYPES` currently `[:classes, :modules, :methods, :method_calls, :mixins]`. After Phase 1, `method_calls` won't come as a top-level key — it must be derived. Needs new keys added to `SYMBOL_TYPES`, a `derive_method_calls` method, and removal of the `method_calls: []` hardcode in `normalize_extractor_result`.
- `lib/rubymap/normalizer/processing_pipeline.rb`
  - `ProcessingPipeline#build_default_steps` (line ~62) returns 5 steps. A new `AttachMetadataStep` must be inserted at index 2 (between `ProcessSymbolsStep` and `ResolveRelationshipsStep`). The new step iterates non-core data from `context.extracted_data` and attaches each type to the normalized result by name lookup.
- `lib/rubymap/normalizer/processors/class_processor.rb`
  - `ClassProcessor#post_process_item` currently handles mixins. Not modified in this spec — mixin handling stays in ClassProcessor. The new `AttachMetadataStep` handles patterns, attributes, class_variables, and aliases separately.
- `lib/rubymap/normalizer.rb`
  - `NormalizedClass` struct already has fields: `mixins`, `dependencies`, `attributes` (via Rails fields). `NormalizedMethod` struct has: `branches`, `loops`, `conditionals`, `body_lines` (already defined, currently unpopulated). The structs may need minor additions — verify during implementation.
- `lib/rubymap/enricher/converters/class_converter.rb`
  - `ClassConverter#convert_single` already delegates to `NormalizedClassBuilder` which has `apply_analysis_fields` and `apply_rails_fields` methods. These already handle extended fields. Should work without modification — verify.

### Shaping reference

- **Decision 1 (calls_made → method_calls)**: InputAdapter derives. The adapter's `adapt` method gains a private `derive_method_calls(methods)` that iterates all methods, extracts their `calls_made` arrays, and produces a flat `method_calls` array with entries like `{from: "OwnerClass#method_name", to: "ReceiverClass#called_method", type: "method_call"}`. This avoids duplicating calls_made in two places (methods AND a flat array).
- **Decision 2 (non-core data attachment)**: New `AttachMetadataStep` in the normalizer pipeline. Inserted at position 2 (between ProcessSymbols and ResolveRelationships). One step class with private methods per data type (`attach_patterns`, `attach_attributes`, `attach_class_variables`, `attach_aliases`). Each method looks up the target class/module in `result.classes`/`result.modules` by name and attaches the data. This keeps the ClassProcessor focused on core normalization.

## Acceptance Criteria

- [ ] AC#1: Given an `Extractor::Result` with classes containing `dependencies`, `mixins`, and Phase 1 `calls_made`/`branches`/`loops`/`conditionals`/`body_lines` on methods, when `ResultAdapter.adapt(result)` is called, then the returned hash contains keys `:classes`, `:modules`, `:methods`, `:constants`, `:mixins`, `:attributes`, `:dependencies`, `:patterns`, `:class_variables`, `:aliases`, and `:method_calls`, and method hashes include `calls_made`, `branches`, `loops`, `conditionals`, and `body_lines`.
- [ ] AC#2: Given a pipeline hash with methods containing `calls_made` arrays, when `InputAdapter#adapt` is called, then the output contains a `:method_calls` key with a flat array derived from all methods' `calls_made`, and the `method_calls: []` hardcode is removed from `normalize_extractor_result`.
- [ ] AC#3: Given a pipeline hash with `:patterns` (Rails DSL entries), `:attributes`, `:class_variables`, and `:aliases`, when the normalizer runs, then a new `AttachMetadataStep` attaches each data type to the correct `NormalizedClass`/`NormalizedModule` by name lookup in `NormalizedResult`.
- [ ] AC#4: Given `Pipeline#run` completes successfully after Phase 1 has landed, when `enrich()` is called, then the emitter hash includes `:patterns`, `:attributes`, `:class_variables`, `:aliases`, and `:method_calls` keys alongside existing `:classes`, `:modules`, `:methods`, and `:metadata`.
- [ ] AC#5: Given `bundle exec rspec spec/normalizer/ spec/enricher/ spec/indexer/`, when run, then all existing tests pass with no behavioral changes.
- [ ] AC#6: Given an end-to-end pipeline run on a Ruby file with calls inside methods and Rails DSL at class body level, when the enriched output is inspected, then `method_calls` is non-empty, `patterns` contains Rails DSL entries, and method hashes include `calls_made` with Phase 1 fields.

## Technical Direction

Extend `ResultAdapter` to return all data types from `Extractor::Result`. Add private methods: `attributes_hash`, `dependency_hash`, `pattern_hash`, `class_variable_hash`, `alias_hash`, `mixin_hash`. Each follows the same pattern as existing `class_hash` — map known fields, use `@result.file_path` for file, use `location_line` for line. [AC#1]

In `ResultAdapter#method_hash`, add `calls_made`, `branches`, `loops`, `conditionals`, and `body_lines` to the returned hash. These are direct field mappings from `MethodInfo`. [AC#1]

In `InputAdapter`, add a private `derive_method_calls(methods)` method. It iterates the `methods` array from the pipeline hash. For each method with a non-empty `calls_made`, it produces `method_call` entries: `{from: "#{method[:owner]}##{method[:name]}", to: build_to(call), type: "method_call"}`. The `build_to` helper constructs the target string from `call[:receiver]` chain and `call[:method]` — e.g., receiver `["Rails", "logger"]` + method `"info"` → `"Rails.logger.info"`. [AC#2]

Extend `InputAdapter#SYMBOL_TYPES` to include `:attributes`, `:dependencies`, `:patterns`, `:class_variables`, `:aliases` alongside the existing five. [AC#2]

Remove the `method_calls: []` hardcode from `InputAdapter#normalize_extractor_result` — it's no longer needed since `derive_method_calls` handles this from the pipeline hash. [AC#2]

Create a new `AttachMetadataStep` class inside `lib/rubymap/normalizer/processing_pipeline.rb` (alongside existing step classes). It follows the same `PipelineStep` interface: `def call(context)`. Inside `call`, read `context.extracted_data` for patterns, attributes, class_variables, aliases. For each data type, call a private attachment method that looks up the target class/module in `context.result.classes`/`context.result.modules` by name and attaches the data to the struct. [AC#3]

Insert `AttachMetadataStep.new` at index 2 in `build_default_steps` (after ProcessSymbols, before ResolveRelationships). [AC#3]

In `Pipeline#extract()`, add `mixins: [], attributes: [], dependencies: [], patterns: [], class_variables: [], aliases: [], method_calls: []` to the `all_data` initialization hash. Same for `extract_result_to_cache`. [AC#4]

In `Pipeline#enrich()`, add `patterns: enrichment_result.patterns`, `attributes: enrichment_result.attributes`, `class_variables: enrichment_result.class_variables`, and `aliases: enrichment_result.aliases` to the returned hash (with safe fallbacks to `[]` if enrichment_result doesn't respond to those methods). Also forward `method_calls` if available. [AC#4]

Do not modify `ClassProcessor`, `ModuleProcessor`, or `MethodProcessor` — these continue to handle core normalization. The new step is additive. [AC#5]

Do not create new files for the step — define it inside `processing_pipeline.rb` following the existing pattern of `ExtractSymbolsStep`, `ProcessSymbolsStep`, etc. This keeps the normalizer pipeline self-contained. (guidance)

Prefer `respond_to?` checks when reading data from `EnrichmentResult` in `Pipeline#enrich()` so that future additions to EnrichmentResult don't break the pipeline. (guidance)

## Domain Rules

- `method_calls` derivation must produce one flat entry per call, not per method. A method with 3 calls produces 3 `method_call` entries.
- The `from` field on derived method_calls uses the owning class and method name: `"#{owner}##{method_name}"` for instance methods, `"#{owner}.#{method_name}"` for class methods.
- The `to` field on derived method_calls reconstructs the call target from the receiver chain: `receiver.join(".") + ".#{method}"` when receiver is present, or just the method name when receiver is nil (self-call).
- `AttachMetadataStep` operates on already-normalized classes/modules. It does not create new NormalizedClass/NormalizedModule objects — it only enriches existing ones by name.
- Pattern data with a nil `target` or a target that doesn't match any normalized class/module is silently skipped (logged at debug level if verbose).
- The `InputAdapter` continues to accept both Hash and `ExtractorResult` inputs. The `derive_method_calls` method is only called when methods data is present (hash path — `normalize_hash`).
- Existing `ResultAdapter` methods (`class_hash`, `module_hash`, `method_hash`, `constant_hash`) must not change their return structure — new fields are additive.

## Edge Cases & Failure Modes

- Pipeline hash has empty arrays for all new keys (no data extracted): `ResultAdapter` and `InputAdapter` produce empty arrays. No error. Normalizer steps receive empty data and are no-ops.
- Method has nil/empty `calls_made` array: `derive_method_calls` skips the method. No entry produced.
- Method has `calls_made` with nil receiver (self-call like `save`): `build_to` produces just the method name (e.g., `"save"`) without a leading dot.
- Pattern has `target: nil` or target class name that doesn't match any normalized class: `attach_patterns` silently skips. No error raised.
- `EnrichmentResult` doesn't respond to `patterns` or `attributes`: `Pipeline#enrich` uses `respond_to?` checks and falls back to `[]`.
- Cache system stores pipeline hash with new keys: `extract_result_to_cache` already calls `merge_result!` which uses `ResultAdapter` — the adapted hash includes new keys automatically. Cache round-trip works.
- Normalizer pipeline is customized with `with_steps`: if user code replaces the default steps, `AttachMetadataStep` is not automatically included (user is responsible for their custom pipeline). Default pipeline always includes it.
- Input is a `NormalizedResult` object (not a hash) passed directly to the normalizer: `InputAdapter` handles this via `ExtractorResult` duck typing — verify the path doesn't break with new data types.

## Examples

### Example 1: Full data flow from extractor to emitter

- Setup: Ruby file `app/models/user.rb` contains `class User < ApplicationRecord; has_many :posts; def save; log("saving"); super; end; end`. Phase 1 is landed.
- Action: `Rubymap.map("app/models/user.rb")` runs through all pipeline stages.
- Result: The enriched output hash contains `method_calls` with entries for `log` and `super` inside `save`. `patterns` contains a Rails DSL entry for `has_many :posts`. Method hash for `save` includes `calls_made` with two entries, `branches: 0`, `loops: 0`, `conditionals: 0`.

### Example 2: InputAdapter derives method_calls from calls_made

- Setup: Pipeline hash with `methods: [{owner: "User", name: "save", scope: "instance", calls_made: [{receiver: nil, method: "log", arguments: [{type: :string, value: "saving"}], has_block: false}]}]`
- Action: `InputAdapter.new.adapt(hash)`
- Result: Output `[:method_calls]` contains `[{from: "User#save", to: "log", type: "method_call"}]`. Output `[:methods]` still contains the original method data with `calls_made` intact.

### Example 3: AttachMetadataStep enriches normalized classes

- Setup: NormalizedResult has a `NormalizedClass` with `name: "User"`. `context.extracted_data[:patterns]` contains `[{type: "rails_dsl", method: "has_many", target: "User", arguments: [{type: :symbol, value: "posts"}]}]`.
- Action: `AttachMetadataStep#call(context)`
- Result: The `User` NormalizedClass now has `patterns` field (or equivalent) containing the `has_many` entry.

### Example 4: Pipeline#enrich forwards new data

- Setup: `EnrichmentResult` has `patterns` responding to an array of `PatternInfo` objects and `class_variables` responding to an array of `ClassVariableInfo` objects.
- Action: `pipeline.send(:enrich, normalized_result)`
- Result: Returned hash includes `patterns: [...]` and `class_variables: [...]` alongside `classes`, `modules`, `methods`, `metadata`. The emitter can now use this data.

## Boundaries

- In scope: `ResultAdapter` extension (all new keys, Phase 1 fields on methods), `InputAdapter` extension (new symbol types, `derive_method_calls`), `AttachMetadataStep` (new normalizer step), `Pipeline` initialization and enrichment changes, `extract_result_to_cache` and `merge_cached_result!` updates.
- Out of scope: Emitter format changes (Phase 3), enricher logic changes (Phase 5 — enrichers will receive data but their logic is not modified), indexer graph changes, normalizer processor logic changes (ClassProcessor mixin handling untouched), normalizer struct field additions (verify existing fields are sufficient; only add fields if absolutely required).
- Do not modify: `ClassProcessor`, `ModuleProcessor`, `MethodProcessor`, `MethodCallProcessor`, `MixinProcessor` — these continue to handle their current responsibilities unchanged. `ResolverFactory` and resolver classes. `Deduplicator` and `MergeStrategy`. `Enricher` module internals (only Pipeline#enrich changes — the Enricher class itself is untouched). `Emitter` module.
