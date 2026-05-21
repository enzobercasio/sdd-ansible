---
spec_id: TEAM-RHEL-OVERRIDES
title: RHEL Team Overrides
status: approved
version: "1.0"
owner: rhel-platform@company.com
applies_to_team: rhel
created: 2026-05-21
last_reviewed: 2026-05-21
---

# RHEL Team Overrides

> Applies to every spec with `team: rhel`. Layers on top of `BEST-PRACTICES-SPEC.md`. When rules conflict, this document wins.

---

## §1 Intent

Capture RHEL-specific conventions once here so individual specs don't repeat them. These rules reflect Red Hat's recommended practices for automating RHEL 8 and RHEL 9 hosts using the officially supported collections and RHEL System Roles.

---

## §2 Additional Requirements

### Package Management

- **REQ-RHEL-1**: Use `ansible.builtin.dnf` for RHEL 8 and `ansible.builtin.dnf5` for RHEL 9 and later. The `yum:` module is deprecated and must not be used regardless of the FQCN.
- **REQ-RHEL-2**: All package operations must specify `state:` explicitly (`present`, `latest`, `absent`). Never rely on the default state.
- **REQ-RHEL-3**: Security-only patch playbooks must set `security: true` and `bugfix: false` on `ansible.builtin.dnf` tasks. Full patch playbooks must set both `security: true` and `bugfix: true`.
- **REQ-RHEL-4**: Playbooks that install packages must check and respect maintenance windows. Use a pre-flight `assert` to validate the current time falls within the window before any `dnf` task runs.
- **REQ-RHEL-5**: Package installation from non-standard repositories must explicitly enable only the required repo using `enablerepo:` and disable it after — never permanently enable third-party repos via automation.

### RHEL System Roles

- **REQ-RHEL-10**: Where a `redhat.rhel_system_roles` role covers the required function, it must be used instead of hand-written tasks. The system roles are Red Hat-tested and maintained — prefer them over equivalent task sequences.

  | Function | Required Role |
  |---|---|
  | SELinux policy management | `redhat.rhel_system_roles.selinux` |
  | Firewall rules | `redhat.rhel_system_roles.firewall` |
  | NTP / Chrony configuration | `redhat.rhel_system_roles.timesync` |
  | Network interface configuration | `redhat.rhel_system_roles.network` |
  | Kernel tuning (`sysctl`) | `redhat.rhel_system_roles.kernel_settings` |
  | Logging (rsyslog / journald) | `redhat.rhel_system_roles.logging` |
  | RHEL registration | `redhat.rhel_system_roles.rhc` |
  | Crypto policy | `redhat.rhel_system_roles.crypto_policies` |
  | Storage management | `redhat.rhel_system_roles.storage` |
  | SSH server hardening | `redhat.rhel_system_roles.sshd` |
  | Certificate management | `redhat.rhel_system_roles.certificate` |
  | HA clustering | `redhat.rhel_system_roles.ha_cluster` |

- **REQ-RHEL-11**: System role variables must be declared in the calling role's `defaults/main.yml` with the `rhel_` prefix and then passed to the system role via `vars:`. Do not set system role variables in inventory — they belong in the spec-derived role defaults.

### SELinux

- **REQ-RHEL-20**: SELinux must **never** be disabled or set to permissive by automation. If a task requires an SELinux policy change, use `redhat.rhel_system_roles.selinux` to add the required boolean, port label, or file context.
- **REQ-RHEL-21**: Any task that installs a service or creates files in non-standard paths must configure the correct SELinux file context using `community.general.sefcontext` and `ansible.builtin.command: restorecon -Rv <path>` (with `changed_when:`).
- **REQ-RHEL-22**: SELinux state must be verified with `ansible.posix.selinux_facts` in the pre-flight block. If SELinux is disabled on a target host, the play must fail with a clear error — not attempt to enable it inline.

### Firewall

- **REQ-RHEL-30**: Firewall rules must be managed with `redhat.rhel_system_roles.firewall` or `ansible.posix.firewalld`. Direct `iptables` or `nftables` manipulation is forbidden.
- **REQ-RHEL-31**: Firewall rule tasks must be idempotent — use `permanent: true` and `immediate: true` together to avoid a split state between runtime and persistent rules.
- **REQ-RHEL-32**: Service-opening rules must reference service names (`service: http`) rather than port numbers where a firewalld service definition exists. This makes intent explicit and survives port remapping.

### Subscription & Content

- **REQ-RHEL-40**: RHEL registration and subscription management must use `redhat.rhel_system_roles.rhc`. Do not call `subscription-manager` directly via `command:` or `shell:`.
- **REQ-RHEL-41**: Content access credentials (activation keys, organization IDs) must be injected via AAP Custom Credentials or Vault. Never store them in role defaults or inventory.
- **REQ-RHEL-42**: Before enabling a repository, validate that the subscription attached to the host includes the required channel. Fail cleanly if the entitlement is missing.

