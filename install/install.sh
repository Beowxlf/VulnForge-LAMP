#!/usr/bin/env bash
set -euo pipefail

WARNING="This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet."
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="/var/www/vulnforge"
DB_NAME="${VULNFORGE_DB_NAME:-vulnforge}"
DB_USER="${VULNFORGE_DB_USER:-vulnforge_lab}"
DB_PASS="${VULNFORGE_DB_PASS:-lab-only-password}"
BIND_IP="${VULNFORGE_BIND_IP:-127.0.0.1}"

printf '\n*** %s ***\n\n' "$WARNING"
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./install/install.sh"; exit 1; }
[[ -r /etc/os-release ]] || { echo "Cannot identify operating system."; exit 1; }
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || { echo "This installer supports Ubuntu Server only (found ${ID:-unknown})."; exit 1; }
if [[ ! "$BIND_IP" =~ ^127\.0\.0\.1$|^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
  echo "Refusing non-loopback/non-RFC1918 bind address: $BIND_IP" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-json curl
systemctl enable --now mariadb apache2

mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
mysql "$DB_NAME" < "$ROOT_DIR/install/seed.sql"

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -a "$ROOT_DIR"/. "$TARGET_DIR"/
rm -rf "$TARGET_DIR/.git"
chown -R root:www-data "$TARGET_DIR"
find "$TARGET_DIR" -type d -exec chmod 0750 {} +
find "$TARGET_DIR" -type f -exec chmod 0640 {} +
# Deliberately weak only for bounded fake uploads and sample logs.
chmod 0777 "$TARGET_DIR/uploads" "$TARGET_DIR/logs"
chmod 0666 "$TARGET_DIR/logs/app.log"
chmod 0755 "$TARGET_DIR/public" "$TARGET_DIR/public/assets" "$TARGET_DIR/backup"
chmod 0644 "$TARGET_DIR/public/index.php" "$TARGET_DIR/public/.htaccess" "$TARGET_DIR/public/assets/style.css" "$TARGET_DIR/backup/"*

# Host telemetry is separate from the deliberately incomplete, web-visible fake audit log.
install -d -o www-data -g adm -m 0750 /var/log/vulnforge
install -o www-data -g adm -m 0640 /dev/null /var/log/vulnforge/app_events.jsonl

cp "$ROOT_DIR/apache/vulnforge.conf" /etc/apache2/sites-available/vulnforge.conf
if [[ "$BIND_IP" != "127.0.0.1" ]]; then
  sed -i "s/127\.0\.0\.1:8080/$BIND_IP:8080/g; s/Require local/Require ip 127.0.0.1 10.0.0.0\/8 172.16.0.0\/12 192.168.0.0\/16/g" /etc/apache2/sites-available/vulnforge.conf
fi
a2enmod rewrite
a2dissite 000-default.conf >/dev/null || true
a2ensite vulnforge.conf >/dev/null
apache2ctl configtest
systemctl restart apache2

cat > /etc/vulnforge-lab.conf <<EOF
VULNFORGE_DB_NAME='$DB_NAME'
VULNFORGE_DB_USER='$DB_USER'
VULNFORGE_DB_PASS='$DB_PASS'
VULNFORGE_ROOT='$TARGET_DIR'
EOF
chmod 0600 /etc/vulnforge-lab.conf

echo
printf 'Lab URL: http://%s:8080\n' "$BIND_IP"
echo 'Reset command: sudo /var/www/vulnforge/install/reset_lab.sh'
printf '\n*** %s ***\n' "$WARNING"
