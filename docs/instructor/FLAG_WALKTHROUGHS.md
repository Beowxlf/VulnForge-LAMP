# Flag Walkthroughs

> **INSTRUCTOR-ONLY SPOILERS:** This document reveals all 20 exact flags and intended solution paths. Use only in the isolated VulnForge-LAMP lab with fictional accounts and data. It contains no authorization for testing any other system.

Each walkthrough separates application behavior from evidence interpretation. Wazuh notes assume the optional repository configuration is installed; rule firing still depends on collection, decoding, manager configuration, and thresholds. The fake in-app audit viewer is intentionally incomplete and must not be treated as authoritative host telemetry.

For SQL injection background, consult the authorized-testing references in [REFERENCES.md](REFERENCES.md); this guide uses only one minimal, lab-specific pattern and does not reproduce payload catalogs.

---

# Challenge: Someone Else’s Invoice

| Field | Value |
|---|---|
| Flag | `FLAG{A01_INVOICE_IDOR_01}` |
| OWASP Category | A01:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=invoice&id=1002` (or `/?route=api-invoice&id=1002`) |
| Required Role/Account | Any signed-in non-owner; `j.smith@northstar.local` is the clearest baseline |
| Primary Weakness | Object lookup by invoice ID without an ownership authorization check |
| Related CWE if known | CWE-639 (Authorization Bypass Through User-Controlled Key) |
| Expected Evidence Sources | Browser response, Apache, JSONL app telemetry, fake audit table, invoice database row, Wazuh |
| Detection Opportunity | Correlate a successful invoice view with `invoice_idor_suspected` for the same request and user |
| Remediation Theme | Enforce object-level authorization on every invoice read |

## 1. Objective

Demonstrate that an authenticated employee can retrieve invoice 1002, owned by a different fictional user, and observe its private note containing the flag.

## 2. What the Player Sees

The **My invoices** page lists only records assigned to the current account, but invoice detail links contain numeric `id` values. Nearby IDs are plausible local objects.

## 3. What Is Actually Happening

The detail controller loads an invoice solely by `invoices.id`. It records a normal invoice view and detects an owner mismatch in telemetry, but it does not deny the response. Invoice 1002 belongs to user 4 and its `private_note` stores the flag.

## 4. Step-by-Step Lab Walkthrough

1. Sign in as `j.smith@northstar.local` / `smith123` and open **Invoices**; note that invoice 1001 is the account-owned record.
2. Open invoice 1001 and record the request shape and account holder.
3. In the same local browser session, change only `id=1001` to `id=1002`.
4. Confirm that the page still returns successfully, identifies Morgan Chen as account holder, and displays `Cross-account marker: FLAG{A01_INVOICE_IDOR_01}`.
5. For instructor validation, correlate the response with the invoice owner in the seeded database and the owner-mismatch JSONL event.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A successful GET to `/?route=invoice&id=1002`; the response names another account holder and includes the private note.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A01_INVOICE_IDOR_01}` when the challenge condition is met.
- **Database/server-side evidence:** `invoices.id=1002` has `user_id=4`; the active Jordan Smith account has `id=3`.
- **Apache visibility:** The access log records the GET, query string, source, status, and user agent, but not invoice ownership.
- **`/var/log/vulnforge/app_events.jsonl`:** `invoice_view` and `invoice_idor_suspected` share the request ID; the latter includes invoice and owner IDs plus the session identity.
- **Fake in-app audit visibility:** An `invoice.view` row is inserted even for the cross-account read, but it does not explicitly label the authorization violation.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `invoice_idor_suspected` (plus `invoice_view`)
- **Likely route:** `invoice` or `api-invoice`
- **Likely rule/group:** Rule `100504`, “Northstar invoice owner mismatch / possible IDOR,” group `idor,authorization`
- **Sample dashboard query:** ``data.event_type:"invoice_idor_suspected" and data.route:"invoice"``
- **What the alert proves:** The application observed a requested invoice whose owner differed from the authenticated user.
- **What the alert does not prove:** By itself it does not prove which response content the browser rendered, the user’s intent, or broader invoice access.

## 7. Noise and Detection-Awareness Notes

Normal invoice reads generate `invoice_view`; only owner mismatches generate the higher-confidence event. Repeated sequential requests are noisier, but one mismatch is enough to validate the defect. Defenders should correlate identity, invoice owner, response status, request ID, and any later flag submission. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Testing while signed in as the invoice owner, citing only the numeric URL, or treating the fake `invoice.view` audit row as proof that authorization succeeded correctly.

## 9. Remediation

Load invoices through an authorization-scoped query such as owner plus ID, or apply a centralized policy before rendering. Return a consistent denial/not-found response, test cross-account cases, and audit actor, target owner, decision, and outcome.

## 10. Detection Engineering Improvement

Keep the owner-mismatch event, add explicit authorization decision and response outcome, and alert on any successful mismatch. Join `request_id` to Apache and distinguish UI versus API routes.

## 11. Analyst Takeaway

A successful transport request is not the key fact; the evidence becomes high confidence when authenticated identity, database ownership, returned private data, and owner-mismatch telemetry agree.

---

# Challenge: Restricted Support Preview

| Field | Value |
|---|---|
| Flag | `FLAG{A01_ADMIN_TICKET_BYPASS_02}` |
| OWASP Category | A01:2025 |
| Difficulty | Medium |
| Route/Page | `GET /?route=ticket&id=3&preview=admin` |
| Required Role/Account | Any signed-in non-admin; `guest@northstar.local` is suitable |
| Primary Weakness | A client-controlled preview parameter is accepted as an authorization condition |
| Related CWE if known | CWE-862 (Missing Authorization Check) |
| Expected Evidence Sources | Browser response, Apache, JSONL app telemetry, support-ticket database row, Wazuh base event |
| Detection Opportunity | Compare denied and successful views of the same restricted ticket by a non-admin |
| Remediation Theme | Remove client-controlled authorization shortcuts and enforce server-side policy |

## 1. Objective

Show that a non-admin can use the local preview control to view restricted support ticket 3 and its internal-note flag.

## 2. What the Player Sees

The normal support queue shows only the signed-in user’s non-admin tickets. Direct access to ticket 3 is denied, establishing a useful baseline.

## 3. What Is Actually Happening

The route permits access when the ticket belongs to the user, the database role is admin, **or** `preview=admin` is supplied. The last condition treats untrusted query data as authority. Ticket 3 contains the A01 flag.

## 4. Step-by-Step Lab Walkthrough

1. Sign in as the guest or employee account and request `/?route=ticket&id=3`; preserve the denied response.
2. Repeat the same local request with `&preview=admin`.
3. Confirm the restricted “Admin migration incident” ticket renders and its internal update contains `FLAG{A01_ADMIN_TICKET_BYPASS_02}`.
4. Compare the two Apache records and JSONL `support_ticket_view` outcomes.
5. Confirm from the seed data that ticket 3 is `admin_only=1` and owned by the admin user.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Two nearly identical requests differ only by `preview=admin`; the latter returns the restricted ticket and flag.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A01_ADMIN_TICKET_BYPASS_02}` when the challenge condition is met.
- **Database/server-side evidence:** Support ticket 3 is owned by user 1 and marked `admin_only=1`.
- **Apache visibility:** Both denied and successful requests, including the preview query parameter, are visible.
- **`/var/log/vulnforge/app_events.jsonl`:** `support_ticket_view` records `denied` then `success`, with the non-admin identity; it does not label this specific bypass as an A01 event.
- **Fake in-app audit visibility:** No fake `audit_logs` row is created for support-ticket access.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `support_ticket_view`
- **Likely route:** `ticket`
- **Likely rule/group:** No dedicated custom rule; base rule `100500` recognizes the JSON event but level 0 may not create a stored alert
- **Sample dashboard query:** ``data.event_type:"support_ticket_view" and data.route:"ticket"``
- **What the alert proves:** The application recorded a denied or successful support-ticket view for the stated identity.
- **What the alert does not prove:** A success event alone does not prove the ticket was unauthorized; ownership, role, target ID, and request parameter require correlation.

## 7. Noise and Detection-Awareness Notes

Ordinary support use produces successful view events. The suspicious signal is a non-owner/non-admin success, especially after a denial. Low-volume validation may resemble a legitimate link click, so defenders need target ownership and authorization-decision fields rather than request-count thresholds alone. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Skipping the denied baseline, using the real admin account, or claiming the success event itself identifies the preview bypass.

## 9. Remediation

Authorize ticket access from server-maintained identity and explicit support roles. Ignore or remove `preview` as an access decision, scope the query to permitted tickets, and add negative authorization tests.

## 10. Detection Engineering Improvement

Add ticket owner, `admin_only`, effective role, authorization reason, and decision to structured telemetry. Detect a successful restricted-ticket view by a non-admin and correlate denied→success sequences.

## 11. Analyst Takeaway

Parameters may select presentation behavior, but they must never grant authority. The strongest finding compares the same identity and object before and after the client-controlled authorization switch.

---

# Challenge: Nightly Backup Exposure

| Field | Value |
|---|---|
| Flag | `FLAG{A02_EXPOSED_BACKUP_01}` |
| OWASP Category | A02:2025 |
| Difficulty | Easy |
| Route/Page | `GET /backup/` then `/backup/northstar-backup.sql.bak` |
| Required Role/Account | No application account required; local Apache access only |
| Primary Weakness | Indexed web alias exposes operational backup artifacts |
| Related CWE if known | CWE-552 (Files or Directories Accessible to External Parties) |
| Expected Evidence Sources | Browser response, Apache access log, backup file, Wazuh Apache rule |
| Detection Opportunity | Alert on any request beneath the deliberately exposed `/backup/` alias |
| Remediation Theme | Store backups outside served paths and disable indexing/access |

## 1. Objective

Retrieve the fictional nightly export through the local Apache alias and identify the flag embedded in its migration marker.

## 2. What the Player Sees

The `/backup/` path displays an Apache directory listing containing a saved configuration and SQL backup.

## 3. What Is Actually Happening

Apache explicitly maps `/backup/` to the repository backup directory with `Options Indexes`. Direct file access bypasses PHP, so no application telemetry or session is involved.

## 4. Step-by-Step Lab Walkthrough

1. From the local lab browser, open `/backup/`.
2. Open `northstar-backup.sql.bak`; do not use or test the fake credential comment.
3. Record `FLAG{A02_EXPOSED_BACKUP_01}` in the fictional `legacy_notes` insert.
4. Correlate the directory and file GETs in Apache/Wazuh, noting the absence of JSONL and fake audit records.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Directory listing and a successful text response for the `.bak` file.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A02_EXPOSED_BACKUP_01}` when the challenge condition is met.
- **Database/server-side evidence:** No live database query is needed; the marker is text in the backup artifact.
- **Apache visibility:** Both `/backup/` and the selected filename are recorded with source, user agent, status, and byte count.
- **`/var/log/vulnforge/app_events.jsonl`:** None because Apache serves the alias directly.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** No application `event_type`
- **Likely route:** Apache URL `/backup/...`
- **Likely rule/group:** Rule `100506`, “Northstar exposed backup directory accessed,” group `web,backup_access`
- **Sample dashboard query:** ``rule.id:"100506" or (location:"/var/log/apache2/vulnforge_access.log" and url:"/backup/*")``
- **What the alert proves:** A client requested the exposed backup path and the Apache decoder/rule matched it.
- **What the alert does not prove:** It does not by itself prove the file contents were read, retained, or used.

