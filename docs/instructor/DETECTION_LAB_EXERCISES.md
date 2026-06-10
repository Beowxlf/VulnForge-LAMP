# Detection Lab Exercises

> **Instructor-only spoilers; authorized local lab only.** Generate evidence only in the isolated VulnForge-LAMP environment with fictional accounts. These exercises teach defensive correlation and do not provide monitoring-evasion, log-tampering, stealth, public scanning, malware, persistence, or destructive techniques.

## Exercise workflow

For each exercise, record the lab time window, source IP, account, request/response, `X-Request-ID` where available, Apache record, JSONL event, fake-audit result, Wazuh rule, and any evidence gap. Reset between cohorts when state matters.

---

# Exercise: Failed Login Burst Against Fake Accounts

| Field | Value |
|---|---|
| Related Flags | A07 context; A09 logging gap |
| Data Sources | Apache access log, `app_events.jsonl`, Wazuh, fake audit viewer |
| Difficulty | Easy |
| Goal | Validate threshold detection and document why the fake audit viewer is incomplete |

## Scenario

A learner reports repeated sign-in failures from one lab source. Determine what Wazuh can establish and what remains unknown.

## Actions to Generate Evidence

1. From one isolated-lab browser/source, submit five deliberately incorrect passwords to the local login form within two minutes using only fake `@northstar.local` identifiers.
2. Open the fake audit viewer after signing in normally and compare it with JSONL/Wazuh.
3. Stop after generating the configured threshold; do not automate or target any non-lab account.

## What to Look For

- Five `login_failure` JSON events with one `src_ip`.
- Rule 100501 for individual failures and 100502 when frequency/time conditions are met.
- Apache POSTs to `/?route=login`.
- No corresponding fake `audit_logs` rows and no submitted passwords/identifiers in JSONL.

## Wazuh Queries

```text
`data.event_type:"login_failure"`
```
```text
`rule.id:"100502"`
```
```text
`data.src_ip:"<lab-source-ip>" and data.event_type:("login_failure" or "login_success")`
```

## Expected Findings

Wazuh should identify repeated rejected attempts from one source. The finding must state that telemetry omits credentials and does not by itself prove automation or compromise.

## False Positives

Classroom typing errors, stale lab passwords, password-manager retries, or an instructor threshold test.

## Detection Improvement

Add safe target-account classification or a pseudonymous target ID, outcome reason, and rate-limit action; retain omission of raw credentials.

## Remediation Recommendation

Use rate limiting, MFA for privileged accounts, adaptive hashing, account protection, and complete protected authentication auditing.

---

# Exercise: Successful Default Credential Login

| Field | Value |
|---|---|
| Related Flags | `FLAG{A07_DEFAULT_ADMIN_01}` |
| Data Sources | Apache, `app_events.jsonl`, account configuration/database, dashboard response, Wazuh |
| Difficulty | Easy |
| Goal | Separate proof of successful admin authentication from proof that a default credential remains configured |

## Scenario

A successful admin login appears after setup. Decide whether it represents ordinary instructor use or unresolved factory credentials.

## Actions to Generate Evidence

1. Sign in once with the documented fictional admin credentials.
2. Capture the dashboard deployment notice and login event.
3. Compare the event with the seeded account/configuration state; never log the password in evidence.

## What to Look For

- `login_success` for `admin@northstar.local` with role admin.
- Apache login POST and dashboard GET.
- Admin-only default-setup marker in the response.
- No fake authentication audit row.

## Wazuh Queries

```text
`data.event_type:"login_success" and data.username:"admin@northstar.local"`
```
```text
`data.username:"admin@northstar.local"`
```

## Expected Findings

The event proves successful admin authentication; configuration/response evidence establishes that the factory setup remains active. Authorization of the human actor remains a separate question.

## False Positives

Authorized instructor administration and reset validation.

## Detection Improvement

Create a rule based on a secure “bootstrap credential unresolved” account attribute plus success, and correlate unexpected source or preceding failures.

## Remediation Recommendation

Require unique setup credentials, disable bootstrap accounts, use MFA and modern password hashing, and restrict admin access.

---

# Exercise: IDOR Invoice Access

| Field | Value |
|---|---|
| Related Flags | `FLAG{A01_INVOICE_IDOR_01}` |
| Data Sources | Browser response, Apache, JSONL, invoices database, fake audit table, Wazuh |
| Difficulty | Medium |
| Goal | Build a high-confidence object-authorization evidence chain |

