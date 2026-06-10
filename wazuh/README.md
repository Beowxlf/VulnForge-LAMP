# Optional Wazuh integration pack

This directory provides **optional** lab telemetry configuration for a Wazuh
agent installed on the Northstar/VulnForge Ubuntu VM and a separate Wazuh
manager. The main installer does not install, enroll, configure, or contact
Wazuh. Nothing in this pack sends data to a third-party service.

## Contents

- `agent/ossec-localfile-vulnforge.xml` — local log collection blocks to merge
  manually into the agent's `/var/ossec/etc/ossec.conf`.
- `manager/local_rules.xml` — conservative custom manager rules using IDs
  `100500`–`100513`.
- `manager/local_decoder.xml` — explains why the built-in JSON decoder is used.
- `manager/logtest_samples.txt` — sanitized events for `wazuh-logtest`.
- `queries/wazuh_dashboard_filters.md` — starter Discover/dashboard filters.
- `queries/investigation_playbooks.md` — evidence-driven SOC exercises.

Start with [`docs/WAZUH_INTEGRATION.md`](../docs/WAZUH_INTEGRATION.md). Keep the
vulnerable application and all Wazuh systems on an isolated private/internal
lab network; never expose VulnForge to the internet.
