---
type: checklist
name: blade-tda-orient
description: "Orientation checklist for the tech-debt audit — verifies the auditor built a real mental model before judging"
phase: TDA-O
agent: blade
    - name: Reorient
      meaning: "Step skipped or scratchpad incomplete"

placeholders: []

---

# Orientation Checklist

> Phase 1 is read-only except for the scratchpad and the task list. Every item below verifies that orientation actually happened — not that audit findings were collected.

---

## 1. Project Surface Read

- [ ] **README and architecture docs read**

- [ ] **Package manifest read**

- [ ] **Makefile (or equivalent) inventoried**

- [ ] **CLAUDE.md / AGENTS.md read**

---

## 2. Module Map

- [ ] **Top-level modules identified**

- [ ] **Entry points identified**

---

## 3. Churn Signal

- [ ] **`git log --oneline -200` read**

- [ ] **`git log --stat --since="6 months ago"` read**

- [ ] **Top 20 largest files listed**

- [ ] **Top 20 most-modified files (last 6 months) listed**

- [ ] **Large × high-churn intersection identified**

---

## 4. Mental Model

- [ ] **Mental model paragraph written**

- [ ] **README ↔ reality consistency check performed**

---

## 5. Audit Plan Published

- [ ] **`nmux_tasks` populated with one task per dimension**

- [ ] **Audit shape decision recorded**

---

## 6. Repeat-Run Reconciliation

- [ ] **Existing TECH_DEBT_AUDIT.md handled**

---

## 7. Scratchpad Written

- [ ] **`.nmux/tech-debt-audit/orient.md` exists**

---

## Verdict

| Verdict | Criteria |
|---|---|
| **ORIENTED** | All items annotated. Scratchpad complete. Ready for TDA-A. |
| **REORIENT** | Any FAIL state. Return to orientation before proceeding. |

**Auditor:** _______________
**Date:** _______________
**Verdict:** [ ] ORIENTED / [ ] REORIENT
