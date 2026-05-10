---
type: checklist
name: quill-documentation
description: Documentation quality gate — developer, operator, and architecture perspectives verified for completeness, accuracy, and audience-appropriateness
phase: DC
agent: quill

---

# Documentation Checklist

> before sign-off. All factual claims must be traceable to pipeline artifacts or
> verifiable against the code.

**Story:** `{{story_id}}`
**Date:** `[YYYY-MM-DD]`

---

## A. Mandatory: Artifact Gathering

> Confirm that all pipeline outputs from prior phases have been reviewed.

- [ ] **Technical design consumed** — design doc from TD phase read and understood `[state: ]`
- [ ] **Implementation code reviewed** — actual code (not just design) inspected for exported `[state: ]`
- [ ] **Review findings consumed** — Blade's review annotations from RV phase reviewed for `[state: ]`
- [ ] **Refactoring notes consumed** — Hon's refactoring notes from RF phase reviewed for `[state: ]`
- [ ] **Feedback loop learnings consumed** — Clario's FL notes reviewed (if available) `[state: ]`
- [ ] **Human Advocate assessment consumed** — Hon's Human Advocate assessment from RF phase reviewed `[state: ]`

---

## B. Mandatory: Developer Documentation

> If no developer-facing API changes exist, annotate trigger item as `N/A (no developer-facing API changes)` and skip remaining B items.

- [ ] **Trigger: Developer-facing API changes exist** `[state: ]`

### B1. API Surface

- [ ] **All exported types documented** — purpose, key fields, relationships to other types `[state: ]`
- [ ] **All exported functions documented** — parameters, return values, error conditions `[state: ]`
- [ ] **Interface contracts documented** — behavioral expectations `[state: ]`
- [ ] **Error handling guidance provided** — what errors callers should expect `[state: ]`

### B2. Integration Guidance

- [ ] **Setup path documented** — clear steps from zero to working: dependencies `[state: ]`
- [ ] **Code examples provided** — non-trivial usage examples that a developer can adapt `[state: ]`
- [ ] **Pattern usage documented** — when and why to use specific patterns introduced `[state: ]`

---

## C. Mandatory: Operator Documentation

> If no operator-facing changes exist, annotate trigger item as `N/A (no operator-facing changes)` and skip remaining C items.

- [ ] **Trigger: Operator-facing changes exist** `[state: ]`

### C1. Feature Behavior

- [ ] **Feature described in operator terms** — what it does `[state: ]`
- [ ] **Configuration options documented** — each option with description `[state: ]`
- [ ] **Expected output documented** — what the operator sees when the feature runs `[state: ]`

### C2. Boundaries and Migration

- [ ] **Edge cases and limitations documented** — known boundaries documented honestly `[state: ]`
- [ ] **Migration steps documented** (conditional: apply when breaking changes exist) — clear path for before, during, and after migration `[state: ]`
- [ ] **Rollback path documented** (conditional: apply when breaking changes exist) — what to do if migration fails or needs reversal `[state: ]`

---

## D. Mandatory: Architecture Documentation

> If no architectural decisions were made, annotate trigger item as `N/A (no architectural decisions)` and skip remaining D items.

- [ ] **Trigger: Architectural decisions exist** `[state: ]`

### D1. Decision Records

- [ ] **Decisions recorded in ADR format** — for each decision: context `[state: ]`

  | Decision | ADR Location | Summary |
  |----------|--------------|---------|
  |          |              |         |

### D2. Trade-offs and Boundaries

- [ ] **Trade-offs documented** — what was gained `[state: ]`
- [ ] **System boundary impacts documented** — how this change affects neighboring systems `[state: ]`
- [ ] **Pattern rationale documented** — why this pattern was chosen `[state: ]`

---

## E. Mandatory: Cross-Cutting Quality

> These items apply regardless of which perspectives were documented.

- [ ] **Factual claims are traceable** — every factual claim traceable to a pipeline artifact `[state: ]`
- [ ] **Register boundaries maintained** — no audience mixing: developer jargon stays in developer `[state: ]`
- [ ] **Consistency across perspectives** — the same reality rendered for three audiences `[state: ]`
- [ ] **Gaps documented honestly** — unknowns documented as known limitations `[state: ]`
- [ ] **Documentation order justified** — the chosen documentation order (which perspective leads) is `[state: ]`

---

## F. Mandatory: Delivery Readiness

- [ ] **Documentation committed** — all documentation files staged and committed with descriptive `[state: ]`
- [ ] **Story file updated** — documentation summary or reference added to story file `[state: ]`
- [ ] **All checklist items annotated** — every item above carries a state annotation (no `[state: ]`
- [ ] **No CONCERN annotations remain unresolved** — or documented in Notes section below `[state: ]`

---

## Notes

> Record issues, observations, concerns, or important context encountered during documentation.
> Every CONCERN annotation from above must have a corresponding entry here.

- **Story:** *(story ID)*
- **Perspectives documented:** *(developer / operator / architecture — list which were applicable)*
- **Documentation order and reasoning:** *(which perspective led and why)*
- **Known gaps:** *(list any honestly, or "none")*
- **Concerns:** *(list any unresolved concerns)*
- **Artifact quality notes:** *(any pipeline artifacts that were sparse or missing, and how documentation handled the gap)*

---

## Sign-Off

> By signing, the agent affirms that:
> 1. All applicable perspectives are documented with audience-appropriate register
> 2. Every factual claim is traceable to pipeline artifacts or verifiable against code
> 3. Gaps are documented honestly, not fabricated
> 4. Register boundaries are maintained — no audience mixing
> 5. The checklist is complete — every item annotated
>
> **Do not sign if any concern remains undocumented.**

```
Sign-off: ____________________________
Date:     ____________________________
Verdict:  [ ] The knowledge is clear.
          [ ] Documented with noted gaps (see Notes).
          [ ] BLOCKED — cannot document (see Notes for blocking issues).
```
