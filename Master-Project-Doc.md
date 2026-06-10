# VulnForge-LAMP Master Design Document

## 1. Project Summary

**VulnForge-LAMP** is an intentionally vulnerable LAMP-stack web application designed for local cybersecurity training. The goal is to help a learner move from basic web vulnerability theory into hands-on website boxes similar to CTF, TryHackMe, Hack The Box, PortSwigger-style labs, and internal purple-team web exercises.

The app will run inside an Ubuntu VM on Hyper-V and should be treated as hostile by design.

**Primary goal:**  
Build a beginner-friendly vulnerable web box containing all **OWASP Top 10:2025** web vulnerability categories.

**Secondary goal:**  
Teach not only exploitation concepts, but also evidence collection, logging gaps, detection thinking, and remediation.

## 2. Safety Boundary

This application is intentionally unsafe.

Rules:

1. Run only in a private lab.
2. Do not expose the VM to the public internet.
3. Use Hyper-V **Private** or **Internal** virtual switch where possible.
4. Use fake users, fake data, fake secrets, and fake business records.
5. Never reuse real passwords.
6. Never connect the app to real email, cloud services, payment systems, or external APIs.
7. Keep snapshots before testing.
8. Reset the lab after each major run.

Recommended Hyper-V layout:

| Component | Recommendation |
|---|---|
| Hypervisor | Hyper-V |
| Guest OS | Ubuntu Server |
| Network | Private or Internal vSwitch |
| Attacker VM | Kali, Parrot, or Ubuntu testing VM |
| Target VM | VulnForge-LAMP |
| Internet exposure | None |
| Snapshot | Before install and after clean install |

As of June 2026, Ubuntu 26.04 LTS has been released, but Ubuntu 24.04 LTS remains a practical choice for a stable lab if package compatibility matters. Canonical announced Ubuntu 26.04 LTS on April 23, 2026. :contentReference[oaicite:2]{index=2}

## 3. Technology Stack

| Layer | Selection |
|---|---|
| OS | Ubuntu Server |
| Web server | Apache |
| Language | PHP |
| Database | MySQL or MariaDB |
| Frontend | Basic HTML, Bootstrap, minimal JavaScript |
| Deployment | GitHub repo pulled by Ubuntu VM |
| Install method | Bash installer |
| Reset method | Bash reset script and SQL seed restore |

## 4. Repository Structure

```text
vulnforge-lamp/
├── README.md
├── docs/
│   ├── MASTER_DESIGN.md
│   ├── INSTALL_UBUNTU_LAMP.md
│   ├── PLAYER_GUIDE.md
│   ├── FLAG_GUIDE_INSTRUCTOR.md
│   └── HARDENING_GUIDE.md
├── install/
│   ├── install.sh
│   ├── reset_lab.sh
│   └── seed.sql
├── apache/
│   └── vulnforge.conf
├── app/
│   ├── config/
│   ├── controllers/
│   ├── models/
│   ├── views/
│   ├── vendor/
│   └── helpers/
├── public/
│   ├── index.php
│   ├── assets/
│   ├── uploads/
│   └── backup/
├── logs/
│   └── app.log
└── tests/
    └── smoke_tests.md