## Scenario

An employee session requested invoice 1002, which belongs to another fictional employee.

## Actions to Generate Evidence

1. Sign in as Jordan Smith and open owned invoice 1001.
2. Request invoice 1002 once and capture the response.
3. Find `invoice_view` and `invoice_idor_suspected` by request ID.
4. Confirm ownership in the seeded database and inspect the fake audit row.

## What to Look For

- Rule 100504.
- Identity user 3 versus owner user 4.
- Successful response with Morgan Chen and the private note.
- Fake `invoice.view` row that records access but not the violation.

## Wazuh Queries

```text
`rule.id:"100504"`
```
```text
`data.event_type:"invoice_idor_suspected"`
```
```text
`data.request_id:"<request-id>"`
```

## Expected Findings

The combined chain proves a successful cross-owner response. The rule alone proves only an observed owner mismatch.

## False Positives

Legitimate delegated finance access in a differently designed production system; stale ownership data; instructor validation.

## Detection Improvement

Include target owner, policy decision, authorized role, and response outcome. Alert on any successful mismatch and test UI/API parity.

## Remediation Recommendation

Enforce owner/role authorization in the query or policy layer and add cross-account regression tests.

---

# Exercise: Admin Access Denied and Admin Access Anomaly

| Field | Value |
|---|---|
| Related Flags | `FLAG{A08_CLIENT_ROLE_TRUST_01}`; A01 admin-control context |
| Data Sources | Apache, JSONL, session/database role, Wazuh, fake audit viewer |
| Difficulty | Medium |
| Goal | Correlate an authorization denial with a later role-integrity anomaly |

## Scenario

A guest is denied the admin console, imports a profile, and then accesses the same console with an effective admin role.

## Actions to Generate Evidence

1. As guest, request `/?route=admin` and preserve the denial.
2. Import the minimal lab JSON with `role` set to `admin`.
3. Request the admin route again and capture the effective/stored role contradiction.
4. Compare JSONL and the fake audit viewer.

## What to Look For

- Rule 100503 on `admin_access_denied`.
- Rule 100508 on `profile_import`.
- Later `admin_access` for a database guest with message `effective_role=admin`.
- No fake audit record for import or privilege transition.

## Wazuh Queries

```text
`data.username:"guest@northstar.local" and data.event_type:("admin_access_denied" or "profile_import" or "admin_access")`
```
```text
`rule.id:("100503" or "100508")`
```

## Expected Findings

The sequence supports a high-confidence integrity-to-authorization finding when database role and response agree. A successful admin event alone is insufficient.

## False Positives

Legitimate admin users importing harmless preferences; an instructor intentionally demonstrating the challenge.

## Detection Improvement

Alert on stored-role/effective-role divergence and on non-admin identities accessing admin. Add import signature/schema decision fields.

## Remediation Recommendation

Derive role only from server-controlled identity, reject authorization fields in imports, and centralize admin policy checks.

---

# Exercise: Backup Directory Access

| Field | Value |
|---|---|
| Related Flags | `FLAG{A02_EXPOSED_BACKUP_01}` |
| Data Sources | Apache access log, Wazuh Apache decoder/rule, backup artifact |
| Difficulty | Easy |
| Goal | Investigate a direct web-server artifact access with no application telemetry |

## Scenario

Wazuh reports access to the exposed backup alias. Determine what was requested and what cannot be inferred.

## Actions to Generate Evidence

1. Open `/backup/` once and retrieve the seeded `.bak` file.
2. Find rule 100506 and the underlying Apache entries.
3. Verify that no JSONL or fake audit event exists because PHP was bypassed.

## What to Look For

- Directory and file GETs, source, status, user agent, and byte counts.
- Rule 100506 for `/backup`.
- Flag in the local response/artifact.
- No app identity or request ID.

## Wazuh Queries

```text
`rule.id:"100506"`
```
```text
`location:"/var/log/apache2/vulnforge_access.log" and url:"/backup/*"`
```

## Expected Findings

The alert proves path access. Response/artifact capture is needed to establish content disclosure; user identity is unavailable unless separately correlated.

## False Positives

Instructor validation, vulnerability scanner inside the authorized lab, or an accidental bookmark.

## Detection Improvement

Preserve status/bytes/filename and correlate source/time with later app events. Add coverage tests for alias paths.

