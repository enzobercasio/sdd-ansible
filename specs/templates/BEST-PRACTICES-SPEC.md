---
spec_id: BEST-PRACTICES
title: Universal Ansible Playbook Best Practices
status: approved
version: "4.0"
owner: automation-coe@company.com
risk_tier: governance
applies_to: all
created: 2026-01-15
last_reviewed: 2026-05-21
---

# Universal Ansible Best Practices

> **CoE base layer.** Every playbook in this repo must meet these rules unless an override spec explicitly documents a justified deviation.
>
> This document is the minimum standard a CoE needs to adapt — not the complete standard for any given team. Teams add domain-specific constraints via `TEAM-<name>-overrides.md`.

---

## §1 Intent

Every playbook must be: **correct** (does what its spec says), **idempotent** (safe to re-run), **secure** (no exposed secrets), **traceable** (linked to an approved spec), and **testable** (assertions prove it works).

---

## §2 Rules

### Code Structure

- **REQ-S1**: Use fully-qualified collection names (FQCN) for every module — `ansible.builtin.copy`, not `copy`. This ensures correct module resolution in any Execution Environment.
- **REQ-S2**: Variable names must be `snake_case` and prefixed with the role name — `webserver_port`, not `port`. Role-prefixed variables prevent shadowing when roles are composed.
- **REQ-S3**: Every play must declare `vars: { spec_id: "<ID>", spec_version: "<N.N>" }` for traceability.
- **REQ-S4**: Every task that implements a requirement must be tagged `req:<REQ-N>`. Tasks that do not implement a requirement (audit logging, pre-flight checks) must be tagged `req:infra`.
- **REQ-S5**: Use `loop:` with `loop_control.label:`; never `with_items:` or other deprecated `with_*` forms.
- **REQ-S6**: Play names must be descriptive and human-readable. Task names must begin with the REQ number they implement where applicable — e.g., `REQ-2 — Install packages in rolling batches`.
- **REQ-S7**: `any_errors_fatal: true` is the default for plays that apply destructive or partially-reversible changes. Explicitly override with justification if parallel failure isolation is required.

### Idempotency & Safety

- **REQ-I1**: Every task must be idempotent — a second run with the same inputs produces zero changes.
- **REQ-I2**: `command:` and `shell:` tasks must include `creates:`, `removes:`, or an explicit `changed_when: false` / `changed_when: <condition>`. Prefer native modules whenever one exists. If a module equivalent does not exist, document why in a task comment.
- **REQ-I3**: All playbooks must run cleanly under `--check` mode. Tasks that cannot support check mode must declare `check_mode: false` with an inline comment explaining the technical reason.
- **REQ-I4**: Risky operations (partial-effect risk — file writes, service restarts, package changes) must be wrapped in `block:` / `rescue:` / `always:`. The `rescue:` block must attempt recovery or emit a clear failure message. The `always:` block must clean up temporary state.
- **REQ-I5**: Handlers must be named consistently: `Restart <service>`, `Reload <service>`, `Enable <service>`. Handlers are only triggered at the end of a play — document this expectation in the role README if the ordering is significant.

### Input Validation

- **REQ-V1**: Required variables must be validated at play start using `ansible.builtin.assert`. Validation tasks must run before any state-changing task.
- **REQ-V2**: Variable types must be enforced — use `is string`, `is number`, `is boolean`, `is iterable` Jinja2 tests in assertions. Coercion failures are easier to diagnose at validation time than mid-task.
- **REQ-V3**: Variables with enumerated valid values must be validated against the allowed list: `assert: that: var in ['dev', 'staging', 'prod']`.
- **REQ-V4**: Path variables that will be used in `shell:` or `command:` tasks must be validated against an allowlist or regex before use. Unvalidated paths are an injection vector.
- **REQ-V5**: Every variable declared in `defaults/main.yml` must have a safe default or be explicitly undefined with `""` and validated as required by REQ-V1.

### Secrets & Privilege

