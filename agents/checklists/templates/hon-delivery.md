---
type: checklist
name: hon-delivery
description: Final refinement gate before merge — behavior preserved, review cuts executed, triangulated quality signals, delivery-ready
phase: RF
agent: hon

---

# Delivery Checklist

---

## A. Mandatory: Behavior Preservation

> Behavior is sacred.

### A1. Test Suite Integrity

- [ ] **Full test suite passes** — `{{test_command}}` exits 0 `[state: ]`
- [ ] **System tests pass** (if applicable) — `{{system_test_command}}` exits 0 `[state: ]`
- [ ] **Existing behavioral tests unchanged** — diff to prior phase's test files shows only `[state: ]`
- [ ] **Added tests serve refinement, not new scope** — each new test covers a refactoring-safety gap or confirms behavior preservation `[state: ]`

### A2. Behavioral Boundary

> Behavior changes must trace to a review cut or prior-phase decision.

- [ ] **No behavior changes beyond review cuts** — every runtime-visible change traces to a marked cut `[state: ]`
- [ ] **Public API within sanctioned surface** — signatures, return types, error behavior match approved design `[state: ]`
- [ ] **Schema within sanctioned surface** — no migrations or data-shape changes beyond approved scope `[state: ]`
- [ ] **No new dependencies added** — manifest unchanged from reviewed state `[state: ]`

---

## B. Mandatory: Refactoring Completeness

### B1. Review Cuts Executed

- [ ] **All marked cuts addressed** — each annotation has a corresponding change or justified deferral `[state: ]`
- [ ] **Each cut verified independently** — tests pass after each discrete change `[state: ]`
- [ ] **Cut execution recorded** — results captured in spec file `[state: ]`

### B2. Deferred Cuts

- [ ] **All deferred cuts documented** — or confirm "none deferred" `[state: ]`

### B3. Deep Polish Applied

- [ ] **Code scanned for duplication** — DRY violations addressed `[state: ]`
- [ ] **Long methods/functions broken into focused pieces** `[state: ]`
- [ ] **Complex conditionals simplified** — guard clauses applied where appropriate `[state: ]`
- [ ] **Naming reviewed for clarity** — intention-revealing `[state: ]`
- [ ] **Code smells addressed** `[state: ]`
- [ ] **Project style conventions followed** `[state: ]`
- [ ] **No new lint findings on changed files** — `{{lint_command}}` reports no new offenses `[state: ]`

### B4. Proactive Opportunities Documented

> Opportunities beyond scope are documented, not acted upon.

- [ ] **Proactive opportunities recorded** — appended to spec file or Notes below `[state: ]`

---

## C. Mandatory: Stopping Signals — TRIANGULATED

> All three signals must be satisfied simultaneously.
> For stacks with tooling, document the manual assessment method and result.

### C1. Mutation Assessment

> **Target:** {{mutation_threshold}} via `{{mutation_tool}}`. For stacks without
> a first-class mutation tool (Go, most native codebases), the manual protocol
> below is the *primary* path, not a fallback — it produces the same signal
> with none of the tool-availability fiction.

**Manual Mutation Protocol** (primary for stacks without an integrated mutation tool)

1. For each changed method/function, mentally apply these mutations:
   - Negate conditionals (`if` to `unless`/`!`, `==` to `!=`)
   - Remove statements (delete lines, remove calls)
   - Replace return values (swap true/false, return nil/zero)
   - Boundary mutations (off-by-one, empty collection)
   - Remove error handling
2. For each mutation, verify: would an existing test catch this?
3. If no test catches it: add a test (test gap) or simplify the code (code excess).
4. Document acceptable survivors with reasoning.

- [ ] **Mutation assessment performed** — via tool or manual protocol `[state: ]`
- [ ] **Surviving mutants categorized** — added test, simplified code, or accepted with reason `[state: ]`
- [ ] **Result recorded** — tool output or manual-protocol summary captured `[state: ]`

### C2. Coverage

> **Target:** No coverage regressions; maintain or improve coverage on changed files

- [ ] **Coverage assessed for all changed files** `[state: ]`
- [ ] **No coverage regressions** `[state: ]`
- [ ] **Coverage gaps documented** `[state: ]`

