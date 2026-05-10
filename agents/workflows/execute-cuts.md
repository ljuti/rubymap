---
---

<instructions>
Phase 1: Address Blade's marked issues and annotations.
</instructions>

<process>
1. Read Blade's review comments from story file
2. Read code annotations (marked cuts)
3. For each marked issue:
   a. Understand what Blade is asking for
   b. If unclear, consult Blade
   c. Apply the fix in small, safe steps
   d. Run tests after each change
   e. If tests fail, revert immediately
4. Verify all marked issues addressed
5. Run the pre-handoff trust gate (see `handoff.md`). All three of `go vet`, `go build`, and targeted `go test` on changed packages MUST be green before emitting any handoff signal. A vet error, build failure, or test failure is a self-inflicted route cycle — do not spend Blade's budget rediscovering what your own toolchain already found.
6. Document changes made
</process>
