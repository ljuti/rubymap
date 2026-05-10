---
type: checklist
name: spark-implementation
description: "Implementation quality gate and handoff artifact for code review"
phase: IM
agent: spark
placeholders:
  - key: test_runner
  - key: system_test_command
  - key: lint_command
  - key: lint_tool
  - key: security_scanner_command
  - key: security_scanner
  - key: dependency_audit_command
  - key: coverage_tool
  - key: coverage_threshold
  - key: mutation_tool
  - key: mutation_threshold

---

# Implementation Checklist

**Story:** `[story identifier]`
**Date:** `[YYYY-MM-DD]`

---

## A. Mandatory: Acceptance & Behavior

Every acceptance criterion must map to at least one passing test. Tests must verify behavior (what the system does), not implementation details (how it does it).

- [ ] **All tests pass** `[state: ]`
  - Command: `{{test_command}}`
  - Output: `[paste summary line]`
  - System tests (if applicable): `{{system_test_command}}`
  - Output: `[paste summary or "N/A"]`

- [ ] **Acceptance criteria mapped to tests** `[state: ]`

  | AC # | Criterion (short description) | Test file(s) and test name(s) |
  |------|-------------------------------|-------------------------------|
  |      |                               |                               |

- [ ] **Tests are behavior-focused** `[state: ]`

- [ ] **Acceptance-level tests present (outer loop)** `[state: ]`

- [ ] **Unit tests present (inner loop)** `[state: ]`

- [ ] **No deferred unit-test task** `[state: ]`

---

## B. Mandatory: Test Quality

Coverage and mutation scores must meet configured thresholds: **coverage >= {{coverage_threshold}}**, **mutation score >= {{mutation_threshold}}**.

### B.1 Coverage

- [ ] **Coverage measured** `[state: ]`
  - Tool: `{{coverage_tool}}`
  - Result: `[percentage or qualitative assessment]`
  - Meets threshold ({{coverage_threshold}}): `[yes / no / unable to measure — explain]`

- [ ] **Uncovered paths assessed** `[state: ]`

  | Uncovered path | Disposition |
  |----------------|-------------|
  | `[file:line or description]` | `[dead code removed / edge case test added / acceptable gap / ...]` |

### B.2 Mutation Testing

- [ ] **Mutation strategy followed (scoped-first)** `[state: ]`

- [ ] **Mutation testing executed** `[state: ]`
  - Tool: `{{mutation_tool}}`
  - Scope: `[subject(s) / component / story / full]`
  - Result: `[score or qualitative assessment]`
  - Meets threshold ({{mutation_threshold}}): `[yes / no / unable to measure — explain]`

- [ ] **Surviving mutants assessed** `[state: ]`

  | Surviving mutant description | Justification |
  |------------------------------|---------------|
  | `[what mutation survived]`   | `[why acceptable or what test was added]` |

### B.3 Quality Tool Status

- [ ] **Tool availability confirmed** `[state: ]`
  - {{mutation_tool}}: `[available / not available]`
  - {{coverage_tool}}: `[available / not available]`
  - If tools missing, note alternative assessment method used

---

## C. Mandatory: Design Alignment

Implementation must honor the technical design. Deviations are permitted with first-principles reasoning.

- [ ] **Interfaces match design** `[state: ]`

- [ ] **Test seeds covered** `[state: ]`

  | Test seed (from design) | Implemented test(s) |
  |-------------------------|---------------------|
  |                         |                     |

  Uncovered seeds: `[list any not implemented and explain why, or "None"]`

- [ ] **Architecture patterns honored** `[state: ]`


- [ ] **File list matches design** `[state: ]`
  - Created files match: `[yes / no — list discrepancies]`
  - Modified files match: `[yes / no — list discrepancies]`
  - Unexpected files: `[list any not in the design, or "None"]`

---

## D. Mandatory: Code Quality Gates

These checks mirror the CI pipeline and must pass locally before handoff.

- [ ] **Linter passes** `[state: ]`
  - Command: `{{lint_command}}`
  - Result: `[pass / N offenses — list or summarize]`

- [ ] **Security scanner passes** `[state: ]`
  - Command: `{{security_scanner_command}}`
  - Result: `[pass / N warnings — list or summarize]`

- [ ] **Dependency audit passes** `[state: ]`
  - Command: `{{dependency_audit_command}}`
  - Result: `[pass / N advisories — list or summarize]`

- [ ] **Database/storage state consistent** `[state: ]`


---

## E. Mandatory: Documentation

### E.1 Deviations from Design

- [ ] **Deviations documented with first-principles reasoning** `[state: ]`

  | # | What deviated | Original design intent | What was implemented | First-principles reasoning |
  |---|---------------|----------------------|---------------------|---------------------------|
  |   |               |                      |                     |                           |

### E.2 Discoveries

- [ ] **Discoveries documented for feedback loop** `[state: ]`

  | Discovery | Impact | Recommendation |
  |-----------|--------|----------------|
  |           |        |                |

### E.3 Prior Knowledge Used

- [ ] **Prior knowledge usage documented** `[state: ]`

  | Reference | How it was used | Helpfulness |
  |-----------|-----------------|-------------|
  |           |                 |             |

---

## F. Mandatory: Post-Implementation Explanation

> Required narrative for the reviewer's trust-first review. Honest accounting of plan vs. reality.

### F.1 What was the plan?
`[Describe the implementation approach from the technical design. Intended sequence, scope from test seeds.]`

### F.2 What actually happened?
`[Describe the actual implementation journey. Order of work, number of cycles, surprises.]`

### F.3 What obstacles were encountered and resolved?
`[Describe blockers or friction and how each was resolved. "None" if smooth.]`

### F.4 What deviations were made and why?
`[Summarize deviations from E.1 in narrative form, or "None."]`

### F.5 What edge cases or friction was discovered?
`[Edge cases, framework quirks, or integration friction that future work should know about.]`

---

## G. Mandatory: Handoff Readiness

- [ ] **All tests pass** (re-confirmed after final changes) `[state: ]`
  - `{{test_command}}` result: `[paste summary]`

- [ ] **Story file updated** `[state: ]`
  - Completion notes written: `[yes / no]`
  - File list accurate: `[yes / no]`

- [ ] **Commits are clean and descriptive** `[state: ]`
  - Number of commits: `[N]`
  - Commit message style: `[describe]`

- [ ] **This checklist is complete** `[state: ]`
  - All items have annotations (no blanks): `[confirmed]`
  - Honest assessment — nothing glossed over: `[confirmed]`

---

**Sign-off date:** `[YYYY-MM-DD]`