## Remediation Recommendation

Remove the alias, store backups outside web roots, deny serving/indexing, and govern backup access and retention.

---

# Exercise: Diagnostics Abuse

| Field | Value |
|---|---|
| Related Flags | `FLAG{A02_VERBOSE_DIAGNOSTICS_02}`; `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}` |
| Data Sources | Apache, JSONL diagnostics event, Wazuh, browser response |
| Difficulty | Easy |
| Goal | Distinguish detailed information disclosure from bounded parser behavior and real command execution |

## Scenario

A source views detailed diagnostics and then uses the simulated command console.

## Actions to Generate Evidence

1. Request the normal and detailed diagnostics views.
2. Run `status;show marker` only in the bounded local console.
3. Compare rule 100505 with Apache-only command-console evidence.
4. Document explicitly that no OS shell API is involved.

## What to Look For

- `diagnostics_view` with `detail=true` in message metadata.
- Rule 100505.
- Apache command-console query and fixed two-line response.
- No command-console JSONL event and no host process evidence.

## Wazuh Queries

```text
`data.event_type:"diagnostics_view"`
```
```text
`rule.id:"100505"`
```
```text
`location:"/var/log/apache2/vulnforge_access.log" and url:"*route=command-console*"`
```

## Expected Findings

The diagnostics alert proves page processing; the console request proves only application-parser input. No evidence supports an OS-execution claim.

## False Positives

Routine health checks, helpdesk diagnostics, or instructor demonstrations.

## Detection Improvement

Add Boolean detail field and bounded operation ID/count. Keep detection wording precise and avoid “RCE” labels.

## Remediation Recommendation

Restrict/minimize diagnostics and replace free-form operation parsing with an authorized enum.

---

# Exercise: Product Search Suspicious Parameter Pattern

| Field | Value |
|---|---|
| Related Flags | `FLAG{A05_SQLI_CATALOG_01}` |
| Data Sources | Apache, JSONL, Wazuh, browser result count, products database |
| Difficulty | Medium |
| Goal | Separate a pattern indicator from confirmed SQL injection impact |

## Scenario

A catalog query matched the SQL-like metadata rule. Determine whether data disclosure occurred.

## Actions to Generate Evidence

1. Run one normal search and record result count.
2. Use the single minimal lab-only pattern from the instructor walkthrough.
3. Capture returned internal note or any query error.
4. Correlate `suspicious_parameter_pattern`, `product_search`, and optional exception.

## What to Look For

- Rule 100513 for SQL pattern.
- Result count/pattern metadata in `product_search`.
- Apache encoded query.
- Browser disclosure of the seeded internal note for confirmed impact.

## Wazuh Queries

```text
`rule.id:"100513"`
```
```text
`data.event_type:("suspicious_parameter_pattern" or "product_search" or "application_exception") and data.route:"products"`
```

## Expected Findings

Pattern match alone is suspicious behavior; changed results plus returned internal data is high-confidence exploitation evidence in the lab.

## False Positives

Users searching for text containing punctuation/security terminology, instructor validation, or malformed bookmarks.

## Detection Improvement

Correlate pattern class with result cardinality, query-template ID, error outcome, and challenge submission; test benign punctuation.

## Remediation Recommendation

Use bound parameters, omit internal fields from public result sets, use least database privilege, and normalize errors.

---

# Exercise: Profile Import Integrity Abuse

| Field | Value |
|---|---|
| Related Flags | `FLAG{A08_CLIENT_ROLE_TRUST_01}` |
| Data Sources | Apache, JSONL, Wazuh, session/database role, fake audit viewer |
| Difficulty | Medium |
| Goal | Detect an integrity failure that changes authorization context |

## Scenario

A non-admin profile import is followed by successful administrative access.

## Actions to Generate Evidence

1. Perform one harmless guest-role import as baseline.
2. Import the lab admin-role document and open admin.
3. Compare profile-import events; note that content is intentionally omitted.
4. Use database role and admin event message to establish divergence.

## What to Look For

- Rule 100508 on both accepted imports.
- `admin_access` with effective admin role for a stored guest.
- No fake audit entries for either transition.

## Wazuh Queries

```text
`rule.id:"100508"`
```
```text
`data.event_type:("profile_import" or "admin_access") and data.username:"guest@northstar.local"`
```

## Expected Findings

The import rule cannot distinguish harmless from privilege-bearing content. The correlated role contradiction establishes the security consequence.