## 7. Noise and Detection-Awareness Notes

One browser visit can generate requests for both the directory and file. Since application logs are absent by design, defenders must preserve Apache evidence. Fewer requests create fewer records, but the defensive response is to protect the path and alert on all access—not to rely on volume. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Searching only application routes, expecting `app_events.jsonl`, or treating the fake archive credential as a real secret.

## 9. Remediation

Remove the alias, keep backups outside the document root, deny web-server access, disable indexing, encrypt and access-control backups, and scan release artifacts for backup extensions.

## 10. Detection Engineering Improvement

Retain the path-specific Apache rule, add status/bytes and filename fields to triage, and verify that denied probes after remediation still produce useful telemetry.

## 11. Analyst Takeaway

Directly served artifacts create a visibility split: Apache may be the only network evidence. Application-only monitoring cannot detect resources that never execute application code.

---

# Challenge: Diagnostics Overshare

| Field | Value |
|---|---|
| Flag | `FLAG{A02_VERBOSE_DIAGNOSTICS_02}` |
| OWASP Category | A02:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=diagnostics&detail=1` |
| Required Role/Account | No account required |
| Primary Weakness | Public diagnostic detail discloses environment and internal path information |
| Related CWE if known | CWE-200 (Exposure of Sensitive Information) |
| Expected Evidence Sources | Browser response, Apache, JSONL app telemetry, Wazuh |
| Detection Opportunity | Monitor detailed diagnostics views and correlate them with exceptions or later sensitive actions |
| Remediation Theme | Restrict diagnostics and minimize production output |

## 1. Objective

Enable the detailed local status view and capture the debug marker plus the sensitive configuration context displayed with it.

## 2. What the Player Sees

A public System Status page offers a **View detailed diagnostics** link and normal service health information.

## 3. What Is Actually Happening

When `detail=1`, the server renders environment mode, debug status, database host, document root, and the seeded debug marker without authentication.

## 4. Step-by-Step Lab Walkthrough

1. Open `/?route=diagnostics` and record the ordinary health view.
2. Follow **View detailed diagnostics** or request `/?route=diagnostics&detail=1`.
3. Capture the displayed path/configuration lines and `FLAG{A02_VERBOSE_DIAGNOSTICS_02}`.
4. Find the matching `diagnostics_view` JSONL event and Apache request.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A GET with `detail=1`; the response contains environment and document-root details.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A02_VERBOSE_DIAGNOSTICS_02}` when the challenge condition is met.
- **Database/server-side evidence:** The flag is returned from `app_settings.debug_marker`.
- **Apache visibility:** Records the diagnostics route and query string.
- **`/var/log/vulnforge/app_events.jsonl`:** `diagnostics_view` with message metadata `detail=true`; it is tagged A05 in current telemetry even though the seeded challenge category is A02, an important classification caveat.
- **Fake in-app audit visibility:** No fake audit row.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `diagnostics_view`
- **Likely route:** `diagnostics`
- **Likely rule/group:** Rule `100505`, “Northstar diagnostics page viewed,” group `diagnostics,information_disclosure`
- **Sample dashboard query:** ``data.event_type:"diagnostics_view" and data.route:"diagnostics"``
- **What the alert proves:** The diagnostics route was processed and whether the application marked it as detailed.
- **What the alert does not prove:** It does not capture the full response or prove the viewer used the disclosed information.

## 7. Noise and Detection-Awareness Notes

Legitimate health checks may access diagnostics, including the non-detailed page. The event’s `detail` metadata is in the message rather than a dedicated field, so triage should also inspect the Apache query string. Correlate detailed views with identity, source, exceptions, and subsequent activity. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Reporting only the flag while omitting the path/config leakage, or assuming the telemetry OWASP tag changes the seeded A02 mapping.

## 9. Remediation

Require an administrative support role or private management interface, disable detailed output outside development, and return only coarse health state with a correlation ID.

## 10. Detection Engineering Improvement

Emit `detail_requested` as a Boolean dynamic field, add authentication/role context, and create a higher-severity rule specifically for unauthenticated detailed diagnostics.

## 11. Analyst Takeaway

The security issue is not the marker; it is the unnecessary exposure of operational context. Detection should distinguish ordinary health availability from verbose diagnostic disclosure.

---

# Challenge: Outdated Package Notes

| Field | Value |
|---|---|
| Flag | `FLAG{A03_OUTDATED_PACKAGE_DOC_02}` |
| OWASP Category | A03:2025 |
| Difficulty | Easy |
| Route/Page | White-box artifact `app/vendor/fake-vendor/unsafe-helper/README.md` |
| Required Role/Account | Authorized local repository/host access; no portal account |
| Primary Weakness | Outdated bundled dependency and release notes containing sensitive marker |
| Related CWE if known | CWE-1104 (Use of Unmaintained Third-Party Components) |
| Expected Evidence Sources | Repository file, package manifest; no HTTP/Apache/JSONL unless an instructor serves or opens it separately |
| Detection Opportunity | Inventory dependency name/version and compare it with approved software metadata |
| Remediation Theme | Govern dependencies and exclude development notes from releases |

## 1. Objective

Review the fictional dependency’s local package documentation and identify the release note that exposes the flag.

## 2. What the Player Sees

Portal release notes identify `unsafe-helper` as an installed dependency and link to the support console; the repository contains its fake vendor package.

## 3. What Is Actually Happening

The bundled README identifies version 0.8.1 as outdated and includes a maintainer note containing the flag. This challenge intentionally uses authorized white-box artifact review rather than a web route.

## 4. Step-by-Step Lab Walkthrough

