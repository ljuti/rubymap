---
params:
  recipient: "Who receives the handoff"
  sign_off: "Agent's sign-off line"
---

<instructions>
Prepare and deliver work to {{recipient}}.
</instructions>

<process>
1. Pre-handoff trust gate — all three must pass before continuing:
   a. `go vet ./...` — zero warnings
   b. `go build ./...` — zero errors
   c. `go test ./internal/<pkg>/...` (scoped to edited packages; `-race` if concurrency touched) — all green
   Failure is a blocker — fix root cause, don't suppress.
2. Verify acceptance criteria against spec.
3. Write post-work explanation: plan, what happened, obstacles, deviations + why, trust gate results.
4. Update story file with journey.
5. Prepare description with reviewer context.
6. Commit with clear messages.
7. Sign off: "{{sign_off}}"
</process>

<constraints>
- Don't handoff if §1 is red. Fix first.
- Don't bypass gate with `-skip`, `-run` narrowing, or `// nolint`.
- Pre-existing failures: document in post-work explanation + confirm with next phase.
</constraints>
