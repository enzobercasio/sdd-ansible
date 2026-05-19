---
spec_id: AUTO-2026-0055
title: Event-Driven Disk Space Auto-Remediation
status: approved
version: "1.0"
owner: platform-engineering@company.com
risk_tier: medium
team: platform
use_case: eda
target_environments: [staging, prod]
related_specs: []
ansible_collections_required:
  - ansible.builtin
  - ansible.eda
  - community.general
created: 2026-04-20
approved_by: enzo.bercasio
approved_date: 2026-05-03
---

# Spec: Event-Driven Disk Space Auto-Remediation

> Inherits from: `BEST-PRACTICES-SPEC.md`, `TEAM-PLATFORM-overrides.md`, `USE-CASE-EDA-overrides.md`

---

## §1 Intent

Automatically remediate non-critical disk space alerts on Linux hosts before they escalate to operational incidents, reducing on-call toil and mean-time-to-resolution for known, safe cleanup scenarios while preserving human review for higher-risk situations.

---

## §2 Scope

### In scope

- Linux hosts (RHEL 8/9, Ubuntu 22.04+) in `staging` and `prod` environments
- Disk usage alerts at the WARNING threshold (80–89% utilisation)
- Cleanup of: rotated logs older than 30 days, package manager caches, temporary files in `/tmp` older than 7 days, journald logs beyond 14-day retention
- Event sources: Prometheus Alertmanager and Dynatrace problem feed

### Out of scope

- CRITICAL alerts (≥90% utilisation) — these escalate directly to humans
- Application-managed directories (`/var/lib/<app>`, `/data/`) — risk of data loss
- Database files, transaction logs, or any path tagged `do-not-touch` in CMDB
- Windows hosts (separate spec required)

---

## §3 Requirements (EARS notation)

- **REQ-1**: When a WARNING-tier disk alert event is received from a trusted source, the system shall validate the event signature and originating source IP — *acceptance: events from untrusted sources are dropped and logged*.
- **REQ-2**: When the alert payload is validated, the system shall verify the affected host is in scope (Linux, env=staging|prod, not tagged `do-not-touch`) — *acceptance: out-of-scope hosts trigger no action and emit a "skipped" event*.
- **REQ-3**: While disk utilisation is between 80% and 89% inclusive, the system shall execute the cleanup playbook — *acceptance: utilisation outside this range triggers no remediation*.
- **REQ-4**: When cleanup begins, the system shall acquire a per-host lock to prevent concurrent remediation — *acceptance: a second alert for the same host within 30 minutes does not trigger a second run*.
- **REQ-5**: When cleanup runs, the system shall remove only paths matching the approved cleanup manifest (logs >30d, package caches, /tmp >7d, journald >14d) — *acceptance: no file outside the manifest is modified*.
- **REQ-6**: When cleanup completes, the system shall measure post-cleanup utilisation and emit a structured outcome event — *acceptance: outcome event contains spec_id, host, before_pct, after_pct, bytes_freed, duration*.
- **REQ-7**: If post-cleanup utilisation remains ≥80%, then the system shall escalate to a human-handled ticket — *acceptance: ITSM ticket created with spec_id and event correlation ID*.
- **REQ-8**: If three or more remediation events fire for the same host within 24 hours, then the system shall suppress further automated remediation and create an investigation ticket — *acceptance: 4th event within 24h is suppressed and logged*.
- **REQ-9**: Where the host's CMDB record indicates `change_freeze: true`, the system shall not remediate and shall create a notification ticket only — *acceptance: change-frozen hosts produce no state changes*.

---

## §4 Non-Functional Requirements

- **NFR-1 (Latency)**: Median time from event receipt to remediation start < 30 seconds
- **NFR-2 (Throughput)**: Handle 100 concurrent events without queue saturation
- **NFR-3 (Reliability)**: ≥99% successful remediation rate when conditions are met
- **NFR-4 (Auditability)**: Every event, decision, and action recorded with correlation ID; events forwarded to SIEM
- **NFR-5 (Safety)**: No remediation action shall modify files matching exclusion list, even if the cleanup manifest would otherwise match

