---
type: checklist
name: blade-state-lifecycle
description: State-lifecycle invariants — setup/teardown, persisted-state reconciliation, rollback on partial failure, class-sweep discipline
phase: RV
agent: blade

---

# State-Lifecycle Invariants Checklist

> Annotate every item. N/A requires a one-line reason. When marking an ISSUE, audit adjacent code paths for the same class of defect before closing the review round — single-instance cuts of lifecycle bugs are a known drip-review failure mode.
> Scope: this checklist is mandatory for any diff that allocates, persists, or tears down resources (worktrees, lockfiles, temp dirs, DB rows representing run state, long-lived goroutines, file handles, external processes). If the diff is pure computation with no resource lifecycle, mark every item N/A with reason `no resource lifecycle touched`.

---

## 1. Setup — Allocate-and-Persist Ordering

- [ ] **Validation runs before allocation**

- [ ] **Persisted state is not written before the resource it describes is fully ready**

- [ ] **Initial save failure triggers rollback**

- [ ] **Rollback failures are reported, not swallowed**

---

## 2. Execution — Live-Resource Invariants

- [ ] **Resource path is the single source of truth during execution**

- [ ] **Retry/nudge loops observe the same resource as the initial execution**

- [ ] **Resume path verifies resource still exists before use**

---

## 3. Teardown — Success and Failure Paths

- [ ] **Successful completion clears stale state references**

- [ ] **Failed execution preserves state for debugging**

- [ ] **Cleanup runs after all dependents release the resource**

- [ ] **Partial-teardown failures surface clearly**

---

## 4. Class-Sweep Discipline

- [ ] **Every instance of the finding class has been audited in the current diff**

- [ ] **Regression tests cover every asserted invariant**

---

## 5. Mandatory: Overall Lifecycle Verdict

| Verdict | Criteria |
|---------|----------|
| **Holds** | All applicable items PASS. No adjacent-instance concerns. Regression coverage present. |
| **Gaps** | Any item ISSUE, or §4.2 test coverage missing for an invariant the diff depends on. |

**Verdict:** [ ] Holds / [ ] Gaps
**Rationale:** _______________

**Reviewer:** _______________
**Date:** _______________
