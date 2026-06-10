# Optional Wazuh integration

> **Lab use only.** VulnForge is intentionally vulnerable. Keep it on an
> isolated Hyper-V Private or carefully controlled Internal switch and never
> expose it to the internet.

This integration lets a Wazuh agent on the Northstar/VulnForge Ubuntu VM collect
local Apache, application, authentication, and database logs and forward them to
a separate Wazuh manager for SOC training. It is entirely optional: the main
installer does not install Wazuh, enroll an agent, modify `ossec.conf`, add
active response, or contact a third-party service.

## 1. Recommended topology

- **Wazuh manager VM:** Wazuh server/indexer/dashboard, maintained separately
  from the vulnerable target.
- **Northstar/VulnForge Ubuntu VM:** Apache/PHP/MariaDB application plus an
  optional Wazuh agent.
- **Optional attacker/browser VM:** a disposable system used only for authorized
  lab traffic.

Attach every VM to the same Hyper-V **Private** switch, or to an **Internal**
switch with tightly controlled host access. Use static RFC1918 addresses. Do not
configure public DNS, inbound NAT, internet port forwarding, a public reverse
proxy, or cloud tunneling for the vulnerable portal. If package access is needed,
use a temporary controlled adapter and disconnect it before exercises.

## 2. Telemetry sources

| Source | Purpose | Important limitation |
|---|---|---|
| `/var/log/apache2/vulnforge_access.log` | Request/source/status timeline and direct alias access | Limited application identity/authorization context |
| `/var/log/apache2/vulnforge_error.log` | Apache/PHP operational errors | An error is not automatically an attack |
| `/var/log/vulnforge/app_events.jsonl` | Sanitized structured application events | Lab telemetry; not every challenge logs cleanly |
| `/var/log/auth.log` | Ubuntu authentication activity | Host evidence, not portal authentication |
| `/var/log/mysql/error.log` or `/var/log/mysql/mariadb.log` | Database service errors | Path is package/distro dependent |
| VulnForge `audit_logs` and web-visible `logs/app.log` | Intentionally incomplete/tamperable A09 challenge evidence | May omit or misrepresent important events |

The installer creates `/var/log/vulnforge/app_events.jsonl` with ownership that
allows the Apache worker to append and the local `adm` group to read. Each line
is one JSON object. Events include timestamps, host/request/source metadata,
authenticated fictional identity when available, event classification, outcome,
and a bounded message. They never intentionally include passwords, reset-token
values, session or remember-me cookie values, authorization headers, raw flag
submissions, or uploaded file contents.

The reset command truncates the JSONL telemetry so a new exercise begins with a
clean host log. Export evidence before resetting if it is needed for review.

## 3. Install and enroll the Wazuh agent manually

Use the official Wazuh dashboard **Deploy new agent** workflow or the official
Wazuh Linux agent installation documentation for your exact Wazuh release and
Ubuntu version. Enter the private address of the separate manager and a clear
agent name such as `northstar-lab`.

Do not add Wazuh installation to `install/install.sh`. Do not point the agent at
a public or third-party manager. This repository deliberately does not embed a
manager address, enrollment password, repository key, or unattended installer.

## 4. Add local log collection

On the VulnForge VM, open the existing agent configuration:

```bash
sudoedit /var/ossec/etc/ossec.conf
```

Copy the applicable `<localfile>` blocks from
`wazuh/agent/ossec-localfile-vulnforge.xml` **inside the existing
`<ossec_config>` element**. Do not overwrite the rest of `ossec.conf`.

For the database source, check which file exists and enable only that path:

```bash
sudo test -f /var/log/mysql/error.log && echo mysql-error
sudo test -f /var/log/mysql/mariadb.log && echo mariadb-log
```

Depending on Ubuntu/Wazuh packaging, the agent service account may need local
read access through the `adm` group. Prefer the package-supported group and ACL
approach; do not make host logs world-readable.

Validate the agent configuration according to the installed Wazuh version, then
restart and inspect status:

```bash
sudo systemctl restart wazuh-agent
sudo systemctl status wazuh-agent --no-pager
sudo tail -n 100 /var/ossec/logs/ossec.log
```

## 5. Install manager rules

