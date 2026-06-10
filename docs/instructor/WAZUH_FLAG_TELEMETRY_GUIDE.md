# Wazuh Flag Telemetry Guide

> **Instructor-only spoilers; authorized local lab use only.** This guide explains defender visibility, not how to avoid it. A Wazuh alert is a rule match that must be correlated with underlying evidence.

## Coverage assumptions

This matrix assumes the optional collection blocks and manager rules in `wazuh/` are installed as described in the repository Wazuh guide. Direct Apache aliases (`/backup/`, `/uploads/`, and `/logs/`) do not execute PHP and therefore cannot emit `app_events.jsonl`. The fake audit source is either the database-backed `/?route=logs` viewer or the exposed sample `/logs/app.log`; neither is equivalent to protected host telemetry.

Field names can vary by Wazuh/indexer version. Expand a known event first and verify the local schema before saving filters.

## Per-flag coverage matrix

| Flag | Route | Expected Apache Evidence | Expected `app_events.jsonl` Evidence | Expected Fake Audit Evidence | Expected Wazuh Rule/Alert | Evidence Gap |
|---|---|---|---|---|---|---|
| `FLAG{A01_INVOICE_IDOR_01}` | `/?route=invoice&id=1002` or `api-invoice&id=1002` | Successful GET with target ID | `invoice_view` plus `invoice_idor_suspected`, identity, owner mismatch, request ID | `invoice.view` only on UI route; it does not label the mismatch | `100504` possible IDOR | Alert does not preserve response body or prove the flag was rendered; fake audit is misleadingly ordinary |
| `FLAG{A01_ADMIN_TICKET_BYPASS_02}` | `/?route=ticket&id=3&preview=admin` | Denied baseline and successful preview request | `support_ticket_view` with denied/success outcome | None | No dedicated rule; base `100500` match is level 0 | Event omits owner/admin-only fields and bypass reason, so unauthorized success requires database/role correlation |
| `FLAG{A02_EXPOSED_BACKUP_01}` | `/backup/`, `/backup/northstar-backup.sql.bak` | Directory/file GET, status, source, bytes | None | None | `100506` backup access | Direct serving has no application identity, request ID, or proof that content was read |
| `FLAG{A02_VERBOSE_DIAGNOSTICS_02}` | `/?route=diagnostics&detail=1` | GET includes `detail=1` | `diagnostics_view`; message states `detail=true` | None | `100505` diagnostics viewed | Event does not capture leaked response; current event carries A05 telemetry tag although challenge is seeded as A02 |
| `FLAG{A03_OUTDATED_PACKAGE_DOC_02}` | Local `app/vendor/.../README.md`; optional portal context | Optional `vendor-demo`/`changelog` GET only | None | None | No dedicated rule | Local repository file read is outside web telemetry; package inventory/SBOM is the appropriate source |
| `FLAG{A03_UNSAFE_HELPER_OUTPUT_01}` | `/?route=vendor-demo&debug=1` | GET includes debug control | None | None | No dedicated rule | Apache proves request, not returned banner; no package-debug event |
| `FLAG{A04_WEAK_ENCODING_01}` | `/?route=profile`, then offline decode | Profile GET | None for view | None | No dedicated rule | Logs cannot prove the client decoded Base64; profile-export telemetry is absent |
| `FLAG{A04_WEAK_HASH_PROFILE_02}` | Login as Morgan, then `/?route=profile` | Login POST and profile GET | `login_success`; no profile-view event | Authentication omitted | No dedicated success rule | Telemetry proves authentication, not MD5 storage or biography response |
| `FLAG{A05_SQLI_CATALOG_01}` | `/?route=products&q=...` | Encoded search query, status | `suspicious_parameter_pattern`, `product_search`; optional `application_exception` | None | `100513`; optional `100512` | Pattern alert does not prove successful SQL semantic change or returned internal note |
| `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}` | `/?route=command-console&check=...` | GET includes bounded operation chain | None | None | No dedicated rule | No application semantic event; Apache must not be misread as OS command execution |
| `FLAG{A06_REFUND_LOGIC_01}` | `POST /?route=refund` | POST and status; form values absent | `refund_request`, values omitted | None | No dedicated rule | Event cannot distinguish positive from negative quantity or show computed outcome |
| `FLAG{A06_PREDICTABLE_RESET_02}` | `POST /?route=password-reset` | GET/POST and status; token absent | `password_reset_request`, `password_reset_complete` success/failure | None | No dedicated rule | Target, issuance, token lifecycle, and password-change state are omitted |
| `FLAG{A07_DEFAULT_ADMIN_01}` | Login then dashboard | Admin login POST and dashboard GET | `login_success` with admin identity/role | Authentication omitted | No dedicated successful-default-login rule | Event does not prove which password was used or whether actor was authorized |
| `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}` | Remember cookie then dashboard | Dashboard GET; cookie generally absent from combined log | No restoration event; later events show restored identity | None | No dedicated rule | Original identity, cookie validation, and reason for restoration are invisible |
| `FLAG{A08_CLIENT_ROLE_TRUST_01}` | `POST /?route=profile-import`, then admin | Import POST and admin GET | `profile_import`, then `admin_access` with effective-role message | Import/role change omitted | `100508` for import; no dedicated admin anomaly | Import body omitted; sequence and role contradiction are needed to prove consequence |
| `FLAG{A08_UNSIGNED_UPLOAD_META_02}` | `/uploads/`, `/uploads/welcome.txt` | Directory/file GET | None for seeded read; `file_upload` only for new POST | None | `100507` only for upload events | Direct reads lack app identity; no download/provenance event; no FIM unless separately enabled |
| `FLAG{A09_TAMPERABLE_LOG_01}` | `/logs/`, `/logs/app.log` | Directory/file GET | None | The exposed file itself is weak evidence; database viewer is separate | No dedicated rule | Read evidence does not prove tampering; file integrity and permissions need host evidence |
| `FLAG{A09_MISSING_AUDIT_EVENT_02}` | Login/import comparison, then `/?route=logs&compare=1` | Requests exist across compared sources | Login/import events may exist; no compare-view event | Expected login/import/role rows are absent | `100501/100502`, `100508` as applicable | Absence must be separated from collection failure; even JSONL is intentionally incomplete |
| `FLAG{A10_VERBOSE_EXCEPTION_01}` | `/?route=product&id=demo` | GET; may show status 200 despite exception page | `application_exception`, route `product` | None | `100512` application exception | Alert omits leaked response and may carry misleading default status |
| `FLAG{A10_API_ERROR_LEAK_02}` | `/?route=api-invoice` without `id` | GET with HTTP 500 | `application_exception`, route, A10, status 500 | None | `100512` application exception | Alert does not contain leaked JSON file/line/debug marker |

