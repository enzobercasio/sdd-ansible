---
spec_id: BEST-PRACTICES
title: Universal Ansible Playbook Best Practices
status: approved
version: "3.0"
owner: automation-coe@company.com
risk_tier: governance
applies_to: all
created: 2026-01-15
last_reviewed: 2026-05-19
---

# Universal Ansible Best Practices

> **CoE base layer.** Every playbook in this repo must meet these rules unless an override spec explicitly documents a justified deviation.

---

## §1 Intent

Every playbook must be: **correct** (does what its spec says), **idempotent** (safe to re-run), **secure** (no exposed secrets), **traceable** (linked to an approved spec), and **testable** (assertions prove it works).

---

## §2 Rules

### Code Structure

- **REQ-S1**: Use fully-qualified collection names for every module — `ansible.builtin.copy`, not `copy`.
- **REQ-S2**: Variable names must be `snake_case` and prefixed with the role name — `webserver_port`, not `port`.
- **REQ-S3**: Every play must declare `vars: { spec_id: "<ID>" }` for traceability.
- **REQ-S4**: Every task that implements a requirement must be tagged `req:<REQ-N>`.
- **REQ-S5**: Use `loop:` with `loop_control.label:`; never `with_items:` or other `with_*` forms.

### Idempotency & Safety

- **REQ-I1**: Every task must be idempotent — a second run with the same inputs produces zero changes.
- **REQ-I2**: `command:` and `shell:` tasks must include `creates:`, `removes:`, or an explicit `changed_when:`. Prefer native modules whenever one exists.
- **REQ-I3**: All playbooks must run cleanly under `--check` mode. Tasks that cannot declare `check_mode: false` with a comment explaining why.
- **REQ-I4**: Risky operations (partial-effect risk) must be wrapped in `block:` / `rescue:` / `always:`.

### Secrets & Privilege

- **REQ-P1**: Secrets (passwords, tokens, keys) must **never** appear in source code, defaults, or example values. Retrieve via Ansible Vault or AAP credential injection only.
- **REQ-P2**: `become: true` must be applied at task level only, not playbook-wide, unless every task truly requires elevation.
- **REQ-P3**: Tasks that handle secrets in parameters or output must declare `no_log: true`.

### Logging & Traceability

- **REQ-L1**: Every playbook must log a session-start and session-end message containing `spec_id`, `spec_version`, executor, target group, and ISO-8601 timestamp.
- **REQ-L2**: State-changing tasks must emit an audit message describing what changed, on which target, and when.
- **REQ-L3**: Sensitive data must be redacted from logs (`no_log: true`).

### Testing

- **REQ-T1**: Every role must have at least one Molecule scenario covering its happy path.
- **REQ-T2**: Every `shall` requirement in the spec must map to at least one `assert` task in a Molecule `verify.yml`.
- **REQ-T3**: `ansible-lint` and `ansible-playbook --syntax-check` must pass before any merge.

---

## §3 Always-Forbidden Patterns

No override makes these acceptable without CoE sign-off and a documented justification in the spec:

- ❌ Hardcoded passwords, API keys, or secrets anywhere in code
- ❌ `ignore_errors: true` without a `failed_when:` condition and a documented recovery plan
- ❌ `validate_certs: false` without a documented justification
- ❌ `become: true` at playbook level when only one task needs it
- ❌ Production changes without a rollback step documented in the spec

---

## §4 Override Mechanism

A team or spec may override any rule in §2 if:

1. The deviation is documented in the spec's **§6 Approvals** section.
2. The justification is technical ("module X cannot guarantee idempotency"), not stylistic.
3. The override is accepted by the appropriate approver (team lead for low risk, CoE for medium/high).

**Precedence**: spec > use-case override > team override > this document.

---

## §5 Compliance

Rules are enforced by:

- `ansible-lint` (§3 REQ-S*, REQ-I2 automatically)
- `ci/check-spec-coverage.sh` (REQ-S3, REQ-S4)
- Spec review (REQ-I*, REQ-P*, REQ-L*)
- Periodic CoE audits
