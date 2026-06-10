# Advanced Analyst Notes

> **Scope:** Authorized, isolated VulnForge-LAMP analysis only. The goal is disciplined defensive reasoning, not attack automation or monitoring evasion.

## 1. Think like an analyst, not just a flag hunter

A flag hunter asks, “How do I make the marker appear?” An analyst also asks:

1. What identity and session were in use?
2. Which request caused the state transition or disclosure?
3. What authorization, validation, integrity, or error-handling decision failed?
4. Which independent sources record the action?
5. Which facts are directly observed, and which are inferred?
6. Could normal use produce the same record?
7. What prevention and detection changes would reduce risk?

Capture the precondition, request, response, server-side state, telemetry, and timestamp before submitting the flag. The scoreboard proves only that a known string was accepted; it is not a substitute for explaining the weakness.

## 2. Confidence vocabulary

| Term | Meaning in this lab | Example |
|---|---|---|
| Indicator | A fact worth examining that is not inherently malicious. | A request to `/?route=diagnostics&detail=1`. |
| Suspicious behavior | Activity inconsistent with the expected workflow or requiring correlation. | One employee session requests another user's invoice. |
| High-confidence evidence | Multiple sources support a specific prohibited or unintended application outcome. | Apache request, `invoice_idor_suspected`, and the other owner's private note in the response. |
| Confirmed compromise | A justified conclusion that an unauthorized security impact occurred, with scope and identity established. | In this CTF, do not use this label merely because a flag was displayed; the application is intentionally vulnerable and all activity is authorized. |

Confidence should rise when independent sources agree. It should fall when a conclusion depends on a single client-controlled, incomplete, or tamperable record.

## 3. Build an evidence chain

Use a repeatable chain:

1. **Establish context:** VM, lab URL, time window, source IP, browser/session, and fake account.
2. **Record baseline:** expected page, visible objects, role, and relevant database ownership.
3. **Capture action:** method, route, parameters, status, response marker, and `X-Request-ID` when available.
4. **Preserve source evidence:** Apache line, JSONL event, fake audit row, database row, and Wazuh alert.
5. **Correlate:** prefer `request_id`; otherwise use a narrow timestamp, source IP, method, route, user, and target object.
6. **Explain the control failure:** distinguish transport success from failed authorization or validation.
7. **State gaps:** identify what was not logged, what was client-controlled, and what remains an inference.
8. **Conclude proportionally:** describe the demonstrated lab impact without claiming broader access.

A useful chain for invoice IDOR is: signed-in user → numeric invoice request → successful response containing a different owner → owner-mismatch JSONL event → Apache request → database ownership confirmation → accepted flag submission.

## 4. Distinguish the evidence sources

| Source | What it can establish | Important limitation |
|---|---|---|
| Browser-visible data | What the client rendered, including a flag or debug detail. | A screenshot may omit the exact request, identity, or server-side cause. |
| Server-side state | Session values, effective role, file presence, and application decisions. | Usually requires authorized white-box inspection and may change after reset. |
| Database state | Object ownership, seeded values, audit rows, and submissions. | Database presence alone does not prove that a user received the value over HTTP. |
| Apache access/error logs | Request path, query string, method, status, source, user agent, and server errors. | Apache sees transport facts, not application intent or object ownership. |
| Application JSONL telemetry | Sanitized event type, route, identity, role, outcome, request ID, and selected context. | Coverage is selective; parameters and sensitive values are intentionally omitted. |
| Wazuh alerts | A collected event matched a decoder/rule under a given configuration. | An alert is a rule result, not automatic proof of exploitation or impact. |
| Fake in-app audit records | What the deliberately incomplete application audit feature claims happened. | It omits sensitive events, weakly attributes some records, and is part of the A09 lesson. |

Treat the web-visible `/logs/app.log` as a lab artifact, not authoritative host telemetry. It is intentionally exposed and weakly protected. Do not alter it during exercises.

## 5. Why A09 matters

### Missing logs

Authentication failures, profile imports, and effective-role changes do not enter the fake `audit_logs` table. Their absence can prevent reconstruction even though Apache or JSONL records exist.

### Misleading logs

A line such as “authentication complete” lacks actor, source, target, and outcome. It can create false confidence while supporting no useful conclusion.

