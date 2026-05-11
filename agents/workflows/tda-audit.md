---
---

<instructions>
Walk the audit dimensions and produce file-cited findings. Decide serial vs. parallel based on Phase 1's audit-shape decision. Every concrete finding must cite `path/to/file.ext:LINE`.
</instructions>

<process>
1. **Read the orientation scratchpad** at `.nmux/tech-debt-audit/orient.md`. Treat its mental model and module map as the working understanding. The audit-shape decision (`serial` or `delegate`) determines the next step.

2. **Update `nmux_tasks`.** Mark the first dimension `in_progress`. Update tasks as dimensions complete throughout the phase.

3. **Choose execution mode based on the orient decision:**

   **Serial mode** (small repos): walk the 9 dimensions in this order, one at a time, on the whole tree. Use the dimension list and tooling guide below. Append every finding to `.nmux/tech-debt-audit/findings.jsonl` as one JSON object per line.

   **Delegate mode** (large repos): for each module recorded in the orient scratchpad, call `nmux_delegate` with:
   - `target: "holmes"`
   - `task: "audit module <path> against the 9 tech-debt dimensions"`
   - `context: <full contents of orient.md>` plus the explicit module path and a reminder of the `findings.jsonl` write contract
   - `tools: ["read_file", "grep", "fd", "bash"]` (plus `nmux_signal` is auto-attached)
   - `background: true` so multiple modules run in parallel
   Then poll with `nmux_delegate_status` and collect each child's findings as it completes. Children write directly to `.nmux/tech-debt-audit/findings.jsonl` per the `tda-audit-module` workflow contract.

4. **The 9 dimensions** (each child or each serial pass walks all of these):

   1. **Architectural decay** — circular deps, layering violations, god files (>500 LOC) and god functions, duplicated logic across 3+ sites where an abstraction should exist, abstractions that exist but nobody uses, dead code (unused exports, unreachable branches, stale commented-out blocks).
   2. **Consistency rot** — multiple ways of doing the same thing (HTTP clients, error handling, logging, config loading, validation, date handling). Naming drift. Folder structure that no longer reflects what the code actually does.
   3. **Type & contract debt** — `any` / `unknown` / `as any` / `# type: ignore` / loose dicts / `interface{}` smuggled across boundaries. Untyped API boundaries. Missing schema validation at trust boundaries.
   4. **Test debt** — coverage gaps on critical paths. Tests that assert implementation rather than behavior. Skipped or flaky tests. High-churn files with no tests.
   5. **Dependency & config debt** — vulnerability scan, unused deps, duplicate deps doing the same job, env var sprawl (referenced but not documented; defaults inconsistent across envs).
   6. **Performance & resource hygiene** — N+1 queries, sync work in async paths, blocking I/O on hot paths, uncleaned listeners or handles, unnecessary serialization.
   7. **Error handling & observability** — swallowed exceptions, blanket catches, errors logged but not handled, inconsistent error shapes across modules, missing structured logs on critical paths.
   8. **Security hygiene** — hardcoded secrets, string-concat SQL, missing input validation at trust boundaries, permissive auth or CORS, weak crypto.
   9. **Documentation drift** — README claims that don't match reality, comments that contradict adjacent code, public APIs without docstrings.

5. **Stack-specific tooling.** Prefer `make` targets from orient scratchpad. Fallback by stack:
   - Go: `make lint/vet/test/ci` → `go vet`, `staticcheck`, `golangci-lint run`, `govulncheck`.
   - TS/JS: `npm run lint/audit/test` → `npm audit`, `npx knip`, `npx madge --circular`, `npx depcheck`, `tsc --noEmit`.
   - Python: `make lint/test` → `pip-audit`, `ruff check`, `vulture`, `mypy --strict`.
   - Rust: `make lint` or `cargo make audit` → `cargo audit`, `cargo udeps`, `cargo machete`, `cargo clippy -- -W clippy::pedantic`.
   Tool unavailable → record as finding under "Dependency & config debt" with note "audit tool unavailable". Do not install globally.

6. **Findings record format** (`.nmux/tech-debt-audit/findings.jsonl`): `{"id":"F001","category":"...","file":"path","line":142,"severity":"High","effort":"M","description":"...","recommendation":"...","source":"serial"}`. Severity: Critical|High|Medium|Low. Effort: S|M|L. Source: serial, child:<module>, or repeat-run. IDs assigned in arrival order. Every finding cites file+line.

7. **Cap:** 200 findings/child, ~80/serial pass. Exceed → collapse near-duplicates.
8. **Looks-bad-but-fine log** (`.nmux/tech-debt-audit/looks-bad-but-fine.md`): one line per `path:line — pattern X looks like Y, but load-bearing because Z`. Must be non-empty by phase end.
9. **Open questions log** (`.nmux/tech-debt-audit/open-questions.md`): one line per ambiguous call.
10. Update `nmux_tasks` as dimensions complete.
11. Complete phase checklist if assigned.
12. `nmux_signal type=phase-complete` with reason `audit complete — N findings, M open questions, K looks-bad-but-fine` — final action.
</process>

<constraints>
- Cite `file:line` for every concrete finding. A finding without a citation is a vibe and must be reworked or dropped.
- Read the code before judging it. A pattern that looks wrong in isolation may be load-bearing — that's what `looks-bad-but-fine.md` is for.
- Do not recommend rewrites. Recommend specific, scoped changes.
- Do not pad. If a dimension has nothing material, the dimension's task transitions to `completed` and no findings are appended for that dimension. The synthesis phase will say "Nothing material" for that section.
- Do not edit production code. Phase 2 only writes to `.nmux/tech-debt-audit/`.
- `looks-bad-but-fine.md` MUST be non-empty by phase end. This is enforced by the deliverable checklist in Phase 3.
</constraints>
