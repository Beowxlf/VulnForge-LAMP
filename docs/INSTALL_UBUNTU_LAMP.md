# Ubuntu LAMP Installation

> **This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.**

## Before installation

1. Create an Ubuntu Server VM and connect it to a Hyper-V **Private** vSwitch.
2. Do not configure inbound NAT, port forwarding, a public IP, or public DNS.
3. Take a clean checkpoint.
4. Copy this repository into the VM without adding real secrets.

## Automated install

```bash
cd VulnForge-LAMP
sudo ./install/install.sh
```

The script verifies Ubuntu, installs Apache/PHP/MariaDB, creates the local database and lab user, imports `install/seed.sql`, stages the application before replacing `/var/www/vulnforge`, writes the installed PHP database runtime configuration, enables the vhost, applies intentionally weak permissions only to resettable fake logs/uploads, runs `apache2ctl configtest`, and prints the warning and URL.

### Access from a separate training VM

The safe default is loopback. On a private RFC1918-only vSwitch, select the target VM’s static private IP:

```bash
sudo VULNFORGE_BIND_IP=192.168.56.20 ./install/install.sh
```

Accepted ranges are `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, and `192.168.0.0/16`. The installer refuses other addresses. Add a host firewall rule scoped to the attacker VM if possible.

## Validation

```bash
sudo apache2ctl configtest
curl -I http://127.0.0.1:8080/
sudo mysql vulnforge -e "SELECT category,COUNT(*) FROM flags GROUP BY category;"
```

For a private-IP install, substitute that IP in the curl command. Confirm all ten categories report two flags.

## Reset

```bash
sudo /var/www/vulnforge/install/reset_lab.sh
```

The reset drops and recreates all seeded tables, so submissions and runtime profile changes disappear. It then recreates uploads, backups, and fake logs from `install/baseline/` and truncates `/var/log/vulnforge/app_events.jsonl`.

## Uninstall

From a VM checkpoint is preferred. Otherwise disable the site, remove `/var/www/vulnforge`, remove `/etc/vulnforge-lab.conf`, and drop the `vulnforge` database and `vulnforge_lab@localhost` user. Do not repurpose this Apache instance for production.

## Troubleshooting

- **403 from another VM:** the default site is loopback-only. Reinstall with an RFC1918 `VULNFORGE_BIND_IP` on a Private/Internal switch.
- **Database connection error:** verify MariaDB is running and that `/etc/vulnforge-lab.conf` and `/var/www/vulnforge/app/config/runtime.php` contain the same installed database settings.
- **No routes:** verify `a2enmod rewrite`, `AllowOverride All`, and the vhost configuration.
- **Reset denied:** run it with `sudo`; reset requires local MariaDB administration and filesystem ownership changes.