### Tamperable logs

An application-accessible or weakly permissioned log has reduced evidentiary value because integrity and custody are uncertain. The safe lesson is to recognize this weakness, not to demonstrate modification.

### Access without intent

Apache can prove that a diagnostics or invoice URL was requested. It cannot by itself prove that the requester understood the weakness, saw a flag, or intended abuse. Application context and response evidence are needed.

A logging control is effective only when useful events are generated, protected, collected, normalized, alerted on appropriately, retained, and reviewed.

## 6. Write a finding

Use this structure:

- **Summary:** one sentence describing the failed control and demonstrated local impact.
- **Affected route:** exact method and route, including the relevant parameter name but no unnecessary secret values.
- **Impact:** what unauthorized disclosure, action, or loss of assurance was demonstrated in the fictional lab.
- **Evidence:** request/response, screenshot, request ID, Apache line, JSONL event, database ownership, and Wazuh rule as applicable.
- **Reproduction in lab:** concise prerequisites and bounded steps against the local application.
- **OWASP mapping:** the seeded A01–A10 category; add CWE only when the root cause fits.
- **Remediation:** server-side design and implementation changes, plus test coverage.
- **Detection opportunity:** event fields, rule logic, correlation, expected false positives, and evidence gaps.

Separate facts from inference. For example: “The response displayed invoice 1002's private note” is observed; “the actor exported all finance records” is unsupported unless additional evidence exists.

## 7. Avoid overclaiming

- **“Wazuh alert observed” does not automatically mean compromise.** It proves that collected data matched a configured rule. Validate the underlying event and outcome.
- **“Apache request observed” does not automatically mean exploitation.** A request may be ordinary navigation, a failed attempt, instructor validation, or an automated health check.
- **“Flag found” proves the lab condition, not a real-world breach.** Flags are intentionally seeded markers and may be visible in source or database during white-box review.
- A successful HTTP status does not necessarily prove sensitive content was returned.
- A database marker does not prove remote access to that marker.
- No Wazuh alert does not prove no activity occurred; collection, decoding, rule coverage, thresholds, and source gaps all matter.

## 8. Compare black-box and white-box evidence

**Black-box evidence** comes from permitted application interaction: links, requests, responses, cookies, visible files, and behavior differences. It best represents what a player can demonstrate remotely inside the lab, but may leave root cause uncertain.

**White-box evidence** comes from code, SQL seed data, Apache configuration, filesystem permissions, Wazuh rules, and database queries. It can confirm the exact failed condition and logging path, but code visibility alone does not prove exploitability through the deployed application.

Use both: black-box evidence demonstrates reachable impact; white-box evidence confirms why it occurred and how to remediate it. If they disagree, check deployment state, reset status, route changes, account ownership, and whether the request reached the expected host.

## 9. Turn a CTF solve into a SOC detection

1. Define the security-relevant behavior, not the literal flag string.
2. Identify the strongest event source and the fields needed for identity, target, action, outcome, and correlation.
3. Decide whether a single event is sufficient or a sequence is required.
4. Create a rule or dashboard hunt that is specific enough to be actionable.
5. Document benign explanations and expected training noise.
6. Generate one positive and one negative local test.
7. Verify decoding and rule behavior with `wazuh-logtest` where applicable.
8. State what the detection proves and which evidence must be collected next.

Example: detect an authenticated invoice owner mismatch, not the appearance of `FLAG{A01_INVOICE_IDOR_01}`. Correlate the mismatch with the same `request_id`, Apache response, authenticated role, and later flag submission.

## 10. Turn a CTF solve into a developer remediation ticket

A useful ticket describes a failed invariant. For invoice access: “Every invoice read must authorize the authenticated user against the invoice owner or an explicitly approved finance role.” Include:

- the affected controller/route and data object;
- current behavior and expected behavior;
- a minimal local reproduction;
- security and business impact;
- acceptance criteria for unauthorized, authorized, and not-found cases;
- unit/integration tests that prevent regression;
- required audit fields and correlation ID;
- rollout considerations, including avoiding sensitive response or log content.

Do not write “fix security” or prescribe logging as the sole remedy. Detection provides visibility; it does not replace access control, validation, integrity checks, safe authentication, or exception handling.
