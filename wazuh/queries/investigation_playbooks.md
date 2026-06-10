# Northstar SOC investigation playbooks

These playbooks are for an isolated training environment. They intentionally do
not include active response, destructive payloads, or instructions to expose the
application. Preserve evidence before resetting the lab.

## Common triage sequence

1. Record the alert time, Wazuh agent, rule ID, `src_ip`, `request_id`, route,
   username/user ID, role, and outcome.
2. Pivot on `data.request_id` in `app_events.jsonl`, then inspect Apache activity
   from the same source and a narrow time window.
3. Compare the claimed identity and role with the fictional database and current
   session context. Do not assume an alert proves compromise.
4. Note gaps or contradictions rather than “repairing” the intentionally
   vulnerable challenge during an exercise.

## Login brute force against fake accounts

- Start with rule `100502` and count `login_failure` events by `src_ip` over two
  minutes.
- Compare Apache POSTs to `/?route=login` with JSONL failures and any later
  `login_success` from the same source.
- The submitted identifier and password are intentionally absent. Do not try to
  recover them from telemetry.
- Confirm that the fake in-app audit viewer omits failures; this is expected A09
  behavior, not evidence that the requests did not occur.

## IDOR invoice access

- Start with rule `100504`; capture the session user, requested invoice ID, and
  owner user ID from metadata.
- Correlate the `invoice_view` and `invoice_idor_suspected` records by
  `request_id`, then find the matching Apache GET.
- Validate the invoice owner in the lab database and document whether the page
  returned successfully. The telemetry detects an owner mismatch but does not
  change the intentionally vulnerable route.

## Admin bypass attempt

- Review `admin_access_denied` followed by `admin_access` from the same source or
  user.
- Compare the database role with the effective role described in the event and
  the request sequence in Apache logs.
- Inspect profile import activity in the preceding time window. Do not treat a
  successful admin page view alone as proof of operating-system compromise.

## Backup directory access

- Start with rule `100506` and inspect the Apache URL, status, source, and user
  agent.
- Search adjacent requests for specific backup artifacts and compare timestamps
  with other portal activity.
- This evidence comes from Apache because direct alias access does not execute
  application code and therefore produces no JSONL app event.

## Upload activity

- Review `file_upload` events for outcome, sanitized basename, and size; uploaded
  contents are deliberately never logged.
- Correlate the POST with Apache and inspect the resettable lab upload directory
  locally if authorized.
- Remember that the application intentionally accepts weakly validated training
  uploads while Apache disables PHP execution in the alias.

## Diagnostics abuse

- Review rule `100505`, especially repeated detailed diagnostics views or events
  near `application_exception` and suspicious-parameter alerts.
- Correlate the request with Apache and note whether `detail=true` appears only
  as safe metadata in the app event.
- Distinguish the bounded simulated command console from real shell execution.

## A09 logging-gap comparison

Build a timeline from three evidence sources:

1. **Apache access/error logs:** transport-level requests, status codes, client
   source, and server errors. They do not know application authorization intent.
2. **`/var/log/vulnforge/app_events.jsonl`:** structured host telemetry with
   request IDs, selected authentication/authorization outcomes, and sanitized
   metadata. It is useful but intentionally not a complete forensic record.
3. **Fake/tamperable in-app audit records:** the `audit_logs` database table and
   web-visible `logs/app.log`. These intentionally omit authentication failures,
   profile imports, and privilege changes, and may be incomplete or misleading.

Look for requests present in Apache but absent from the fake audit viewer; then
check whether JSONL supplies partial application context. Also look for fake
in-app records with weak attribution. The lesson is that multiple sources can
reconstruct part of an incident while application-layer logging still fails A09
expectations.