## False Positives

Normal portability imports and instructor testing.

## Detection Improvement

Log allowed field names, schema/signature result, prior/stored/effective role, and policy source without storing the full document.

## Remediation Recommendation

Allow-list non-security preferences, verify provenance where needed, and never import role/permission authority.

---

# Exercise: Upload Activity

| Field | Value |
|---|---|
| Related Flags | `FLAG{A08_UNSIGNED_UPLOAD_META_02}` |
| Data Sources | Apache, `file_upload` JSONL, Wazuh, authorized filesystem inspection, optional future FIM |
| Difficulty | Easy |
| Goal | Investigate upload processing without assuming execution or malicious content |

## Scenario

A user uploads a harmless fictional text file and another client later accesses the upload directory.

## Actions to Generate Evidence

1. Sign in and upload a small non-sensitive `.txt` file created for the lab.
2. Find rule 100507 and the Apache POST.
3. Browse the upload alias and record the GET.
4. If FIM is later enabled by the instructor, correlate the resulting file event; do not add or execute scripts.

## What to Look For

- `file_upload` outcome, basename, and size; contents omitted.
- Rule 100507.
- Apache POST and direct GET.
- No execution because Apache disables PHP in the alias.

## Wazuh Queries

```text
`rule.id:"100507"`
```
```text
`data.event_type:"file_upload"`
```
```text
`location:"/var/log/apache2/vulnforge_access.log" and url:"/uploads/*"`
```

## Expected Findings

The event proves processing, not safety, authenticity, execution, or download. Filesystem/FIM and response evidence provide separate facts.

## False Positives

Normal document sharing, repeated uploads after filename mistakes, or instructor reset validation.

## Detection Improvement

Add stable file ID/hash, media classification, scan result, uploader, and download telemetry; correlate upload→FIM→download.

## Remediation Recommendation

Store outside served paths, generate names, validate/scan, authorize downloads, maintain server-side metadata, and retain no-execution controls.

---

# Exercise: A09 Logging-Gap Investigation

| Field | Value |
|---|---|
| Related Flags | `FLAG{A09_TAMPERABLE_LOG_01}`; `FLAG{A09_MISSING_AUDIT_EVENT_02}` |
| Data Sources | Apache, JSONL, database fake audit, exposed sample log, Wazuh |
| Difficulty | Hard |
| Goal | Build a source-by-source coverage and trust assessment |

## Scenario

An incident timeline appears incomplete. Determine whether events are missing, merely absent from the fake viewer, or present in a less trustworthy source.

## Actions to Generate Evidence

1. Generate one failed login, one successful login, one invoice view, and one profile import.
2. Compare Apache, JSONL, `/?route=logs`, and `/logs/app.log` for the same window.
3. Use `compare=1` to validate the challenge, but do not alter any log.
4. Document source owner, integrity, fields, coverage, and retention assumptions.

## What to Look For

- Apache has transport evidence for all web actions.
- JSONL has auth/import/invoice context, though selectively.
- Fake database audit has invoice access but omits auth/import.
- Exposed sample log has weak attribution and uncertain integrity.

## Wazuh Queries

```text
`location:"/var/log/vulnforge/app_events.jsonl"`
```
```text
`location:"/var/log/apache2/vulnforge_access.log"`
```
```text
`data.event_type:("login_failure" or "login_success" or "invoice_view" or "profile_import")`
```

## Expected Findings

The expected result is a coverage matrix, not a compromise declaration. Distinguish architecture gaps from failed collection by checking whether the source should have emitted an event.

## False Positives

Normal omissions by design, delayed collection, time-zone confusion, reset between observations, or a direct alias that bypasses PHP.

## Detection Improvement

Add source-health alerts, expected-event tests, protected forwarding, consistent request IDs, and completeness metrics for high-value workflows.

## Remediation Recommendation

Define a security audit schema, protect logs from web/application modification, centralize collection, and review alert coverage.

---

# Exercise: Flag Submission Burst

| Field | Value |
|---|---|
| Related Flags | All flags; especially validation after another exercise |
| Data Sources | Scoreboard Apache POSTs, `flag_submission_*` JSONL, Wazuh, submissions database |
| Difficulty | Easy |
| Goal | Interpret training-specific threshold alerts without treating them as real compromise |

## Scenario

Multiple incorrect flags are submitted rapidly, followed by an accepted flag.

