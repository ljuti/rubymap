---
---

<instructions>
Read every artifact produced in Phases 1 and 2, deduplicate and rank findings, and write the operator-facing deliverable to `TECH_DEBT_AUDIT.md` in the repo root. The required sections are non-negotiable; the deliverable checklist enforces them.
</instructions>

<process>
1. **Read all scratchpad artifacts:**
   - `.nmux/tech-debt-audit/orient.md` — mental model, module map, audit-shape decision
   - `.nmux/tech-debt-audit/findings.jsonl` — every finding from Phase 2 (serial + delegated children)
   - `.nmux/tech-debt-audit/looks-bad-but-fine.md` — patterns the auditors considered flagging and chose not to
   - `.nmux/tech-debt-audit/open-questions.md` — calls the auditors couldn't make
   - Existing `TECH_DEBT_AUDIT.md` if this is a repeat run

2. **Deduplicate findings.** Two findings are duplicates when they describe the same defect at the same `file:line` (or within a 5-line window of the same file for the same category). Merge by keeping the more severe `severity`, the larger `effort` estimate, and the more specific `recommendation`. Track the merge in a brief comment on the surviving finding (`merged: H042, F019`).

3. **Renumber findings** with stable IDs of the form `F001`, `F002`, … in the final ranked order. Renumbering happens once, after dedup.

4. **Rank.** Sort findings by `severity` (Critical → High → Medium → Low) then by `effort` (S → M → L within each severity). The "Top 5" section in the deliverable draws from the top of this ranking.

5. **Repeat-run reconciliation.** If a prior `TECH_DEBT_AUDIT.md` exists, for each prior finding:
   - If still present in current findings → tag `STILL OPEN`
   - If no longer present → tag `RESOLVED` and keep it in an appendix table
   - If present but with different scope/severity → tag `UPDATED` and show the delta
   New findings (no prior counterpart) get `NEW`.

6. **Write `TECH_DEBT_AUDIT.md`** in repo root with these sections in order:

   ```
   # Tech Debt Audit — <repo>
   Generated: <YYYY-MM-DD>
   ## Executive summary
   <max 10 bullets, ranked by impact. Lead with severity counts.>
   ## Architectural mental model
   <1-2 paragraphs from orient.md. Surface README contradictions.>
   ## Findings
   | ID | Category | File:Line | Severity | Effort | Description | Recommendation |
   |----|----------|-----------|----------|--------|-------------|----------------|
   | F001 | ... | ... | Critical | L | ... | ... |
   ## Top 5 — if you fix nothing else, fix these
   <5 expanded entries with concrete diff sketches.>
   ## Quick wins
   <Low-effort × Medium+ findings, IDs as references. Or "no quick wins identified".>
   ## Things that look bad but are actually fine
   <From looks-bad-but-fine.md. MUST be non-empty.>
   ## Open questions for the maintainer
   <From open-questions.md. Or "no open questions — every call was clear".>
   ## Repeat-run delta
   <Only if prior audit existed: STILL OPEN / RESOLVED / UPDATED / NEW summary.>
   ```

7. **Verify required sections:** Executive summary ≤10 bullets. Findings table has ≥1 row per category with findings (categories with none: note "Nothing material" in summary). Top 5 has 5 entries (all if <5 total). Quick wins non-empty if any Low×Medium+ exist (else "no quick wins"). **Things that look bad but are fine is non-empty** — if empty, audit is shallow, return to Phase 2. Open questions has ≥1 entry or "no open questions" line. Every finding cites file:line.

8. **Clean up scratchpad:** Delete `.nmux/tech-debt-audit/findings.jsonl`, `looks-bad-but-fine.md`, `open-questions.md`, `orient.md`. Keep the directory.

9. **Update `nmux_tasks`** — mark the deliverable task `completed`.

10. Complete the phase checklist (if assigned), annotating each item and calling `nmux_checklist` with your results.

11. Call `nmux_signal` with type `"phase-complete"` and reason `"TECH_DEBT_AUDIT.md written at <repo-root>/TECH_DEBT_AUDIT.md — N findings (Critical: a, High: b, Medium: c, Low: d)"` — this MUST be your final action. Do not emit any assistant text after the tool call.
</process>

<constraints>
- The deliverable file path is `TECH_DEBT_AUDIT.md` in the repo root, not anywhere else.
- The "Things that look bad but are actually fine" section is required and non-empty. If Phase 2's `looks-bad-but-fine.md` is empty, treat that as a Phase 2 failure: signal `blocked` with `diagnostic.reason_kind: "shallow_audit"` and route back to TDA-A rather than ship a deliverable without that section.
- Do not invent findings during synthesis. The synthesizer dedupes, ranks, and writes — it does not audit. New observations become open questions, not findings.
- Do not recommend rewrites. The deliverable inherits Phase 2's "scoped changes only" discipline.
</constraints>
