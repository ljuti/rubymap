---
type: checklist
name: blade-tda-deliverable
description: "Deliverable checklist for the tech-debt audit — verifies TECH_DEBT_AUDIT"
phase: TDA-S
agent: blade

---

# Deliverable Checklist

> The "Things that look bad but are actually fine" section is load-bearing. Empty means the audit was shallow — route back to TDA-A, not just TDA-S.

---

## 1. File Location and Header

- [ ] **`TECH_DEBT_AUDIT.md` written at repo root**

- [ ] **Header contains repo name and generation date**

---

## 2. Required Sections (Order and Presence)

- [ ] **Executive summary present (≤10 bullets)**

- [ ] **Architectural mental model present**

- [ ] **Findings table present with required columns**

- [ ] **Top 5 section present with concrete advice**

- [ ] **Quick wins present**

- [ ] **Things that look bad but are actually fine — NON-EMPTY**

- [ ] **Open questions present**

- [ ] **Repeat-run delta present (if prior audit existed)**

---

## 3. Citation Discipline

- [ ] **Every finding row in the findings table cites file:line**

- [ ] **No invented findings during synthesis**

---

## 4. Dedup and Ranking

- [ ] **Duplicates merged**

- [ ] **IDs renumbered as F001, F002, …**

- [ ] **Ranked by severity then effort**

---

## 5. Scope Discipline

- [ ] **No rewrite recommendations**

- [ ] **No padding**

---

## 6. Cleanup

- [ ] **Scratchpad files deleted**

- [ ] **`nmux_tasks` deliverable task marked completed**

---

## Verdict

| Verdict | Criteria |
|---|---|
| **DELIVERED** | All sections present, "looks bad but is fine" non-empty, citations intact, scratchpad cleaned up. |
| **RESHAPE** | Required section missing or empty. If looks-bad-but-fine is empty, route back to TDA-A; otherwise return to TDA-S. |

**Synthesizer:** _______________
**Date:** _______________
**Verdict:** [ ] DELIVERED / [ ] RESHAPE
