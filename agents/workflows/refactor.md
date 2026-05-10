---
params:
  scope: "What is being refactored"
  trigger: "When refactoring is triggered"
  stopping_criteria: "When to stop"
---

<instructions>
Refactor {{scope}} (triggered: {{trigger}}).
</instructions>

<process>
1. Ensure all tests are passing (green state)
2. Identify refactoring opportunities:
   - Duplicated code
   - Long methods
   - Complex conditionals
   - Unclear naming
3. Apply refactoring in small, safe steps
4. Run tests after each change
5. If any test fails, revert immediately
6. Continue until: {{stopping_criteria}}
7. Confirm all tests still pass
7a. If remaining cleanup won't fit one slice: `nmux_signal type=blocked subtype=scope_too_big` with `diagnostic: {failure, reason_kind, hints}`. Use generic `blocked` for ordinary obstacles.
7b. Pre-handoff trust gate: `go vet`, `go build`, `go test` (scoped to edited packages, `-race` if concurrency touched) must all be green.
8. Stage and commit: `git status` + `git diff --stat` review, stage related files (not `git add -A`), commit with concise subject (<72 chars) + body, verify with `git log --oneline -1`.
9. Complete phase checklist if assigned.
10. `nmux_signal type=phase-complete` with reason summarizing refactor + commit SHA — final action.
</process>
