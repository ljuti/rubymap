---
params:
  module: "Module path being audited (e.g., internal/foo)"
  scope: "What the module is responsible for, drawn from the orient scratchpad"
---

<instructions>
Audit module {{module}} against the 9 tech-debt dimensions. This workflow is invoked by Blade via `nmux_delegate` during the TDA-A phase. The parent agent embeds this template into the delegation task; you (Holmes) execute it inside the delegated harness.
</instructions>

<process>
1. Read orient scratchpad from parent context.
2. Constrain scope to `{{module}}`. Cross-module references → open questions, not findings.
3. Walk all 9 dimensions in order: architectural decay, consistency rot, type & contract debt, test debt, dependency & config debt (module-owned only), performance & resource hygiene, error handling & observability, security hygiene, documentation drift. Prefer `make` targets; scope tools to module path.
4. Read before judging: patterns that look wrong but are load-bearing → `.nmux/tech-debt-audit/looks-bad-but-fine.md`.
5. Cite `file:line` on every finding.
6. Append findings to `.nmux/tech-debt-audit/findings.jsonl` with `source: child:{{module}}`. Use `H<NNN>` IDs.
7. Append open questions to `.nmux/tech-debt-audit/open-questions.md` prefixed `[{{module}}]`.
8. Append looks-bad-but-fine to `.nmux/tech-debt-audit/looks-bad-but-fine.md` prefixed `[{{module}}]`. Must have ≥1 entry (or explicit "none — every flagged pattern was real debt").
9. Cap: 200 findings max. Collapse near-duplicates if exceeded.
10. Return summary as delegate result:
    ```
    Module: {{module}}
    Findings: N (Critical: a, High: b, Medium: c, Low: d)
    Looks-bad-but-fine: K
    Open questions: M
    Notable: <1-2 sentence most consequential finding>
    ```
    No `nmux_signal` — delegated children return via delegate result. Final action is the summary.
</process>

<constraints>
- Stay in `{{module}}`. Cross-module → open questions.
- Cite `file:line` for every finding.
- Read-only except `.nmux/tech-debt-audit/`. No production code edits. No rewrite recommendations.
- `looks-bad-but-fine.md` must have ≥1 entry.
</constraints>
