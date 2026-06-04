---
spec_id: USE-CASE-NETWORK-OVERRIDES
title: Network Device Automation Use-Case Overrides
status: approved
version: "1.0"
owner: automation-coe@company.com
applies_to_use_case: network
authoritative: true
created: 2026-03-20
last_reviewed: 2026-04-30
---

# Network Device Automation Use-Case Overrides

> Applies to any spec with `use_case: network`. Layers on top of `BEST-PRACTICES-SPEC.md` and any team-specific overrides.

## §1 Intent

Codify safety patterns specific to network device automation, where the blast radius of a misconfiguration includes loss of management connectivity, broadcast storms, routing black holes, and cross-tenant impact. Network changes are uniquely difficult to roll back automatically — so the discipline must front-load safety.

## §2 Additional Requirements (REQ-NET)

### Connection & Authentication

- **REQ-NET-1**: Network playbooks shall use `ansible.netcommon.network_cli` or vendor-specific connection plugins. The `ssh` connection is forbidden for network devices.
- **REQ-NET-2**: All credentials shall come from AAP machine credentials or HashiCorp Vault — never inventory variables.
- **REQ-NET-3**: Connection timeouts shall be explicit and conservative (default 30s, max 120s).

### Pre-Change Validation

- **REQ-NET-10**: Before any change, the playbook shall capture and store the running configuration (`backup: yes` or equivalent) — *acceptance: backup file exists with timestamp before any modification*.
- **REQ-NET-11**: Before any change, the playbook shall validate the device is reachable AND authenticated AND in expected state — *acceptance: connection check + show version + role/model match*.
- **REQ-NET-12**: For changes affecting routing or layer 2 topology, the playbook shall capture the current topology state (BGP neighbors, OSPF adjacencies, spanning tree state) for diff after change.

### Change Application

- **REQ-NET-20**: Configuration changes shall use idempotent modules (`*_config`, `*_facts`) — `command:`-style raw CLI is forbidden except for read-only operations.
- **REQ-NET-21**: Changes shall be applied within a `commit_confirm` window (where supported by the platform) requiring positive confirmation, or shall include a rollback timer.
- **REQ-NET-22**: Changes affecting multiple devices shall be staged: lab → one device → 10% of fleet → full rollout, with verification gates between stages.

### Post-Change Validation

- **REQ-NET-30**: After any change, the playbook shall verify the change took effect by reading back the relevant configuration — *acceptance: post-change state matches intended state*.
- **REQ-NET-31**: After any change affecting reachability, the playbook shall verify management connectivity is preserved — *acceptance: subsequent ping or session establishment succeeds*.
- **REQ-NET-32**: After any change affecting topology, the playbook shall verify the topology converged within the expected window (e.g., BGP neighbor up, OSPF full adjacency).

### Persistence

- **REQ-NET-40**: After any successful change, the playbook shall save the running configuration to startup configuration explicitly — running-only changes are forbidden in production.
- **REQ-NET-41**: A configuration backup shall be uploaded to the configuration archive (Git, NSO, ServiceNow) within 60 seconds of change application.

### Rollback

- **REQ-NET-50**: Every spec for `use_case: network` shall document a rollback procedure that uses the pre-change backup captured under REQ-NET-10 — *acceptance: §11 of spec is non-empty and references the backup mechanism*.
- **REQ-NET-51**: Rollback playbooks shall themselves be spec-driven and tested.

## §3 Required Patterns

### Pre-Change Block

Every network playbook starts with this block:

```yaml
- name: REQ-NET-11 — Validate device state before change
  block:
    - name: Verify connectivity and gather facts
      <vendor>.<vendor>.<vendor>_facts:
        gather_subset: min
      register: device_facts

    - name: Assert device is in expected role/model
      ansible.builtin.assert:
        that:
          - device_facts.ansible_facts.ansible_net_model in expected_models
        fail_msg: "Device {{ inventory_hostname }} not in expected models — see specs/<SPEC-ID> §3 REQ-NET-11"

    - name: REQ-NET-10 — Backup running configuration
      <vendor>.<vendor>.<vendor>_config:
        backup: true
        backup_options:
          dir_path: "{{ network_backup_dir }}/{{ ansible_date_time.iso8601 }}"
      register: pre_change_backup
  tags:
    - "spec:<SPEC-ID>"
    - "req:REQ-NET-10"
    - "req:REQ-NET-11"
```

### Change Block

```yaml
- name: REQ-N — Apply configuration change
  <vendor>.<vendor>.<vendor>_config:
    lines: "{{ desired_config_lines }}"
    parents: "{{ config_section_parents | default(omit) }}"
    save_when: never  # We save explicitly under REQ-NET-40
  register: change_result
  notify:
    - verify post change
    - save running config
  tags:
    - "spec:<SPEC-ID>"
    - "req:REQ-N"
```

### Post-Change Verification (handler)

```yaml
- name: verify post change
  block:
    - name: REQ-NET-30 — Read back configuration
      <vendor>.<vendor>.<vendor>_command:
        commands:
          - show running-config | section <relevant-section>
      register: post_change_state

    - name: REQ-NET-30 — Assert configuration matches intent
      ansible.builtin.assert:
        that:
          - desired_pattern in post_change_state.stdout[0]
        fail_msg: "REQ-NET-30 violation: change did not take effect"
```

## §4 Forbidden Patterns for Network

- ❌ Use of `ssh` connection plugin for network devices
- ❌ `_command:` modules used for configuration changes (use `_config:`)
- ❌ Configuration changes without backup
- ❌ Configuration changes without post-verification
- ❌ Running-config-only changes (must persist via REQ-NET-40)
- ❌ Bulk changes across >10% of fleet without staging gates
- ❌ Direct CLI strings interpolated from untrusted input
- ❌ Disabling SSL for `eapi`, `nxapi`, `restconf`, or other API connections

## §5 Required Collections (varies by vendor)

```yaml
collections:
  - name: ansible.netcommon
    version: ">=5.0.0"
  # Pick those relevant to your fleet:
  - name: cisco.ios
  - name: cisco.nxos
  - name: arista.eos
  - name: junipernetworks.junos
  - name: vyos.vyos
```

## §6 Test Requirements (Override of TEST-UNI)

For network use-cases, Molecule tests run against:

- Vendor-provided VM images (Cisco IOSv, Arista cEOS, Junos vMX) where available
- ContainerLab or similar virtual topology tools
- Mock-driver scenarios for unit-style verification

Production-realistic testing requires investment but is non-negotiable for network automation.

## §7 Override Authority

Deviations from network overrides require:

1. Network team lead sign-off
2. Security review (network changes have outsized security impact)
3. Documentation in spec §10

## §8 Examples in Repository

- Future: `specs/examples/AUTO-2026-NNNN-firewall-rule-change.md`
- Future: `specs/examples/AUTO-2026-NNNN-bgp-neighbor-add.md`

## §9 References

- Ansible Network Documentation
- RFC 6020 (NETCONF / YANG) for model-driven approaches
- Internal: network change management policy
