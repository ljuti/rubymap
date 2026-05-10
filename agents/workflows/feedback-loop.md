---
---

<instructions>
Evaluate design vs final implementation and record learnings to the lore store.
</instructions>

<process>
1. Compare original design to final implementation.
2. Identify where design matched well and where it diverged.
3. Analyze improvements for future designs.
4. For each learning, call `nmux_lore_record` with `content` (self-contained statement), `category` (ARCHITECTURAL_DECISION, PATTERN_OUTCOME, INTERFACE_LESSON, EDGE_CASE_DISCOVERY, IMPLEMENTATION_FRICTION, TESTING_STRATEGY, DEPENDENCY_BEHAVIOR, PERFORMANCE_INSIGHT), `source` (FWU id + phase).
5. If no learnings, state so explicitly with reason — don't skip silently.
6. `nmux_signal type=phase-complete reason="Feedback loop complete. Recorded N learning(s)."` (or `"Recorded 0 learnings — implementation matched design."`) — final action.
</process>
