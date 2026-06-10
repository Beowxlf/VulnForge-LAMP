#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
required=(README.md docs/MASTER_DESIGN.md docs/INSTALL_UBUNTU_LAMP.md docs/FLAG_GUIDE_INSTRUCTOR.md docs/PLAYER_GUIDE.md docs/HARDENING_GUIDE.md install/install.sh install/reset_lab.sh install/seed.sql apache/vulnforge.conf app/helpers/bootstrap.php public/index.php logs/app.log uploads/welcome.txt backup/northstar-backup.sql.bak)
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
if rg -n '\b(shell_exec|exec|system|passthru|proc_open|popen)\s*\(' --glob '*.php' app public; then
  echo 'unsafe OS command execution API found' >&2
  exit 1
fi
php_files=$(find app public -type f -name '*.php' -print)
while IFS= read -r file; do php -l "$file" >/dev/null; done <<< "$php_files"
bash -n install/install.sh install/reset_lab.sh tests/smoke.sh
echo 'VulnForge static smoke tests passed.'