### FIPS & Cryptographic Policy

- **REQ-RHEL-50**: RHEL hosts with FIPS mode enabled must not be targeted by automation that uses cryptographic operations outside the approved policy (e.g., MD5 checksums, SSLv3, RSA < 2048-bit). Use `redhat.rhel_system_roles.crypto_policies` to enforce policy before running cryptographic tasks.
- **REQ-RHEL-51**: Do not change the system-wide cryptographic policy without explicit CAB approval. Policy changes affect all services on the host — document the impact in the spec's §6 Failure Modes.

### Boot & Kernel

- **REQ-RHEL-60**: Kernel parameter changes must use `redhat.rhel_system_roles.kernel_settings`. Direct `/etc/sysctl.d/` file management is permitted only when the system role does not support the required parameter.
- **REQ-RHEL-61**: Playbooks that modify the bootloader or kernel must include a reboot handler using `ansible.builtin.reboot` with explicit `reboot_timeout:`. Document the expected reboot time in the spec.
- **REQ-RHEL-62**: After a reboot, run a post-reboot validation block to confirm the expected kernel version and critical services are running before declaring success.

---

## §3 Tooling Conventions

| Concern | Use this |
|---|---|
| Package install/remove | `ansible.builtin.dnf` (RHEL 8) / `ansible.builtin.dnf5` (RHEL 9+) |
| Service management | `ansible.builtin.systemd_service` |
| Firewall | `redhat.rhel_system_roles.firewall` or `ansible.posix.firewalld` |
| SELinux | `redhat.rhel_system_roles.selinux` + `community.general.sefcontext` |
| RHEL registration | `redhat.rhel_system_roles.rhc` |
| File ACLs | `ansible.posix.acl` |
| Filesystem mounts | `ansible.posix.mount` |
| Cron jobs | `ansible.builtin.cron` (never edit crontab files directly) |
| Reboot | `ansible.builtin.reboot` with `reboot_timeout:` |
| Crypto policy | `redhat.rhel_system_roles.crypto_policies` |

---

## §4 Forbidden (in addition to universal list)

- ❌ `yum:` module in any form
- ❌ Disabling or setting SELinux to permissive
- ❌ Direct `iptables` / `nftables` manipulation
- ❌ Calling `subscription-manager` via `shell:` or `command:`
- ❌ Storing activation keys or organization IDs in role defaults or inventory
- ❌ Changing system-wide cryptographic policy without CAB approval
- ❌ Modifying `/etc/sudoers` directly — use `community.general.sudoers` or `redhat.rhel_system_roles.sudo`
- ❌ Writing to RHEL-managed paths (`/etc/sysconfig/network-scripts/` on RHEL 9) — use the system role

---

## §5 Required Collections

```yaml
collections:
  - name: redhat.rhel_system_roles
    version: ">=1.23.0"
  - name: ansible.posix
    version: ">=1.5.4"
  - name: ansible.builtin
    version: ">=2.15.0"
  - name: community.general
    version: ">=8.0.0"
```

Source: Red Hat Automation Hub (`console.redhat.com/ansible/automation-hub`). `redhat.rhel_system_roles` is a certified collection and must be sourced from Automation Hub, not Galaxy.

---

## §6 Override Authority

Deviations from this document require:

1. Documentation in the spec's §7 Approvals → Deviations table.
2. Sign-off from the RHEL team lead.
3. For security-related deviations (REQ-RHEL-20, REQ-RHEL-50): additional sign-off from the security team.

---

## §7 References

| Reference | URL |
|---|---|
| RHEL 9 Administration and Configuration Tasks Using System Roles | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/administration_and_configuration_tasks_using_system_roles_in_rhel/ |
| RHEL System Roles on Automation Hub | https://console.redhat.com/ansible/automation-hub/repo/published/redhat/rhel_system_roles/ |
| RHEL 9 Security Hardening Guide | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/ |
| RHEL 9 Managing Software with DNF | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/ |
| RHEL 9 Using SELinux | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/ |
| RHEL 9 Configuring and Managing Networking | https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/ |
| ansible.posix Collection Index | https://docs.ansible.com/ansible/latest/collections/ansible/posix/ |
| community.general.sefcontext Module | https://docs.ansible.com/ansible/latest/collections/community/general/sefcontext_module.html |
| ansible.builtin.dnf Module | https://docs.ansible.com/ansible/latest/collections/ansible/builtin/dnf_module.html |
| ansible.builtin.dnf5 Module | https://docs.ansible.com/ansible/latest/collections/ansible/builtin/dnf5_module.html |
| Red Hat Simple Content Access | https://docs.redhat.com/en/documentation/subscription_central/1-latest/html/getting_started_with_simple_content_access/ |