1. Open the portal changelog or dependency console to identify package `fake-vendor/unsafe-helper` version 0.8.1.
2. On the authorized lab host or repository, inspect `app/vendor/fake-vendor/unsafe-helper/README.md`.
3. Record the maintainer note containing `FLAG{A03_OUTDATED_PACKAGE_DOC_02}`.
4. Compare the README with `app/vendor/manifest.json` to document version/status evidence.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** No required flag-bearing HTTP response; portal pages provide package context only.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A03_OUTDATED_PACKAGE_DOC_02}` when the challenge condition is met.
- **Database/server-side evidence:** None.
- **Apache visibility:** Only optional changelog/vendor-console navigation is logged; local file inspection is not.
- **`/var/log/vulnforge/app_events.jsonl`:** No dedicated event for dependency-document review.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None for the decisive file read
- **Likely route:** Optional `vendor-demo` or `changelog` navigation
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``data.route:"vendor-demo" or data.route:"changelog"` (context only; often no JSONL event exists)`
- **What the alert proves:** At most, web logs prove contextual portal navigation; the repository file itself proves the seeded artifact condition.
- **What the alert does not prove:** Wazuh web telemetry cannot prove that a local authorized reader opened the README.

## 7. Noise and Detection-Awareness Notes

This challenge demonstrates an evidence gap rather than a need to infer hidden activity. Package inventory, software composition analysis, and build provenance are stronger controls than HTTP request counting. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Expecting the README beneath the Apache document root, or claiming that an outdated label alone proves exploitation.

## 9. Remediation

Maintain an approved dependency inventory, update or remove unsupported components, review vendor changes, scan packaged artifacts for secrets/markers, and keep internal release notes out of production builds.

## 10. Detection Engineering Improvement

In a production analogue, ingest software inventory/SBOM findings and alert on disallowed versions. Do not fabricate a web alert for an event the web application cannot observe.

## 11. Analyst Takeaway

Supply-chain analysis often depends on build and inventory evidence outside request logs. An outdated component is risk context; exploitability and impact require separate evidence.

---

# Challenge: Unsafe Helper Banner

| Field | Value |
|---|---|
| Flag | `FLAG{A03_UNSAFE_HELPER_OUTPUT_01}` |
| OWASP Category | A03:2025 |
| Difficulty | Medium |
| Route/Page | `GET /?route=vendor-demo&debug=1` |
| Required Role/Account | No account required |
| Primary Weakness | Bundled helper exposes verbose debug output; related helper output trusts caller markup |
| Related CWE if known | CWE-829 (Inclusion of Functionality from Untrusted Control Sphere); related CWE-79 |
| Expected Evidence Sources | Browser response, Apache, helper source/manifest; no dedicated JSONL or fake audit event |
| Detection Opportunity | Monitor public use of dependency debug controls and inventory affected versions |
| Remediation Theme | Disable verbose dependency diagnostics and encode untrusted output |

## 1. Objective

Enable the local dependency support banner and capture the exact package/version marker returned by the helper.

## 2. What the Player Sees

The dependency support console lists `unsafe-helper` 0.8.1 and offers an **Enable verbose support banner** link.

## 3. What Is Actually Happening

The route calls `Helper::debugBanner()` when `debug=1`, returning the flag. Separately, the same helper concatenates portal search input into HTML; instructors should discuss that risk without requiring active script execution.

## 4. Step-by-Step Lab Walkthrough

1. Open `/?route=vendor-demo` and note package name/version.
2. Follow the verbose-banner control, producing `/?route=vendor-demo&debug=1`.
3. Record `unsafe-helper/0.8.1 :: FLAG{A03_UNSAFE_HELPER_OUTPUT_01}`.
4. Optionally review the local helper source to connect package behavior to output handling; no real-target or large payload testing is needed.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A GET with `debug=1`; the banner is browser-visible.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A03_UNSAFE_HELPER_OUTPUT_01}` when the challenge condition is met.
- **Database/server-side evidence:** None.
- **Apache visibility:** Records the route and debug query parameter.
- **`/var/log/vulnforge/app_events.jsonl`:** No `app_event` is emitted for the vendor route.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None
- **Likely route:** `vendor-demo` visible only in Apache
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``location:"/var/log/apache2/vulnforge_access.log" and url:"*route=vendor-demo*debug=1*"` (field availability depends on Apache decoding)`
- **What the alert proves:** Apache proves the debug URL was requested; the response capture proves the banner was returned.
- **What the alert does not prove:** No Wazuh application alert proves the response content or misuse of the separate search-rendering behavior.

## 7. Noise and Detection-Awareness Notes

A single instructor click and a curious learner click look the same in Apache. Detection is useful as a configuration-policy signal, but dependency version management and removal of debug functionality are primary. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Conflating the verbose banner flag with the separate unescaped search output, or claiming a Wazuh alert exists when only Apache collection is available.

## 9. Remediation

Remove or gate debug banners, upgrade/review the helper, encode all caller-controlled output at the final HTML sink, and add dependency and output-encoding tests.

## 10. Detection Engineering Improvement

Add a structured `dependency_debug_view` event with package, version, authenticated context, and outcome; alert when debug mode is used outside an approved support context.

## 11. Analyst Takeaway

A package-version clue, verbose output, and unsafe rendering are related supply-chain concerns but distinct facts. Report exactly which behavior produced the flag and which risks are only source-confirmed.

---

# Challenge: Base64 Is Not Encryption

| Field | Value |
|---|---|
| Flag | `FLAG{A04_WEAK_ENCODING_01}` |
| OWASP Category | A04:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=profile` plus local Base64 decoding |
| Required Role/Account | `analyst@northstar.local` / `analyst123` |
| Primary Weakness | Sensitive profile note protected only by reversible encoding |
| Related CWE if known | CWE-311 (Missing Encryption of Sensitive Data) |
| Expected Evidence Sources | Browser profile output, local decoding result, database user row, Apache; no dedicated profile-view JSONL |
| Detection Opportunity | Inventory encoded sensitive fields and monitor access to profile exports where possible |
| Remediation Theme | Do not treat encoding as confidentiality; minimize and properly encrypt sensitive data |

## 1. Objective

Retrieve the analyst’s encoded private-note value from the profile and decode it locally to obtain the flag.

## 2. What the Player Sees

The profile page labels the value as a legacy reversible format and displays the current user’s encoded private note.

## 3. What Is Actually Happening

The analyst row stores a Base64 representation of `FLAG{A04_WEAK_ENCODING_01}`. Base64 changes representation but supplies no secrecy, key, or integrity.

## 4. Step-by-Step Lab Walkthrough

1. Sign in as `analyst@northstar.local` and open **Profile**.
2. Copy only the displayed fictional encoded note.
3. Decode it locally with a trusted offline Base64 tool or language function; do not send it to an external service.
4. Confirm the result is `FLAG{A04_WEAK_ENCODING_01}` and retain the displayed `base64(user:2)` context as evidence.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Authenticated GET of the profile returns the Base64 value and identifies the format.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A04_WEAK_ENCODING_01}` when the challenge condition is met.
- **Database/server-side evidence:** User 2 stores the encoded flag in `encoded_private_note` and labels the scheme `base64(user:2)`.
- **Apache visibility:** Records profile access but not the decoded result.
- **`/var/log/vulnforge/app_events.jsonl`:** No event is emitted for viewing the profile; only profile updates are logged.
- **Fake in-app audit visibility:** None for profile views.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None for the decisive view/decode
- **Likely route:** `profile` in Apache only
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``location:"/var/log/apache2/vulnforge_access.log" and url:"*route=profile*"``
- **What the alert proves:** Apache can prove profile access; browser and local decode evidence establish the reversible disclosure.
- **What the alert does not prove:** It cannot show that the user decoded the value or that any cryptographic operation occurred.

## 7. Noise and Detection-Awareness Notes

Profile views are ordinary activity. Request volume is not a good signal for misuse of weak encoding; data classification and storage review are more effective. Defenders can correlate unusual export access only if export-specific telemetry exists. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Calling Base64 encryption, using the wrong user’s note, or submitting fictional data to a public decoding website.

## 9. Remediation

Remove unnecessary private data, use authenticated encryption with managed keys when confidentiality is required, separate key access from data access, and avoid exposing ciphertext/encoded values without purpose.

## 10. Detection Engineering Improvement

Add an explicit profile-export event with actor and data class but never log the note itself. Use code/configuration scanning to detect Base64 used as a security control.

## 11. Analyst Takeaway

The decisive evidence is design-level: anyone who can read the encoded value can reverse it. Network monitoring cannot compensate for a representation being mislabeled as protection.

---

# Challenge: Legacy Password Storage

| Field | Value |
|---|---|
| Flag | `FLAG{A04_WEAK_HASH_PROFILE_02}` |
| OWASP Category | A04:2025 |
| Difficulty | Medium |
| Route/Page | `GET /?route=profile` while signed in as Morgan Chen |
| Required Role/Account | `m.chen@northstar.local` / `chen123` (all credentials are fictional and documented) |
| Primary Weakness | Unsalted MD5 password storage disclosed by profile metadata |
| Related CWE if known | CWE-916 (Use of Password Hash With Insufficient Computational Effort) |
| Expected Evidence Sources | Browser profile, login JSONL, database user row, Apache, Wazuh base telemetry |
| Detection Opportunity | Inventory legacy password schemes and monitor use of accounts pending migration |
| Remediation Theme | Use a modern adaptive password hash and migrate on authentication |

## 1. Objective

Authenticate as the seeded Morgan Chen account, observe the profile’s `md5` hash-scheme label, and identify the flag embedded in that fictional profile biography.

## 2. What the Player Sees

Every profile displays its hash scheme. Morgan’s biography contains the training marker and the account is listed in the lab’s fake credential table.

## 3. What Is Actually Happening

Seeded passwords are stored as unsalted MD5 and login compares `md5(submitted_password)` directly. The flag is in Morgan’s `profile_bio`; no password cracking is required or appropriate.

## 4. Step-by-Step Lab Walkthrough