On the separate Wazuh manager, back up existing local customization and merge the
contents of `wazuh/manager/local_rules.xml` into:

```text
/var/ossec/etc/rules/local_rules.xml
```

The pack uses custom rule IDs `100500`–`100513`. Confirm they do not collide with
other local rules. The JSON source uses Wazuh's built-in JSON decoder, so no
custom decoder is required; `wazuh/manager/local_decoder.xml` documents that
decision. If future custom decoders are added, place them under:

```text
/var/ossec/etc/decoders/local_decoder.xml
```

No rule in this pack configures active response. The rules are conservative
training signals and should not block, delete, quarantine, or execute commands.
After validation, restart the manager using the service procedure appropriate to
your Wazuh installation.

## 6. Test with `wazuh-logtest`

Run the manager-side tester:

```bash
sudo /var/ossec/bin/wazuh-logtest
```

Paste one sanitized line at a time from
`wazuh/manager/logtest_samples.txt`. Confirm that JSON events first match rule
`100500` and then the expected child rule. Repeated/frequency rules require
multiple matching lines with the same source field; adjust only in the isolated
lab. Test the Apache sample separately for backup rule `100506`.

For a non-interactive single sample:

```bash
printf '%s\n' '{"app":"northstar-vulnforge","event_type":"admin_access_denied","src_ip":"192.168.56.30"}' | sudo /var/ossec/bin/wazuh-logtest
```

If dynamic JSON fields do not match, inspect the decoder output from phase 2 and
adapt local field names to the installed Wazuh release rather than adding a
payload-capturing decoder.

## 7. Suggested dashboard filters

Starter filters are in `wazuh/queries/wazuh_dashboard_filters.md`. Useful pivots
include:

- `rule.groups: "vulnforge"`
- `data.app: "northstar-vulnforge"`
- `data.event_type: "login_failure"`
- `data.event_type: ("admin_access_denied" or "invoice_idor_suspected")`
- `location: "/var/log/apache2/vulnforge_access.log"`
- `rule.id: ("100502" or "100504" or "100506" or "100511")`

Always inspect an indexed event first because field mappings vary by Wazuh
version. Save separate Apache and JSONL views, then correlate on source and a
narrow timestamp window; `request_id` is available within app events and in the
response header but is not added to the default Apache combined format.

## 8. Investigation playbooks

Detailed steps are in `wazuh/queries/investigation_playbooks.md` for:

1. Login brute force against fake accounts.
2. IDOR invoice access.
3. Admin bypass attempts.
4. Backup directory access.
5. Upload activity.
6. Diagnostics abuse.
7. A09 logging-gap comparison.

The core method is to compare Apache transport evidence, sanitized app telemetry,
database/user/session context, and the deliberately incomplete fake audit trail.

## 9. Preserving the A09 challenge

Wazuh support does **not** repair the A09 Security Logging and Alerting Failures
lesson. Three evidence planes intentionally differ:

- Apache records requests and direct access to aliases such as `/backup/`, but
  lacks rich application intent.
- `app_events.jsonl` supplies selected structured host telemetry while preserving
  challenge behavior and avoiding secret/raw-value collection.
- The database-backed audit viewer and `logs/app.log` remain fake, incomplete,
  weakly attributed, and tamperable. Authentication failures, profile imports,
  and effective-role changes remain absent from that in-app audit view.

A learner should discover that an event may appear in Apache and/or Wazuh while
being absent or misleading in the in-app audit record. Partial external evidence
does not make the application's audit design complete or trustworthy.

## 10. Known limitations

- This is lab telemetry, not a production logging architecture.
- Not every intentionally vulnerable challenge logs cleanly or completely.
- A Wazuh alert is a triage lead and does not prove compromise by itself.
- Validate conclusions with Apache logs, app logs, database state, and
  user/session context.
- `src_ip` is the direct peer from `REMOTE_ADDR`; the app does not trust forwarded
  headers. If a reverse proxy is introduced, document the changed evidence model.
- The application silently continues if the JSONL file is unavailable so that an
  optional telemetry failure does not break challenge routes. Monitor Wazuh agent
  health and file permissions separately.
- Frequency and dynamic-field behavior may vary by Wazuh release; validate every
  local rule with `wazuh-logtest` before an exercise.