## Actions to Generate Evidence

1. While signed in, submit six clearly invalid placeholder flags within two minutes.
2. Submit one flag already legitimately obtained during the local exercise.
3. Inspect rules 100510, 100511, and 100509 plus the submissions table.

## What to Look For

- Six failures from one source can trigger 100511.
- A success triggers 100509 with challenge ID but omits raw flag.
- Apache records scoreboard POSTs without form values.
- Database records only accepted submissions.

## Wazuh Queries

```text
`rule.id:("100509" or "100510" or "100511")`
```
```text
`data.event_type:("flag_submission_failure" or "flag_submission_success")`
```

## Expected Findings

The burst proves repeated unrecognized submissions under the configured threshold. It does not prove automated guessing or how an accepted flag was found.

## False Positives

Typos, case errors, learners pasting hints, classroom demonstrations, or retry after reset.

## Detection Improvement

Use user/session/challenge context, distinguish duplicate accepted submissions, and tune classroom thresholds separately from production analogues.

## Remediation Recommendation

Provide clear input validation and training feedback; this lab-specific workflow has no direct production remediation beyond secure telemetry handling.

---

# Exercise: Exception and Debug Leakage Investigation

| Field | Value |
|---|---|
| Related Flags | `FLAG{A10_VERBOSE_EXCEPTION_01}`; `FLAG{A10_API_ERROR_LEAK_02}` |
| Data Sources | Browser/API response, Apache, JSONL, Wazuh, application error context |
| Difficulty | Medium |
| Goal | Compare handled validation leakage with an explicit API 500 and avoid overclaiming |

## Scenario

Two malformed local requests produce application-exception alerts, but their HTTP status and client leakage differ.

## Actions to Generate Evidence

1. Request a product with a harmless non-numeric ID.
2. Request `/?route=api-invoice` without `id`.
3. Capture status/body/request ID for both.
4. Compare rule 100512 events and Apache status codes.

## What to Look For

- Both produce `application_exception` and rule 100512.
- Product path may retain HTTP 200 while leaking exception/path/marker.
- API path returns HTTP 500 JSON with file/line/marker.
- Neither appears in fake audit.

## Wazuh Queries

```text
`rule.id:"100512"`
```
```text
`data.event_type:"application_exception" and data.route:("product" or "api-invoice")`
```
```text
`data.http_status:500`
```

## Expected Findings

The event proves an instrumented exceptional path. Response evidence proves disclosure, and status differences expose error-handling quality issues.

## False Positives

Bad links, client integration bugs, manual QA, health checks, and instructor validation.

## Detection Improvement

Add handled/unhandled classification, explicit status, safe error code, operation, and request ID; alert on spikes and sensitive-route exceptions.

## Remediation Recommendation

Validate inputs, use correct 4xx responses, return generic error contracts, disable debug output, and keep details in protected server logs.

---

# Noise, Evidence, and Defensive Interpretation

- Fewer requests may produce fewer records and may not cross frequency thresholds. That is a limitation of volume-based detection, not advice to reduce visibility.
- Legitimate-looking routes can still carry malicious or unintended application behavior. A normal invoice, import, upload, diagnostics, or reset route must be interpreted with identity, target, policy, and outcome.
- Absence of an alert is not absence of activity. Verify collection health, decoder output, rule level, threshold state, source architecture, and whether PHP executed at all.
- Correlate Apache, `app_events.jsonl`, database state, fake audit records, response evidence, and Wazuh. No single source is complete.
- Low-volume testing may resemble ordinary use. Prefer semantic detection—owner mismatch, role contradiction, invalid workflow state, exception leakage—over assuming that request count equals intent.
- Fake in-app audit data is intentionally incomplete and potentially misleading. Preserve it as one evidence source, not the source of truth.
- Do not delete or edit logs, manipulate timestamps, spoof user agents to avoid detection, use proxy chains, or attempt any other monitoring-evasion behavior. Those actions are outside the lab objectives.

## Instructor debrief questions

1. Which fact is directly observed, and which conclusion is inferred?
2. What does the matching Wazuh rule prove and not prove?
3. Which source would remain available if the application failed before emitting JSONL?
4. Which event fields are missing for identity, target, authorization decision, and outcome?
5. Would the proposed detection identify the root behavior or only a literal lab flag/payload?
6. What secure design change prevents the issue even if monitoring fails?
