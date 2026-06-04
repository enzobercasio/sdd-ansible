---
spec_id: TEAM-WINDOWS-OVERRIDES
title: Windows Team Overrides
status: approved
version: "1.0"
owner: windows-platform@company.com
applies_to_team: windows
created: 2026-05-21
last_reviewed: 2026-05-21
---

# Windows Team Overrides

> Applies to every spec with `team: windows`. Layers on top of `BEST-PRACTICES-SPEC.md`. When rules conflict, this document wins.

---

## §1 Intent

Capture Windows automation conventions once here so individual specs don't repeat them. These rules reflect Red Hat's recommended practices for managing Windows hosts from AAP using the `ansible.windows` certified collection.

---

## §2 Additional Requirements

### Connection & Transport

- **REQ-WIN-1**: Windows target hosts must use WinRM or SSH as the connection transport. WinRM over HTTPS is required for production. WinRM over HTTP is permitted in isolated dev/lab environments only, with a documented justification.
- **REQ-WIN-2**: WinRM connection variables (`ansible_connection`, `ansible_winrm_transport`, `ansible_winrm_server_cert_validation`) must be set in group_vars or AAP inventory — never inline in playbooks.
- **REQ-WIN-3**: SSH on Windows (OpenSSH for Windows) is the preferred transport for new hosts running Windows Server 2019 or later. Where SSH is available, prefer it over WinRM — it uses standard AAP Machine Credentials and eliminates WinRM firewall complexity.
- **REQ-WIN-4**: Kerberos authentication (`ansible_winrm_transport: kerberos`) must be used in domain-joined environments for production. CredSSP and NTLM require explicit justification in the spec.

### Module Selection

- **REQ-WIN-10**: Use `ansible.windows.*` modules over legacy `win_*` short names. FQCN is required per REQ-S1.
- **REQ-WIN-11**: Where `ansible.windows` provides a module, it must be used instead of `community.windows`. Fall back to `community.windows` only when `ansible.windows` does not cover the function, and document the reason.

  | Function | Required Module |
  |---|---|
  | Copy files | `ansible.windows.win_copy` |
  | Create/modify files | `ansible.windows.win_template` |
  | Run commands | `ansible.windows.win_command` |
  | Run shell (PowerShell) | `ansible.windows.win_shell` |
  | Manage packages (MSI/EXE) | `ansible.windows.win_package` |
  | Manage Windows features | `ansible.windows.win_feature` |
  | Manage services | `ansible.windows.win_service` |
  | Manage registry | `ansible.windows.win_regedit` |
  | Manage users | `ansible.windows.win_user` |
  | Manage groups | `ansible.windows.win_group` |
  | Manage scheduled tasks | `community.windows.win_scheduled_task` |
  | Manage ACLs | `ansible.windows.win_acl` |
  | Chocolatey packages | `chocolatey.chocolatey.win_chocolatey` |
  | DSC resources | `community.windows.win_dsc` |

- **REQ-WIN-12**: `ansible.windows.win_shell` and `ansible.windows.win_command` are subject to the same idempotency requirement as REQ-I2 — include `creates:`, `removes:`, or an explicit `changed_when:`. PowerShell scripts run via `win_shell` must be idempotent.

### Privilege & Execution Context

- **REQ-WIN-20**: `become: true` on Windows uses `become_method: runas`. The `runas` user and password must be injected via AAP Windows Credential — never hardcoded.
- **REQ-WIN-21**: Local Administrator account must not be used as the `ansible_user` for routine automation. Use a dedicated service account with the minimum necessary privileges. Document the required account in the spec §4 Inputs.
- **REQ-WIN-22**: UAC elevation must be handled via `become: true` with `become_method: runas` — do not attempt to suppress or bypass UAC through registry modifications.

### Package Management

- **REQ-WIN-30**: Windows software installations must use one of: `ansible.windows.win_package` (for MSI/EXE packages) or `chocolatey.chocolatey.win_chocolatey` (for Chocolatey packages). Direct invocation of `msiexec` via `win_shell` is forbidden unless `win_package` cannot handle the installer.
- **REQ-WIN-31**: Chocolatey must be installed via `chocolatey.chocolatey.win_chocolatey_feature` before any `win_chocolatey` task runs. Do not assume Chocolatey is present. Include a pre-flight check.
- **REQ-WIN-32**: Windows Updates must be managed with `ansible.windows.win_updates`. Reboot handling must use `ansible.windows.win_reboot` with appropriate `reboot_timeout:` and `post_reboot_delay:` values (minimum 60 seconds for domain-joined hosts).
- **REQ-WIN-33**: Software version pinning is required — always specify `version:` or `product_id:` in `win_package` tasks.

### Windows Features & Roles

- **REQ-WIN-40**: Windows Server roles and features must be managed with `ansible.windows.win_feature`. Document feature dependencies in the spec §3 Requirements — Windows features often have cascading dependencies that affect idempotency.
- **REQ-WIN-41**: After installing or removing features that modify IIS, .NET, or networking stacks, include a reboot handler and post-reboot validation.

### Registry

