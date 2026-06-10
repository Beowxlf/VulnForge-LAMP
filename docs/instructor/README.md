# Instructor Documentation

> **INSTRUCTOR-ONLY SPOILERS:** This directory reveals every flag, intended solution path, application weakness, evidence source, and detection opportunity in the VulnForge-LAMP / Northstar Outfitters lab. Do not give these files to learners before a blind run.

> **Authorized lab use only:** Apply every walkthrough only to this isolated, local, intentionally vulnerable training application and its fictional data. Do not use these procedures against public, production, or third-party systems.

## Purpose

These documents help instructors validate all 20 challenge solutions, connect application behavior to Apache and structured telemetry, facilitate SOC investigations, and convert each lab finding into remediation and detection-engineering work. They supplement the concise [existing instructor flag map](../FLAG_GUIDE_INSTRUCTOR.md), [Wazuh integration guide](../WAZUH_INTEGRATION.md), and [hardening guide](../HARDENING_GUIDE.md).

## Publication and spoiler risk

If this repository is public, `docs/instructor/` spoils the complete lab. Use one of these controls:

- keep the entire repository private;
- keep `docs/instructor/` on a private instructor-only branch; or
- remove `docs/instructor/` before publishing a player version.

Treat a distributed copy as compromised for blind-play purposes even if search indexing is later disabled.

## Recommended use

1. First run the lab blind as a player and capture evidence before reading solutions.
2. Then use [FLAG_WALKTHROUGHS.md](FLAG_WALKTHROUGHS.md) to validate the solution, root cause, and flag location.
3. Then use [WAZUH_FLAG_TELEMETRY_GUIDE.md](WAZUH_FLAG_TELEMETRY_GUIDE.md) and [DETECTION_LAB_EXERCISES.md](DETECTION_LAB_EXERCISES.md) for SOC analysis.
4. Then use the repository [hardening guide](../HARDENING_GUIDE.md) for remediation planning.

The **noise and evidence notes** explain observable lab behavior for defender education. They are not monitoring-evasion guidance: these documents do not teach bypassing Wazuh, suppressing alerts, altering logs, hiding attribution, or attacking real systems.

## Contents

- [FLAG_WALKTHROUGHS.md](FLAG_WALKTHROUGHS.md) — full instructor validation guide for all 20 flags.
- [FLAG_WALKTHROUGH_TEMPLATE.md](FLAG_WALKTHROUGH_TEMPLATE.md) — reusable format for future instructor notes without adding challenges.
- [ADVANCED_ANALYST_NOTES.md](ADVANCED_ANALYST_NOTES.md) — evidence, confidence, reporting, and remediation methodology.
- [WAZUH_FLAG_TELEMETRY_GUIDE.md](WAZUH_FLAG_TELEMETRY_GUIDE.md) — per-flag source coverage, rules, gaps, and pivots.
- [DETECTION_LAB_EXERCISES.md](DETECTION_LAB_EXERCISES.md) — 12 bounded SOC exercises using the local lab.
- [REFERENCES.md](REFERENCES.md) — concise attribution links for OWASP, Wazuh, MITRE ATT&CK, CWE, and PayloadsAllTheThings.
