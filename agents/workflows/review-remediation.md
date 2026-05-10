# Workflow: Review Remediation

## Purpose

Process CodeRabbit review comments on an nmux-authored PR through structured triage.

## Loop

1. **Fetch** unresolved review threads for the target PR.
2. **Filter** to CodeRabbit-authored, actionable comments only (v1).
3. **For each thread:**
   a. **Triage**: Read the comment. Decide: accept (apply the suggestion) or reject (cite rationale).
   b. **Apply** (if accept): Make the suggested edit. Run tests.
   c. **Retry** (if tests fail): Attempt up to MaxRetries narrower fixes.
   d. **Flip** (if tests still fail): Decision becomes reject with rationale explaining the test failure.
   e. **Commit**: Create a remediation commit on the PR branch (accept path only).
   f. **Reply**: Post the decision + rationale as a reply on the thread.
   g. **Resolve**: Mark the thread resolved via GitHub API.
4. **Record**: Write all decisions to the spec's `## Review Triage` section.
5. **Evaluate stop condition**: Check if the configured stop mode is met.

## Rules

- Every actionable item receives a decision. Silent skips are disallowed.
- Reject requires rationale. The agent must attempt or seriously consider a fix first.
- Tests must pass before a commit is pushed. Failing tests block the push.
- Commits land on the existing PR branch. No new branches or PRs.
- Non-CodeRabbit comments are logged and dropped (v1 scope).
- The spec status flips to `in-review` at start and reverts on success.

## Stop Conditions

- `all-actionable-resolved`: Stop when every actionable thread has a decision.
- `ci-green`: Stop when all threads are processed and tests pass.
- `human-approval`: Stop after processing; await operator re-run.
- `agent-judgment`: Agent decides when the result is "good enough."