1. Use the documented local-only credentials `m.chen@northstar.local` / `chen123`.
2. Open **Profile** and record the `Hash scheme: md5` field.
3. Capture the biography text containing `FLAG{A04_WEAK_HASH_PROFILE_02}`.
4. Correlate the successful login with Apache and `login_success`; use source review or the seed row to validate the MD5 design.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Login POST followed by authenticated profile GET; the profile displays the hash-scheme label and flag.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A04_WEAK_HASH_PROFILE_02}` when the challenge condition is met.
- **Database/server-side evidence:** Morgan’s row uses `MD5('chen123')`, `hash_scheme=md5`, and the flag-bearing biography.
- **Apache visibility:** Records login and profile access but not submitted password.
- **`/var/log/vulnforge/app_events.jsonl`:** `login_success` records identity/role; password and hash are omitted. No profile-view event.
- **Fake in-app audit visibility:** Authentication is intentionally omitted from fake audit records.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `login_success` (context only)
- **Likely route:** `login`; profile access via Apache
- **Likely rule/group:** No dedicated single-success rule; base `100500` recognizes JSON, while failure rules do not apply
- **Sample dashboard query:** ``data.event_type:"login_success" and data.username:"m.chen@northstar.local"``
- **What the alert proves:** A successful local authentication occurred for Morgan’s fictional account.
- **What the alert does not prove:** It does not expose the password/hash or prove that weak hashing was exploited; source/database evidence establishes storage weakness.

## 7. Noise and Detection-Awareness Notes

A successful login is expected behavior. The cryptographic failure should be found through storage review and migration reporting, not by treating every login as an incident. Correlate unusual successes with failures only when relevant. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Attempting password cracking, confusing a documented lab login with credential theft, or reporting the biography access without explaining the MD5 storage issue.

## 9. Remediation

Use `password_hash` with Argon2id or an appropriate adaptive algorithm and unique salts; migrate legacy hashes after successful authentication, rate-limit login, and remove scheme details from user-facing pages.

## 10. Detection Engineering Improvement

Track hash-version migration status in secure administrative metrics, not profile pages. Alert on legacy-account authentication only as a migration/risk signal, without logging passwords or hashes.

## 11. Analyst Takeaway

The flag can be reached through documented credentials, but the finding is the weak at-rest verifier. Demonstrating exposure does not require or justify recovering any real password.

---

# Challenge: Catalog Query Injection

| Field | Value |
|---|---|
| Flag | `FLAG{A05_SQLI_CATALOG_01}` |
| OWASP Category | A05:2025 |
| Difficulty | Medium |
| Route/Page | `GET /?route=products&q=<local-lab search pattern>` |
| Required Role/Account | No account required |
| Primary Weakness | Catalog search input is concatenated directly into SQL |
| Related CWE if known | CWE-89 (SQL Injection) |
| Expected Evidence Sources | Browser results/error, Apache, JSONL search and suspicious-pattern events, product database row, Wazuh |
| Detection Opportunity | Alert on SQL-metacharacter patterns and correlate with result anomalies or exceptions |
| Remediation Theme | Use parameterized queries and least-privilege database access |

## 1. Objective

Demonstrate within the fake catalog that crafted search input can alter the query and cause the selected `internal_note` field to be displayed, revealing the flag.

## 2. What the Player Sees

Normal catalog browsing deliberately selects `NULL internal_note`; searches use a different result path that can render a non-empty internal note.

## 3. What Is Actually Happening

The search term is interpolated into two SQL `LIKE` clauses. A minimal local tautology/comment pattern can broaden the result set; because the search query selects `internal_note`, the Aurora Camp Lantern row exposes `FLAG{A05_SQLI_CATALOG_01}`.

## 4. Step-by-Step Lab Walkthrough

1. Open the catalog with no query and note that internal notes are absent.
2. Submit a normal search such as `lantern` to establish expected behavior.
3. In this local lab only, use a minimal quote/tautology/comment pattern that closes the `LIKE` value and makes the predicate true, for example the URL-encoded equivalent of `%' OR 1=1 -- `; do not build a payload list or apply it elsewhere.
4. Confirm that multiple products are returned and the Aurora Camp Lantern’s internal note displays `FLAG{A05_SQLI_CATALOG_01}`.
5. Correlate `product_search`, `suspicious_parameter_pattern`, Apache, and the seeded product row. See [REFERENCES.md](REFERENCES.md) for OWASP WSTG and PayloadsAllTheThings attribution.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** The crafted `q` parameter changes result count and exposes an internal-note value; malformed variants may also produce a verbose query error.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A05_SQLI_CATALOG_01}` when the challenge condition is met.
- **Database/server-side evidence:** Product `NS-210` stores the flag in `internal_note`; the vulnerable query includes that column.
- **Apache visibility:** Records the encoded query string, source, status, and user agent.
- **`/var/log/vulnforge/app_events.jsonl`:** `suspicious_parameter_pattern` reports parameter name, pattern class, and length without raw input; `product_search` records result count and pattern; errors create `application_exception`.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `suspicious_parameter_pattern`, `product_search`, optionally `application_exception`
- **Likely route:** `products`
- **Likely rule/group:** Rule `100513`, “Possible SQLi-looking Northstar search metadata,” group `web_attack,sqli_pattern`; exceptions may match `100512`
- **Sample dashboard query:** ``data.event_type:"suspicious_parameter_pattern" and data.route:"products"``
- **What the alert proves:** The application recognized SQL-looking metadata in a catalog parameter; correlated results can prove altered behavior.
- **What the alert does not prove:** Pattern matching alone does not prove successful injection, data disclosure, or malicious intent.

## 7. Noise and Detection-Awareness Notes

Malformed experimentation may create many pattern and exception events; careful validation may create only one. Defenders should not depend only on volume. Correlate parameter classification, result-count change, exception, response evidence, and later flag submission. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Dumping generic payload catalogs, testing any non-lab target, reporting only a regex alert, or overlooking that the selected `internal_note` column makes the disclosure visible.

## 9. Remediation

Replace string construction with prepared statements and bound parameters, avoid selecting internal-only fields for public results, use a least-privilege database account, normalize errors, and add injection regression tests.

## 10. Detection Engineering Improvement

Add search result cardinality, query template ID, and success/error outcome as structured fields. Correlate suspicious input with unusually broad results or a subsequent successful A05 flag submission.

## 11. Analyst Takeaway

A signature is an indicator; changed query semantics and returned internal data are exploitation evidence. Prevention must remove SQL interpretation of user data rather than rely on alerting.

---

# Challenge: Diagnostic Command Chain

| Field | Value |
|---|---|
| Flag | `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}` |
| OWASP Category | A05:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=command-console&check=status%3Bshow%20marker` |
| Required Role/Account | No account required |
| Primary Weakness | A simulated command parser accepts multiple operations from one untrusted input |
| Related CWE if known | CWE-77 (Improper Neutralization of Special Elements used in a Command), simulated only |
| Expected Evidence Sources | Browser response and Apache; app setting in database; no JSONL or fake audit event |
| Detection Opportunity | Monitor use of delimiters or multiple operations in the bounded console |
| Remediation Theme | Use an allow-listed operation identifier rather than parsing command text |

## 1. Objective

Use the lab’s explicitly bounded interpreter to run a normal status operation followed by its fixed `show marker` operation.

## 2. What the Player Sees

The command console states that it never invokes an operating-system shell and supports fixed fake-data operations such as `status` and `count`.

## 3. What Is Actually Happening

The application splits the `check` value on semicolons and evaluates each segment against three hard-coded strings. `show marker` reads the seeded marker; there is no shell, process execution, filesystem command, or external effect.

## 4. Step-by-Step Lab Walkthrough