- **REQ-P1**: Secrets (passwords, tokens, API keys, certificates) must **never** appear in source code, `defaults/main.yml`, `vars/`, example values, or Ansible inventory files. Retrieve via Ansible Vault or AAP credential injection only.
- **REQ-P2**: `become: true` must be applied at task level only, not playbook-wide, unless every task in the play truly requires elevation. Over-privileged plays are a lateral-movement risk.
- **REQ-P3**: Tasks that handle secrets in parameters, register output, or `debug:` output must declare `no_log: true`. This applies to any task whose output could expose a secret in AAP job logs.
- **REQ-P4**: SSH private keys, API tokens, and cloud credentials must be injected at runtime via AAP Machine Credentials, Custom Credentials, or Vault lookups. Embedding credential paths in playbook vars is forbidden.
- **REQ-P5**: `validate_certs: true` is mandatory for all `ansible.builtin.uri:`, `ansible.builtin.get_url:`, and similar HTTP tasks in staging and production. Setting `validate_certs: false` requires a documented justification in the spec's Deviations table and is automatically blocked by `ansible-lint` in the production profile.

### Error Handling & Rollback

- **REQ-E1**: Every play targeting `risk_tier: medium` or `risk_tier: high` hosts must define an explicit rollback or recovery procedure in the spec (§6 Failure Modes). The playbook must reference this procedure in a task comment or role README.
- **REQ-E2**: `ignore_errors: true` is forbidden unless accompanied by an explicit `failed_when:` condition that narrows the suppressed failure, and a documented recovery path in the spec.
- **REQ-E3**: Long-running tasks (package installs, filesystem operations, data migrations) must implement a timeout via `async:` and `poll:` to prevent hung jobs blocking AAP workers.
- **REQ-E4**: Pre-flight checks must run in a dedicated `pre_tasks:` block. If any pre-flight check fails, the play must exit cleanly without having made any changes.

### Logging & Traceability

- **REQ-L1**: Every playbook must log a session-start message before any state-changing task, containing: `spec_id`, `spec_version`, `ansible_user`, target group name, and UTC timestamp (`{{ now(utc=true, fmt='%Y-%m-%dT%H:%M:%SZ') }}`).
- **REQ-L2**: Every playbook must log a session-end message in an `always:` block, containing the same fields plus final job status (passed / failed / changed counts where available).
- **REQ-L3**: State-changing tasks must emit an audit message describing what changed, on which target, and the UTC timestamp. Use `ansible.builtin.debug:` or a dedicated logging role.
- **REQ-L4**: Sensitive data must be redacted from all log output (`no_log: true` on the task). Never log secrets — even in `FAILED` task output.
- **REQ-L5**: Audit logs from `risk_tier: medium` and `risk_tier: high` playbooks must be forwarded to a central log aggregator (Splunk, Elastic, or equivalent) configured by the team override. The BEST-PRACTICES layer does not mandate a specific aggregator — teams provide that via `TEAM-<name>-overrides.md`.

### Supply Chain & Collections

- **REQ-C1**: All collections used in a playbook must be declared with an explicit minimum version in `requirements.yml`. Pinned versions are preferred for `risk_tier: high`.
- **REQ-C2**: Collections must be sourced from Red Hat Automation Hub (console.redhat.com) or the team's approved Automation Hub instance. Community Galaxy collections are only permitted if explicitly approved in the team override and pinned to a specific version.
- **REQ-C3**: Execution Environments (EEs) used in production must be built from Red Hat-supported base images (`registry.redhat.io/ansible-automation-platform/ee-supported-rhel9:latest` or equivalent) and tracked in a `execution-environment.yml` in the repo. Custom EEs must be rebuilt when base image CVEs are patched.
- **REQ-C4**: Roles sourced from Ansible Galaxy must not be used in `risk_tier: medium` or `risk_tier: high` playbooks unless reviewed, forked into the team repo, and treated as first-party code.

### Testing

- **REQ-T1**: `ansible-lint` using the `production` profile must pass with zero violations before any merge. Skipped rules must be annotated inline with a justification (`# noqa: rule-id — reason`).
- **REQ-T2**: `ansible-playbook --syntax-check` must pass for every playbook in the repo.
- **REQ-T3**: For `risk_tier: medium` and `risk_tier: high` playbooks, at least one Molecule scenario must cover the happy path. Each `shall` requirement in the spec must map to at least one `assert` task in `verify.yml`.
- **REQ-T4**: Molecule tests must run inside the same Execution Environment used in production. Configure the VS Code Ansible extension (`.vscode/settings.json`) to point at the production EE — do not test against the local Python environment.
- **REQ-T5**: Idempotency is verified by running the Molecule `converge` step twice and asserting zero changes on the second run. Molecule's built-in idempotency check (`molecule idempotence`) satisfies this requirement.

