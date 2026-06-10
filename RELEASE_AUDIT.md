# Release-candidate audit

Audit date: 2026-06-10

## Checks performed

- Reviewed public and authenticated route handlers, navigation targets, session redirects, page headers, bundled assets, and upload behavior.
- Cross-checked all 20 seeded flags and the two-flags-per-category A01–A10 distribution against the player, instructor, and hardening guides.
- Reviewed installer and reset behavior, Apache aliases and upload execution policy, database table/foreign-key order, telemetry fields and sensitive-data omissions, and optional Wazuh configuration.
- Ran the repository smoke test, PHP and Bash syntax checks, XML parsing, flag-count checks, remote-asset and OS-command API scans, and `git diff --check`.

## Issues found

- Installer reruns from `/var/www/vulnforge` could remove the running source tree before copying it.
- Installer database environment overrides were used for MariaDB setup but were not persisted to the PHP application configuration.
- Public-bind validation accepted malformed strings that merely began with an RFC1918 prefix.
- Reset accepted an insufficiently validated root path and did not explicitly report host telemetry restoration.
- The upload form displayed a success message even when `move_uploaded_file()` failed.
- The Wazuh agent snippet had multiple top-level XML elements, the decoder documentation had no XML root, and the smoke assertion did not match the snippet wording.
- The instructor guide described the remember-me flag as appearing in settings rather than in the restored-session dashboard notice.

## Fixes made

- Stage the complete application before replacing the target, restore baseline artifact directories on install, and generate a local PHP runtime database configuration using the installed values.
- Validate complete IPv4 addresses and permit only exact loopback or RFC1918 ranges; validate database identifiers before using them in SQL or reset commands.
- Require a safe absolute lab root plus the expected seed/baseline structure before reset removes any artifact directories.
- Render upload success only after a successful move and provide a styled error otherwise.
- Make all supplied Wazuh files standalone parseable XML while retaining merge-not-overwrite instructions and built-in JSON decoding behavior.
- Correct the instructor location text and expand smoke coverage for XML parsing and broken route references.

## Known limitations

- The audit environment is not an Ubuntu systemd VM and has no MariaDB client/server, Apache service, or Wazuh installation. Package installation, live `seed.sql` import, `apache2ctl configtest`, HTTP workflows, and Wazuh service validation remain manual VM release checks.
- `shellcheck` is not installed in the audit environment; Bash syntax checks pass.
- Intentionally vulnerable mechanics remain deliberately unsafe and must never be exposed outside an isolated lab.

## Manual Ubuntu VM test checklist

- [ ] Install from a fresh repository checkout with default settings; confirm package installation, seed import, Apache config test, and `http://127.0.0.1:8080/`.
- [ ] Rerun `/var/www/vulnforge/install/install.sh`; confirm the installed-tree idempotency path completes and baseline files are restored.
- [ ] Install with an RFC1918 `VULNFORGE_BIND_IP` and reject malformed/public addresses; verify the VM remains on a Private/Internal network.
- [ ] Install once with non-default `VULNFORGE_DB_NAME`, `VULNFORGE_DB_USER`, and `VULNFORGE_DB_PASS`; confirm login and reset use the same database.
- [ ] Exercise login, logout, remember-me restoration, every navigation link, unauthenticated redirects, admin challenge paths, upload success/failure, API error output, mobile navigation, and all 20 flag submissions.
- [ ] Confirm `/backup/`, `/uploads/`, and `/logs/` indexing matches the challenge guide, while uploaded `.php` files are served without execution.
- [ ] Run reset after creating submissions and changing uploads/backups/logs; confirm seed data, flags, submissions, baseline artifacts, and `/var/log/vulnforge/app_events.jsonl` return to baseline.
- [ ] Validate generated JSON Lines and permissions, merge Wazuh `<localfile>` blocks into the existing `ossec.conf`, run `wazuh-logtest`, and confirm no installer step installs Wazuh or overwrites manager/agent configuration.

## Final synchronization after instructor documentation merge

The final synchronization audit on 2026-06-10 confirmed that the release-audit and instructor/SOC workstreams are present together with no unresolved conflict markers. All 20 seeded flags match the full instructor walkthroughs, each A01–A10 category retains exactly two flags, documented routes resolve to the front controller, compatibility endpoint, or intentional Apache alias, and the required application, Apache, and Wazuh paths are consistent.

The synchronization review corrected only documentation merge drift: the Wazuh per-flag matrix now has 20 machine-countable flag rows, and the API walkthrough now identifies `/api/invoice.php` accurately as a compatibility endpoint for the `api-invoice` route. No challenge mechanics, flags, route behavior, A09 logging gaps, or telemetry sensitivity boundaries changed.

Static smoke, PHP syntax, Bash syntax, XML parsing, Markdown relative-link, remote-asset, PHP OS-command API, and whitespace checks must pass before release. `shellcheck` may be unavailable when it is not installed. Live Apache, MariaDB, and optional Wazuh service testing cannot be completed in this audit container and must occur on the Ubuntu VM.

### Final Ubuntu VM command checklist

After cloning on the Ubuntu VM:

```bash
sudo ./install/install.sh
sudo apachectl configtest
sudo systemctl status apache2 --no-pager
sudo systemctl status mariadb --no-pager
curl -i http://127.0.0.1:8080/
sudo tail -n 20 /var/log/apache2/vulnforge_access.log
sudo tail -n 20 /var/log/apache2/vulnforge_error.log
sudo tail -n 20 /var/log/vulnforge/app_events.jsonl
sudo ./install/reset_lab.sh
./tests/smoke.sh
```

If Wazuh is installed later:

```bash
sudo systemctl status wazuh-agent --no-pager
sudo tail -n 50 /var/ossec/logs/ossec.log
sudo /var/ossec/bin/agent_control -l
```

Manager-side:

```bash
sudo /var/ossec/bin/wazuh-logtest
sudo systemctl restart wazuh-manager
sudo systemctl status wazuh-manager --no-pager
```