1. Open `/?route=command-console` and run the default `status` operation.
2. In the same local form, enter `status;show marker`.
3. Confirm the output contains both `orders: ok` and `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}`.
4. Capture the Apache request and explicitly document that the behavior is parser injection in a simulation, not OS command execution.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A GET whose `check` value contains two simulated operations; the response contains two fixed output lines.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}` when the challenge condition is met.
- **Database/server-side evidence:** The marker comes from `app_settings.command_marker`.
- **Apache visibility:** Records the encoded delimiter and operation text.
- **`/var/log/vulnforge/app_events.jsonl`:** No command-console event is emitted.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None
- **Likely route:** `command-console` in Apache only
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``location:"/var/log/apache2/vulnforge_access.log" and url:"*route=command-console*"``
- **What the alert proves:** Apache proves the bounded console request; response evidence proves the parser accepted both operations.
- **What the alert does not prove:** It does not indicate operating-system command execution because the code never calls a shell API.

## 7. Noise and Detection-Awareness Notes

Repeated guesses create more Apache records, while a single chained request may resemble ordinary diagnostic use. Defenders should parse operation count/delimiters and understand the application’s bounded semantics rather than mislabel every semicolon as host compromise. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Claiming remote command execution, trying destructive shell commands, or omitting the simulation boundary from the finding.

## 9. Remediation

Replace free-form command grammar with a server-side allow-listed operation enum, accept one operation per request, authorize diagnostics, and log operation ID/outcome without sensitive output.

## 10. Detection Engineering Improvement

Emit a `diagnostic_operation` event with operation count and recognized/unrecognized status. Alert on multiple operations while keeping the description explicit that this lab control is simulated.

## 11. Analyst Takeaway

Accurate scoping matters. The input changes application-parser control flow, but evidence does not support an OS-execution claim.

---

# Challenge: Negative Refund Quantity

| Field | Value |
|---|---|
| Flag | `FLAG{A06_REFUND_LOGIC_01}` |
| OWASP Category | A06:2025 |
| Difficulty | Medium |
| Route/Page | `POST /?route=refund` |
| Required Role/Account | No account required |
| Primary Weakness | Business workflow accepts negative quantity and applies promotional arithmetic without state validation |
| Related CWE if known | CWE-840 (Business Logic Errors) |
| Expected Evidence Sources | Browser response, Apache, JSONL refund event, coupon database row; no dedicated Wazuh rule |
| Detection Opportunity | Record validated business values and flag impossible quantity/direction combinations |
| Remediation Theme | Define and enforce refund invariants and workflow state |

## 1. Objective

Submit a negative fictional return quantity with coupon `LABREFUND` and observe the business-logic marker.

## 2. What the Player Sees

A refund estimator accepts a numeric quantity and promotion code and clearly states that no payment provider or real refund is involved.

## 3. What Is Actually Happening

The server casts quantity to an integer and immediately calculates `20 * quantity * (1 + percent/100)`. It never enforces positive quantity, purchase ownership, return state, coupon usage, or monetary direction. A negative quantity with `LABREFUND` appends the coupon’s internal-note flag.

## 4. Step-by-Step Lab Walkthrough

1. Open `/?route=refund` and calculate a normal positive estimate as a baseline.
2. Submit a small negative quantity such as `-1` with the lab-only coupon `LABREFUND`.
3. Record the negative calculated amount and `FLAG{A06_REFUND_LOGIC_01}`.
4. Correlate the POST with Apache and the sanitized `refund_request` JSONL event; note that submitted values are intentionally omitted.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A POST to the refund route returns a calculated negative amount and the marker.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A06_REFUND_LOGIC_01}` when the challenge condition is met.
- **Database/server-side evidence:** Coupon `LABREFUND` has 25 percent and stores the flag in its internal note.
- **Apache visibility:** Records the POST and response status, but standard access logging does not include form fields.
- **`/var/log/vulnforge/app_events.jsonl`:** `refund_request` records that an estimate was requested and tags A06, but omits quantity and coupon.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `refund_request`
- **Likely route:** `refund`
- **Likely rule/group:** No dedicated custom rule; base `100500` only
- **Sample dashboard query:** ``data.event_type:"refund_request" and data.route:"refund"``
- **What the alert proves:** A refund estimate request reached the application.
- **What the alert does not prove:** Because values and computed outcome are omitted, it does not prove negative quantity or exploitation.

## 7. Noise and Detection-Awareness Notes

Normal and abnormal estimates produce the same event. Fewer requests mean fewer indicators, but the larger issue is insufficient semantic telemetry. Correlate browser evidence or approved business-state data rather than inferring abuse from request count. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Treating the calculation as a real refund, expecting Wazuh to know the quantity, or focusing on the coupon instead of missing business invariants.

## 9. Remediation

Validate positive bounded quantities, require an eligible completed purchase and return authorization, enforce coupon state/usage, calculate money with safe types, and separate estimate from approved refund execution.

## 10. Detection Engineering Improvement

Log non-sensitive semantic fields such as quantity sign/category, order reference, workflow state, decision, and calculated direction. Alert on impossible combinations, not merely all refund requests.

## 11. Analyst Takeaway

Business-logic detection requires domain context. A generic POST event proves activity but cannot distinguish a normal estimate from an invalid negative workflow.

---

# Challenge: Predictable Reset Token

| Field | Value |
|---|---|
| Flag | `FLAG{A06_PREDICTABLE_RESET_02}` |
| OWASP Category | A06:2025 |
| Difficulty | Medium |
| Route/Page | `POST /?route=password-reset` |
| Required Role/Account | No authenticated account required; use only seeded fictional user IDs |
| Primary Weakness | Long-lived reset tokens follow a guessable public pattern |
| Related CWE if known | CWE-640 (Weak Password Recovery Mechanism) |
| Expected Evidence Sources | Browser response, Apache, JSONL reset request/completion, password-reset database row, Wazuh base telemetry |
| Detection Opportunity | Correlate reset verification failures/successes by source and target without logging token values |
| Remediation Theme | Use random single-use expiring tokens bound to a verified recovery flow |

## 1. Objective

Infer the local token format and verify one seeded fake user token to display the reset marker; no password or account state is changed.

## 2. What the Player Sees

The form placeholder and challenge hint describe a `reset-userid-year` shape. No email is sent and all data remains local.

## 3. What Is Actually Happening

The seed contains tokens such as `reset-2-2026` and `reset-3-2026`, valid until 2030. Any exact token match returns the associated fictional email and the global reset flag, without marking the token used.

## 4. Step-by-Step Lab Walkthrough

1. Open `/?route=password-reset` and record the token-shape clue.
2. Using only a seeded fake user ID, submit `reset-2-2026`.
3. Confirm the response accepts the analyst account token and displays `FLAG{A06_PREDICTABLE_RESET_02}`.
4. Verify JSONL contains a page-view `password_reset_request` and a successful `password_reset_complete`; token values remain omitted.
5. Do not attempt any real account recovery, email interaction, or password change—the lab performs none.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** GET page view and POST token verification; the successful response identifies a fictional email and marker.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A06_PREDICTABLE_RESET_02}` when the challenge condition is met.
- **Database/server-side evidence:** `password_resets` contains predictable tokens, unused state, and far-future expiry.
- **Apache visibility:** Records the GET/POST and status, not the form token.
- **`/var/log/vulnforge/app_events.jsonl`:** `password_reset_request` on non-POST view and `password_reset_complete` with success/failure; token and target are omitted.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `password_reset_request`, `password_reset_complete`
- **Likely route:** `password-reset`
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``data.event_type:"password_reset_complete" and data.outcome:"success"``
- **What the alert proves:** A token was accepted or rejected by the local verifier.
- **What the alert does not prove:** The event does not identify the token, target account, password change, or whether an unauthorized person supplied it.

## 7. Noise and Detection-Awareness Notes

Normal recovery verification and predictable-token testing look similar. A burst of failures could be suspicious, but a single success requires identity, target, issuance, and session context. Absence from fake audit remains an A09 gap. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Assuming a password is changed, using non-lab identifiers, or logging/reproducing token values beyond the fictional walkthrough.

## 9. Remediation

Generate cryptographically random, hashed-at-rest, short-lived, single-use tokens; bind them to a verified request and user; invalidate after use; rate-limit verification; notify the account owner.

## 10. Detection Engineering Improvement

Emit a reset transaction ID, target user ID, issuance age, used/expired decision, and source—never the raw token. Detect unissued successes, repeated failures, and reuse.

## 11. Analyst Takeaway

A successful verifier event is important but incomplete. Recovery security depends on token entropy, lifecycle, binding, and auditable state transitions.

---

# Challenge: Factory Admin Credentials

| Field | Value |
|---|---|
| Flag | `FLAG{A07_DEFAULT_ADMIN_01}` |
| OWASP Category | A07:2025 |
| Difficulty | Easy |
| Route/Page | `POST /?route=login`, then `GET /?route=dashboard` |
| Required Role/Account | `admin@northstar.local` / `admin123` |
| Primary Weakness | Known factory/default administrative credential remains active |
| Related CWE if known | CWE-1392 (Use of Default Credentials) |
| Expected Evidence Sources | Browser dashboard, Apache, JSONL login event, user database row, Wazuh base telemetry |
| Detection Opportunity | Identify successful use of a default/admin account, especially after failures or from unexpected sources |
| Remediation Theme | Require unique setup credentials, rotation, MFA, and administrative access controls |

## 1. Objective

Sign in with the documented fictional factory administrator credential and observe the admin-only deployment marker on the dashboard.

## 2. What the Player Sees

The repository/player guide lists fake accounts, and the dashboard displays a special deployment notice only when the current email is the seeded admin address.

## 3. What Is Actually Happening

The default `admin123` credential remains valid. Successful authentication creates an admin session, and the dashboard condition renders `FLAG{A07_DEFAULT_ADMIN_01}`.

## 4. Step-by-Step Lab Walkthrough

1. From the isolated lab login page, enter `admin@northstar.local` and `admin123`.
2. After redirect, confirm the user chip shows the admin identity/role.
3. Capture the **Factory administrator setup remains active** card and `FLAG{A07_DEFAULT_ADMIN_01}`.
4. Correlate the login POST, redirect/dashboard GET, and `login_success` event.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Successful login POST and authenticated dashboard response with admin-only card.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A07_DEFAULT_ADMIN_01}` when the challenge condition is met.
- **Database/server-side evidence:** User 1 has admin role and MD5 of the documented default password.
- **Apache visibility:** Records login and dashboard requests but not password.
- **`/var/log/vulnforge/app_events.jsonl`:** `login_success` records admin identity and role.
- **Fake in-app audit visibility:** Authentication is absent from fake audit records.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `login_success`
- **Likely route:** `login`
- **Likely rule/group:** No dedicated success/default-account rule; base `100500` only
- **Sample dashboard query:** ``data.event_type:"login_success" and data.username:"admin@northstar.local"``
- **What the alert proves:** The administrator account authenticated successfully from the recorded source.
- **What the alert does not prove:** It does not prove that the submitted password was the default value or that the actor lacked authorization.

