# Final repository synchronization audit

Audit date: 2026-06-10

## 1. Purpose

This audit verifies that the release-candidate bug-audit workstream and the instructor walkthrough/SOC telemetry workstream are fully merged, internally consistent, and statically ready for the first Ubuntu VM installation. It is limited to synchronization, conflict cleanup, documentation/reference consistency, and regression checks; it does not add features, flags, hardening, or route changes.

## 2. Branch/commit checked

- Branch: `work`
- Baseline commit audited: `d6ea259ba413c9f0e422a852e41ac413064c3045`
- Final audit changes are recorded by the commit containing this document.

## 3. Merge-conflict artifact results

- `git status --short --branch` showed a clean `work` branch before audit edits.
- Repository-wide searches found none of the three standard version-control conflict delimiter patterns.
- The non-Markdown conflict-language scan found no `HEAD`, incoming/current-change, or stashed-change artifacts.
- Review of challenge headings, telemetry rows, installer/reset blocks, and audit sections found no duplicate conflict-resolution sections.

## 4. File presence results

All required release-audit, Wazuh integration, query/playbook, and instructor documentation files are present. This includes the complete release documentation set, three Wazuh XML files, manager samples, two query/playbook documents, and all seven files under `docs/instructor/` named in the audit requirements.

## 5. Flag consistency results

- `install/seed.sql` contains exactly 20 unique flags.
- `docs/instructor/FLAG_WALKTHROUGHS.md` contains the same 20 unique flags; the sorted flag diff is empty.
- Each OWASP Top 10:2025 category A01 through A10 has exactly two unique seeded flags.
- `docs/instructor/FLAG_WALKTHROUGHS.md` has exactly 20 `# Challenge:` sections.
- `docs/instructor/WAZUH_FLAG_TELEMETRY_GUIDE.md` has exactly 20 machine-countable flag rows.
- No flag value was added, removed, renamed, or modified.

## 6. Route/doc synchronization results

- Documented application route names resolve to cases in `public/index.php`, the explicit `api-invoice` branch, or the `logout` pre-switch handler.
- `/api/invoice.php` exists as a compatibility endpoint that delegates to the `api-invoice` route; the walkthrough wording was synchronized accordingly.
- `/backup/`, `/uploads/`, and `/logs/` are intentional Apache aliases rather than front-controller routes.
- Required log paths are consistent: `/var/log/apache2/vulnforge_access.log`, `/var/log/apache2/vulnforge_error.log`, and `/var/log/vulnforge/app_events.jsonl`.
- Required application roots are consistent: `/var/www/vulnforge` and `/var/www/vulnforge/public`.
- No alternative stale application root or log filename was found.

## 7. Installer/reset results

Static review confirms `install/install.sh` retains strict mode, Ubuntu-only package installation, complete IPv4 and loopback/RFC1918 bind validation, public-bind rejection, database identifier validation, MariaDB setup, seed import, staged application installation, runtime PHP database configuration, Apache vhost installation, structured log creation, and the local-only warning. It neither installs Wazuh nor modifies `ossec.conf`.

Static review confirms `install/reset_lab.sh` retains strict mode, an absolute non-root VulnForge root guard plus expected baseline/seed checks, database reseeding, bounded removal and restoration of uploads/backups/fake logs under the validated lab root, and reset of `/var/log/vulnforge/app_events.jsonl`. It does not modify Wazuh.

## 8. Wazuh integration results

- All three supplied XML files parse successfully.
- Wazuh remains optional and is not installed by the main installer.
- Documentation consistently requires manually merging applicable `<localfile>` blocks into the existing `/var/ossec/etc/ossec.conf` and explicitly forbids overwriting that file.
- Application name `northstar-vulnforge`, event types, rule IDs/groups, dashboard fields, and required log paths align across application telemetry, manager rules, dashboard filters, Wazuh documentation, and instructor telemetry material.
- The pack configures no active response, contains no monitoring-evasion guidance, and repeatedly states that an alert is a lead requiring correlation rather than proof of compromise.

## 9. Instructor documentation results

- Exactly 20 challenge walkthrough sections are present.
- Exactly 20 Wazuh flag telemetry rows are present.
- Exactly 12 detection lab exercises are present.
- Spoiler warnings appear in `docs/instructor/README.md`, the repository `README.md`, and `docs/PLAYER_GUIDE.md`; players are told not to use instructor material during blind runs.
- Every seeded flag appears in the complete walkthrough file.

## 10. Static test results

Passed checks:

- Repository smoke test.
- PHP syntax validation for every PHP file under `app/` and `public/`.
- Bash syntax validation for installer, reset, and smoke scripts.
- Wazuh XML parsing.
- Exact flag diff/count/category checks and instructor section/row/exercise counts.
- Merge-marker and conflict-artifact searches.
- Relative Markdown link validation across `README.md`, `docs/**/*.md`, and `wazuh/**/*.md`.
- Remote HTTP(S) application asset scan.
- PHP OS command-execution API scan.
- Git whitespace checks.

`ShellCheck` was not installed in the audit container and is recorded as an environment limitation, not a passing check.

## 11. Known limitations

- The audit container is not the target Ubuntu systemd VM and does not provide live Apache, MariaDB, or Wazuh services.
- Package installation, live database import, Apache virtual-host behavior, HTTP challenge workflows, Wazuh enrollment/decoding/rule firing, service restarts, and reset behavior against installed services require VM validation.
- The application is intentionally vulnerable. A09 fake-audit logging gaps and all other intended challenge mechanics remain unchanged.
- Fake credentials and the fake backup password are deliberate, documented lab artifacts; no real secret material was found.

## 12. Manual Ubuntu VM test checklist

After cloning on Ubuntu VM:

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

## 13. Final readiness assessment

**READY_FOR_UBUNTU_INSTALL**

No unresolved conflict markers remain; all required files and 20 flags are present; documentation, routes, paths, telemetry, installer/reset behavior, and optional Wazuh guidance are synchronized; and all available required static checks pass. The remaining work is the explicitly documented live Ubuntu VM validation.