- **REQ-WIN-50**: Registry modifications must use `ansible.windows.win_regedit`. Never modify the registry via `win_shell` with `reg.exe` commands.
- **REQ-WIN-51**: Critical registry paths (SAM, SECURITY, SYSTEM hive) must not be modified by automation. Changes to these paths require CAB approval and must be documented in the spec.
- **REQ-WIN-52**: Registry tasks must specify `state: present` or `state: absent` explicitly. Do not rely on defaults.

### Idempotency Challenges

Windows modules present unique idempotency challenges. Pay special attention to:

- **REQ-WIN-60**: `ansible.windows.win_feature` — adding the same feature twice is idempotent, but removing a feature that was never installed produces a changed status on some Windows versions. Use a `win_feature_facts` pre-check for removal tasks.
- **REQ-WIN-61**: `ansible.windows.win_package` — `state: absent` requires the exact product name or product ID. Use `win_package_facts` to verify the package name before removal.
- **REQ-WIN-62**: PowerShell scripts via `win_shell` — scripts that perform their own idempotency checks must still declare `changed_when:` with the exact condition under which a change occurred. Do not use `changed_when: false` unless the script genuinely never makes changes.

### Secrets on Windows

- **REQ-WIN-70**: Windows service account passwords must be injected via AAP Windows Credential or Vault. Never store service account passwords in role defaults.
- **REQ-WIN-71**: Certificate operations must use `community.windows.win_certificate_store` — do not manage certificate stores via PowerShell scripts. Certificates containing private keys must be handled with `no_log: true`.
- **REQ-WIN-72**: DPAPI-encrypted values must not be decrypted or re-encrypted by automation unless explicitly required by the spec and approved by the security team.

---

## §3 Tooling Conventions

| Concern | Use this |
|---|---|
| Package installs (MSI/EXE) | `ansible.windows.win_package` |
| Package installs (Chocolatey) | `chocolatey.chocolatey.win_chocolatey` |
| Windows Updates | `ansible.windows.win_updates` + `ansible.windows.win_reboot` |
| Windows features/roles | `ansible.windows.win_feature` |
| Services | `ansible.windows.win_service` |
| Registry | `ansible.windows.win_regedit` |
| File copy | `ansible.windows.win_copy` |
| Templates | `ansible.windows.win_template` |
| ACLs / permissions | `ansible.windows.win_acl` |
| Users / groups | `ansible.windows.win_user` / `ansible.windows.win_group` |
| Scheduled tasks | `community.windows.win_scheduled_task` |
| Certificates | `community.windows.win_certificate_store` |
| DSC resources | `community.windows.win_dsc` |
| Firewall rules | `community.windows.win_firewall_rule` |

---

## §4 Forbidden (in addition to universal list)

- ❌ WinRM over HTTP in staging or production
- ❌ Using `ansible_user: Administrator` (local Administrator) for routine automation
- ❌ Modifying the registry via `reg.exe` in `win_shell` tasks
- ❌ Installing software via raw PowerShell `Invoke-WebRequest` + `Start-Process` without `win_package`
- ❌ Setting `ansible_winrm_server_cert_validation: ignore` in staging or production
- ❌ Storing service account passwords in role defaults or group_vars
- ❌ Modifying SAM, SECURITY, or SYSTEM registry hives without CAB approval
- ❌ Using DSC via raw PowerShell — use `community.windows.win_dsc` for testability

---

## §5 Required Collections

```yaml
collections:
  - name: ansible.windows
    version: ">=2.3.0"
  - name: community.windows
    version: ">=2.2.0"
  - name: chocolatey.chocolatey
    version: ">=1.5.0"
```

Source: Red Hat Automation Hub for `ansible.windows`. `chocolatey.chocolatey` is sourced from Automation Hub (certified). `community.windows` is sourced from Automation Hub (community — requires team lead approval per REQ-C2).

---

## §6 Override Authority

Deviations from this document require:

1. Documentation in the spec's §7 Approvals → Deviations table.
2. Sign-off from the Windows platform team lead.
3. For authentication-related deviations (REQ-WIN-1, REQ-WIN-4): additional sign-off from the security team.

---

## §7 References

| Reference | URL |
|---|---|
| ansible.windows Collection Index | https://docs.ansible.com/ansible/latest/collections/ansible/windows/ |
| community.windows Collection Index | https://docs.ansible.com/ansible/latest/collections/community/windows/ |
| chocolatey.chocolatey Collection | https://docs.ansible.com/ansible/latest/collections/chocolatey/chocolatey/ |
| Ansible Windows Guide | https://docs.ansible.com/ansible/latest/os_guide/windows_usage.html |
| Setting Up Windows for Remote Management | https://docs.ansible.com/ansible/latest/os_guide/windows_setup.html |
| WinRM Setup and Configuration | https://docs.ansible.com/ansible/latest/os_guide/windows_winrm.html |
| Windows SSH Support | https://docs.ansible.com/ansible/latest/os_guide/windows_ssh.html |
| ansible.windows.win_updates Module | https://docs.ansible.com/ansible/latest/collections/ansible/windows/win_updates_module.html |
| ansible.windows.win_package Module | https://docs.ansible.com/ansible/latest/collections/ansible/windows/win_package_module.html |
| AAP Windows Credentials | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/automation_controller_user_guide/controller-credentials |
| Microsoft OpenSSH for Windows Server | https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse |
