# Player Guide

## Safety and objective

This is an authorized, local-only exercise containing only fictional data. Never aim these techniques at systems you do not own or have explicit permission to test.

> **This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.**

Find all 20 flags and submit them on the authenticated **Scoreboard** page. Flags look like `FLAG{CATEGORY_DESCRIPTION_01}`. Use browser developer tools, HTTP inspection, careful parameter changes, and local decoding/query reasoning. Do not modify the host OS or use destructive commands.

## Accounts

| Email | Password |
|---|---|
| `admin@northstar.local` | `admin123` |
| `analyst@northstar.local` | `analyst123` |
| `j.smith@northstar.local` | `smith123` |
| `m.chen@northstar.local` | `chen123` |
| `guest@northstar.local` | `guest` |

These credentials are intentionally obvious, fake, and valid nowhere else.

## How to approach the portal

Treat Northstar Outfitters like a small internal business system rather than a collection of isolated puzzles. Sign in, establish what an ordinary employee can see, and then move through the portal as a staff member would:

1. Start on the **Dashboard** and note the available Finance, Support, Profile, and File Exchange workflows.
2. Build a mental map of public tools such as the **Catalog**, **Portal Search**, **System Status**, and **Release Notes**, then compare them with authenticated areas.
3. Read business records carefully. Invoice references, support status, profile exports, product notes, and operational messages can all reveal how the fictional application trusts data.
4. Use normal browser tools first: inspect links, parameters, forms, cookies, responses, comments, local files, and API output. Make one controlled change at a time.
5. Follow clues between departments. A release note may point to an IT pilot, an account setting may affect an admin view, and a directory listing may complement a portal workflow.
6. Submit discoveries in the **Security Readiness Scoreboard**. It always contains exactly 20 objectives, with two for each OWASP Top 10:2025 category.

The corporate styling is part of the scenario, not a claim that the code is secure. Every exercise remains intentionally vulnerable and confined to fake, resettable data.

## Rules of engagement

- Stay on the VulnForge VM and its private lab network.
- Do not scan public targets or bridge the VM to the internet.
- Do not attempt persistence, malware, credential collection, or destructive shell commands.
- The command-console exercise is deliberately simulated; solve it using its displayed fictional grammar.
- Reset whenever the state becomes confusing.

## Challenge hints

| Category / challenge | Difficulty | Hint level 1 | Hint level 2 |
|---|---:|---|---|
| A01 Someone Else’s Invoice | Easy | Invoice identifiers may be trusted more than ownership. | Compare nearby fictional invoice numbers. |
| A01 Restricted Support Preview | Medium | A support view trusts a preview control. | Inspect the restricted ticket authorization inputs. |
| A02 Nightly Backup Exposure | Easy | Operational leftovers may be web-accessible. | Browse the deliberately indexed backup alias. |
| A02 Diagnostics Overshare | Easy | Status pages can expose too much. | Request detailed status. |
| A03 Outdated Package Notes | Easy | A fictional dependency ships documentation. | Review its package directory and README. |
| A03 Unsafe Helper Banner | Medium | The dependency has verbose support output. | Follow the changelog to the vendor demo. |
| A04 Base64 Is Not Encryption | Easy | A private field is encoded, not encrypted. | Inspect an analyst profile value and decode it locally. |
| A04 Legacy Password Storage | Medium | The profile reveals a legacy hash scheme. | Compare seeded users and their profile clues. |
| A05 Catalog Query Injection | Medium | Search text enters a database query. | Think about selecting normally hidden catalog columns. |
| A05 Diagnostic Command Chain | Easy | The simulated console accepts multiple operations. | Read its safe grammar and chain a marker operation. |
| A06 Negative Refund Quantity | Medium | Sign and workflow state are not validated. | Exercise the lab coupon with an unusual quantity. |
| A06 Predictable Reset Token | Medium | Tokens derive from local public values. | Infer the fake user-ID/year pattern. |
| A07 Factory Admin Credentials | Easy | Defaults were never changed. | Use the documented fictional administrator account. |
| A07 Remember-Me Impersonation | Medium | The cookie is encoded but unsigned. | Decode it, alter the local identifier, and re-encode. |
| A08 Unsigned Profile Import | Medium | Imported JSON is treated as authority. | Change the role in a profile document. |
| A08 Trusted Upload Metadata | Easy | Client metadata is trusted and exposed. | Inspect the upload listing, including metadata artifacts. |
| A09 Writable-Looking Log | Easy | Sample logs have intentionally weak protection. | Browse the exposed log alias. |
| A09 Authentication Event Gap | Medium | Sensitive actions never reach the viewer. | Compare expected events with displayed events. |
| A10 Verbose Product Exception | Easy | Type errors reveal internals. | Give product detail an unexpected identifier type. |
| A10 API Exception Detail | Easy | The API mishandles a missing argument. | Call the invoice endpoint without its required ID. |

## Reset

```bash
sudo /var/www/vulnforge/install/reset_lab.sh
```
