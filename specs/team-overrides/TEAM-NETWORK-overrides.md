---
spec_id: TEAM-NETWORK-OVERRIDES
title: Network Team Overrides
status: approved
version: "1.0"
owner: network-engineering@company.com
applies_to_team: network
created: 2026-05-21
last_reviewed: 2026-05-21
---

# Network Team Overrides

> Applies to every spec with `team: network`. Layers on top of `BEST-PRACTICES-SPEC.md`. When rules conflict, this document wins.
>
> **Note**: For use-case-specific EDA or event-driven automation targeting network devices, also apply `USE-CASE-EDA-overrides.md`.

---

## §1 Intent

Capture network automation conventions once here so individual specs don't repeat them. These rules reflect Red Hat's recommended practices for managing network devices from AAP using `ansible.netcommon` and vendor-specific certified collections.

Network devices present fundamentally different automation challenges than servers: they typically lack a Python runtime, changes can be network-disruptive (loss of management plane), and rollback is often manual. These rules exist to enforce discipline around those risks.

---

## §2 Additional Requirements

### Connection & Transport

- **REQ-NET-1**: Network device connection must use the appropriate connection plugin for the device type. The default `ansible_connection: ansible.netcommon.network_cli` must be used for CLI-managed devices. `ansible.netcommon.netconf` is preferred for NETCONF-capable devices. `ansible.netcommon.httpapi` is used for REST API-based devices.

  | Device / OS | Connection Plugin |
  |---|---|
  | Cisco IOS / IOS-XE | `ansible.netcommon.network_cli` |
  | Cisco NX-OS | `ansible.netcommon.network_cli` or `ansible.netcommon.httpapi` |
  | Cisco IOS-XR | `ansible.netcommon.network_cli` or `ansible.netcommon.netconf` |
  | Arista EOS | `ansible.netcommon.network_cli` or `ansible.netcommon.httpapi` |
  | Juniper Junos | `ansible.netcommon.netconf` (preferred) or `ansible.netcommon.network_cli` |
  | F5 BIG-IP | `ansible.netcommon.httpapi` |
  | Palo Alto PAN-OS | `ansible.netcommon.httpapi` |

- **REQ-NET-2**: `ansible_network_os` must be set for all network device groups in inventory. Never rely on auto-detection.
- **REQ-NET-3**: Network device credentials must be injected via AAP Network Credential type. SSH private keys, passwords, and enable passwords must never appear in inventory, group_vars, or role defaults.
- **REQ-NET-4**: SSH key-based authentication is preferred over password authentication for all network devices that support it. Document the SSH key management procedure in the role README.

### Configuration Backup

- **REQ-NET-10**: Every playbook that modifies device configuration must back up the current running configuration before making any change. Use `ansible.netcommon.net_get` or the vendor-specific `<vendor>_command` module to retrieve and store the backup in a timestamped file.
- **REQ-NET-11**: Configuration backups must be stored in a location accessible to the team and retained for a minimum of 30 days. Document the backup path convention in the role README: `backups/<device_hostname>/<spec_id>/<timestamp>.cfg`.
- **REQ-NET-12**: The backup task must be in the `pre_tasks:` block and must complete successfully before any configuration change task runs. If the backup fails, the play must exit without making changes.

### Change Safety

- **REQ-NET-20**: Network automation targeting production devices is always `risk_tier: medium` or `risk_tier: high`. There is no `risk_tier: low` for production network changes — even small config changes can cause outages.
- **REQ-NET-21**: Changes that modify routing, BGP neighbors, OSPF areas, VLANs, or spanning tree must be `risk_tier: high` and require CAB approval.
- **REQ-NET-22**: All network change playbooks must implement a **commit confirmation** pattern where available (Junos `confirmed-commit`, IOS-XR commit confirmed). For platforms without native commit confirmation, implement a post-change verification step that rollbacks via the backup if validation fails.
- **REQ-NET-23**: Playbooks that could interrupt management plane connectivity (changing management IP, ACLs on management interface, shutting interfaces) must implement an out-of-band (OOB) verification step. Document the OOB access method in the spec §6 Failure Modes.
- **REQ-NET-24**: Serial execution is the default for network automation. Never run network changes in parallel (`strategy: free` or high `forks:`) unless explicitly justified. Parallel changes to interconnected devices can produce unpredictable states.
- **REQ-NET-25**: Network changes must only run inside a defined maintenance window. Implement a pre-flight `assert` checking that the current UTC time falls within the window declared in the spec §4 Inputs.

### Configuration Validation

- **REQ-NET-30**: After applying configuration changes, validate the device state using a separate `validate` task block. Do not rely on the configuration module's return code alone.
- **REQ-NET-31**: Routing and BGP playbooks must verify adjacency state after changes using `<vendor>_command` to run `show` commands and parse output with `ansible.utils.cli_parse` or `ansible.netcommon.cli_parse`.
- **REQ-NET-32**: ACL and firewall rule changes must verify that the management access path is not blocked before committing the change. Include a connectivity check (ICMP or TCP to management IP) in the `verify` block.
- **REQ-NET-33**: Use `ansible.utils.validate` with YANG or JSON Schema models to validate configuration intent before pushing to devices. This catches schema errors before they reach the device.

### Idempotency on Network Devices

Network modules present idempotency challenges not present in server automation:

