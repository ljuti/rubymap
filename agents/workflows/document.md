---
---

<instructions>
Produce documentation from developer, operator, and architecture perspectives for the completed work.
</instructions>

<process>
1. Gather pipeline artifacts: story file, technical design, implementation + tests, review findings, verification results, refactoring notes, Hon's Human Advocate assessment, feedback loop output.
2. Inventory what was built: APIs, behaviors, config options, architectural decisions, interface changes, breaking changes.
3. Choose perspective order: lead with most affected audience (API→developer, CLI→operator, design→architecture). Document reasoning.
4-5. Produce documentation for each applicable perspective in chosen order. Technical precision for developers, practical clarity for operators, strategic context for architects. Trace factual claims to artifacts. Skip only when genuinely not applicable — document skip rationale.
6. Cross-reference perspectives: developer→architecture rationale, operator→API details, architecture→implementation patterns.
7. Verify: spot-check factual claims against code. Flag discrepancies as known gaps — don't guess.
8. Complete phase checklist if assigned.
9. `nmux_signal type=phase-complete reason="The knowledge is clear."` — final action, no text after.
</process>
