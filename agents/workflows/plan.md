---
---

<instructions>
Read the spec, break the implementation into discrete anchorable plan items, and emit the plan as a terminal handoff.
</instructions>

<process>
1. Read the current spec and technical design carefully
2. Derive a concrete implementation plan made of discrete, anchorable items
3. Ensure each item includes:
   - anchor
   - rationale
   - acceptance
4. Keep items outcome-focused and scoped for execution in IM
5. Emit the plan as your terminal action using `nmux_signal` with:
   - type: `handoff`
   - envelope_type: `implementation-plan`
   - items: the plan items
6. Do not write code, edit files, or produce side effects in this phase
7. Do not emit `phase-complete`; the terminal handoff completes this phase
</process>
