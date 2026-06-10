# Hardening Guide

This guide describes how each teaching defect should be removed. A remediated fork should also eliminate directory aliases, debug markers, lab credentials, unsafe permissions, and the scoreboard’s plaintext flags. Do not treat selective fixes as sufficient for internet deployment.

## Global production baseline

- Start from a new, supported host rather than promoting the training VM.
- Bind through a deliberately designed network tier; use TLS, host firewalling, authentication rate limits, secure headers, and least privilege.
- Move secrets to a managed secret store, rotate all credentials, and prohibit defaults.
- Disable `display_errors`, directory indexes, debug routes, and backup/log aliases.
- Run PHP/Apache and database identities with minimum permissions; make code read-only.
- Add automated dependency inventory, security review, tests, centralized logs, monitoring, and incident response procedures.
- Use only synthetic data in non-production environments.

## Challenge remediation map

| Category / challenge | Root cause | Remediation summary | Detection / validation |
|---|---|---|---|
| A01 Invoice IDOR | Query fetches invoice by ID without owner authorization. | Centralize object authorization and query by both invoice ID and authenticated user/tenant; permit privileged access through explicit policy. | Test horizontal and vertical access for every object ID; alert on repeated denied IDs. |
| A01 Support preview bypass | Client query value participates in the authorization decision. | Ignore presentation controls for authorization; enforce server-side role/ownership policy before loading restricted content. | Unit-test every role/action matrix and log denied restricted-ticket requests. |
| A02 Backup exposure | Backup is under a web alias with indexes enabled. | Store backups outside web roots, encrypt them, restrict service identities, disable indexing, and test deployment artifacts. | CI/CD deny-list for backup extensions and external content discovery scans. |
| A02 Diagnostics overshare | Unauthenticated detailed diagnostics expose internals. | Return only health status; protect operational detail with strong admin authentication and network policy; remove secrets/paths. | Test responses for sensitive keys and monitor access to health/admin endpoints. |
| A03 Package documentation | Unreviewed/outdated dependency content is deployed. | Maintain an SBOM, pin reviewed versions with integrity verification, exclude development docs, and define update ownership. | Dependency policy and artifact-content checks in CI. |
| A03 Unsafe helper | Dependency returns unescaped caller content and verbose internals. | Replace/update the component, encode at the output context, disable debug APIs, and wrap third-party calls behind reviewed adapters. | SAST/template tests and dependency advisory monitoring. |
| A04 Base64 field | Encoding is mistaken for confidentiality. | Classify the data; use authenticated encryption with managed keys when confidentiality is required, or do not store it. | Data-flow review and tests confirming ciphertext authentication/key rotation. |
| A04 MD5 passwords | Fast unsalted legacy hash. | Rehash with `password_hash()` using Argon2id/bcrypt, verify with `password_verify()`, and transparently migrate on login. | Flag weak schemes in schema/code and monitor migration completion. |
| A05 Catalog SQL injection | Raw interpolation of search text. | Use prepared statements and bound parameters; return only needed columns; use a least-privilege DB account. | Injection regression tests, SAST, query anomaly monitoring. |
| A05 Simulated command chain | User input is parsed as multiple trusted operations. | Use an enum/allowlist selected server-side, accept one operation per request, reject delimiters, and never invoke a shell. | Test separators/unknown operations and log rejected operation names. |
| A06 Refund flaw | Calculation occurs without positive quantity, purchase, status, limit, or idempotency checks. | Model refund state transitions; verify order ownership, refundable balance, positive quantities, coupon eligibility, and idempotency in one transaction. | Business-abuse tests and alerts for negative/duplicate/excess refunds. |
| A06 Predictable reset | Deterministic long-lived token based on public values. | Generate a CSPRNG token, store only a hash, expire quickly, bind to one account/purpose, invalidate after use, and rate-limit. | Alert on repeated failures and test entropy, expiry, replay, and account binding. |
| A07 Default admin | Documented shared credential remains enabled. | Require unique enrollment, force rotation, remove shared accounts, apply MFA to administration, and rate-limit authentication. | Deployment gate for defaults; alerts on admin login and brute-force patterns. |
| A07 Remember-me token | Unsigned Base64 user ID authenticates directly. | Use random opaque server-side tokens with hashed storage, rotation, device/session metadata, expiry, revocation, and secure cookie attributes. | Test tampering/replay/logout revocation; monitor token reuse anomalies. |
| A08 Profile import | Unsigned JSON controls effective role. | Treat imported fields as untrusted preferences; schema-validate, allowlist mutable fields, and derive authorization only from server records. Sign imports if provenance matters. | Log imports and test forbidden fields such as role, tenant, and account ID. |
| A08 Upload metadata | Client metadata is marked trusted and exposed. | Generate metadata server-side, store files outside web root, randomize names, content-scan, limit type/size, and authorize downloads. | Upload/download authorization tests and alerts on rejected content. |
| A09 Exposed/tamperable log | Logs are web-accessible, writable by the app group, and contain weak context. | Remove web aliases, use append-only/remote centralized logging, restrict permissions, protect integrity, and minimize sensitive data. | Permission/content checks; detect log stoppage, deletion, and sequence gaps. |
| A09 Missing audit events | Login failures/imports/role effects are omitted. | Define an event taxonomy and capture actor, source, target, action, outcome, request ID, and UTC time for security-relevant events. | Coverage tests map controls to events; alert on auth failures and privilege changes. |
| A10 Product exception | Validation and exception details are rendered to users. | Validate at the boundary, map exceptions to generic errors/correlation IDs, and log details server-side with access control. | Error-response tests ensure no paths, traces, queries, or secrets. |
| A10 API error leak | Missing argument produces verbose JSON and HTTP 500. | Return a stable 400 problem response without internals; use centralized exception middleware and correlation IDs. | Contract tests for status/schema and sensitive-string scanning. |

## Recommended secure code patterns

### Parameterized catalog query

```php
$stmt = db()->prepare(
    'SELECT id, sku, name, description, price FROM products WHERE name LIKE ? OR description LIKE ?'
);
$needle = '%' . $query . '%';
$stmt->execute([$needle, $needle]);
```

### Object-level invoice policy

```php
$stmt = db()->prepare('SELECT * FROM invoices WHERE id = ? AND user_id = ?');
$stmt->execute([$invoiceId, $authenticatedUser['id']]);
```

### Password migration

Use `password_hash($password, PASSWORD_ARGON2ID)` and `password_verify()`. On a successful legacy login, immediately replace the old digest with a modern hash; do not retain the plaintext or log it.

## What should have been logged

At minimum: successful and failed authentication, reset request/verification/use, remember-token issue/rotation/revocation, authorization denial, profile import and rejected fields, effective-role changes, admin action, refund decision, upload decision, and debug/diagnostic access. Log outcomes and stable identifiers, not passwords, reset tokens, session cookies, or full sensitive records.