---

## §5 Inputs (Variable Contract)

> EDA rulebook reads these from the event payload, not survey input.

| Field | Type | Required | Source | Validation | Description |
|---|---|---|---|---|---|
| `event.payload.host` | string | yes | alert payload | FQDN format | Affected host |
| `event.payload.severity` | string | yes | alert payload | `warning` | Filter for warning-tier only |
| `event.payload.utilisation_pct` | float | yes | alert payload | 80.0–89.99 | Current disk usage % |
| `event.payload.mount_point` | string | yes | alert payload | Starts with `/` | Affected mount |
| `event.meta.source` | string | yes | event metadata | One of: prometheus, dynatrace | Trusted source check |
| `event.meta.signature` | string | yes | event metadata | Valid HMAC | Event integrity |

---

## §6 Outputs / Acceptance Criteria

- Remediation outcome event emitted within 30 seconds of receipt
- Disk utilisation reduced to <80% in ≥80% of remediation attempts
- Zero modifications to files outside the approved cleanup manifest
- Audit log entry per remediation containing all decision points and outcomes
- ITSM ticket created for any unsuccessful remediation (REQ-7) or freeze conflict (REQ-9)

---

## §7 Failure Modes

| Failure Mode | Detection | Response | REQ Reference |
|---|---|---|---|
| Untrusted event source | Signature check fails | Drop event, log security warning | REQ-1 |
| CMDB lookup unavailable | API timeout/error | Default to NOT remediate, escalate | REQ-2, REQ-9 |
| Cleanup playbook fails mid-run | Module returns error | Stop, restore from /tmp/cleanup-state, alert | REQ-5 |
| Post-cleanup still ≥80% | Utilisation check after cleanup | Create ITSM ticket, do not retry | REQ-7 |
| Lock acquisition fails | Existing lock found | Skip event, log, no further action | REQ-4 |
| Repeated triggers (>3/24h) | Counter check | Suppress, create investigation ticket | REQ-8 |

---

## §8 Acceptance Tests

- `molecule/default/` — happy path: warning alert → remediation → post-utilisation drop
- `molecule/untrusted-source/` — REQ-1 negative test
- `molecule/out-of-scope-host/` — REQ-2 negative test (host tagged `do-not-touch`)
- `molecule/critical-severity-passthrough/` — REQ-3 (critical alerts not auto-remediated)
- `molecule/concurrent-event-suppression/` — REQ-4 lock behaviour
- `molecule/manifest-boundary/` — REQ-5 verifies no out-of-manifest paths touched
- `molecule/escalation-on-failure/` — REQ-7 ticket creation
- `molecule/repeat-trigger-suppression/` — REQ-8 24h window
- `molecule/change-freeze/` — REQ-9 notification-only behaviour

---

## §9 Approvals

- [x] Team lead — enzo.bercasio (2026-04-28)
- [x] Security review (REQ-1, REQ-5, NFR-5) — security-coe (2026-04-30)
- [x] Change advisory board — cab-apac (2026-05-02)
- [x] CoE acceptance of deviations — N/A (no deviations) (2026-05-03)

---

## §10 Deviations from Best Practices

| Deviation | Best Practice REQ | Justification | Risk Acceptance |
|---|---|---|---|
| None | — | — | — |

---

## §11 Rollback Procedure

Cleanup operations are not reversible (deleted log files are gone). Rollback is therefore preventive:

1. EDA controller has a kill switch: setting the activation `enabled: false` halts all future remediations within seconds.
2. The cleanup manifest is version-controlled; reverting the spec to v0.9 (when no cleanup occurred) effectively disables remediation.
3. For investigation: every remediation event includes the manifest hash, host, and bytes freed; combined with the host's backup policy, audit can determine impact.

---

## §12 References

- Prometheus Alertmanager event schema: <internal-link>
- Dynatrace problem API: https://docs.dynatrace.com/docs/dynatrace-api/environment-api/problems-v2
- AAP EDA controller documentation
- Internal: cleanup manifest review process
