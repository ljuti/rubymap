---
type: checklist
name: clario-design
description: Technical design quality gate before handoff to implementation
phase: TD
agent: clario

---

# Technical Design Checklist

> Used during the Technical Design workflow (TD) before handoff to implementation.
> Document the completed checklist in the story file's **Technical Design** section.

---

## 1. Mandatory: Story Comprehension

- [ ] **Read story requirements in full** — acceptance criteria `[state: ]`
- [ ] **Identify the story's functional requirements** — list which product requirements this `[state: ]`
- [ ] **Check epic context** — read preceding stories in the `[state: ]`
- [ ] **Verify story is unblocked** — confirm dependencies from prior stories `[state: ]`

---

## 2. Mandatory: Security Classification

Assign exactly one classification. This gates conditional sections below.

- [ ] **Classification assigned:** `public` | `internal` | `confidential` | `restricted` `[state: ]`


---

## 3. Mandatory: Gap Analysis

Assess the current codebase against what this story requires. Reference actual files.

- [ ] **Models / data structures** — list existing structures affected and `[state: ]`
- [ ] **Controllers / handlers / routes** — list existing handlers affected and `[state: ]`
- [ ] **Database / storage** — identify migration or schema change `[state: ]`
- [ ] **API surface** — identify endpoint additions or modifications `[state: ]`
- [ ] **UI / presentation layer** — list templates `[state: ]`
- [ ] **Events / messaging** — if story touches event-driven flow `[state: ]`
- [ ] **Shared modules / utilities** — any shared behavior extracted or `[state: ]`
- [ ] **Configuration** — changes to config files `[state: ]`
- [ ] **Gap summary table** — tabulate DONE / GAP / `[state: ]`


---

## 4. Mandatory: Architecture Decisions

- [ ] **Structural hierarchy** — declare where new code fits `[state: ]`
- [ ] **Context boundaries** — confirm which bounded context or `[state: ]`
- [ ] **Pattern compliance** — verify design follows {{architecture_doc}} patterns `[state: ]`
- [ ] **Data flow** — trace data path from user `[state: ]`
- [ ] **Existing patterns reused** — reference existing code patterns that `[state: ]`


---

## 5. Mandatory: Interface & Contract Design

- [ ] **Public API of new types** — method/function signatures `[state: ]`
- [ ] **Validation constraints** — input validation rules `[state: ]`
- [ ] **Side effect contracts** — lifecycle hooks `[state: ]`
- [ ] **Response contracts** — HTTP status codes `[state: ]`
- [ ] **Storage constraints** — NOT NULL, unique indexes, foreign `[state: ]`
- [ ] **Integration contracts** — if story touches external APIs `[state: ]`

---

## 6. Mandatory: Test Seeds

Provide title-level behavioral scenarios that feed the TDD cycle. Use {{test_runner}} conventions.

- [ ] **Unit test seeds** — behavioral scenarios for validations `[state: ]`
- [ ] **Integration test seeds** — request-response or cross-component scenarios `[state: ]`
- [ ] **Edge case seeds** — boundary conditions `[state: ]`
- [ ] **Isolation scenarios** — if feature has data boundaries `[state: ]`
- [ ] **System test scenarios** (conditional: include when story involves UI behavior or user flows) `[state: ]`
- [ ] **Test data requirements** — fixtures, factories, or seed data `[state: ]`

---

## 7. Mandatory: Files to Create/Modify

- [ ] **File manifest** — tabulate CREATE / MODIFY / `[state: ]`

---

## 8. Mandatory: Handoff Readiness

- [ ] **All acceptance criteria addressed** — every AC has a corresponding `[state: ]`
- [ ] **No ambiguity remaining** — if unclear items exist `[state: ]`
- [ ] **Story file updated** — Technical Design section written with `[state: ]`
- [ ] **Sign-off** `[state: ]`

---

## C1. Conditional: Security Design

- [ ] **Authentication requirements** — does this feature require authenticated `[state: ]`
- [ ] **Authorization model** — which roles or permissions can `[state: ]`
- [ ] **Input validation** — all user inputs validated and `[state: ]`
- [ ] **Output encoding** — verify output encoding prevents injection `[state: ]`
- [ ] **Data boundary enforcement** — confirm scoped queries cannot return `[state: ]`

- [ ] **Threat model** — document threat assessment (STRIDE or `[state: ]`
- [ ] **Credential handling** — if feature stores or transmits `[state: ]`
- [ ] **Session security** — if feature creates or modifies `[state: ]`
- [ ] **Audit logging** — sensitive operations must emit audit `[state: ]`
- [ ] **PII handling** — if feature stores PII `[state: ]`

- [ ] **Cross-boundary access controls** — privileged access must be logged `[state: ]`
- [ ] **Encryption key management** — document key rotation and isolation `[state: ]`
- [ ] **Security scanner baseline** — note expected {{security_scanner}} warnings this `[state: ]`

---

## C2. Conditional: Performance NFRs

- [ ] **Response time budget** — target latency for critical path `[state: ]`
- [ ] **Query design** — N+1 prevention `[state: ]`
- [ ] **Caching strategy** — what to cache `[state: ]`
- [ ] **Background job design** — if feature uses async processing `[state: ]`
- [ ] **Pagination** — if feature returns collections `[state: ]`
- [ ] **Partial update boundaries** — identify boundaries for incremental UI `[state: ]`

---

## C3. Conditional: Reliability NFRs

- [ ] **Failure modes** — enumerate what can go wrong `[state: ]`
- [ ] **Retry strategy** — backoff parameters `[state: ]`
- [ ] **Idempotency** — if operation can be retried `[state: ]`
- [ ] **Graceful degradation** — what does the user see `[state: ]`
- [ ] **Data consistency** — if feature writes across multiple `[state: ]`

---

## C4. Conditional: Integration NFRs

- [ ] **API contract** — document endpoint `[state: ]`
- [ ] **Authentication flow** — token acquisition `[state: ]`
- [ ] **Rate limiting** — respect external rate limits `[state: ]`
- [ ] **Timeout configuration** — HTTP client timeouts appropriate for `[state: ]`
- [ ] **Error mapping** — map external error codes to `[state: ]`
- [ ] **Data transformation** — if mapping between external and `[state: ]`
- [ ] **Test doubles** — specify how external API is `[state: ]`

---

## Quick Reference: Trigger Evaluation

| Question | Section |
|----------|---------|
| Classification >= `internal`? | C1 (base) |
| Classification >= `confidential`? | C1 (base + confidential) |
| Classification = `restricted`? | C1 (all) |
| Story mentions response times, dashboards, or large datasets? | C2 |
| Story calls an external API or processes webhooks? | C3 + C4 |
| Story involves background/async processing? | C3 |
| Story writes to multiple data stores? | C3 |