## 7. Noise and Detection-Awareness Notes

An instructor’s legitimate admin login creates the same event. Detection requires asset/source expectations, default-credential retirement state, and preceding failures—not a blanket compromise label. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Saying Wazuh captured the password, calling all admin logins malicious, or forgetting that the account is deliberately fictional.

## 9. Remediation

Force unique credentials during installation, disable bootstrap accounts after setup, use adaptive hashing and MFA, restrict admin access, and monitor/rotate administrative credentials.

## 10. Detection Engineering Improvement

Add an account-security attribute indicating unresolved factory setup (without storing the password in logs) and alert when such an account authenticates. Correlate failures→success and unexpected source/role.

## 11. Analyst Takeaway

The success event proves account use, while configuration state proves the default-credential risk. Neither alone establishes an unauthorized actor.

---

# Challenge: Remember-Me Impersonation

| Field | Value |
|---|---|
| Flag | `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}` |
| OWASP Category | A07:2025 |
| Difficulty | Medium |
| Route/Page | Cookie `remember_lab`, then `GET /?route=dashboard` |
| Required Role/Account | Start with any account using “Keep signed in”; locally encode another seeded `user:N` value |
| Primary Weakness | Unsigned, predictable remember-me cookie is trusted as identity |
| Related CWE if known | CWE-345 (Insufficient Verification of Data Authenticity) |
| Expected Evidence Sources | Browser cookie/session and dashboard, Apache, later identity-bearing app events; database user IDs; no dedicated restoration event |
| Detection Opportunity | Detect identity/session restoration with signed-token validation metadata and impossible account transitions |
| Remediation Theme | Use random server-side session tokens or signed, rotating remember tokens |

## 1. Objective

Show that the remember cookie is only Base64-encoded, alter it to another seeded fictional user ID, and observe the restoration marker after a new session is created.

## 2. What the Player Sees

Selecting **Keep this private lab browser signed in** creates a `remember_lab` cookie. Decoding it locally yields text such as `user:5`.

## 3. What Is Actually Happening

When no session user exists, `current_user()` Base64-decodes the cookie and trusts any `user:<digits>` value, sets that ID in the session, and marks the session as restored. The dashboard then displays `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}`.

## 4. Step-by-Step Lab Walkthrough

1. Sign in to a fake account with the remember option selected and inspect the local `remember_lab` cookie.
2. Decode the cookie locally and confirm the `user:N` format.
3. Sign out or otherwise clear only the active lab session while retaining/replacing the remember cookie.
4. For this lab only, Base64-encode another seeded value such as `user:2`, set it as `remember_lab`, and request the dashboard.
5. Confirm the restored identity and the session notice containing `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}`. Do not use real identities or tokens.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A dashboard request carries the modified cookie and returns another fictional identity plus the restoration marker.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}` when the challenge condition is met.
- **Database/server-side evidence:** Numeric IDs map directly to seeded users.
- **Apache visibility:** Standard combined logging records the request but generally not cookie contents.
- **`/var/log/vulnforge/app_events.jsonl`:** No dedicated `remember_token_restored` event. Later events may show the restored identity, and logout logs the current identity.
- **Fake in-app audit visibility:** No fake audit row for restoration or effective identity change.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None for restoration; subsequent identity-bearing events only
- **Likely route:** `dashboard` in Apache
- **Likely rule/group:** No dedicated custom rule
- **Sample dashboard query:** ``data.username:"analyst@northstar.local"` in a narrow time window after the dashboard request (indirect evidence only)`
- **What the alert proves:** The browser response and session identity demonstrate local restoration; subsequent events can show which identity the server used.
- **What the alert does not prove:** Apache or Wazuh alone does not reveal the cookie manipulation or original user because cookie value and restoration cause are not logged.

## 7. Noise and Detection-Awareness Notes

Ordinary remembered sessions and tampered ones are indistinguishable in current telemetry. This is an evidence gap, not a reason to log raw cookies. Defenders need token-validation outcome, token ID, prior session context, and account/source baselines. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Changing the cookie while an existing session still takes precedence, expecting the encoded cookie to be cryptographically protected, or logging the raw token as a proposed fix.

## 9. Remediation

Use high-entropy server-side remember tokens stored hashed, bind selector/validator pairs to account and device context, rotate on use, revoke on logout/password change, set secure cookie attributes, and never accept a bare user ID.

## 10. Detection Engineering Improvement

Emit a `remember_session_restore` event with user, token record ID, validation result, rotation result, and source—never raw token material. Detect invalid signatures, reuse, and abrupt identity changes.

## 11. Analyst Takeaway

The central failure is authenticity, not encoding. Current monitoring can see the resulting identity but not why it was trusted, making preventive token design essential.

---

# Challenge: Unsigned Profile Import

| Field | Value |
|---|---|
| Flag | `FLAG{A08_CLIENT_ROLE_TRUST_01}` |
| OWASP Category | A08:2025 |
| Difficulty | Medium |
| Route/Page | `POST /?route=profile-import`, optionally `GET /?route=admin` |
| Required Role/Account | Any signed-in non-admin; guest is suitable |
| Primary Weakness | Unsigned client JSON controls effective authorization role |
| Related CWE if known | CWE-345 (Insufficient Verification of Data Authenticity) |
| Expected Evidence Sources | Browser response, session state, Apache, JSONL profile import/admin access, app setting, Wazuh |
| Detection Opportunity | Correlate non-admin profile import with effective admin access |
| Remediation Theme | Treat imported data as preferences only; sign/validate allowed fields and derive role server-side |

## 1. Objective

Import a minimal local profile document claiming the admin role, observe the flag, and verify that the session’s effective role can open the admin console.

## 2. What the Player Sees

The import page accepts JSON and warns that the legacy workflow lacks a signature. The sample document contains a client-supplied `role` field.

## 3. What Is Actually Happening

The server stores `data["role"]` directly in `$_SESSION["imported_role"]`. If it equals `admin`, the import response shows the flag; the admin route also prefers this session value over the database role.

## 4. Step-by-Step Lab Walkthrough

1. Sign in as `guest@northstar.local` and open **Profile → Import profile JSON**.
2. Submit the minimal lab document `{"display_name":"Guest Player","role":"admin"}`.
3. Confirm **Effective imported role: admin** and `FLAG{A08_CLIENT_ROLE_TRUST_01}`.
4. Open `/?route=admin` and verify the console uses the imported effective role while the user chip/database role remains guest.
5. Correlate `profile_import` with `admin_access` for the same username/source and narrow time window.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Profile-import POST accepts the document; later admin GET succeeds.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A08_CLIENT_ROLE_TRUST_01}` when the challenge condition is met.
- **Database/server-side evidence:** The guest’s stored role remains guest; the flag is `app_settings.import_review_marker`.
- **Apache visibility:** Records the import POST and admin GET, but not the POST body in standard access logs.
- **`/var/log/vulnforge/app_events.jsonl`:** `profile_import` success records the database identity but omits the document; `admin_access` records `effective_role=admin` while the event role remains the stored role.
- **Fake in-app audit visibility:** Neither import nor privilege change is written to the fake audit table.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `profile_import`, followed by `admin_access`
- **Likely route:** `profile-import`, then `admin`
- **Likely rule/group:** Rule `100508` for profile import; no dedicated success anomaly for `admin_access`
- **Sample dashboard query:** ``data.event_type:("profile_import" or "admin_access") and data.username:"guest@northstar.local"``
- **What the alert proves:** A profile import occurred and the same database identity later accessed admin with an effective role described in telemetry.
- **What the alert does not prove:** The import event alone does not prove the submitted role; the admin event and response establish the consequence.

## 7. Noise and Detection-Awareness Notes

Legitimate profile imports may be common, and a single import alert is low context. The high-value sequence is non-admin identity → successful import → effective admin access. Low request volume does not remove the semantic contradiction. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Changing the database role in the explanation, claiming the JSON is signed, or stopping at the flag without validating the authorization consequence.

## 9. Remediation

Reject authorization fields in imported documents, allow-list preference fields, validate schema, authenticate integrity/provenance where portability requires it, and always derive roles from server-controlled identity data.

## 10. Detection Engineering Improvement

Add imported-field names, signature-validation result, prior/effective role, and authorization source as safe structured fields. Correlate import with role divergence and admin access.

## 11. Analyst Takeaway

Integrity failures become access-control failures when client data is treated as authority. The contradictory stored role and effective role are especially strong analyst evidence.

---

# Challenge: Trusted Upload Metadata

