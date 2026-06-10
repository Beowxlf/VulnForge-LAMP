#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./install/reset_lab.sh"; exit 1; }
CONFIG=/etc/vulnforge-lab.conf
if [[ -r "$CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG"
else
  VULNFORGE_DB_NAME="${VULNFORGE_DB_NAME:-vulnforge}"
  VULNFORGE_ROOT="${VULNFORGE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
fi
ROOT="${VULNFORGE_ROOT:-/var/www/vulnforge}"
DB_NAME="${VULNFORGE_DB_NAME:-vulnforge}"

[[ $ROOT = /* && $ROOT != / ]] || { echo "Refusing unsafe lab root: $ROOT" >&2; exit 1; }
[[ -f "$ROOT/install/seed.sql" && -d "$ROOT/install/baseline/uploads" && -d "$ROOT/install/baseline/logs" && -d "$ROOT/install/baseline/backup" ]] || {
  echo "Refusing reset because the expected VulnForge seed and baseline files are missing under: $ROOT" >&2
  exit 1
}
[[ $DB_NAME =~ ^[A-Za-z0-9_]+$ ]] || { echo "Refusing invalid database name: $DB_NAME" >&2; exit 1; }

mysql "$DB_NAME" < "$ROOT/install/seed.sql"
rm -rf -- "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
mkdir -p "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
cp -a "$ROOT/install/baseline/uploads"/. "$ROOT/uploads"/
cp -a "$ROOT/install/baseline/logs"/. "$ROOT/logs"/
cp -a "$ROOT/install/baseline/backup"/. "$ROOT/backup"/
chown -R root:www-data "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
chmod 0777 "$ROOT/uploads" "$ROOT/logs"
chmod 0666 "$ROOT/logs/app.log"
chmod 0755 "$ROOT/backup"
chmod 0644 "$ROOT/backup/"*
install -d -o www-data -g adm -m 0750 /var/log/vulnforge
install -o www-data -g adm -m 0640 /dev/null /var/log/vulnforge/app_events.jsonl
echo "Reset complete: database, submissions, flags, uploads, backups, sample logs, and host telemetry restored."
echo "This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet."
