#!/usr/bin/env bash
set -euo pipefail

INSTALL_MISSING=false
if [[ ${1:-} == "--install-missing" && $# -eq 1 ]]; then
  INSTALL_MISSING=true
elif (( $# > 0 )); then
  echo "Usage: $0 [--install-missing]" >&2
  exit 2
fi

missing_required=0

print_pass() {
  printf 'PASS %-20s %s\n' "$1:" "$2"
}

print_warn() {
  printf 'WARN %-20s %s\n' "$1:" "$2"
}

print_fail() {
  printf 'FAIL %-20s %s\n' "$1:" "$2"
  missing_required=1
}

command_path() {
  command -v "$1" 2>/dev/null
}

check_required() {
  local label=$1 command_name=$2 package=$3 path
  if path=$(command_path "$command_name"); then
    print_pass "$label" "$path"
  else
    print_fail "$label" "missing. Install with: sudo apt install -y $package"
  fi
}

install_missing_packages() {
  local packages=()

  command -v git >/dev/null 2>&1 || packages+=(git)
  command -v rg >/dev/null 2>&1 || packages+=(ripgrep)
  command -v php >/dev/null 2>&1 || packages+=(php-cli)
  command -v curl >/dev/null 2>&1 || packages+=(curl)

  if ! command -v shellcheck >/dev/null 2>&1 && command -v apt-cache >/dev/null 2>&1; then
    if apt-cache show shellcheck >/dev/null 2>&1; then
      packages+=(shellcheck)
    fi
  fi

  if (( ${#packages[@]} == 0 )); then
    echo 'No supported Ubuntu packages are missing.'
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo 'Cannot install missing packages: apt-get is not available.' >&2
    return 1
  fi

  local -a apt_prefix=()
  if (( EUID != 0 )); then
    if ! command -v sudo >/dev/null 2>&1; then
      echo 'Cannot install missing packages: sudo is not available.' >&2
      return 1
    fi
    apt_prefix=(sudo)
  fi

  printf 'Installing supported Ubuntu packages:'
  printf ' %s' "${packages[@]}"
  printf '\n'
  "${apt_prefix[@]}" apt-get update
  "${apt_prefix[@]}" apt-get install -y "${packages[@]}"
}

printf 'VulnForge preflight check\n'
printf '%-5s %-21s %s\n' 'STATE' 'CHECK' 'DETAIL'

if [[ $INSTALL_MISSING == true ]]; then
  install_missing_packages
  echo
fi

check_required bash bash bash
check_required git git git
check_required rg rg ripgrep
check_required php php php-cli
check_required curl curl curl
check_required apt-get apt-get apt
check_required systemctl systemctl systemd
check_required sudo sudo sudo

if path=$(command_path mysql); then
  print_pass 'mysql/mariadb client' "$path"
elif path=$(command_path mariadb); then
  print_pass 'mysql/mariadb client' "$path"
else
  print_warn 'mysql/mariadb client' 'missing. Installed by install/install.sh; standalone client: sudo apt install -y mariadb-client'
fi

if path=$(command_path apache2ctl); then
  print_pass 'apache control' "$path"
elif path=$(command_path apachectl); then
  print_pass 'apache control' "$path"
else
  print_warn 'apache control' 'missing. Installed by install/install.sh; package: sudo apt install -y apache2'
fi

if path=$(command_path shellcheck); then
  print_pass shellcheck "$path"
else
  print_warn shellcheck 'missing. Optional. Install with: sudo apt install -y shellcheck'
fi

if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet wazuh-agent 2>/dev/null; then
  print_pass 'wazuh-agent service' 'active'
elif command -v systemctl >/dev/null 2>&1 && [[ $(systemctl list-unit-files wazuh-agent.service --no-legend 2>/dev/null || true) == wazuh-agent.service* ]]; then
  print_warn 'wazuh-agent service' 'installed but not active. Wazuh is optional and must be installed separately.'
else
  print_warn 'wazuh-agent service' 'not installed. Optional; install Wazuh separately if needed.'
fi

if [[ -x /var/ossec/bin/wazuh-logtest ]]; then
  print_pass 'wazuh-logtest' '/var/ossec/bin/wazuh-logtest (manager only)'
else
  print_warn 'wazuh-logtest' 'not present. Optional and expected only on a Wazuh manager.'
fi

if (( missing_required != 0 )); then
  echo
  echo 'Preflight failed: install the missing required commands shown above.' >&2
  exit 1
fi

echo
echo 'Preflight passed: all required commands are available.'
