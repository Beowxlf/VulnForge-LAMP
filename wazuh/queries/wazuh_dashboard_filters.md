# Wazuh dashboard filters for the Northstar lab

Field names can vary slightly by Wazuh/indexer version. In **Threat hunting** or
**Discover**, expand one VulnForge event first and confirm whether dynamic JSON
fields appear as `data.event_type`, `data.route`, and `data.src_ip` (the common
layout) before saving a filter.

## Scope to the lab

```text
rule.groups: "vulnforge"
```

```text
agent.name: "northstar-lab"
```

```text
data.app: "northstar-vulnforge"
```

## Authentication and authorization

```text
data.event_type: "login_failure"
```

```text
data.event_type: ("admin_access_denied" or "invoice_idor_suspected")
```

```text
rule.id: "100502"
```

## High-interest application activity

```text
data.event_type: ("file_upload" or "profile_import" or "diagnostics_view")
```

```text
data.event_type: "application_exception"
```

```text
data.event_type: "suspicious_parameter_pattern" and data.message: "*sql_metacharacter_sequence*"
```

## Apache evidence

```text
location: "/var/log/apache2/vulnforge_access.log"
```

```text
rule.id: "100506"
```

If URL fields are available from the Apache decoder, use:

```text
url: "/backup/*"
```

## Training workflow

```text
data.event_type: ("flag_submission_success" or "flag_submission_failure")
```

```text
rule.id: ("100509" or "100511")
```

## Useful views

1. A date histogram split by `data.event_type`.
2. A table grouped by `data.src_ip`, then `data.username`, with event count.
3. A table containing `@timestamp`, `agent.name`, `data.request_id`,
   `data.route`, `data.event_type`, `data.outcome`, and `rule.id`.
4. Side-by-side saved searches for the Apache access-log location and
   `data.app: "northstar-vulnforge"` to support A09 comparison.

Treat these as starting points. A matching lab rule is a lead, not proof of
compromise; correlate the underlying Apache record, JSONL event, database state,
and authenticated user/session context.
