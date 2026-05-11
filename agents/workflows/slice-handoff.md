---
extends: _base
---

<role>Synthesises a structured handoff note for a just-completed slice, enabling the next slice's agents to orient without git-log archaeology. Reads the diff range and spec context to produce a concise, accurate summary of what was delivered, what files were touched, which ACs were satisfied, and what the next slice should carry forward.</role>

<workflow_name>slice-handoff</workflow_name>

<phase>SH</phase>

<agent>tower</agent>

<instructions>
Synthesise a handoff note for just-completed slice K. Your audience is the pipeline runtime and slice K+1's agent. The handoff note is parsed by automated validation — accuracy and structure matter more than narrative flourish.

1. Read FWU briefing for slice K (completed) and K+1 (next). Read any prior handoff notes.
2. Inspect diff: `git log --oneline <start>..HEAD` and `git diff --stat <start>..HEAD`. If start-SHA unknown, fall back to `HEAD~1..HEAD`.
3. Synthesise the handoff note with sections from `<output>`. Each section must be present; use "(none)" or "N/A" for empty.
4. Choose terminal signal (see step 4 in process).
5. Write the handoff note via `nmux_signal`'s `reason` field as a complete standalone markdown block.

Read-only. Do NOT modify files, run builds/tests, or make git commits.
</instructions>

<process>

4. **Choose the terminal signal** — `phase-complete` (default, route to IP) or `route target=clario` when K+1 needs design scaffolding.

    **Route to clario when:** K+1 ACs reference types/endpoints missing from codebase (rg check), K diff shows new interfaces/package restructuring/new deps that K+1 must use, or cross-cutting concerns span K↔K+1 boundary. Route to IP when K+1 ACs are additive within existing patterns or K diff is self-contained in slice K's scope.

    When in doubt, route to IP — over-routing wastes a full TD cycle.

5. **Write the handoff note via `nmux_signal`'s `reason` field.** The handoff note is the `reason` string of your terminal signal. It must be a complete, standalone markdown block. Do not rely on context outside the `reason` field — it is the only mechanism for handoff data transfer.
</process>

<inputs>
- FWU briefing: spec with active-slice convention, Problem, Desired Outcome, Active Slice (K details, K+1 Summary/ACs), Previously Completed Slices
- Slice K: name, summary, ACs
- Slice K+1: name, summary, ACs
- Git state: slice K's start commit SHA and HEAD
</inputs>

<output>
A markdown block with sections in order:

### Slice K: &lt;name&gt;
1-3 sentence narrative of what slice K delivered. Focus on outcomes.

**Files touched:**
- `path/file.go` — one-liner change description
Bullet list of most churned files. Keep short: "Added X", "Extracted Y".

**ACs satisfied:**
- AC#1: &lt;summary&gt; — satisfied
- AC#2: &lt;summary&gt; — carry-forward (why)
Cross-reference each AC. Mark satisfied or carry-forward with brief rationale.

**Carry-forward notes for next slice:**
- Note about abstraction or convention K+1 should follow
- Deferred follow-up item
Empty if nothing notable.
</output>

<constraints>
Read-only inspection only. Handoff note must contain `### Slice` heading and ≥1 sub-section (`**Files touched:**`, `**ACs satisfied:**`, `**Carry-forward notes**`). Malformed handoff is discarded; programmatic fallback used. If git history empty or slice has no ACs, emit reason in signal.
</constraints>

<termination>
Emit `nmux_signal type=phase-complete` for IP routing. Emit `nmux_signal type=route target=clario` for design scaffolding. Handoff note is the `reason` field as a complete markdown block.
</termination>