- **REQ-NET-40**: Use resource modules (`cisco.ios.ios_vlans`, `arista.eos.eos_bgp_global`, etc.) instead of `<vendor>_config` wherever available. Resource modules implement idempotency by comparing desired state to current device state — `<vendor>_config` does a text diff and is less reliable.
- **REQ-NET-41**: `<vendor>_config` tasks must use `diff: true` in check mode to show what will change before committing. Always run `--check` first for `risk_tier: high` changes.
- **REQ-NET-42**: Tasks using `<vendor>_command` to push raw CLI are not idempotent by nature. Wrap them in a `when:` condition that first checks device state via a `<vendor>_facts` task. Document the state check logic in the task comment.
- **REQ-NET-43**: `changed_when:` must be defined for all `<vendor>_command` tasks. Use parsed command output or `diff_lines` to determine whether a change actually occurred.

### NETCONF & REST API

- **REQ-NET-50**: NETCONF playbooks must use `ansible.netcommon.netconf_get` for state reads and `ansible.netcommon.netconf_edit_config` for state writes. Do not parse raw NETCONF XML manually — use `ansible.utils.xml_to_dict` for structured access.
- **REQ-NET-51**: REST API playbooks using `ansible.builtin.uri:` must always set `validate_certs: true` (per REQ-P5). Vendor-specific `httpapi` connection plugins handle TLS at the connection layer — prefer them over raw `uri:` calls.

---

## §3 Tooling Conventions

| Concern | Use this |
|---|---|
| CLI device interaction | `ansible.netcommon.network_cli` + vendor resource modules |
| NETCONF interaction | `ansible.netcommon.netconf_edit_config` / `netconf_get` |
| REST API interaction | Vendor `httpapi` plugin (not raw `ansible.builtin.uri:`) |
| Config backup | `ansible.netcommon.net_get` or vendor `_command` |
| Config validation | `ansible.utils.validate` + `ansible.utils.cli_parse` |
| BGP / routing facts | Vendor-specific `_bgp_global`, `_bgp_address_family` modules |
| VLAN management | Vendor-specific `_vlans` resource module |
| ACL management | Vendor-specific `_acls` resource module |
| Interface management | Vendor-specific `_interfaces` resource module |
| Prefix list management | Vendor-specific `_prefix_lists` resource module |

---

## §4 Forbidden (in addition to universal list)

- ❌ `risk_tier: low` for production network device changes
- ❌ Network credentials in inventory, group_vars, or role defaults
- ❌ Applying configuration changes without a pre-change backup
- ❌ `strategy: free` or forks > 1 without documented justification
- ❌ Raw CLI pushes via `<vendor>_config` when a resource module exists
- ❌ Parallel changes to BGP-peered or STP-adjacent devices without CAB approval
- ❌ Changes to management interface ACLs without an OOB verification step
- ❌ `validate_certs: false` for REST API-based network automation in production
- ❌ Running network change playbooks outside a declared maintenance window

---

## §5 Required Collections

```yaml
collections:
  - name: ansible.netcommon
    version: ">=6.1.0"
  - name: ansible.utils
    version: ">=4.1.0"
```

Add vendor-specific collections based on the devices in scope:

```yaml
  # Cisco IOS / IOS-XE
  - name: cisco.ios
    version: ">=8.0.0"

  # Cisco NX-OS
  - name: cisco.nxos
    version: ">=8.0.0"

  # Cisco IOS-XR
  - name: cisco.iosxr
    version: ">=9.0.0"

  # Arista EOS
  - name: arista.eos
    version: ">=9.0.0"

  # Juniper Junos
  - name: junipernetworks.junos
    version: ">=8.0.0"

  # F5 BIG-IP (httpapi)
  - name: f5networks.f5_modules
    version: ">=1.28.0"
```

Source: Red Hat Automation Hub. All listed collections are Red Hat Certified. Only include vendor collections relevant to the devices in scope.

---

## §6 Override Authority

Deviations from this document require:

1. Documentation in the spec's §7 Approvals → Deviations table.
2. Sign-off from the network team lead.
3. For change-safety deviations (REQ-NET-21 through REQ-NET-25): CAB approval.
4. For parallel execution (REQ-NET-24): written justification from the network architect.

---

## §7 References

| Reference | URL |
|---|---|
| ansible.netcommon Collection Index | https://docs.ansible.com/ansible/latest/collections/ansible/netcommon/ |
| ansible.utils Collection Index | https://docs.ansible.com/ansible/latest/collections/ansible/utils/ |
| Ansible Network Automation Guide | https://docs.ansible.com/ansible/latest/network/getting_started/network_differences.html |
| Network Resource Modules | https://docs.ansible.com/ansible/latest/network/user_guide/network_resource_modules.html |
| cisco.ios Collection Index | https://docs.ansible.com/ansible/latest/collections/cisco/ios/ |
| cisco.nxos Collection Index | https://docs.ansible.com/ansible/latest/collections/cisco/nxos/ |
| arista.eos Collection Index | https://docs.ansible.com/ansible/latest/collections/arista/eos/ |
| junipernetworks.junos Collection Index | https://docs.ansible.com/ansible/latest/collections/junipernetworks/junos/ |
| ansible.netcommon on Automation Hub | https://console.redhat.com/ansible/automation-hub/repo/published/ansible/netcommon/ |
| AAP Network Credentials | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/automation_controller_user_guide/controller-credentials |
| Ansible Network Getting Started | https://docs.ansible.com/ansible/latest/network/getting_started/index.html |
| NETCONF Overview | https://docs.ansible.com/ansible/latest/network/user_guide/platform_netconf_enabled_platforms.html |
