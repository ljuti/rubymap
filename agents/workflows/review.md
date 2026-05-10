---
---

<instructions>
Execute full code review workflow with trust-first priority. Enumerate findings across every trust tier before selecting blockers — drip reviews (one new cut per round) burn the route budget and must be avoided.
</instructions>

<process>
1. Read implementation from Spark
2. Read post-implementation explanation from story file
3. Execute trust-first review sequence across all five tiers. Every tier MUST be walked, not skipped:
   a. Test Quality — How much can we trust the test suite?
   b. Design Alignment — Is direction correct per Clario's design?
   c. Correctness — Does it work as intended?
   d. Security — Any vulnerabilities?
   e. Readability — Can others understand?
4. Before blockers, produce a **Findings Table**: every tier gets a row; name what was checked even if zero findings.

   | Tier | Findings (count + 1-line summary) | What was checked | Blocking? |
   |------|-----------------------------------|------------------|-----------|
   | Test Quality | ... | ... | yes/no |
   | Design Alignment | ... | ... | yes/no |
   | Correctness | ... | ... | yes/no |
   | Security | ... | ... | yes/no |
   | Readability | ... | ... | yes/no |

5. Class-sweep before any single cut: if a finding belongs to a known bug class (state lifecycle, error paths, concurrency, resource cleanup, spec-alignment, scope inflation), audit the rest of the diff for other instances of the same class and include them in the same row. One-instance cuts that leave related defects for the next round are a process failure.
6. For each finding in the table:
   - Write explanatory feedback ("this breaks because X")
   - Ask curious questions when approach is unclear
   - Provide concrete alternatives
7. When a review cut clearly maps to one of Spark's plan items, populate `relates_to` with that plan item ID
   - Example: a review cut correcting plan item `plan-007` should carry `relates_to: "plan-007"`
   - This link is advisory correlation only; use it when it helps Spark connect the cut to the plan
8. Self-check: Grade all comments for constructiveness AND confirm the findings table covers every tier. If any tier row is missing or says "didn't check", return to step 3.
9. Compile review (story file comments + code annotations)
10. Make routing decision based on the Blocking column:
    - Any row marked `yes` → Create review-cut work items for Spark (step 10a), then route to Spark
    - Non-blocking design concerns only → Consult Clario first
    - Zero blocking findings → Handoff to Hon
10a. **Create review-cut work items** (routing to Spark): For each blocking finding, call `nmux_work_items create` with items array. Each: `envelope_type: review-cut`, `to_phase: IM`, `anchor: {file, line}`, `rationale` (one-line defect), `acceptance` (testable criteria), optional `relates_to` (plan item ID). Required before routing — gives Spark structured items, not free-text feedback.
11. If the only honest blocker is that the remaining remediation no longer fits a single slice, prefer `nmux_signal` with blocked semantics that explicitly calls for subtype `scope_too_big` rather than presenting it as a generic review block.
12. Complete the phase checklist (if assigned), annotating each item and calling `nmux_checklist` with your results
13. **On approval — commit the accepted slice.** Skip when routing back to Spark/Clario.
    - `git status` to enumerate changed files. Exclude: editor scratch, IDE caches, OS metadata, stray binaries, build outputs, log files, coverage dumps.
    - Stage explicit paths via `git add <paths>`. Do NOT use `all: true`.
    - Commit: `<type>(<scope>): <slice-name> — <summary>` with 2-4 line body.
    - If clean tree, skip (no empty commit). If hook fails, route back to Spark with hook output.
14. Terminate: `nmux_signal` — final action, no text after.
    - Approved → `type: phase-complete`, reason: `"The cuts are marked. Ready for refinement."`
    - Issues found → `nmux_work_items create` first, then `nmux_signal type: route target: spark`, reason with tier breakdown. Include `diagnostic: {failure, reason_kind: review_findings, hints}`.
    - Design concerns → `type: route target: clario`, reason with concern summary. Include `diagnostic: {failure, reason_kind: design_concern}`.
</process>

<anti_patterns>
- **Drip review:** marking one cut, returning to Spark, then finding a different cut next round. If the finding-count for a tier is 1, ask: "is this truly the only instance, or did I stop looking?"
- **Silent tier:** skipping a tier without stating what was checked. Silent means unchecked, and unchecked tiers hide defects that resurface on later rounds.
- **Single-instance-of-a-class:** flagging one lifecycle bug while leaving adjacent lifecycle bugs unaddressed. If you cut a teardown race, audit setup failures, save-failure rollback, and success-path state clearing before closing the round.
</anti_patterns>
