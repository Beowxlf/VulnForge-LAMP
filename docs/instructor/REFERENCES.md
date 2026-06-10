# References and Attribution

These links provide background and defensive context. The instructor documentation summarizes concepts rather than reproducing payload collections or large passages.

- [OWASP Top 10:2025](https://owasp.org/Top10/2025/0x00_2025-Introduction/) — the current OWASP web-application risk categories used to organize the lab's two flags per category.
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — a structured methodology for authorized web security testing, evidence collection, and reporting.
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — a community reference for security-testing patterns; use only in authorized environments, and note that this guide intentionally does not reproduce its payload catalogs.
- [Wazuh log data collection](https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/index.html) — explains collection and analysis of endpoint and application logs.
- [Wazuh `localfile` configuration](https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/localfile.html) — documents agent-side file collection settings used for Apache and JSONL sources.
- [Wazuh JSON decoder](https://documentation.wazuh.com/current/user-manual/ruleset/decoders/json-decoder.html) — describes extraction of JSON values into dynamic fields for rule matching and search.
- [Wazuh custom rules and decoders](https://documentation.wazuh.com/current/user-manual/ruleset/index.html) — introduces rule matching and locally maintained detection content.
- [Wazuh decoder and rule testing (`wazuh-logtest`)](https://documentation.wazuh.com/current/user-manual/ruleset/testing.html) — documents testing sample events against installed decoders and rules.
- [MITRE ATT&CK Enterprise](https://attack.mitre.org/matrices/enterprise/) — a knowledge base for describing observed adversary behaviors; mappings should be made cautiously and should not inflate a lab observation into a claim of compromise.
- [Common Weakness Enumeration (CWE)](https://cwe.mitre.org/) — a software-weakness taxonomy used here for approximate root-cause mappings.