### AAP Integration

- **REQ-A1**: Every playbook designed for AAP execution must document a complete `AAP Usage` section in the role README: job template settings, survey fields mapped from spec §4, and a sample `aap job launch` CLI command.
- **REQ-A2**: AAP survey fields must be validated at the AAP level (required vs optional, type, default) — these must match the `defaults/main.yml` variable definitions. Mismatches between survey and defaults cause silent runtime failures.
- **REQ-A3**: Playbooks intended for unattended (scheduled) AAP execution must implement guard conditions — confirm target hosts are in the expected state before proceeding. Do not assume the previous run succeeded.
- **REQ-A4**: `risk_tier: high` playbooks must use an AAP Workflow with an approval node before the job template executes. Document the approval node configuration in the role README.
- **REQ-A5**: Job templates must set `LIMIT` to a specific group or host pattern — never run against `all` in production. The target group must be validated against a known-good list by a pre-flight `assert`.

---

## §3 Always-Forbidden Patterns

No override makes these acceptable without CoE sign-off and a documented justification in the spec's Deviations table:

- ❌ Hardcoded passwords, API keys, certificates, or any secret in source code
- ❌ `ignore_errors: true` without an explicit `failed_when:` and a documented recovery plan
- ❌ `validate_certs: false` in staging or production without a documented justification
- ❌ `become: true` at playbook level when only a subset of tasks require elevation
- ❌ `risk_tier: medium` or `risk_tier: high` changes without a rollback step in the spec
- ❌ `with_items:`, `with_dict:`, `with_subelements:`, or any other deprecated `with_*` loop syntax
- ❌ `any_errors_fatal: false` in plays with destructive tasks, without justification
- ❌ Inline variable values that would cause `ansible-lint` to emit a `no-log-password` or `risky-file-permissions` violation

---

## §4 Override Mechanism

A team or spec may override any rule in §2 if:

1. The deviation is documented in the spec's **§7 Approvals → Deviations table**.
2. The justification is technical ("module X cannot guarantee idempotency"), not stylistic.
3. The override is accepted by the appropriate approver (team lead for `risk_tier: low`, CoE for `risk_tier: medium/high`).

**Precedence**: individual spec > use-case override > team override > this document.

---

## §5 Compliance

Rules are enforced by:

| Mechanism | Rules Covered |
|---|---|
| `ansible-lint` production profile | REQ-S1, REQ-S2, REQ-I2, REQ-P2, REQ-P3, REQ-P5, REQ-T1 |
| `ansible-playbook --syntax-check` | REQ-T2 |
| `ci/check-spec-coverage.sh` | REQ-S3, REQ-S4 |
| Spec review (`@spec-reviewer` rule) | REQ-I*, REQ-V*, REQ-P*, REQ-L*, REQ-E* |
| `@security-reviewer` rule | REQ-P*, REQ-C*, REQ-E* |
| Molecule idempotency scenario | REQ-I1, REQ-T5 |
| Periodic CoE audits | All |

---

## §6 References

All references point to Red Hat official documentation. Verify the version tag matches your AAP deployment.

| Reference | URL |
|---|---|
| Red Hat Ansible Automation Platform 2.5 Documentation | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/ |
| AAP Automation Controller User Guide | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/automation_controller_user_guide/ |
| AAP Automation Controller Administration Guide | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/automation_controller_administration_guide/ |
| Using Content Collections with AAP | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/using_content_collections_with_ansible_automation_platform/ |
| Building Custom Execution Environments | https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.5/html/creating_and_consuming_execution_environments/ |
| ansible-lint Rules Reference | https://ansible.readthedocs.io/projects/lint/en/latest/rules/ |
| Molecule Documentation | https://ansible.readthedocs.io/projects/molecule/ |
| ansible.builtin Collection Index | https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ |
| Ansible Best Practices (upstream) | https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html |
| EARS Requirements Notation | https://www.iaria.org/conferences2013/filesICCGI13/ICCGI_2013_Tutorial_Mavin.pdf |
| Red Hat Automation Hub | https://console.redhat.com/ansible/automation-hub |
