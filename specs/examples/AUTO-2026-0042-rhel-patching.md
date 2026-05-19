---
spec_id: AUTO-2026-0042
title: Automated RHEL Patching with Maintenance Window
status: approved
version: "1.0"
owner: platform-engineering@company.com
risk_tier: medium
team: platform
use_case: patching
target_environments: [dev, staging, prod]
related_specs: [AUTO-2026-0019]
ansible_collections_required:
  - ansible.builtin
  - ansible.posix
  - community.general
  - redhat.rhel_system_roles
created: 2026-04-15
approved_by: enzo.bercasio
approved_date: 2026-05-01
---

# Spec: Automated RHEL Patching with Maintenance Window

> Inherits from: `BEST-PRACTICES-SPEC.md`, `TEAM-PLATFORM-overrides.md`

---

## §1 Intent

Reduce manual effort and inconsistency in monthly RHEL security patching across the web tier, ensuring all production hosts receive critical updates within their SLA window while minimising service disruption through controlled batching and automated reboot orchestration.

---

## §2 Scope

### In scope

- RHEL 8 and 9 hosts in the `webservers` and `appservers` inventory groups
- Security and bugfix errata only (advisory types `RHSA` and `RHBA`)
- Automated reboot when kernel updates are applied, with service drain
- Slack notification of patching outcomes

### Out of scope

- Database tier (handled by AUTO-2026-0019)
- Kernel updates requiring service drain >5 minutes
- Major version upgrades (e.g., RHEL 8 → 9) — separate spec required
- Windows hosts (covered by separate spec under `USE-CASE-WINDOWS-overrides`)

---

## §3 Requirements (EARS notation)

- **REQ-1**: When the playbook is invoked, the system shall verify all targets are reachable before applying any changes — *acceptance: 100% of declared hosts respond to ping module within 10 seconds*.
- **REQ-2**: When patching begins, the system shall patch hosts in batches of 10% of the group size (configurable via `batch_percentage`) — *acceptance: max concurrent host count never exceeds calculated batch size*.
- **REQ-3**: While outside the approved maintenance window (22:00–04:00 SGT), the system shall refuse to execute and log the refusal — *acceptance: pre-flight time check fails outside window with clear error message*.
- **REQ-4**: If a kernel update is applied, then the system shall reboot the host with a 5-minute service drain (load balancer marks unhealthy first) — *acceptance: kernel version differs pre/post and host returns to healthy state in load balancer*.
- **REQ-5**: When patching completes (success or failure), the system shall post a structured summary to Slack channel `#ops-changes` — *acceptance: message contains spec_id, host count, success count, failure count, duration*.
- **REQ-6**: Where `dry_run` mode is enabled, the system shall not modify any host state and shall report what would change — *acceptance: zero `changed: true` results when dry_run=true*.
- **REQ-7**: If any host fails patching, then the system shall halt the current batch, complete in-flight hosts gracefully, and alert the on-call rota — *acceptance: subsequent batches do not begin; PagerDuty incident created*.

---

## §4 Non-Functional Requirements

- **NFR-1 (Performance)**: Complete patching of 200 hosts within the 6-hour maintenance window
- **NFR-2 (Reliability)**: Succeed on first attempt for ≥95% of invocations over 6 months
- **NFR-3 (Auditability)**: All actions logged to AAP job output and forwarded to SIEM via syslog within 60 seconds
- **NFR-4 (Recoverability)**: Manual rollback procedure documented in §11; automatic rollback not in scope
- **NFR-5 (Observability)**: Progress message every 10% of hosts patched, including current batch number and elapsed time

---

## §5 Inputs (Variable Contract)

| Variable | Type | Required | Default | Validation | Description |
|---|---|---|---|---|---|
| `target_group` | string | yes | — | Must exist in inventory | Inventory group name |
| `batch_percentage` | int | no | 10 | 1–50 | Rolling batch size as % of group |
| `dry_run` | bool | no | false | — | Check mode only |
| `notification_channel` | string | no | "#ops-changes" | Starts with `#` | Slack channel for summary |
| `errata_severity` | string | no | "Important" | One of: Critical, Important, Moderate, Low | Minimum errata severity to apply |
| `force_outside_window` | bool | no | false | — | Override maintenance window check (requires CAB approval) |

---

## §6 Outputs / Acceptance Criteria

- All targeted hosts return `patched: true` in the run summary
- Zero failed reboots (hosts that failed to come back online)
- Slack notification posted within 60 seconds of completion
- Total runtime under 4 hours for 200-host group
- All hosts return to "healthy" state in load balancer within 5 minutes of reboot
- Job tagged in AAP with `spec_id: AUTO-2026-0042` for audit reporting

---

## §7 Failure Modes

| Failure Mode | Detection | Response | REQ Reference |
|---|---|---|---|
| Host unreachable at pre-flight | Ping module fails | Halt run, alert, no changes made | REQ-1 |
| dnf transaction fails | Module returns rc != 0 | Skip host, mark failed, continue batch, halt next batch | REQ-2, REQ-7 |
| Reboot timeout (>10 min) | wait_for_connection fails | Mark host degraded, alert on-call, halt batch | REQ-4, REQ-7 |
| Maintenance window expires mid-run | Time check between batches | Complete in-flight batch, defer remaining hosts | REQ-3 |
| Load balancer drain fails | LB API returns error | Skip host, log, continue (do not patch) | REQ-4 |
| Slack notification fails | Webhook returns non-2xx | Log to syslog, continue (notification is non-blocking) | REQ-5 |

---

## §8 Acceptance Tests

- `molecule/default/` — happy path covering REQ-1, REQ-2, REQ-5, REQ-6
- `molecule/maintenance-window-violation/` — negative test for REQ-3 (must refuse)
- `molecule/kernel-update-reboot/` — REQ-4 verification with simulated kernel update
- `molecule/host-unreachable/` — REQ-1 negative test
- `molecule/host-failure-halts-batch/` — REQ-7 verification
- `molecule/dry-run/` — REQ-6 verification of zero changes

---

## §9 Approvals

- [x] Team lead — enzo.bercasio (2026-04-25)
- [x] Security review (REQ-3, REQ-7, NFR-3) — security-coe (2026-04-28)
- [x] Change advisory board — cab-apac (2026-05-01)
- [x] CoE acceptance of any deviations — N/A (no deviations) (2026-05-01)

---

## §10 Deviations from Best Practices

| Deviation | Best Practice REQ | Justification | Risk Acceptance |
|---|---|---|---|
| None | — | — | — |

---

## §11 Rollback Procedure

If a patch causes regression after deployment:

1. Identify the affected host(s) from the AAP job output.
2. Run the dedicated rollback playbook: `playbooks/rhel_patching_rollback.yml -e "rollback_target=<hostname>"`
3. The rollback playbook performs `dnf history undo` for the most recent transaction matching this spec_id.
4. Verify host returns to pre-patch state via `dnf history list`.
5. If rollback fails, escalate to the platform on-call and consider manual snapshot restore (out of scope of this automation).

Documented runbook: <internal-link-to-runbook>

---

## §12 References

- Red Hat advisory feed: https://access.redhat.com/security/security-updates
- AAP job template: `RHEL-Patching-Monthly` (template_id: 42)
- Related: AUTO-2026-0019 (database tier patching)
- Internal change record: CHG-2026-118