## Useful Wazuh Dashboard Filters

Confirm exact quoting and field mapping in the installed dashboard.

```text
agent.name:<vulnforge-agent>
```

The repository examples use `northstar-lab` as a sample agent name:

```text
agent.name:"northstar-lab"
```

```text
data.app:"northstar-vulnforge"
```

Some environments may alias or normalize this as `data.app:vulnforge`; inspect a decoded event before relying on the shorter value.

```text
data.event_type:"login_failure"
```

```text
data.event_type:"invoice_idor_suspected"
```

```text
data.event_type:"flag_submission_success"
```

```text
rule.groups:"vulnforge"
```

```text
location:"/var/log/vulnforge/app_events.jsonl"
```

```text
location:"/var/log/apache2/vulnforge_access.log"
```

Useful compound pivots:

```text
data.src_ip:"<lab-source-ip>" and data.event_type:("login_failure" or "login_success")
```

```text
data.request_id:"<request-id>"
```

```text
rule.id:("100504" or "100508" or "100512" or "100513")
```

```text
data.username:"guest@northstar.local" and data.event_type:("profile_import" or "admin_access")
```

## Alert Interpretation

### `login_failure` — rules 100501 and 100502

- **Proves:** the application rejected an authentication attempt; rule 100502 proves at least the configured frequency from one decoded `src_ip` within the timeframe.
- **Does not prove:** the submitted identifier/password, an automated tool, intent, account compromise, or that a later success used the guessed credential.
- **Pivot next:** same source and narrow time window; Apache login POSTs; later `login_success`; target-account context if a future safe field is added; fake-audit omission.

### `login_success`

- **Proves:** the application created an authenticated session for the recorded fictional identity.
- **Does not prove:** which password was used, that it was a default credential, or that the actor was unauthorized.
- **Pivot next:** preceding failures, source/user baseline, dashboard/admin activity, remembered-session context, and account configuration state.

### `invoice_idor_suspected` — rule 100504

- **Proves:** requested invoice owner differed from the session user according to application/database context.
- **Does not prove:** response body contents, user intent, or access to additional invoices.
- **Pivot next:** same `request_id` `invoice_view`, Apache request/status, database owner, response capture, and subsequent flag submission.

### `admin_access_denied` — rule 100503