**Structural Coverage Protocol** (when no coverage tool is available):
1. For each changed file, identify corresponding test file(s).
2. Verify each public method/function has at least one test.
3. Verify each conditional branch has coverage for both paths.
4. Verify each error/exception path has test coverage.
5. Record any gaps with justification.

### C3. Complexity

> **Target:** No method exceeds {{max_method_length}} lines or cyclomatic complexity of {{max_complexity}}

- [ ] **Linter complexity metrics pass** — no complexity offenses on changed files `[state: ]`
- [ ] **No method/function exceeds length threshold** — all <= {{max_method_length}} lines `[state: ]`
- [ ] **Cyclomatic complexity within bounds** — all <= {{max_complexity}} `[state: ]`
- [ ] **Type-level complexity acceptable** — no god objects `[state: ]`

### C4. Triangulation Verdict

- [ ] **All three stopping signals satisfied simultaneously** `[state: ]`
  - Mutation assessment: tool score OR manual protocol summary
  - Coverage: no regression on changed files
  - Complexity: within `{{max_method_length}}` / `{{max_complexity}}` bounds
- [ ] **Any unmet signal justified** — if a signal can't be measured in this stack, document justification `[state: ]`

---

## D. Mandatory: Delivery Readiness

### D1. Security and Static Analysis

- [ ] **Security scanner passes** — `{{security_scanner_command}}` reports no new warnings `[state: ]`
- [ ] **Dependency audit passes** — `{{dependency_audit_command}}` reports no new advisories `[state: ]`

### D2. CI Pipeline Verification

- [ ] **All CI steps would pass** — verified locally against `{{ci_config}}` steps `[state: ]`

### D3. Commit Quality

- [ ] **Each commit explains the refactoring applied** — not just "what" but "why" `[state: ]`
- [ ] **Commits are atomic** — each commit is a single logical refactoring step `[state: ]`
- [ ] **Commit messages follow project conventions** `[state: ]`
- [ ] **No debug code, TODO comments, or temporary scaffolding left behind** `[state: ]`

### D4. Refinement Narrative Recorded

> Pick the project's convention (spec file, story file, or notes).

- [ ] **Refinement narrative recorded** — all cuts applied and results documented `[state: ]`
- [ ] **Review cut execution results logged** — each cut marked done `[state: ]`
- [ ] **Stopping signal measurements captured** — mutation, coverage, complexity `[state: ]`
- [ ] **Proactive opportunities listed** — or confirmed "none identified" `[state: ]`
- [ ] **Completed delivery checklist preserved** alongside narrative `[state: ]`

---

## E. Mandatory: Final Verification

- [ ] **Full test suite passes one final time** — `{{test_command}}` after all changes committed `[state: ]`
- [ ] **Working tree is clean** — `git status` shows no untracked or modified files `[state: ]`
- [ ] **All checklist items above carry a state annotation** `[state: ]`
- [ ] **No CONCERN annotations remain unresolved** — or documented in Notes section below `[state: ]`

---

## Notes

> Record issues, observations, concerns, or important context encountered during delivery.
> Every CONCERN annotation from above must have a corresponding entry here.

- **Work Unit:** *(spec name / story ID / feature identifier)*
- **Review Handoff Quality:** *(Excellent / Good / Adequate)*
- **Refinement Effort:** *(Minimal / Moderate / Significant)*
- **Concerns:** *(list any unresolved concerns)*
- **Learnings:** *(insights for feedback loop)*

---

## Sign-Off

> This sign-off is a commitment. By signing, the agent affirms that:
> 1. Behavior is preserved — all tests pass; behavior changes trace to review cuts or prior-phase decisions.
> 2. Refinement is complete — every review cut was executed or deferred with justification.
> 3. Stopping signals are triangulated — mutation assessment, coverage, and complexity all satisfied (or unmet signals justified).
> 4. Code is production-ready — CI pipeline would pass, no debug artifacts remain.
> 5. Narrative is recorded — the project's refinement-narrative artifact is updated and opportunities noted.
>
> **Do not sign if any concern remains undocumented.**

```
Sign-off: ____________________________
Date:     ____________________________
Verdict:  [ ] Honed to its essence.
          [ ] Delivered with documented concerns (see Notes).
          [ ] BLOCKED — cannot deliver (see Notes for blocking issues).
```
