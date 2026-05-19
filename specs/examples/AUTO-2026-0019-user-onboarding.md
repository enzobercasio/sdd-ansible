---
spec_id: AUTO-2026-0019
title: Standard User Account Onboarding to Linux Hosts
status: approved
version: "1.2"
owner: platform-engineering@company.com
risk_tier: low
team: platform
use_case: provisioning
target_environments: [dev, staging, prod]
related_specs: []
ansible_collections_required:
  - ansible.builtin
  - ansible.posix
created: 2026-02-10
approved_by: enzo.bercasio
approved_date: 2026-02-15
---

# Spec: Standard User Account Onboarding to Linux Hosts

> Inherits from: `BEST-PRACTICES-SPEC.md`, `TEAM-PLATFORM-overrides.md`
>
> This is a `risk_tier: low` spec — kept intentionally minimal.

---

## §1 Intent

Standardise onboarding of engineering users to Linux hosts, ensuring consistent username conventions, group memberships, and SSH key deployment across the fleet, replacing manual ticket-driven provisioning.

---

## §2 Scope

### In scope

- Linux hosts (RHEL, Ubuntu) tagged `engineering-access` in inventory
- Account creation, group assignment, SSH key deployment
- Idempotent re-execution (re-running has no effect on already-provisioned users)

### Out of scope

- Production database hosts (separate process via DBA)
- Privileged/root account provisioning
- Account de-provisioning (separate spec)

---

## §3 Requirements (EARS notation)

- **REQ-1**: When the playbook is invoked with a user list, the system shall create each user with the standard UID range (5000–9999) — *acceptance: `getent passwd <user>` returns UID in range*.
- **REQ-2**: When a user is created, the system shall add them to the groups specified in the user record — *acceptance: `id <user>` shows expected group memberships*.
- **REQ-3**: When SSH keys are provided, the system shall install them in `~/.ssh/authorized_keys` with mode 0600 — *acceptance: file exists with correct mode and content*.
- **REQ-4**: If a user already exists with matching UID and groups, then the system shall make no changes — *acceptance: `changed: false` for existing users*.
- **REQ-5**: If the SSH key list for an existing user differs from the spec input, then the system shall reconcile to the spec input — *acceptance: removed keys are deleted, added keys are present*.

---

## §5 Inputs

| Variable | Type | Required | Default | Validation | Description |
|---|---|---|---|---|---|
| `users` | list of dicts | yes | — | Each dict has `username`, `groups`, `ssh_keys` | User records to onboard |

User dict structure:
```yaml
username: jdoe                    # required, string, lowercase, [a-z0-9_-]+
groups: [engineering, docker]     # required, list of strings, must exist
ssh_keys:                         # required, list of public key strings
  - ssh-ed25519 AAAA... jdoe@laptop
```

---

## §6 Outputs / Acceptance Criteria

- All listed users exist on all target hosts with correct UID, groups, and keys
- Re-running the playbook produces zero changes

---

## §8 Acceptance Tests

- `molecule/default/` — onboard a fresh user, verify all REQs
- `molecule/idempotent/` — second run of default produces zero changes (REQ-4)
- `molecule/key-rotation/` — REQ-5 verifies reconciliation when keys change

---

## §9 Approvals

- [x] Team lead — enzo.bercasio (2026-02-15)

---

## §12 References

- AUTO-2026-0020 (user de-provisioning, planned)
- Internal: standard UID/GID allocation document
