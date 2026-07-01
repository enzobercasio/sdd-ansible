---
spec_id: AUTO-YYYY-NNNN
title: <Short descriptive title>
status: draft  # draft | review | approved | in-use | deprecated
version: "1.0"
owner: <team-email@company.com>
team: <team-name>          # triggers TEAM-<name>-overrides.md if one exists
use_case: <use-case-tag>   # triggers USE-CASE-<tag>-overrides.md if one exists
target_environments: [dev, staging, prod]
created: <YYYY-MM-DD>
last_modified: <YYYY-MM-DD>
---

# Spec: <Title>

> **Inherits from**: `BEST-PRACTICES-SPEC.md`
> _(and `TEAM-<team>-overrides.md`, `USE-CASE-<use_case>-overrides.md` if they exist)_

---

## §1 Intent

_One paragraph. Why does this automation exist — what business outcome does it achieve? Focus on the **why**, not the how._

---

## §2 Scope

### In scope
- <What this automation handles — be specific about hosts, environments, and conditions>

### Out of scope
- <What it does not handle — reference other specs for related functionality>

---

## §3 Requirements

> Each requirement must be testable and atomic. Use EARS notation where helpful.
> - **Ubiquitous**: "The system shall…"
> - **Event-driven**: "When \<trigger\>, the system shall…"
> - **State-driven**: "While \<state\>, the system shall…"
> - **Unwanted-behaviour**: "If \<undesired condition\>, then the system shall…"

- **REQ-1**: …  — *acceptance: \<measurable criterion\>*
- **REQ-2**: When …, the system shall …  — *acceptance: \<criterion\>*
- **REQ-3**: If …, then the system shall …  — *acceptance: \<criterion\>*

> **Non-functional requirements** (optional — add if relevant):
> - **NFR-1**: <Performance — e.g., "Complete within 4-hour window for up to 200 hosts">
> - **NFR-2**: <Reliability — e.g., "Succeed on first attempt for >95% of invocations">

---

## §4 Inputs

> These become the AAP job template survey fields.

| Variable | Type | Required | Default | Validation | Description |
|---|---|---|---|---|---|
| `<var_name>` | string | yes | — | <rule or regex> | <description> |
| `<var_name>` | int | no | 10 | 1–100 | <description> |
| `<var_name>` | bool | no | false | — | <description> |

---

## §5 Acceptance Criteria

> These become `assert` tasks in Molecule `verify.yml`.

- <Measurable success condition — tied to a REQ above>
- <Second run with identical inputs produces zero changed tasks>

---

## §6 Failure Modes

| Failure | How detected | Response | REQ |
|---|---|---|---|
| <What can go wrong> | <How we detect it> | <What the playbook does> | REQ-N |

**Rollback** (describe how to undo this automation if it causes a regression):

_<Step-by-step rollback or link to runbook>_

---

## §7 Approvals

- [ ] Team lead — <name> (<date>)

**Deviations from best practices** (document any rule in `BEST-PRACTICES-SPEC.md` this spec cannot follow):

| Deviation | Rule | Justification | Accepted by |
|---|---|---|---|
| <description> | REQ-S1 | <technical reason> | <name, date> |

---

## §8 Changelog

> Update this table whenever the spec changes after initial creation. Every row must reference the requirement(s) affected and who authorised the change.

| Version | Date | Author | Status transition | Summary of change | REQ(s) affected |
|---|---|---|---|---|---|
| 1.0 | <YYYY-MM-DD> | <name> | draft | Initial draft | — |