- **Proves:** the application denied an admin-console request for the recorded identity.
- **Does not prove:** hostile intent or a successful bypass.
- **Pivot next:** later `admin_access`, preceding `profile_import`, role/effective-role mismatch, source, and Apache sequence.

### `admin_access`

- **Proves:** the application rendered the admin route and recorded an effective role in the message.
- **Does not prove:** whether authority came from a legitimate stored admin role, imported role, or query bypass without further context.
- **Pivot next:** database role, `profile_import`, prior denial, event message, and response evidence.

### `diagnostics_view` — rule 100505

- **Proves:** diagnostics was rendered and the application recorded whether detailed output was requested.
- **Does not prove:** which fields the user saw or that disclosure was used.
- **Pivot next:** Apache query string, response capture, adjacent `application_exception`, source/identity, and frequency.

### `suspicious_parameter_pattern` — rule 100513 for SQL-like metadata

- **Proves:** sanitized parameter metadata matched a configured pattern class.
- **Does not prove:** injection succeeded, a database error occurred, or data was returned.
- **Pivot next:** `product_search` result count, `application_exception`, Apache query, browser response, and later A05 submission.

### `profile_import` — rule 100508

- **Proves:** the application accepted or rejected an import for the recorded identity.
- **Does not prove:** the document’s content or a privilege change because the body is omitted.
- **Pivot next:** `admin_access`, database role, effective-role message, Apache sequence, and fake-audit gap.

### `file_upload` — rule 100507

- **Proves:** the application processed a file upload and records outcome, sanitized basename, and size.
- **Does not prove:** file safety, authenticity, execution, or later download.
- **Pivot next:** Apache POST, authorized filesystem inspection, scanning result, later `/uploads/` GET, and a FIM event if FIM is later enabled.

### `application_exception` — rule 100512

- **Proves:** the application entered an instrumented exception/error path.
- **Does not prove:** client-visible leakage, exploit success, or malicious intent.
- **Pivot next:** route/status, Apache response, request ID, error log, repeated source, and the exact safe response capture.

### `flag_submission_success` — rule 100509

- **Proves:** a known flag value was accepted for the recorded lab user and challenge ID.
- **Does not prove:** how the user obtained it, whether the intended vulnerability was exercised, or any real compromise.
- **Pivot next:** preceding route-specific evidence, challenge ID, source, session identity, and instructor validation notes.

### `flag_submission_failure` and burst rule 100511

- **Proves:** one or, for 100511, the configured burst of unrecognized flag submissions occurred.
- **Does not prove:** malicious guessing, automation, or access to challenge data.
- **Pivot next:** same source/user, accepted submissions, scoreboard POSTs, classroom activity window, and duplicate/user-error explanations.

## Correlation Ideas

1. **Same `src_ip` across `login_failure` and `login_success`:** establish sequence and identity, but do not assume the successful password was guessed without additional evidence.
2. **`invoice_idor_suspected` followed by `flag_submission_success`:** narrow by user/source/time and challenge ID; use response/database evidence to validate intended solve.
3. **`diagnostics_view` followed by `application_exception`:** determine whether a user moved from environment discovery to an error path; either event may still be benign lab exploration.
4. **Backup access followed by successful flag submission:** join Apache source/time to JSONL source/time because direct alias access has no request ID or app event.
5. **Upload event followed by file-integrity event if FIM is later enabled:** compare stable file identifier/path/hash and separate expected lab uploads from unapproved change.
6. **Missing fake audit record despite Apache evidence:** confirm JSONL collection health, then document whether the gap is limited to fake audit or affects all application telemetry.
7. **`profile_import` followed by `admin_access`:** compare database role with effective-role message to identify an integrity-to-authorization transition.
8. **Detailed diagnostics or API error followed by A10 submission:** use response capture to prove disclosure; the submission alone does not prove the route used.
9. **Failed flag burst followed by success:** distinguish typo correction/classroom behavior from systematic guessing by checking challenge context and timing.
10. **Direct `/logs/` access plus no application event:** recognize expected architecture; do not call it collection failure when PHP never ran.

## Evidence-quality checklist

Before escalating a lab alert, record:

- agent and source location;
- event time and time-zone basis;
- `src_ip`, username/user ID, role, and effective role if different;
- method, route, status, target object, and request ID where available;
- underlying raw Apache/JSONL event;
- database ownership/state when authorization or workflow logic matters;
- response evidence or server-side state proving impact;
- fake-audit presence or absence;
- collection/rule coverage gaps; and
- a proportional conclusion that does not equate a CTF flag with real-world compromise.
