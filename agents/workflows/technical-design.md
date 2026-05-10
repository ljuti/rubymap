---
---

<instructions>
Execute full technical design workflow for the provided story.
</instructions>

<process>
1. Read and analyze story requirements.
2. Perform gap analysis: current vs. required.
3. Query prior lore via `nmux_lore_query` with domain description. Consider follow-up by `ARCHITECTURAL_DECISION` or `INTERFACE_LESSON`. Reference L-refs in design.
4. Consult: architecture docs, existing code, epic history, ADRs, patterns.
5. Check clarity: sufficient to proceed? If not, generate clarity questions.
6. Design interfaces and contracts with simplicity.
7. Create test seeds: behavioral scenarios, contracts, edge cases.
8. If remaining work won't fit one slice, direct downstream to use `blocked subtype=scope_too_big`.
9. Document design in story file.
10. Create separate tech design doc if complexity warrants.
11. Record architectural decisions via `nmux_lore_record` with `ARCHITECTURAL_DECISION` or `INTERFACE_LESSON`. One per call.
12. Complete phase checklist if assigned.
13. `nmux_signal type=phase-complete reason="The path is clear. Build well."` — final action.
</process>
