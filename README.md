# VulnForge-LAMP

> **This application is intentionally vulnerable. Run only in an isolated lab network. Do not expose to the internet.**

VulnForge-LAMP is a local-only OWASP training application themed as the fictional **Northstar Outfitters Internal Portal**. It provides 20 beginner-friendly CTF challenges—two for each OWASP Top 10:2025 category—using fake users, products, invoices, secrets, payments, logs, and services.

The release-candidate interface presents the lab as a polished corporate intranet for a fictional outdoor equipment, logistics, and retail-support organization. It includes consistent authenticated navigation, employee dashboards, finance records, a helpdesk-style support queue, profile portability, a local document exchange, IT diagnostics, an operations console, audit review, and a professional training-progress register. All branding and business records are fictional, all visual assets are bundled locally, and the presentation layer preserves the intentionally vulnerable challenge behavior.

## Portal experience

- **Employee workspace:** role-aware portal chrome, dashboard summaries, profile tools, and consistent navigation across authenticated routes.
- **Business operations:** realistic fictional product, invoice, support, refund, and file-exchange workflows for Northstar departments.
- **IT and administration:** internal status cards, bounded diagnostics, administrative widgets, audit events, and release notes.
- **Security readiness:** an integrated scoreboard frames challenge progress as authorized internal training rather than a raw flag database.
- **Local assets only:** the interface uses repository-hosted CSS, JavaScript, and an SVG compass mark; it adds no CDN, analytics, tracking, font, or third-party service dependency.

## Safety boundary

- Deploy only to an Ubuntu Server VM attached to a Hyper-V **Private** or carefully controlled **Internal** virtual switch.
- The supplied Apache site binds to `127.0.0.1:8080` by default. The installer accepts only loopback or RFC1918 addresses through `VULNFORGE_BIND_IP`.
- Never port-forward, publish, reverse-proxy, or expose this application to the internet.
- Do not reuse any lab credential. No third-party services are contacted.
- Upload execution is disabled. The command-injection lesson is a simulated interpreter over fixed fake values and never invokes an OS shell.
- Take a VM checkpoint before installation and reset after exercises.

## Quick start

```bash
git clone <your-private-repository> VulnForge-LAMP
cd VulnForge-LAMP
sudo ./install/install.sh
```

The default URL is `http://127.0.0.1:8080`. To permit access from another VM on an isolated RFC1918 lab network:

```bash
sudo VULNFORGE_BIND_IP=192.168.56.20 ./install/install.sh
```

The installer rejects public bind addresses. Review the generated Apache policy before using any non-loopback address.

## Reset in one command

```bash
sudo /var/www/vulnforge/install/reset_lab.sh
```

This restores the schema and seed records, clears submissions, and replaces uploads, exposed backups, and application logs with clean baseline copies.

## Fake player accounts

| Email | Password | Role |
|---|---|---|
| `admin@northstar.local` | `admin123` | admin |
| `analyst@northstar.local` | `analyst123` | analyst |
| `j.smith@northstar.local` | `smith123` | employee |
| `m.chen@northstar.local` | `chen123` | employee |
| `guest@northstar.local` | `guest` | guest |

## Repository map

- `public/` — Apache document root and front controller.
- `app/` — configuration, helpers, and fictional vulnerable dependency.
- `install/` — Ubuntu installer, reset command, SQL seed, and reset baselines.
- `apache/` — localhost-first virtual host.
- `backup/`, `uploads/`, `logs/` — deliberately exposed or weakly protected **fake** lab artifacts.
- `docs/` — architecture, deployment, player hints, instructor solutions, and remediation.
- `tests/` — static smoke tests for required files and safety controls.
- `wazuh/` — optional agent collection blocks, manager rules, sample events, filters, and SOC playbooks.

## Documentation

1. [Master design](docs/MASTER_DESIGN.md)
2. [Ubuntu LAMP installation](docs/INSTALL_UBUNTU_LAMP.md)
3. [Player guide](docs/PLAYER_GUIDE.md)
4. [Instructor flag guide](docs/FLAG_GUIDE_INSTRUCTOR.md)
5. [Hardening guide](docs/HARDENING_GUIDE.md)
6. [Optional Wazuh integration](docs/WAZUH_INTEGRATION.md)

## Deliberately unsafe settings

The project intentionally contains raw SQL construction, object-level authorization failures, weak MD5 password hashes, reversible Base64 data, unsigned client imports, predictable local tokens, verbose errors, indexed fake artifacts, incomplete audit events, and weak permissions on resettable fake logs/uploads. These are teaching defects—not deployment patterns. See the hardening guide before adapting any code.
