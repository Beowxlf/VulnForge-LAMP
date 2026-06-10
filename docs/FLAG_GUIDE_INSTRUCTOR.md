# Instructor Flag Guide

> Instructor material for an authorized, isolated lab. All people, credentials, commerce records, and secrets are fictional. Avoid demonstrating these concepts against public or third-party systems.

## Facilitation notes

Start learners as `guest@northstar.local`, encourage evidence capture before flag submission, and discuss the difference between root cause, exploit symptom, business impact, detection opportunity, and remediation. The intended paths below are conceptual and non-destructive. Use the reset script between cohorts.

## Complete flag map

| # | Category | Challenge | Difficulty | Flag / location | Intended solution summary |
|---:|---|---|---|---|---|
| 1 | A01 | Someone Else’s Invoice | Easy | `FLAG{A01_INVOICE_IDOR_01}` in invoice 1002 | Authenticate, notice numeric invoice IDs, and request another fictional user’s invoice. The controller loads by ID without comparing `user_id`. |
| 2 | A01 | Restricted Support Preview | Medium | `FLAG{A01_ADMIN_TICKET_BYPASS_02}` in restricted ticket 3 | The ticket route treats the client-provided preview mode as equivalent to authorization, exposing an admin-only fake ticket. |
| 3 | A02 | Nightly Backup Exposure | Easy | `FLAG{A02_EXPOSED_BACKUP_01}` in `/backup/northstar-backup.sql.bak` | Follow or enumerate the indexed backup alias and inspect the fake export. |
| 4 | A02 | Diagnostics Overshare | Easy | `FLAG{A02_VERBOSE_DIAGNOSTICS_02}` in detailed status | Enable the detailed diagnostics view and observe environment/path disclosure. |
| 5 | A03 | Outdated Package Notes | Easy | `FLAG{A03_OUTDATED_PACKAGE_DOC_02}` in package README | Inspect the fictional package documentation under `app/vendor/fake-vendor/`. |
| 6 | A03 | Unsafe Helper Banner | Medium | `FLAG{A03_UNSAFE_HELPER_OUTPUT_01}` from helper debug banner | Follow the changelog to the vendor demo and enable verbose output. Discuss the helper’s unescaped greeting separately. |
| 7 | A04 | Base64 Is Not Encryption | Easy | `FLAG{A04_WEAK_ENCODING_01}` in analyst encoded note | Sign in as the analyst and locally Base64-decode the exported private field. |
| 8 | A04 | Legacy Password Storage | Medium | `FLAG{A04_WEAK_HASH_PROFILE_02}` in Morgan Chen’s profile | Observe MD5 labeling and use the access-control weaknesses/default lab accounts to inspect the fake profile clue. Emphasize offline weakness, not password reuse. |
| 9 | A05 | Catalog Query Injection | Medium | `FLAG{A05_SQLI_CATALOG_01}` in product internal note | Demonstrate that catalog input is concatenated into SQL and can make hidden selected columns visible. Keep activity confined to the fake catalog. |
| 10 | A05 | Diagnostic Command Chain | Easy | `FLAG{A05_SIMULATED_COMMAND_CHAIN_02}` from command console | Chain the interpreter’s documented `show marker` operation after a normal operation. It is intentionally parser injection, not OS command execution. |
| 11 | A06 | Negative Refund Quantity | Medium | `FLAG{A06_REFUND_LOGIC_01}` from `LABREFUND` | Submit a negative quantity with the lab coupon. The design performs arithmetic before validating direction or business state. |
| 12 | A06 | Predictable Reset Token | Medium | `FLAG{A06_PREDICTABLE_RESET_02}` in reset verifier | Infer `reset-<user-id>-2026` from the hint and verify a seeded fake user’s token. No email or account change occurs. |
| 13 | A07 | Factory Admin Credentials | Easy | `FLAG{A07_DEFAULT_ADMIN_01}` on admin dashboard | Sign in using the documented lab default `admin123`. |
| 14 | A07 | Remember-Me Impersonation | Medium | `FLAG{A07_PREDICTABLE_REMEMBER_TOKEN_02}` in settings | Decode `remember_lab`, change `user:N`, re-encode it, and revisit the portal. The marker is associated with understanding the cookie design; instructors may reveal it after successful impersonation. |
| 15 | A08 | Unsigned Profile Import | Medium | `FLAG{A08_CLIENT_ROLE_TRUST_01}` after admin-role import | Import JSON whose role is `admin`; the session trusts the unsigned client claim and the admin route accepts it. |
| 16 | A08 | Trusted Upload Metadata | Easy | `FLAG{A08_UNSIGNED_UPLOAD_META_02}` in welcome upload | Browse `/uploads/` and inspect the fake document/metadata. Directory indexing and client trust expose it. |
| 17 | A09 | Writable-Looking Log | Easy | `FLAG{A09_TAMPERABLE_LOG_01}` in `/logs/app.log` | Inspect the exposed sample log and its deliberately weak permissions. Avoid asking learners to damage the file. |
| 18 | A09 | Authentication Event Gap | Medium | `FLAG{A09_MISSING_AUDIT_EVENT_02}` in comparison view | Perform login/import actions, then compare the audit viewer’s records with events that should exist. |
| 19 | A10 | Verbose Product Exception | Easy | `FLAG{A10_VERBOSE_EXCEPTION_01}` in product debug output | Supply a non-integer product ID and capture internal path, component, and marker leakage. |
| 20 | A10 | API Exception Detail | Easy | `FLAG{A10_API_ERROR_LEAK_02}` in API error JSON | Request `/api/invoice.php` without an ID. The endpoint returns an internal path and debug marker. |

## Evidence prompts

For every challenge, ask learners to record: request/route, affected object or control, returned evidence, likely business impact, expected audit event, and one concrete remediation. For A09, have them design fields for actor, source, target, action, outcome, request ID, and timestamp. For A10, contrast user-facing correlation IDs with server-side exception details.

## Reset and cohort cleanup

```bash
sudo /var/www/vulnforge/install/reset_lab.sh
```

The command restores the database, all flags, submissions, uploads, backups, and logs. Revert the VM checkpoint if learners changed operating-system or Apache state outside the exercise.
