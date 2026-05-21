# Spec Authoring Guide

> How to write a good Ansible automation spec.

## What a Good Spec Does

A good spec answers four questions:

1. **What** is being automated and why?
2. **For whom** — who runs it, who is affected?
3. **How well** — what's the bar for "working correctly"?
4. **What if** — what happens when things go wrong?

If your spec doesn't answer all four, it's not done.

## What a Good Spec Is NOT

- ❌ A description of the playbook (that's the README)
- ❌ A list of Ansible tasks (that's the implementation)
- ❌ A change request ticket (that lives in Jira)
- ❌ A user manual (that's documentation)

A spec is a **contract** between intent and implementation, written in a way that both humans and AI can verify against.

## The EARS Notation

Use **Easy Approach to Requirements Syntax (EARS)** for individual requirements. Five patterns:

| Pattern | Form | Example |
|---|---|---|
| **Ubiquitous** | The system shall <action> | The system shall log all changes to syslog. |
| **State-driven** | While <state>, the system shall <action> | While in maintenance window, the system shall accept patch requests. |
| **Event-driven** | When <trigger>, the system shall <action> | When a critical CVE is published, the system shall create a remediation ticket. |
| **Optional** | Where <feature is enabled>, the system shall <action> | Where dry-run mode is enabled, the system shall not modify state. |
| **Unwanted behaviour** | If <undesired>, then the system shall <mitigation> | If a host fails to reboot, then the system shall halt the batch and alert. |

EARS is precise enough for a test author (human or AI) to mechanically translate each requirement into a Molecule assertion.

## Sizing Your Spec to the Risk Tier

| Risk Tier | Spec Length | Required Sections |
|---|---|---|
| **Low** | 1 page | Intent, Scope, Requirements, Inputs, Acceptance |
| **Medium** | 2–3 pages | All Low sections + Non-functional, Failure modes, Approvals |
| **High** | 3–5 pages | All Medium sections + Threat model, Rollback, CAB sign-off |

Don't over-spec a low-risk task. Don't under-spec a high-risk one.

## Section-by-Section Guidance

### Frontmatter (YAML)

```yaml
---
spec_id: AUTO-2026-0042              # Generated, monotonic
title: <Short descriptive title>     # User-readable
status: draft                        # draft | review | approved | deprecated
version: "1.0"
owner: team-platform@company.com     # Group inbox preferred
risk_tier: medium                    # low | medium | high
team: platform                       # Triggers TEAM-platform-overrides.md
use_case: patching                   # Triggers USE-CASE-patching-overrides.md if exists
target_environments: [dev, staging, prod]
related_specs: [AUTO-2026-0019]
ansible_collections_required:
  - ansible.posix
  - community.general
created: 2026-05-01
approved_by: <name>                  # Filled when approved
approved_date: <YYYY-MM-DD>
---
```

### §1 Intent (What)

One paragraph. Answer: "what business outcome does this produce?"

> ✅ Good: "Reduce manual effort and inconsistency in monthly RHEL security patching across web tier servers, ensuring all production systems receive critical updates within SLA windows while minimising service disruption."
> 
> ❌ Bad: "This playbook patches RHEL servers."

### §2 Scope

Two lists. Be ruthless about what's **out** of scope.

```markdown
### In scope
- RHEL 8 and 9 hosts in `webservers` and `appservers` groups
- Security and bugfix errata only

### Out of scope
- Database tier (handled by AUTO-2026-0019)
- Kernel updates requiring drain >5 minutes
- Major version upgrades (separate spec required)
```

### §3 Requirements (EARS)

Number them. **Each requirement must be testable.** If you can't write an assertion for it, rewrite it.

```markdown
- **REQ-1**: When the playbook is invoked, the system shall verify all targets are reachable before any change.
- **REQ-2**: When patching begins, the system shall patch hosts in batches of 10% of the group.
- **REQ-3**: While outside the approved maintenance window (22:00–04:00 SGT), the system shall refuse to execute.
```

**Smell test for requirements:**

| Smell | Example | Fix |
|---|---|---|
| Vague | "The system shall be reliable" | "The system shall succeed on >99% of attempts over 30 days" |
| Multiple requirements | "Patch hosts and notify Slack and update CMDB" | Split into REQ-N, REQ-N+1, REQ-N+2 |
| Implementation detail | "Use the dnf module with state=latest" | "The system shall apply latest available security errata" |
| No actor | "Notifications are sent" | "When patching completes, the system shall post to Slack" |

### §4 Non-Functional Requirements

Where this differs from §3: §3 is about *what*, §4 is about *how well*.

```markdown
- **Idempotent**: Re-runs must be safe (same outcome, no errors)
- **Performance**: Complete patching of 200 hosts within 4-hour window
- **Auditability**: Every action logged to AAP job output and forwarded to SIEM
- **Recoverability**: Documented manual rollback procedure (link to runbook)
- **Observability**: Prometheus metrics emitted for batch progress
```

### §5 Inputs (Variable Contract)

This becomes the AAP survey. Be explicit about types and validation.

```markdown
| Variable | Type | Required | Default | Validation | Description |
|---|---|---|---|---|---|
| `target_group` | string | yes | — | Must exist in inventory | Inventory group name |
| `batch_percentage` | int | no | 10 | 1–50 | Rolling batch size |
| `dry_run` | bool | no | false | — | Check mode only |
| `notification_channel` | string | no | "#ops-changes" | Starts with `#` | Slack channel |
```

### §6 Outputs / Acceptance Criteria

These become Molecule `assert` tasks.

```markdown
- All targeted hosts return `patched: true` in summary
- Zero failed reboots
- Slack notification posted within 60 seconds of completion
- Total runtime under 4 hours
```

### §7 Failure Modes

For `risk_tier: medium/high`. What can go wrong, and what's the response?

```markdown
| Failure Mode | Detection | Response | REQ Reference |
|---|---|---|---|
| Host unreachable | Pre-flight check fails | Halt batch, alert, retry once | REQ-1 |
| Patch installation fails | dnf returns non-zero | Skip host, continue batch, log to ITSM | REQ-2 |
| Reboot timeout | wait_for_connection > 5min | Mark host degraded, notify on-call | REQ-4 |
| Maintenance window expires mid-run | Time check inside loop | Complete current batch, defer rest | REQ-3 |
```

### §8 Acceptance Tests

Maps to Molecule scenarios. Test author uses this directly.

```markdown
- `molecule/default/` — happy path covering REQ-1, REQ-2
- `molecule/maintenance-window-violation/` — negative test for REQ-3
- `molecule/kernel-update-reboot/` — REQ-4 verification
- `molecule/host-unreachable/` — REQ-1 negative test
```

### §9 Approvals

```markdown
- [x] Platform lead — enzo.bercasio (2026-05-01)
- [x] Security review (REQ-3, REQ-5) — security-coe (2026-05-02)
- [x] Change advisory board — cab-apac (2026-05-03)
```

### §10 Deviations from Best Practices

If you must violate `BEST-PRACTICES-SPEC.md`, document why here.

```markdown
- **Uses `command:` module instead of `ansible.builtin.dnf`**: needed because dnf module does not support the `--bugfix-only` flag in our RHEL version. Risk accepted by security review on 2026-05-02. Issue tracked in https://issues.redhat.com/browse/ANSIBLE-12345.
```

## When to Create a Team Override

Create `TEAM-<name>-overrides.md` when:

- **Three or more specs from the same team** include the same constraint
- The constraint is **truly universal** to the team's domain
- The constraint **doesn't fit** in the universal best practices

Examples of good team overrides:

- Platform team always uses HashiCorp Vault for secrets → override
- Security team always emits events to a specific SIEM → override
- Network team always uses `ansible.netcommon.network_cli` → override

Examples of bad team overrides:

- "We prefer 4-space indentation" → put in lint config, not spec
- "We don't like comments" → no, that's terrible
- "Don't run molecule tests" → absolutely not

## When to Create a Use-Case Override

Create `USE-CASE-<name>-overrides.md` when:

- The pattern applies **across teams** but only to **specific automation types**
- It encodes **domain expertise** (EDA event handling, network device idempotency, Windows-specific patterns)

Examples:

- `USE-CASE-EDA-overrides.md` → rulebook patterns, throttling, source filtering
- `USE-CASE-NETWORK-overrides.md` → save running config, idempotency check via `diff`
- `USE-CASE-WINDOWS-overrides.md` → use `ansible.windows.win_*`, always check for pending reboots
- `USE-CASE-SECURITY-overrides.md` → CIS benchmark alignment, immutable audit log

## Spec Lifecycle

```
draft → review → approved → in-use → deprecated
                    ↓
               (amended → bumped version)
```

- **draft**: Author is still writing. No PR review yet.
- **review**: Open PR, awaiting peer + security review.
- **approved**: Merged. Code generation can proceed.
- **in-use**: Has corresponding playbooks and tests in production.
- **deprecated**: Superseded; maintain link to replacement.

Bump version (`1.0 → 1.1`) for any non-trivial requirement change. Re-run reviews for `risk_tier: medium/high` amendments.

## Common Spec Smells

| Smell | Symptom | Fix |
|---|---|---|
| **God spec** | One spec covers too many use cases | Split by use case |
| **Implementation leak** | Requirements specify modules or task names | Rewrite at intent level |
| **Untestable requirement** | "Must be performant" | Quantify: "p95 < 30s" |
| **Phantom dependencies** | References specs that don't exist | Audit before approval |
| **Stale spec** | Code has diverged from spec | Either amend spec or fix code |
| **Approval theatre** | Approvals checked but no review evidence | Require review comments in PR |

## Quick Self-Check

Before submitting a spec for review:

- [ ] Could a developer who has never met me implement this correctly?
- [ ] Could a tester write Molecule scenarios from this without asking me questions?
- [ ] Could an auditor verify compliance from this six months from now?
- [ ] Could Claude Code generate a sensible playbook from this?

If any answer is no, keep refining.
