---
spec_id: USE-CASE-EDA-OVERRIDES
title: Event-Driven Ansible Use-Case Overrides
status: approved
version: "2.0"
owner: automation-coe@company.com
applies_to_use_case: eda
created: 2026-03-15
last_reviewed: 2026-05-19
---

# Event-Driven Ansible (EDA) Use-Case Overrides

> Applies to every spec with `use_case: eda`, regardless of team. Layers on top of `BEST-PRACTICES-SPEC.md` and any team override. When rules conflict, this document wins.

---

## §1 Intent

Event-driven playbooks fire in response to environmental signals, not human clicks. That changes the risk profile: human review is post-hoc, blast radius is amplified by event storms, and source trust becomes critical. These rules address those differences.

---

## §2 Additional Requirements

### Source trust

- **REQ-EDA-1**: Authenticate every event source. Webhooks must validate HMAC signatures or mTLS before any rule evaluation.
- **REQ-EDA-2**: Validate event payloads against a JSON Schema before rule evaluation. Drop and log malformed events.

### Storm protection

- **REQ-EDA-10**: Every rulebook must include a `throttle:` clause limiting actions per source per time window.
- **REQ-EDA-11**: When the same target triggers the same rule 3+ times within 24 hours, escalate to human review instead of auto-remediating.

### Idempotency at rule level

- **REQ-EDA-20**: Rules must check current state before acting — events trigger evaluation, not unconditional execution.

### Safety controls

- **REQ-EDA-30**: Production rulebooks must have a documented kill switch that halts all rule activations within 60 seconds without redeployment.
- **REQ-EDA-31**: After N consecutive failures or unexpected outcomes (configurable, default 3), the rule must auto-disable and alert.

### Observability

- **REQ-EDA-40**: Every action invocation must emit a structured outcome event with: `spec_id`, `correlation_id`, target, outcome, and duration.

### Testing

- **REQ-EDA-50**: Every rulebook must include a test event corpus (`tests/events/*.yml`) covering: valid trigger, invalid signature, malformed payload, throttle threshold, and kill switch.

---

## §3 Required Patterns

### Rulebook skeleton

```yaml
---
- name: <Spec ID> — <Description>
  hosts: all
  sources:
    - <source.plugin>:
        # MUST include source authentication config
  rules:
    - name: <REQ-N> — <description>
      condition: >
        event.payload.<field> == <expected> and
        <guard checking current state>
      throttle:
        once_within: 30 seconds
        group_by_attributes:
          - event.payload.host
      action:
        run_playbook:
          name: <playbook>.yml
          extra_vars:
            spec_id: "<SPEC-ID>"
            correlation_id: "{{ event.meta.correlation_id }}"
```

### Outcome event (emit at end of every action playbook)

```yaml
- name: REQ-EDA-40 — Emit outcome event
  ansible.eda.event:
    type: remediation_outcome
    payload:
      spec_id: "{{ spec_id }}"
      correlation_id: "{{ correlation_id }}"
      target: "{{ inventory_hostname }}"
      outcome: "{{ 'success' if remediation_ok else 'failure' }}"
      duration_seconds: "{{ duration | int }}"
```

---

## §4 Forbidden

- ❌ Rules without `throttle:` clauses
- ❌ Actions that run longer than 5 minutes (split into async + status-check rule)
- ❌ Rules without test event corpora
- ❌ Unvalidated event payload access (always schema-validate first)
- ❌ Rules that chain into other rules without topology documented in the spec

---

## §5 Required Collections

```yaml
collections:
  - name: ansible.eda
    version: ">=2.0.0"
```

---

## §6 Override Authority

Deviations require security review in addition to standard approvals, given the elevated risk surface of event-driven automation.
