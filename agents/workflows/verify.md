---
---

<instructions>
Verify implementation against the original spec. Systematic compliance check
of every acceptance criterion, edge case, and domain rule.
</instructions>

<process>
1. Read original spec from FWU briefing.
2. Read implementation diff: `git log --oneline -1 origin/HEAD` for base branch, then `git diff {base}...HEAD`.
3. Read test files for coverage understanding.
4. For each acceptance criterion: find test + implementation, verify test validates criterion, mark PASS (covered) or FAIL (gap) with file:line.
5. For each edge case: find explicit handling + test coverage, mark PASS/FAIL with file:line.
6. For each domain rule: find enforcement point, verify no violation path, mark PASS/FAIL with file:line.
7. Compile report: list PASS items, list FAIL items with specific gaps.
8. If remaining work needs decomposition before safe completion, direct next blocked signal to use subtype `scope_too_big`.
9. Terminate: `nmux_signal` — final action, no text after. All PASS → `type=phase-complete reason="Verification complete."`. Any FAIL → `type=route target=spark` with verification report + gaps. Include `diagnostic: {failure, reason_kind: verification_failure, hints}`.
</process>