| Field | Value |
|---|---|
| Flag | `FLAG{A08_UNSIGNED_UPLOAD_META_02}` |
| OWASP Category | A08:2025 |
| Difficulty | Easy |
| Route/Page | `GET /uploads/` then `/uploads/welcome.txt` (metadata also in `/uploads/.metadata.json`) |
| Required Role/Account | No account required for browsing; login required only to upload |
| Primary Weakness | Indexed upload area exposes client-controlled content/metadata without authenticity assurance |
| Related CWE if known | CWE-345 (Insufficient Verification of Data Authenticity) |
| Expected Evidence Sources | Browser response, Apache, upload files; JSONL only for new uploads; optional Wazuh upload rule |
| Detection Opportunity | Correlate upload events with subsequent direct file access and, if enabled later, file-integrity events |
| Remediation Theme | Store uploads outside web paths and treat metadata/content as untrusted |

## 1. Objective

Browse the local shared-upload alias and inspect the seeded welcome document that carries the metadata-review flag.

## 2. What the Player Sees

The File Exchange links to an indexed `/uploads/` directory. `welcome.txt` is directly readable; a dot-file metadata artifact also describes client-controlled trust.

## 3. What Is Actually Happening

Apache serves the upload directory directly with indexing and PHP execution disabled. The flag is in `welcome.txt`; `.metadata.json` reinforces that trust metadata is client-controlled. Direct reads never execute PHP.

## 4. Step-by-Step Lab Walkthrough

1. Open `/uploads/` in the isolated lab.
2. Open `welcome.txt` and record `Metadata-Review: FLAG{A08_UNSIGNED_UPLOAD_META_02}`.
3. If reviewing the host filesystem, compare `.metadata.json`, which may not appear in a default directory listing but states that client-controlled metadata was accepted.
4. Correlate direct file GETs in Apache; note that the seeded read creates no `file_upload` JSONL event.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Directory/file GETs expose seeded upload content.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A08_UNSIGNED_UPLOAD_META_02}` when the challenge condition is met.
- **Database/server-side evidence:** None.
- **Apache visibility:** Records directory and file access.
- **`/var/log/vulnforge/app_events.jsonl`:** No event for direct alias reads. A newly posted file through `/?route=uploads` would create `file_upload` with sanitized name and size, not content.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None for seeded file read; `file_upload` only when an upload is generated
- **Likely route:** Apache `/uploads/...` or application route `uploads`
- **Likely rule/group:** Rule `100507` for `file_upload`; no custom direct-read rule
- **Sample dashboard query:** ``data.event_type:"file_upload"` or `location:"/var/log/apache2/vulnforge_access.log" and url:"/uploads/*"``
- **What the alert proves:** The upload rule proves a file was processed; Apache proves a direct path was requested.
- **What the alert does not prove:** Neither proves that metadata/content is trustworthy, executed, or malicious.

## 7. Noise and Detection-Awareness Notes

Shared-file access is legitimate-looking. Correlation should connect uploader, generated filename, later readers, and integrity/scanning results. The absence of an upload event for seeded files is expected. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Trying to execute uploads, treating `trusted:true` as verified provenance, or expecting the direct read to create application JSONL.

## 9. Remediation

Store files outside served directories, use generated names, validate type/size/content, maintain server-side ownership metadata, authorize downloads, scan safely, set non-executable serving controls, and cryptographically verify provenance where required.

## 10. Detection Engineering Improvement

Add download events and stable file IDs/hashes, then correlate upload→scan→download. If FIM is later enabled, use it as integrity evidence without assuming every change is malicious.

## 11. Analyst Takeaway

Metadata is a claim, not proof. Direct Apache serving creates an application-telemetry gap, while the existing no-execution control limits—but does not eliminate—upload risk.

---

# Challenge: Writable-Looking Application Log

| Field | Value |
|---|---|
| Flag | `FLAG{A09_TAMPERABLE_LOG_01}` |
| OWASP Category | A09:2025 |
| Difficulty | Easy |
| Route/Page | `GET /logs/` then `/logs/app.log` |
| Required Role/Account | No application account required |
| Primary Weakness | Application log is web-exposed and installed with deliberately weak lab permissions |
| Related CWE if known | CWE-732 (Incorrect Permission Assignment for Critical Resource) |
| Expected Evidence Sources | Browser response, Apache, local file permissions/content; no JSONL or fake audit event |
| Detection Opportunity | Monitor direct access to log aliases and verify log integrity/permissions separately |
| Remediation Theme | Remove logs from web access and enforce append/ship/integrity controls |

## 1. Objective

Inspect—without modifying—the exposed sample application log and identify the integrity-warning flag and incomplete fields.

## 2. What the Player Sees

Apache indexes `/logs/`, and `app.log` contains ordinary-looking records plus a warning marker and a comment about missing actor/source/outcome details.

## 3. What Is Actually Happening

The artifact is directly served and reset with weak lab permissions. It is intentionally less trustworthy than host-owned Apache/JSONL telemetry. The exercise requires observation only; log modification is prohibited.

## 4. Step-by-Step Lab Walkthrough

1. Open `/logs/` and then `/logs/app.log`.
2. Record `FLAG{A09_TAMPERABLE_LOG_01}` and examples of weak attribution such as “authentication complete.”
3. On an instructor-managed host, permissions may be reviewed read-only to validate the design; do not alter the file.
4. Correlate the read with Apache and document that no application event or fake audit row records direct alias access.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Direct GET returns the entire sample log.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A09_TAMPERABLE_LOG_01}` when the challenge condition is met.
- **Database/server-side evidence:** None.
- **Apache visibility:** Records access to `/logs/` and `/logs/app.log`.
- **`/var/log/vulnforge/app_events.jsonl`:** None because Apache serves the alias.
- **Fake in-app audit visibility:** None; the web file is separate from the database-backed fake audit viewer.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** None
- **Likely route:** Apache URL `/logs/...`
- **Likely rule/group:** No dedicated custom rule for log alias access
- **Sample dashboard query:** ``location:"/var/log/apache2/vulnforge_access.log" and url:"/logs/*"``
- **What the alert proves:** Apache can show that the exposed log path was requested.
- **What the alert does not prove:** It does not prove modification, tampering, or the truth of statements inside the weak log.

## 7. Noise and Detection-Awareness Notes

A learner, instructor, or legitimate support user could read the path. Access monitoring is useful, but integrity assurance requires permissions, remote collection, hashes/signatures where appropriate, and custody—not inference from read volume. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Editing/deleting the log, calling the file authoritative, or confusing it with `/var/log/vulnforge/app_events.jsonl`.

## 9. Remediation

Remove the alias, deny web-server reads, use least-privilege append permissions, forward events promptly to protected storage, restrict administrators, monitor changes, and define retention/time synchronization.

## 10. Detection Engineering Improvement

Add an Apache rule for `/logs/` access and host-level permission/FIM checks. Keep read access and file modification as separate alert types and confidence levels.

## 11. Analyst Takeaway

A log’s value depends on integrity, attribution, and custody. A readable marker proves exposure; it does not prove that prior log statements are complete or untampered.

---

# Challenge: Authentication Event Gap

| Field | Value |
|---|---|
| Flag | `FLAG{A09_MISSING_AUDIT_EVENT_02}` |
| OWASP Category | A09:2025 |
| Difficulty | Medium |
| Route/Page | `GET /?route=logs&compare=1` after login/import comparison |
| Required Role/Account | Any signed-in account |
| Primary Weakness | Security-sensitive actions are absent from the fake database audit trail |
| Related CWE if known | CWE-778 (Insufficient Logging) |
| Expected Evidence Sources | Browser audit viewer, Apache, JSONL telemetry, fake audit table, Wazuh |
| Detection Opportunity | Compare independent sources and alert on expected-event gaps or contradictory records |
| Remediation Theme | Define complete security audit events with protected centralized collection |

## 1. Objective

Generate or review authentication/profile-import activity, show that the fake audit viewer omits it, and use the comparison control to reveal the flag.

## 2. What the Player Sees

The Audit Viewer openly warns that failed authentication, profile imports, and effective-role changes are omitted. Its rows include boot, invoice view, and a report with missing actor.

## 3. What Is Actually Happening

The fake viewer reads only `audit_logs`. Login and import handlers intentionally call JSONL `app_event` but not `audit()`. `compare=1` retrieves the seeded logging-gap marker.

## 4. Step-by-Step Lab Walkthrough

