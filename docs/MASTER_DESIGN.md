# VulnForge-LAMP Master Design

## Mission and scope

VulnForge-LAMP is a deliberately insecure, local-only LAMP application for authorized training. Its fictional business interface, **Northstar Outfitters Internal Portal**, teaches exploitation triage, evidence collection, and remediation across the OWASP Top 10:2025. It is not a production starter and must not be internet-facing.

> **This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.**

## Architecture

```text
Training browser
  │ HTTP, isolated switch only
  ▼
Apache 127.0.0.1:8080 (or explicitly selected RFC1918 lab IP)
  ├── public/index.php       plain-PHP front controller
  ├── /backup /uploads /logs deliberately indexed fake artifacts
  ▼
PHP session + helpers
  ├── app/vendor/fake-vendor fictional dependency
  └── PDO
      ▼
MariaDB vulnforge database (fake records only)
```

There are no email, payment, analytics, cloud, identity-provider, update, or external API integrations. PHP routes render server-side HTML. The only API-like endpoint returns fictional invoice JSON.

## Threat model

**Assets:** disposable flags, fake identities, fake invoices, fake support records, and the VM itself. **Expected actor:** an authorized learner on the same private lab. **Out of scope:** public users, production records, internet targets, lateral movement, persistence, malware, credential collection, third-party exfiltration, and destructive command execution.

The app assumes compromise by design. The network and VM boundary—not application controls—must contain it. The simulated command challenge does not call `shell_exec`, `exec`, `system`, or a shell; it parses chained commands from a three-operation fictional grammar.

## Hyper-V recommendation

| Control | Recommendation |
|---|---|
| Virtual switch | **Private** preferred; **Internal** only when the host must participate |
| NAT/port forwarding | None |
| VM firewall | Permit port 8080 only from the dedicated attacker VM if using RFC1918 binding |
| Checkpoints | Clean OS, post-install clean lab, and before major exercise |
| DNS | Optional hosts-file entry; no public DNS |
| Sensitive data | Never place any real data or credentials in the VM |

## Components and data flow

1. Apache accepts local/private HTTP and serves `public/`.
2. `public/index.php` dispatches the `route` query parameter.
3. `app/helpers/bootstrap.php` creates the session, PDO connection, render helpers, and intentionally incomplete audit helper.
4. MariaDB stores users, challenges, scores, and fictional commerce data.
5. Reset templates under `install/baseline/` restore mutable artifact directories.

## Challenge map

| OWASP 2025 category | Challenge 1 | Challenge 2 |
|---|---|---|
| A01 Broken Access Control | Invoice IDOR | Restricted support preview bypass |
| A02 Security Misconfiguration | Indexed backup | Verbose diagnostics |
| A03 Software Supply Chain Failures | Package documentation flag | Unsafe helper debug output |
| A04 Cryptographic Failures | Reversible Base64 field | MD5-era account/profile clue |
| A05 Injection | Raw catalog SQL query | Bounded simulated command chaining |
| A06 Insecure Design | Negative refund logic | Predictable reset token |
| A07 Authentication Failures | Default admin credentials | Unsigned remember-me cookie |
| A08 Software or Data Integrity Failures | Unsigned profile role import | Trusted upload metadata |
| A09 Security Logging and Alerting Failures | Exposed/tamperable sample log | Missing security audit events |
| A10 Mishandling Exceptional Conditions | Product debug exception | API error detail leak |

## Flag design

Flags use `FLAG{CATEGORY_SHORT_DESCRIPTION_NUMBER}`. Exactly 20 scored flags are seeded, two per category. Locations include database records, profiles, indexed backup and upload files, package documentation, helper output, logs, admin settings, API errors, and verbose exception output. Submissions are unique per local user account.

## Known unsafe settings

- Debug mode and detailed errors are enabled.
- SQL is directly interpolated in catalog search.
- Invoice ownership checks are absent.
- A preview query parameter bypasses a support authorization decision.
- Passwords use MD5 and remember-me cookies are unsigned Base64.
- Imported JSON controls an effective role.
- Fake backups/uploads/logs are directory-indexed.
- Sample log and upload directories are intentionally writable.
- Sensitive security events are omitted from audit records.

## Milestone implementation record

1. Structure, schema, installer, and Apache boundary.
2. Home, authentication, dashboard, products, invoices, support, and profiles.
3. A01, A05, and A07 challenge paths.
4. A02, A04, A06, and A10 paths.
5. Fictional dependency, imports, metadata, and logging lessons for A03/A08/A09.
6. Scoreboard, reset baselines, guides, and smoke tests.
