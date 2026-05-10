---
---

<instructions>
Execute full TDD implementation workflow for the provided story.
</instructions>

<process>
1. Read story file with Clario's technical design
2. **Check for open review-cut items:** Call `nmux_work_items` with `{"method": "list"}`. If review-cut items exist (envelope_type: "review-cut"), they are your PRIMARY task — address each one before starting new implementation work. Each item carries:
   - `rationale`: what's wrong
   - `acceptance`: what "fixed" looks like (write a test proving this BEFORE making code changes)
   - `anchor`: code location to start from
   Work through them in priority order. Call `nmux_work_items update` with status `"in-progress"` when starting an item and `"resolved"` when done (with a brief rationale of what changed).
3. Understand interfaces, contracts, and behavioral narratives
4. Query prior implementation lore: `nmux_lore_query` with domain description. Consider follow-ups filtered by `IMPLEMENTATION_FRICTION`, `PATTERN_OUTCOME`, `TESTING_STRATEGY`, `EDGE_CASE_DISCOVERY`. Note L-refs to apply. If tool unavailable, proceed without — best-effort enrichment, not prerequisite.
5. Design test suite structure from test seeds
6. Execute red-green-refactor cycles:
   - Write failing test (red)
   - Write minimal code to pass (green)
   - Refactor when meaningful mass achieved
7. Validate against acceptance criteria at every green
8. **Scope-too-big block** — if remaining work won't fit one slice, emit `nmux_signal type: blocked subtype: scope_too_big` with reason naming the modules/surfaces that exceed one slice. Omit `subtype` for ordinary blockers (test/build failure, missing dependency). Include `diagnostic: {failure, last_action, reason_kind, hints}`.
9. Run coverage check
10. Run mutation testing to verify test quality
11. Document any deviations with first principles reasoning
12. For each lore entry you actually applied (or deliberately contradicted), call `nmux_lore_feedback` with its L-ref and `feedback: "helpful"` or `"incorrect"`. Use `"not_relevant"` sparingly — only when a retrieval was off-topic enough that filtering it out would improve future queries.
13. Run the pre-handoff trust gate: `go vet`, `go build`, and `go test` (scoped to edited packages; `-race` if concurrency touched) MUST all be green. A red gate means fix-first, not handoff. See `handoff.md` for full rationale.
14. Prepare handoff with post-implementation explanation, including the trust gate results
15. Complete the phase checklist (if assigned), annotating each item and calling `nmux_checklist` with your results
16. Call `nmux_signal` with type `"phase-complete"` and reason summarizing the implementation — this MUST be your final action. Do not emit any assistant text after the tool call.
</process>

<constraints>
- Shape your task list as behavior-sized red-green slices. Each implementation task introduces a component AND the unit tests that drive it — never a task that writes unit tests for components built in earlier tasks.
- A task is only complete when its unit test was written first (failing) and is now green.
- Outer-loop tests (integration, acceptance, E2E) that span multiple components MAY be a separate task — they can't be written before the components exist.
- Coverage, mutation, lint, and checklist tasks MAY remain as terminal tasks.
</constraints>
