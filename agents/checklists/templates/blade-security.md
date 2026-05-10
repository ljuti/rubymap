---
type: checklist
name: blade-security
description: "Security review — Critical/High findings block approval"
phase: RV
agent: blade

placeholders:
  - key: project_name
  - key: stack_description
  - key: security_scanner_command
  - key: security_scanner
  - key: dependency_audit_command

---

# Security Review Checklist

> Security items REQUIRE annotations explaining what was verified.
> Critical/High findings block approval. All items must have an annotation.

---

## Review Depth Guidance

Select review depth based on the type of change. Apply ALL checklist sections at the indicated depth.

| Change Type | Depth | What It Means |
|---|---|---|
| New endpoint or handler exposing data | **Full** | Every section, every item. Annotate all. |
| New data model with validations/hooks | **Full** | Every section, every item. Annotate all. |
| Data isolation or scoping changes | **Full + Escalate** | Full review. Flag for design agent if boundaries are affected. |
| Schema migration adding columns or tables | **Standard** | Focus on data exposure, constraints, placement. |
| UI template changes | **Standard** | Focus on XSS, CSP, output encoding, CSRF presence. |
| Client-side code changes | **Standard** | Focus on XSS, DOM injection, data flow. |
| Shared module refactoring | **Targeted** | Focus on authorization logic preservation, no new surface area. |
| Test-only changes | **Targeted** | Verify no secrets in test data, no test-only backdoors. |
| Config/initializer changes | **Full** | Focus on secrets, CSP, CORS, SSL, filter parameters, host auth. |
| Dependency changes | **Full** | Vulnerability audit, CVE check, license review, supply chain risk. |


---

## 1. Mandatory: Data Isolation and Access Control


- [ ] **[CRITICAL] Primary isolation mechanism prevents boundary violations**

- [ ] **[CRITICAL] New data types are placed in the correct isolation scope**

- [ ] **[CRITICAL] No cross-boundary query leakage**

- [ ] **[HIGH] Boundary identifiers are validated against injection**

- [ ] **[HIGH] Boundary identifiers are immutable after creation**

- [ ] **[MEDIUM] Global/shared data does not leak scoped information**

- [ ] **[MEDIUM] Background jobs preserve scope context**

---

## 2. Conditional: Authentication and Authorization

> Apply this section when the change involves authenticated routes or authorization logic.
> If authentication is not yet implemented, annotate items as `N/A (auth not yet implemented)`.

- [ ] **[CRITICAL] Authentication is enforced on all protected routes**

- [ ] **[CRITICAL] Users can only access their authorized scope**

- [ ] **[HIGH] Administrative routes require elevated authorization**

- [ ] **[HIGH] Session fixation is prevented**

- [ ] **[MEDIUM] Credentials are stored securely**

---

## 3. Mandatory: Injection Risks

- [ ] **[CRITICAL] No raw queries with string interpolation**

- [ ] **[HIGH] Finder/query methods use safe parameter styles**

- [ ] **[HIGH] No command injection via shell execution**

- [ ] **[HIGH] XSS prevention in output templates**

- [ ] **[MEDIUM] Dynamic content responses do not inject unsanitized content**

---

## 4. Mandatory: Request Forgery Protection

- [ ] **[HIGH] CSRF protection is enabled on state-changing endpoints**

- [ ] **[HIGH] CSRF tokens are present in all layouts/forms**

- [ ] **[MEDIUM] API endpoints use token-based auth, not cookie-based**

---

## 5. Mandatory: Input Validation and Mass Assignment

- [ ] **[HIGH] All endpoints use explicit input allowlists**

- [ ] **[HIGH] Sensitive attributes are not user-assignable**

- [ ] **[MEDIUM] Nested/complex input uses explicit allowlists**

---

## 6. Mandatory: Sensitive Data Exposure

- [ ] **[HIGH] Log filtering covers all sensitive fields**

- [ ] **[HIGH] No secrets in source code, seeds, or test fixtures**

- [ ] **[HIGH] Error responses do not leak internal details in production**

- [ ] **[MEDIUM] Data files are not web-accessible**

- [ ] **[MEDIUM] Production logs do not contain sensitive data at default log level**

---

## 7. Mandatory: Transport and Session Security

- [ ] **[HIGH] TLS is enforced in production**

- [ ] **[HIGH] Secure cookie flags are set**

- [ ] **[MEDIUM] Host authorization is configured**

- [ ] **[LOW] HSTS headers are sent**

---

## 8. Mandatory: Content Security Policy

- [ ] **[MEDIUM] CSP is enabled and configured**

- [ ] **[MEDIUM] Inline script protection is active**

- [ ] **[LOW] CSP violation reporting is configured**

---

## 9. Mandatory: Dependency Security

- [ ] **[HIGH] Dependency audit reports no known vulnerabilities**

- [ ] **[HIGH] Security scanner reports no warnings**

- [ ] **[MEDIUM] New dependencies are reviewed for trust and necessity**

- [ ] **[MEDIUM] Client-side dependencies are pinned to specific versions**

---

## 10. Mandatory: Error Handling and Fail-Secure Behavior

- [ ] **[HIGH] Scope resolution failure returns safe response (404, not 500)**

- [ ] **[HIGH] Framework-level security errors are handled gracefully**

- [ ] **[MEDIUM] Rescue/catch blocks do not swallow security-relevant errors**

---

## Review Verdict

| Verdict | Criteria |
|---|---|
| **APPROVED** | Zero Critical/High findings. All items annotated. |
| **APPROVED WITH NOTES** | Zero Critical/High findings. Medium/Low items noted for refinement. |
| **BLOCKED** | Any Critical or High finding present. Must return to implementation. |
| **ESCALATE** | Isolation boundary or architectural concern. Consult design agent. |

**Reviewer:** _______________
**Date:** _______________
**Verdict:** [ ] APPROVED / [ ] APPROVED WITH NOTES / [ ] BLOCKED / [ ] ESCALATE
