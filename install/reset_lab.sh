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
mysql "$DB_NAME" < "$ROOT/install/seed.sql"
rm -rf "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
mkdir -p "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
cp -a "$ROOT/install/baseline/uploads"/. "$ROOT/uploads"/
cp -a "$ROOT/install/baseline/logs"/. "$ROOT/logs"/
cp -a "$ROOT/install/baseline/backup"/. "$ROOT/backup"/
chown -R root:www-data "$ROOT/uploads" "$ROOT/logs" "$ROOT/backup"
chmod 0777 "$ROOT/uploads" "$ROOT/logs"
chmod 0666 "$ROOT/logs/app.log"
chmod 0755 "$ROOT/backup"
chmod 0644 "$ROOT/backup/"*
echo "Reset complete: database, submissions, flags, uploads, backups, and sample logs restored."
echo "This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet."
