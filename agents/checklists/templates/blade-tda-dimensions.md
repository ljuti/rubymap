---
type: checklist
name: blade-tda-dimensions
description: "Dimension-coverage checklist for the tech-debt audit — verifies every dimension was walked and every finding cites file:line"
phase: TDA-A
agent: blade
    - name: Re-audit
      meaning: "Dimension skipped, citations missing, or looks-bad-but-fine empty"

placeholders: []

---

# Dimension Coverage Checklist

---

## 1. Dimension Walks

Each item below confirms the dimension was walked and either produced findings (with `file:line` citations) or has an explicit "Nothing material" annotation.

- [ ] **Dimension 1 — Architectural decay**

- [ ] **Dimension 2 — Consistency rot**

- [ ] **Dimension 3 — Type & contract debt**

- [ ] **Dimension 4 — Test debt**

- [ ] **Dimension 5 — Dependency & config debt**

- [ ] **Dimension 6 — Performance & resource hygiene**

- [ ] **Dimension 7 — Error handling & observability**

- [ ] **Dimension 8 — Security hygiene**

- [ ] **Dimension 9 — Documentation drift**

---

## 2. Citation Discipline

- [ ] **Every concrete finding cites `file:line`**

- [ ] **Process-level findings cite the most relevant config file**

---

## 3. Cap Discipline

- [ ] **Findings count is in range**

---

## 4. Looks-Bad-But-Fine Log

- [ ] **`.nmux/tech-debt-audit/looks-bad-but-fine.md` is non-empty**

---

## 5. Open Questions Log

- [ ] **`.nmux/tech-debt-audit/open-questions.md` is populated, or explicitly empty**

---

## 6. Stack Tooling

- [ ] **Make targets preferred over direct CLI**

- [ ] **Missing audit tools recorded as findings**

---

## 7. Scope Discipline

- [ ] **No production code edited**

- [ ] **No rewrites recommended**

---

## Verdict

| Verdict | Criteria |
|---|---|
| **AUDITED** | All dimensions walked, citations present, looks-bad-but-fine non-empty, no production code edits. |
| **RE-AUDIT** | Dimension skipped, citations missing, looks-bad-but-fine empty, or scope violation. Return to TDA-A. |

**Auditor:** _______________
**Date:** _______________
**Verdict:** [ ] AUDITED / [ ] RE-AUDIT
