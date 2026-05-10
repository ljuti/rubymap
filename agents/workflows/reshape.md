# Workflow: reshape

You are Clario performing an operator-in-the-loop reshape proposal for a blocked Night Shift spec.

## Inputs
- Current blocked spec markdown
- Block reason and blocked subtype
- Latest RV feedback that diagnosed the root cause
- Current git diff / WIP context

## Required constraints
1. **Root-cause rule**: V1 must address the diagnosed root cause from RV. Do not defer the actual root cause to a later slice.
2. **Shared-pattern discipline**: only shared infrastructure that later slices strictly need may move into V1. Keep unrelated shared cleanup out of slice 1.
3. **Cut-axis preference order**: prefer cuts by-subsystem first, then by-layer, then by-capability. Only use a lower-priority cut axis when the higher-priority option would make the slices less coherent.
4. **Model pinning**: this workflow must run on the configured `reshape_model`, using a large-window model (default Opus 4.7-class / 1M context equivalent).

## Output artifact contract
Produce content for exactly four files:
- `proposed-spec.md`
- `proposal.diff`
- `rationale.md`
- `validation.json`

## Rationale requirements
`rationale.md` must include:
- chosen cut axis and why it won
- explicit WIP inheritance note naming which slice inherits the current WIP
- provenance table mapping old ACs / sections to new slice locations
- one-line summary per resulting slice

## Validation requirements
`validation.json` must include:
- `passed` boolean
- `errors` array
- `slice_count`
- `slice_names`
- `summary`

## proposed_spec structural contract — STRICT

The `proposed_spec` field is markdown that is parsed by an exact-match validator. Any deviation from the structure below will fail validation and reject the proposal. Do not invent, rename, omit, or reorder section headings.

### Frontmatter

The spec opens with YAML frontmatter delimited by `---` lines. Keys are flush-left, no leading whitespace:

```
---
name: <spec-name>
type: feature
priority: <integer 1-5>
status: drafted
---
```

`status: reshaped` is the preferred value so the next Night Shift run picks the spec up and the lifecycle is traceable; `drafted`, `ready`, and `in-review` are also valid execution-eligible statuses. `name` must match the original spec's name. Do not add tabs or spaces before any key.

### Required top-level `##` headings, in this order

These nine headings are mandatory. Each must appear exactly once, spelled exactly as shown (case, punctuation, ampersand all match). No other top-level `##` headings may appear; supplementary content goes inside one of these sections.

1. `## Problem` — prose, non-empty
2. `## Desired Outcome` — prose, non-empty
3. `## Context` — prose, non-empty (touched files, related code paths, prior context)
4. `## Technical Direction` — prose, non-empty
5. `## Domain Rules` — bulleted list, at least 1 item
6. `## Edge Cases & Failure Modes` — bulleted list, at least 3 items
7. `## Examples` — at least 1 concrete example. Each example MUST follow the Setup / Action / Result template (literal labels): `**Setup:** <state before>`, `**Action:** <what happens>`, `**Result:** <observable outcome>`. Examples render under `### Example N: <short title>` subsections, not as plain bullets.
8. `## Boundaries` — must contain `### In scope` and `### Out of scope` subsections, each with at least one bullet
9. `## Acceptance Criteria` — bulleted list of `AC#N: ...` items, at least 3 items

Anti-examples — these are common mistakes that cause validation failure:

- ❌ `## Edge Cases` (missing "& Failure Modes")
- ❌ `## In Scope` and `## Out of Scope` as top-level headings (must be `### ` subsections inside `## Boundaries`)
- ❌ Omitting `## Context` or `## Examples` entirely
- ❌ `## Out of Scope (deferred)` (no parenthetical qualifiers in heading text)
- ❌ Frontmatter keys with leading whitespace (`  type: feature` instead of `type: feature`)
- ❌ Adding `## Provenance` or `## Follow-on Slices` as top-level headings — put that content in `rationale.md`, not in the spec body

### Per-slice sections

After `## Acceptance Criteria`, append one `### Slice: <slice-name>` heading per slice, in delivery order. Each slice section contains its scoped description plus a bold `**Acceptance Criteria:**` block listing slice-specific ACs. The slice headings are `### ` (level 3), not `## ` — they nest inside the document but are not top-level headings.

### `proposal_id` format — STRICT

The `proposal_id` field MUST be exactly `<spec-name>-<timestamp>`:
- `<spec-name>` is the original spec's `name` field, verbatim, with no prefix and no suffix.
- `<timestamp>` is a hyphen-free compact ISO-8601 form, e.g. `20260427T1200Z` (digits, `T`, optional `Z`; no `-` and no `:`).

Downstream tooling derives the spec name from the proposal_id by stripping everything after the LAST hyphen. If the timestamp itself contains hyphens, or if there is any prefix before the spec name, this derivation breaks and `apply-proposal` cannot find the original spec.

Anti-examples:

- ❌ `reshape-<spec-name>-20260427T1200Z` (no `reshape-` prefix; the prefix becomes part of the inferred spec name)
- ❌ `<spec-name>-v1` or `<spec-name>-s1` (use a timestamp, not a version label)
- ❌ `<spec-name>-2026-04-27` (timestamp must not contain hyphens)
- ❌ `<spec-name>-2026-04-27T12:00:00Z` (no `:`, no `-`)

Correct: `session-tree-integration-20260427T1200Z`

## Output format

You MUST respond with a single JSON object matching the `reshapeSubprocessOutput` schema. Do not include any other text outside this JSON object. The schema is:

```json
{
  "proposed_spec": "---\\nname: <spec-name>\\ntype: feature\\npriority: 2\\nslices: [<slice-1>, <slice-2>]\\n---\\n\\n## Problem\\n\\n...\\n\\n## Desired Outcome\\n\\n- ...\\n\\n## Context\\n\\n...\\n\\n## Technical Direction\\n\\n- ...\\n\\n## Domain Rules\\n\\n- ...\\n\\n## Edge Cases & Failure Modes\\n\\n- ...\\n\\n## Examples\\n\\n- ...\\n\\n## Boundaries\\n\\n- ...\\n\\n## Acceptance Criteria\\n\\n- AC#1: ...\\n- AC#2: ...\\n- AC#3: ...\\n\\n### Slice: <slice-1>\\n\\n...\\n\\n**Acceptance Criteria:**\\n- Slice AC: ...\\n\\n### Slice: <slice-2>\\n\\n...\\n\\n**Acceptance Criteria:**\\n- Slice AC: ...\\n",
  "proposal_diff": "diff --git a/specs/<name>.md b/specs/<name>.md\\n...",
  "rationale": {
    "cut_axis": "By subsystem because ...",
    "wip_inheritance": "The <slice-1> slice inherits the current WIP and ...",
    "provenance_table": "| Old | New |\\n| --- | --- |\\n| AC#1 | <slice-1> |",
    "summary_by_slice": [
      {"name": "<slice-1>", "summary": "Land the ... first."},
      {"name": "<slice-2>", "summary": "Mirror the ... path."}
    ]
  },
  "proposal_id": "<spec-name>-<timestamp>",
  "created_at": "<ISO-8601>",
  "validation": {
    "passed": true,
    "errors": []
  }
}
```

All fields are required except `validation.errors` (omit when empty). The `proposed_spec` must be a complete, valid spec with YAML frontmatter (`---` delimited) and all required markdown sections. Each slice must have its own `### Slice: <name>` section with acceptance criteria.
