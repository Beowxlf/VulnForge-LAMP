#!/usr/bin/env bash
set -euo pipefail

WARNING="This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet."
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="/var/www/vulnforge"
DB_NAME="${VULNFORGE_DB_NAME:-vulnforge}"
DB_USER="${VULNFORGE_DB_USER:-vulnforge_lab}"
DB_PASS="${VULNFORGE_DB_PASS:-lab-only-password}"
BIND_IP="${VULNFORGE_BIND_IP:-127.0.0.1}"
STAGE_DIR=""

cleanup() {
  if [[ -n "$STAGE_DIR" && -d "$STAGE_DIR" ]]; then
    rm -rf -- "$STAGE_DIR"
  fi
}
trap cleanup EXIT

is_private_bind_ip() {
  local ip=$1 a b c d
  [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  a=$((10#${BASH_REMATCH[1]})); b=$((10#${BASH_REMATCH[2]}))
  c=$((10#${BASH_REMATCH[3]})); d=$((10#${BASH_REMATCH[4]}))
  (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )) || return 1
  (( (a == 127 && b == 0 && c == 0 && d == 1) || a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) ))
}

printf '\n*** %s ***\n\n' "$WARNING"
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./install/install.sh"; exit 1; }
[[ -r /etc/os-release ]] || { echo "Cannot identify operating system."; exit 1; }
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || { echo "This installer supports Ubuntu Server only (found ${ID:-unknown})."; exit 1; }
is_private_bind_ip "$BIND_IP" || { echo "Refusing invalid, non-loopback, or non-RFC1918 bind address: $BIND_IP" >&2; exit 1; }
[[ $DB_NAME =~ ^[A-Za-z0-9_]+$ ]] || { echo "Database name may contain only letters, numbers, and underscores." >&2; exit 1; }
[[ $DB_USER =~ ^[A-Za-z0-9_]+$ ]] || { echo "Database user may contain only letters, numbers, and underscores." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-json curl
systemctl enable --now mariadb apache2

DB_PASS_SQL=${DB_PASS//\\/\\\\}
DB_PASS_SQL=${DB_PASS_SQL//\'/\'\'}
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS_SQL';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS_SQL';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
mysql "$DB_NAME" < "$ROOT_DIR/install/seed.sql"

# Stage the application before replacing the target so rerunning the installer from
# /var/www/vulnforge does not delete the script and source tree mid-install.
install -d -m 0755 "$(dirname "$TARGET_DIR")"
STAGE_DIR="$(mktemp -d "$(dirname "$TARGET_DIR")/.vulnforge-stage.XXXXXX")"
cp -a "$ROOT_DIR"/. "$STAGE_DIR"/
rm -rf "$STAGE_DIR/.git" "$STAGE_DIR/uploads" "$STAGE_DIR/logs" "$STAGE_DIR/backup"
mkdir -p "$STAGE_DIR/public" "$STAGE_DIR/uploads" "$STAGE_DIR/logs" "$STAGE_DIR/backup"
cp -a "$STAGE_DIR/install/baseline/uploads"/. "$STAGE_DIR/uploads"/
cp -a "$STAGE_DIR/install/baseline/logs"/. "$STAGE_DIR/logs"/
cp -a "$STAGE_DIR/install/baseline/backup"/. "$STAGE_DIR/backup"/
php -r '$runtime = ["db_name" => $argv[1], "db_user" => $argv[2], "db_pass" => $argv[3]]; echo "<?php\nreturn ".var_export($runtime, true).";\n";' \
  "$DB_NAME" "$DB_USER" "$DB_PASS" > "$STAGE_DIR/app/config/runtime.php"

chown -R root:www-data "$STAGE_DIR"
find "$STAGE_DIR" -type d -exec chmod 0750 {} +
find "$STAGE_DIR" -type f -exec chmod 0640 {} +
# Deliberately weak only for bounded fake uploads and sample logs.
chmod 0777 "$STAGE_DIR/uploads" "$STAGE_DIR/logs"
chmod 0666 "$STAGE_DIR/logs/app.log"
chmod 0755 "$STAGE_DIR/public" "$STAGE_DIR/public/assets" "$STAGE_DIR/backup"
chmod 0644 "$STAGE_DIR/public/index.php" "$STAGE_DIR/public/.htaccess" "$STAGE_DIR/public/assets/style.css" "$STAGE_DIR/backup/"*
rm -rf -- "$TARGET_DIR"
mv "$STAGE_DIR" "$TARGET_DIR"
STAGE_DIR=""

# Host telemetry is separate from the deliberately incomplete, web-visible fake audit log.
install -d -o www-data -g adm -m 0750 /var/log/vulnforge
install -o www-data -g adm -m 0640 /dev/null /var/log/vulnforge/app_events.jsonl

cp "$TARGET_DIR/apache/vulnforge.conf" /etc/apache2/sites-available/vulnforge.conf
if [[ "$BIND_IP" != "127.0.0.1" ]]; then
  sed -i "s/127\.0\.0\.1:8080/$BIND_IP:8080/g; s/Require local/Require ip 127.0.0.1 10.0.0.0\/8 172.16.0.0\/12 192.168.0.0\/16/g" /etc/apache2/sites-available/vulnforge.conf
fi
a2enmod rewrite
a2dissite 000-default.conf >/dev/null || true
a2ensite vulnforge.conf >/dev/null
apache2ctl configtest
systemctl restart apache2

{
  printf 'VULNFORGE_DB_NAME=%q\n' "$DB_NAME"
  printf 'VULNFORGE_DB_USER=%q\n' "$DB_USER"
  printf 'VULNFORGE_DB_PASS=%q\n' "$DB_PASS"
  printf 'VULNFORGE_ROOT=%q\n' "$TARGET_DIR"
} > /etc/vulnforge-lab.conf
chmod 0600 /etc/vulnforge-lab.conf

echo
printf 'Lab URL: http://%s:8080\n' "$BIND_IP"
echo 'Reset command: sudo /var/www/vulnforge/install/reset_lab.sh'
printf '\n*** %s ***\n' "$WARNING"