1. Generate a failed login and then a successful login using fictional accounts; optionally perform a profile import.
2. While signed in, open `/?route=logs` and confirm those sensitive actions do not appear in the database-backed table.
3. Compare the same time window in Apache and `/var/log/vulnforge/app_events.jsonl`, where at least partial events exist.
4. Select **Compare expected security events** (`&compare=1`) and record `FLAG{A09_MISSING_AUDIT_EVENT_02}`.
5. Document which fields remain missing even in JSONL and which fake rows are weakly attributed.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** Login/import/log-view requests exist in Apache; the compare response displays the marker.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A09_MISSING_AUDIT_EVENT_02}` when the challenge condition is met.
- **Database/server-side evidence:** `audit_logs` contains only seeded/explicit `audit()` records; the marker comes from `app_settings.logging_gap_marker`.
- **Apache visibility:** Shows transport-level actions across the compared time window.
- **`/var/log/vulnforge/app_events.jsonl`:** Contains `login_failure`, `login_success`, and `profile_import` when generated, with sanitized context.
- **Fake in-app audit visibility:** Deliberately missing those events; some existing rows omit actor or decision context.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** Multiple comparison events; no event is emitted for viewing the log comparison itself
- **Likely route:** `login`, `profile-import`, `logs`
- **Likely rule/group:** Rules `100501/100502` for failures and `100508` for import; other events may only match base `100500`
- **Sample dashboard query:** ``data.event_type:("login_failure" or "login_success" or "profile_import")` plus a separate Apache/log-view search`
- **What the alert proves:** The independent sources show activity that the fake audit table does not record.
- **What the alert does not prove:** A Wazuh alert does not mean every required audit field exists or that compromise occurred.

## 7. Noise and Detection-Awareness Notes

This exercise depends on comparing sources, not maximizing request count. A low-volume action can still reveal a gap. Absence from one source must be tested against collection health and alternate evidence before concluding that logging failed. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Equating no fake row with no activity, assuming JSONL is complete, or treating the flag as proof of a real incident.

## 9. Remediation

Create a security-event schema with actor, source, target, action, decision, outcome, request ID, timestamp, and reason; log authentication, recovery, imports, privilege changes, and sensitive reads; protect and centralize records.

## 10. Detection Engineering Improvement

Build expected-event coverage tests and source-health monitoring. Correlate Apache request IDs/time windows with JSONL and alert when high-value actions lack the corresponding application decision event.

## 11. Analyst Takeaway

Logging quality is measured by whether an analyst can reconstruct a security-relevant decision, not by the number of lines. Contradictions and omissions are findings in their own right.

---

# Challenge: Verbose Product Exception

| Field | Value |
|---|---|
| Flag | `FLAG{A10_VERBOSE_EXCEPTION_01}` |
| OWASP Category | A10:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=product&id=not-a-number` |
| Required Role/Account | No account required |
| Primary Weakness | Invalid input returns internal exception class, stack context, filesystem path, and debug marker |
| Related CWE if known | CWE-209 (Generation of Error Message Containing Sensitive Information) |
| Expected Evidence Sources | Browser response, Apache, JSONL application exception, app setting, Wazuh |
| Detection Opportunity | Alert on application exceptions and correlate input class, route, status, and repeated sources |
| Remediation Theme | Validate input and return generic client errors with server-side correlation IDs |

## 1. Objective

Request a non-numeric local product ID and capture the verbose exception details and A10 flag.

## 2. What the Player Sees

Normal product links use numeric IDs. A non-numeric value produces a styled error page rather than a generic validation response.

## 3. What Is Actually Happening

The route checks `ctype_digit`; on failure it manually renders an exception name, submitted value, internal controller path/line, and `app_settings.exception_marker`. It also emits `application_exception`.

## 4. Step-by-Step Lab Walkthrough

1. Open a normal product detail and note the numeric `id` shape.
2. Change the local ID to a harmless non-numeric value such as `demo`.
3. Record the `InvalidArgumentException`, internal path, and `FLAG{A10_VERBOSE_EXCEPTION_01}`.
4. Correlate the browser response, Apache request, request ID header, JSONL exception, and Wazuh rule 100512.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** GET with non-numeric `id`; response includes verbose internal details.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A10_VERBOSE_EXCEPTION_01}` when the challenge condition is met.
- **Database/server-side evidence:** The marker comes from `app_settings.exception_marker`; no product lookup occurs.
- **Apache visibility:** Records the request. The PHP code does not explicitly set a 4xx/5xx status for this branch, so Apache may show 200—an important handling gap.
- **`/var/log/vulnforge/app_events.jsonl`:** `application_exception` records route `product`, A10, and sanitized message; default status may remain 200.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `application_exception`
- **Likely route:** `product`
- **Likely rule/group:** Rule `100512`, “Northstar application exception,” group `application_error`
- **Sample dashboard query:** ``data.event_type:"application_exception" and data.route:"product"``
- **What the alert proves:** The application classified the request as an exception condition on the product route.
- **What the alert does not prove:** The alert does not capture the full leaked response or prove malicious intent; the 200 status may obscure severity.

## 7. Noise and Detection-Awareness Notes

User mistakes and broken links can generate similar exceptions. One event is a triage lead; repeated values/sources increase operational interest but are not required to prove disclosure. Correlate response evidence and status semantics. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Omitting the incorrect/default status, claiming a stack trace was captured in Wazuh, or using disruptive inputs.

## 9. Remediation

Validate and normalize identifiers before controller logic, return a generic 400/404 page, keep detailed exceptions in protected server logs, disable debug output, and provide a request/correlation ID to users.

## 10. Detection Engineering Improvement

Add exception class/code, handled/unhandled state, explicit HTTP status, and correlation ID while excluding submitted values and stack traces. Alert on spikes and sensitive-route exceptions.

## 11. Analyst Takeaway

An exception alert proves server-side error handling occurred; only the response capture proves information disclosure. Correct status codes are also part of safe exceptional-condition handling.

---

# Challenge: API Exception Detail

| Field | Value |
|---|---|
| Flag | `FLAG{A10_API_ERROR_LEAK_02}` |
| OWASP Category | A10:2025 |
| Difficulty | Easy |
| Route/Page | `GET /?route=api-invoice` with no `id` |
| Required Role/Account | No account required |
| Primary Weakness | API returns detailed exception metadata and debug marker for a missing argument |
| Related CWE if known | CWE-209 (Generation of Error Message Containing Sensitive Information) |
| Expected Evidence Sources | JSON HTTP response, Apache, JSONL application exception, app setting, Wazuh |
| Detection Opportunity | Alert on API exception events and correlate status, route, request ID, and repeated sources |
| Remediation Theme | Return a minimal documented error contract and retain detail only server-side |

## 1. Objective

Call the local invoice API without its required identifier and capture the 500 JSON error containing the debug marker.

## 2. What the Player Sees

Release notes mention a fictional invoice API. Calling `/?route=api-invoice&id=1001` shows the response shape; omitting `id` returns a detailed JSON error.

## 3. What Is Actually Happening

The API branch sets HTTP 500, emits `application_exception`, and serializes exception name, internal file path, line, and `app_settings.api_exception_marker` directly to the client.

## 4. Step-by-Step Lab Walkthrough

1. Optionally request `/?route=api-invoice&id=1001` to establish the API route and normal JSON shape.
2. Request `/?route=api-invoice` with the `id` parameter omitted.
3. Record status 500 and `FLAG{A10_API_ERROR_LEAK_02}` plus the internal path/line in the JSON body.
4. Correlate the response with the Apache record and rule 100512 event using timestamp/request ID.

All actions above are bounded to the local VulnForge-LAMP instance and its fictional data.

## 5. Evidence Trail

- **HTTP request/response:** A no-ID GET returns HTTP 500 JSON with exception, file, line, and marker.
- **Browser-visible clues:** The expected response or local artifact displays `FLAG{A10_API_ERROR_LEAK_02}` when the challenge condition is met.
- **Database/server-side evidence:** The marker is `app_settings.api_exception_marker`; no invoice query occurs in the missing-ID branch.
- **Apache visibility:** Records the API request and 500 status.
- **`/var/log/vulnforge/app_events.jsonl`:** `application_exception` with route `api-invoice`, A10, status 500, and a sanitized missing-identifier message.
- **Fake in-app audit visibility:** None.
- **Wazuh visibility:** If collection and rules are installed, use the interpretation below; absence of an alert must be checked against source and rule coverage.

## 6. Wazuh Notes

- **Likely `event_type`:** `application_exception`
- **Likely route:** `api-invoice`
- **Likely rule/group:** Rule `100512`, “Northstar application exception,” group `application_error`
- **Sample dashboard query:** ``data.event_type:"application_exception" and data.route:"api-invoice" and data.http_status:500``
- **What the alert proves:** The API encountered its missing-identifier exception path and returned a server-error status.
- **What the alert does not prove:** The Wazuh event does not prove exactly which debug fields reached the client or that any invoice data was accessed.

## 7. Noise and Detection-Awareness Notes

Client bugs, health checks, and manual exploration can omit required parameters. Treat the event as an application-quality and disclosure lead; correlate response content, frequency, source, and adjacent successful API reads. This observation is for defensive interpretation, not advice to avoid monitoring.

## 8. Common Mistakes

Treating the compatibility path `/api/invoice.php` as a different challenge, claiming invoice access occurred, or reporting only the 500 without the leaked error contract. The compatibility endpoint delegates to the same `api-invoice` route.

## 9. Remediation

Validate required parameters and return a minimal 400 response such as a stable error code and request ID; keep file/line/stack/debug data in protected server logs; document the API contract.

## 10. Detection Engineering Improvement

Differentiate validation errors from unexpected exceptions, include safe API operation and correlation fields, and alert separately on unhandled 5xx spikes versus expected client 4xx errors.

## 11. Analyst Takeaway

The 500 and exception event establish the path; the client response establishes leakage. Safe APIs separate consumer-facing error contracts from diagnostic detail.
