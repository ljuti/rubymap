---
---

<instructions>
Orient before judging. Build a real mental model of the codebase, identify where debt is likely to hide, and publish a per-dimension audit plan. Do not skip this phase — opinions formed before understanding produce bad audits.
</instructions>

<process>
1. **Repeat-run reconcile:** If `TECH_DEBT_AUDIT.md` exists, read it first. Note resolved, stale, and gaps. Orientation becomes a delta.
2. **Read project surface:** README, architecture docs, package manifest, Makefile (note targets), CLAUDE.md/AGENTS.md.
3. **Map directory structure:** Identify modules/layers, entry points, public API location.
4. **Read churn signal:** `git log --oneline -200`, `git log --stat --since="6 months ago"`, top 20 largest and most-modified files. Intersection of large+high-churn = debt hotspots.
5. **Write mental model:** 1-2 paragraphs describing architecture as-is. Contradictions with README are findings.
6. **Decide audit shape:** ≤50k LOC + ≤5 modules → serial. Larger → parallel via `nmux_delegate` to Holmes. Record in scratchpad.
7. **Publish audit plan as `nmux_tasks`:** One task per dimension (architectural decay, consistency rot, type & contract debt, test debt, dependency & config debt, performance & resource hygiene, error handling & observability, security hygiene, documentation drift) + deliverable task. All pending.
8. **Write orientation scratchpad** to `.nmux/tech-debt-audit/orient.md`:
   - Mental model, Module map, Churn hotspots, Make targets, Audit shape decision, Repeat-run delta (if applicable), Surprises (things noticed beyond the 9 dimensions).
9. Complete phase checklist if assigned.
10. `nmux_signal type=phase-complete` with reason summarizing audit shape + module count — final action.
</process>

<constraints>
- Do not start auditing dimensions in this phase. Orient only. Phase 2 owns the actual finding hunt.
- Do not skip steps 4–5 even on a familiar repo. The mental-model write-up is the forcing function that distinguishes an audit from a checklist run.
- Do not edit code. Phase 1 is read-only except for the scratchpad and the task list.
</constraints>
