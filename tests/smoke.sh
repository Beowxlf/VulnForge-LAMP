#!/usr/bin/env bash
set -euo pipefail
missing_commands=()
for command_name in rg sort wc grep bash find python3 php; do
  command -v "$command_name" >/dev/null 2>&1 || missing_commands+=("$command_name")
done
if (( ${#missing_commands[@]} > 0 )); then
  for command_name in "${missing_commands[@]}"; do
    if [[ $command_name == rg ]]; then
      cat >&2 <<'MESSAGE'
Missing required command: rg
Install on Ubuntu with:
  sudo apt update
  sudo apt install -y ripgrep
MESSAGE
    else
      printf 'Missing required command: %s\n' "$command_name" >&2
    fi
  done
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
required=(README.md RELEASE_AUDIT.md docs/MASTER_DESIGN.md docs/INSTALL_UBUNTU_LAMP.md docs/FLAG_GUIDE_INSTRUCTOR.md docs/PLAYER_GUIDE.md docs/HARDENING_GUIDE.md docs/WAZUH_INTEGRATION.md wazuh/README.md wazuh/agent/ossec-localfile-vulnforge.xml wazuh/manager/local_rules.xml wazuh/manager/local_decoder.xml wazuh/manager/logtest_samples.txt wazuh/queries/wazuh_dashboard_filters.md wazuh/queries/investigation_playbooks.md install/install.sh install/reset_lab.sh install/preflight.sh install/seed.sql apache/vulnforge.conf app/helpers/bootstrap.php public/index.php public/assets/css/main.css public/assets/js/main.js public/assets/img/northstar-mark.svg logs/app.log uploads/welcome.txt backup/northstar-backup.sql.bak)
for file in "${required[@]}"; do [[ -f "$file" ]] || { echo "missing: $file"; exit 1; }; done
warning='This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.'
for file in README.md app/helpers/bootstrap.php install/install.sh; do
  if [[ "$file" == app/helpers/bootstrap.php ]]; then
    rg -F "$warning" "$file" public/index.php >/dev/null
  else
    rg -F "$warning" "$file" >/dev/null
  fi
done
[[ $(rg -o "FLAG\{A[0-9]{2}_[A-Z0-9_]+\}" install/seed.sql | sort -u | wc -l) -eq 20 ]]
for category in A01 A02 A03 A04 A05 A06 A07 A08 A09 A10; do
  [[ $(rg -o "FLAG\{${category}_[A-Z0-9_]+\}" install/seed.sql | sort -u | wc -l) -eq 2 ]]
done
rg -F 'Listen 127.0.0.1:8080' apache/vulnforge.conf >/dev/null
rg -F 'Require local' apache/vulnforge.conf >/dev/null
rg -F '/var/log/vulnforge/app_events.jsonl' app/helpers/bootstrap.php install/install.sh wazuh/agent/ossec-localfile-vulnforge.xml >/dev/null
rg -F 'vulnforge_access.log' apache/vulnforge.conf wazuh/agent/ossec-localfile-vulnforge.xml >/dev/null
rg -F 'vulnforge_error.log' apache/vulnforge.conf wazuh/agent/ossec-localfile-vulnforge.xml >/dev/null
rg -F 'Do not overwrite' wazuh/agent/ossec-localfile-vulnforge.xml >/dev/null
[[ -x install/preflight.sh ]] || { echo 'install/preflight.sh must be executable' >&2; exit 1; }
rg -F 'check_required rg rg ripgrep' install/preflight.sh >/dev/null
rg -F 'ripgrep' install/preflight.sh >/dev/null
rg -F 'ripgrep' README.md >/dev/null
rg -F 'install/preflight.sh' docs/INSTALL_UBUNTU_LAMP.md >/dev/null
if rg -n 'https?://' public app --glob '*.php' --glob '*.css' --glob '*.js' | rg -v "'base_url'"; then
  echo 'external HTTP(S) application resource found' >&2
  exit 1
fi
if rg -n '\b(shell_exec|exec|system|passthru|proc_open|popen)\s*\(' --glob '*.php' app public; then
  echo 'unsafe OS command execution API found' >&2
  exit 1
fi
python3 - <<'PY'
import re
import xml.etree.ElementTree as ET
from pathlib import Path

for path in [
    'wazuh/manager/local_rules.xml',
    'wazuh/manager/local_decoder.xml',
    'wazuh/agent/ossec-localfile-vulnforge.xml',
]:
    ET.parse(path)

index = Path('public/index.php').read_text()
bootstrap = Path('app/helpers/bootstrap.php').read_text()
routes = set(re.findall(r"case '([a-z0-9-]+)'", index)) | {'logout', 'api-invoice'}
references = set(re.findall(r'route=([a-z0-9-]+)', index + bootstrap))
missing = references - routes
if missing:
    raise SystemExit(f'route references without handlers: {sorted(missing)}')
PY
php_files=$(find app public -type f -name '*.php' -print)
while IFS= read -r file; do php -l "$file" >/dev/null; done <<< "$php_files"
bash -n install/install.sh install/reset_lab.sh install/preflight.sh tests/smoke.sh
echo 'VulnForge static smoke tests passed.'
