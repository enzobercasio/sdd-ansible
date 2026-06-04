---
spec_id: TEAM-PLATFORM-OVERRIDES
title: Platform Team Overrides
status: approved
version: "2.0"
owner: platform-engineering@company.com
applies_to_team: platform
created: 2026-03-01
last_reviewed: 2026-05-19
---

# Platform Team Overrides

> Applies to every spec with `team: platform`. Layers on top of `BEST-PRACTICES-SPEC.md`. When rules conflict, this document wins.

---

## §1 Intent

Capture platform team conventions once here so individual specs don't repeat them.

---

## §2 Additional Requirements

### Secrets

- **REQ-PT-1**: Retrieve secrets from HashiCorp Vault using `community.hashi_vault.vault_kv2_get`. Ansible Vault is allowed in dev only.
- **REQ-PT-2**: Vault paths must follow `secret/platform/<env>/<spec_id>/<key>`.
- **REQ-PT-3**: Use AAP-managed AppRole for Vault auth. Token auth is forbidden in production.

### Change communication

- **REQ-PT-10**: All playbooks must post a structured Slack message to `#platform-changes` at start and end, including: `spec_id`, AAP job URL, executor, target group, expected duration.
- **REQ-PT-11**: Use `community.general.slack` for Slack messages, not raw webhooks.

### CMDB integration

- **REQ-PT-20**: Before applying changes, verify the target host is not in `change_freeze` or `decommissioning` state in the CMDB.
- **REQ-PT-21**: After successful changes, update the CMDB record with `spec_id`, version, and timestamp.

### Inventory

- **REQ-PT-30**: Validate required inventory group memberships with an `assert` at the start of execution — don't assume group membership.
- **REQ-PT-31**: Prefer dynamic inventory (cloud sources, ServiceNow CMDB) over static inventory for non-trivial host sets.

---

## §3 Tooling Conventions

| Concern | Use this |
|---|---|
| RHEL-specific config | `redhat.rhel_system_roles` roles where available |
| Firewall rules on RHEL | `ansible.posix.firewalld` (not `iptables`) |
| Systemd services | `ansible.builtin.systemd_service` |
| Scheduling | AAP schedules (not cron) |

---

## §4 Forbidden (in addition to universal list)

- ❌ Calling an API via `uri:` when a dedicated collection module exists
- ❌ Provisioning IaaS resources that bypass Terraform
- ❌ Modifying platform-managed paths (`/etc/platform/`, `/opt/platform/`)
- ❌ Cron-based scheduling — use AAP schedules

---

## §5 Required Collections

```yaml
collections:
  - name: community.hashi_vault
    version: ">=6.0.0"
  - name: redhat.rhel_system_roles
    version: ">=1.20.0"
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.general
    version: ">=8.0.0"
```

---

## §6 Override Authority

Deviations from this document require:

1. Documentation in the spec's §7 Approvals → Deviations table.
2. Sign-off from the platform team lead.
