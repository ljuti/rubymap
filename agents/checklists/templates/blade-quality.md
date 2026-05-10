---
type: checklist
name: blade-quality
description: "Code quality review — performance, reliability, maintainability, readability, test quality"
phase: RV
agent: blade
placeholders:
  - key: lint_tool
  - key: max_method_length

---

# Code Quality Checklist

---

## 1. Performance

### 1.1 Query / Data Access Efficiency

- [ ] **No N+1 queries or redundant data fetches introduced**

- [ ] **Appropriate indexes exist for new query patterns**

- [ ] **No unnecessary queries in request middleware or lifecycle hooks**


### 1.2 Caching

- [ ] **Cacheable data uses caching appropriately**

- [ ] **Cache invalidation is correct**

- [ ] **Fragment/partial caching uses boundary-aware keys**

### 1.3 Response Performance

- [ ] **No blocking operations in the request cycle**

- [ ] **UI responses are granular**

---

## 2. Reliability

### 2.1 Error Handling

- [ ] **Happy path and error path are both handled**

- [ ] **Context is always set before scoped queries**

- [ ] **Lifecycle hooks handle failure gracefully**

### 2.2 Data Integrity

- [ ] **Validations match storage constraints**

- [ ] **Schema changes are reversible**

- [ ] **Enum-like fields are constrained at both layers**

### 2.3 Concurrency

- [ ] **Parallel test execution does not cause flaky tests**


---

## 3. Maintainability

### 3.1 Architecture Patterns

- [ ] **Structural hierarchy is followed consistently**

- [ ] **Shared behavior patterns follow project conventions**

- [ ] **Inheritance depth is reasonable**

- [ ] **Constants are defined in the right place**

- [ ] **Lifecycle hook chains are minimal and predictable**

### 3.2 Code Organization

- [ ] **Single Responsibility is maintained**

- [ ] **Method/function length is reasonable**

- [ ] **No dead code introduced**

- [ ] **File naming follows project conventions**

### 3.3 Configuration

- [ ] **Environment-specific config is in the right place**

- [ ] **Magic numbers/strings are extracted to constants or config**

---

## 4. Readability

### 4.1 Code Clarity

- [ ] **Names communicate intent**

- [ ] **Comments explain "why", not "what"**

- [ ] **Test names describe behavior in plain English**

- [ ] **Complex logic is broken into named steps**

### 4.2 Test Readability

- [ ] **Tests follow Arrange-Act-Assert structure**

- [ ] **Test sections are organized**

- [ ] **Test data is minimal and meaningful**

---

## 5. Test Quality Assessment

### 5.1 Coverage

- [ ] **New code has corresponding tests**

- [ ] **Edge cases are tested**

- [ ] **Integration tests verify cross-component flows**

- [ ] **Negative cases are tested**

### 5.2 Test Hygiene

- [ ] **Tests clean up after themselves**

- [ ] **No test interdependence**

- [ ] **Test helpers reduce duplication without hiding intent**

### 5.3 Mutation Testing Discipline

- [ ] **Scoped-first mutation strategy was used**

- [ ] **Mutation results captured to artifacts**

- [ ] **No repeated full-run loops after survivors**

---

## 6. Spec Alignment (Nightshift RV)

### 6.1 Acceptance Criteria Coverage

- [ ] **Every AC item has a verification source**

- [ ] **No AC is silently skipped**

### 6.2 Technical Direction Coverage

- [ ] **Every TD constraint cites an AC**

- [ ] **Cited AC actually verifies the constraint**

- [ ] **Guidance divergence is not an ISSUE**

### 6.3 Scope Discipline

- [ ] **Implementation does not add behavior beyond AC**

- [ ] **Implementation does not silently narrow AC**

---

## 7. Mandatory: Overall Quality Rating

| Rating | Criteria |
|---|---|
| **Strong** | Clean architecture, thorough tests, no performance concerns, readable code. Minor polish only. |
| **Adequate** | Meets requirements, tests pass, no bugs. Some areas could be improved but nothing blocks. |
| **Needs Work** | Missing tests, unclear code, performance issues, architectural drift, **or any AC item without a verification source**. Return to implementation. |

**Rating:** [ ] Strong / [ ] Adequate / [ ] Needs Work
**Rationale:** _______________

---
