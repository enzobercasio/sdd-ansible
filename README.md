# Spec-Driven Ansible Development with Cursor

> A complete implementation kit for running spec-driven Ansible playbook development using Cursor as the AI development partner.

## What This Is

This repository scaffolds a **spec-driven development (SDD) discipline** for Ansible automation, using **Cursor** as the AI coding partner.
The pattern is:

```
Human writes spec  →  Cursor reads spec  →  Cursor generates playbook + tests
                                ↓
                    ansible-lint + (Molecule) 
                                ↓
                               AAP
```

## Features

### Guided spec creation
Cursor walks you through each spec section interactively — one section at a time, one question at a time — before writing any file. Alternatively, say "draft it for me" and the agent produces a full draft for you to review. Either way, no code is generated until the spec is approved. The `@sdd-core` rule (always applied) governs this workflow.

### Three-layer spec hierarchy
Requirements are inherited in order: `BEST-PRACTICES-SPEC.md` (universal baseline) → `TEAM-<name>-overrides.md` (team conventions) → `USE-CASE-<x>-overrides.md` (domain-specific rules) → individual spec. Constraints defined once at a higher layer automatically apply to every playbook that inherits it. Conflicts are flagged and documented in the spec's Deviations table.

### Risk-tier scaled approvals
Every spec declares `risk_tier: low | medium | high`. Approval requirements scale accordingly — team lead only for low, adding security review for medium, adding CAB sign-off for high. The approval checklist lives inside the spec file itself, versioned in Git alongside the code it governs.

### Specialised Cursor rules
Cursor rules in `.cursor/rules/` handle distinct stages of the workflow. Invoke them with `@rule-name` in chat:
- **`@spec-reviewer`** — audits a spec for completeness, ambiguity, and testability before any code is written
- **`@playbook-author`** — generates lint-clean, traceable playbooks and roles from an approved spec
- **`@test-author`** — produces Molecule scenarios mapped to spec requirements (optional)
- **`@security-reviewer`** — reviews generated code for regulated-environment security posture with severity-graded findings
- **`@tutor`** — CoE-aware onboarding rule that teaches SDD concepts using real repo files, at the learner's pace (read-only)

The **`@sdd-core`** rule is always active (`alwaysApply: true`) and defines the core SDD workflow, Definition of Done, and coding defaults.

### Full spec-to-code traceability
Every generated play declares `spec_id`, every role's `meta/main.yml` embeds `spec_id` and `spec_version`, and every task that implements a requirement is tagged `req:REQ-N`. The CI script `check-spec-coverage.sh` enforces this as a pre-merge gate — PRs that break traceability are blocked.

### SDD-aware ansible-lint profile
The `.ansible-lint` configuration enforces a production-grade profile with additional rules aligned to spec requirements: FQCN module names, variable naming conventions, no-log on secrets, risky file permissions, and more. Every lint skip must be justified — unannotated skips are treated as technical debt.

### Execution Environment-first testing
`.vscode/settings.json` configures the VS Code Ansible extension to run all playbook executions and Molecule tests inside the AAP-supported RHEL 9 EE. Local test results match what AAP produces in production. Molecule testing is optional — recommended for `risk_tier: medium/high`.

### AAP-ready role READMEs
Every generated role README includes a complete AAP Usage section: job template field settings, a survey table mapped directly from spec §4 inputs, and an `aap job launch` CLI example. Testing instructions cover check-mode dry runs, `ansible-navigator` EE runs, and Molecule (where present).

### Plain-text audit trail
Every decision traces through Git: approved spec commit → playbook PR → AAP job execution, all in plain text, all auditable without additional tooling. Designed for regulated environments where auditability is a hard requirement.

---

## Repository Structure

```
sdd-ansible/
├── README.md
├── ansible.cfg
├── requirements.yml
├── .ansible-lint
├── .vscode/
│   └── settings.json
├── .cursor/
│   └── rules/
│       ├── sdd-core.mdc          (always applied)
│       ├── spec-reviewer.mdc
│       ├── playbook-author.mdc
│       ├── test-author.mdc
│       ├── security-reviewer.mdc
│       └── tutor.mdc
├── docs/
│   ├── 01-implementation-plan.md
│   ├── 02-how-to-guide.md
│   ├── 03-spec-authoring-guide.md
│   └── 04-cursor-prompting.md
├── specs/
│   ├── templates/
│   │   ├── BASE-SPEC-TEMPLATE.md
│   │   └── BEST-PRACTICES-SPEC.md
│   ├── examples/
│   │   ├── AUTO-2026-0042-rhel-patching.md
│   │   ├── AUTO-2026-0019-user-onboarding.md
│   │   └── AUTO-2026-0055-eda-disk-remediation.md
│   └── team-overrides/
│       ├── TEAM-PLATFORM-overrides.md
│       ├── TEAM-RHEL-overrides.md
│       ├── TEAM-AWS-overrides.md
│       ├── TEAM-WINDOWS-overrides.md
│       ├── TEAM-NETWORK-overrides.md
│       ├── USE-CASE-NETWORK-overrides.md
│       └── USE-CASE-EDA-overrides.md
├── ci/
│   └── check-spec-coverage.sh
└── examples/
    ├── playbooks/
    └── roles/
        └── <role_name>/
            ├── tasks/
            ├── defaults/
            ├── handlers/
            ├── meta/
            ├── templates/
            ├── README.md
            └── molecule/
                └── <scenario>/
                    ├── molecule.yml
                    ├── converge.yml
                    └── verify.yml
```

---

## Component Reference

### `.cursor/rules/` — Cursor rules

Rules are markdown files with frontmatter (`description`, `globs`, `alwaysApply`). Invoke specialised rules with `@rule-name` in Cursor chat.

**`sdd-core.mdc`** — Always applied. Defines your role (AI development partner, not YAML autocompleter), the three-layer spec hierarchy, the Definition of Done checklist, required code patterns (play headers, task tagging, role meta), coding defaults (FQCN, snake_case, loop syntax, secrets handling), spec creation protocol, and hard limits. Update this when your team adopts a new convention.

**`spec-reviewer.mdc`** — Reviews a spec for production readiness before any code is generated. Returns a structured verdict (`APPROVE`, `APPROVE-WITH-CHANGES`, or `REJECT`) with specific, actionable issues. Invoke with: `@spec-reviewer review specs/AUTO-YYYY-NNNN-*.md`.

**`playbook-author.mdc`** — Generates production-grade playbooks and roles from an approved spec. Will not start without `status: approved` in the spec frontmatter. Runs `ansible-lint` and self-audits against the Definition of Done.

**`test-author.mdc`** — Generates Molecule test scenarios from spec requirements (optional). Produces a coverage matrix mapping each `REQ-N` to scenarios and assertions.

**`security-reviewer.mdc`** — Reviews generated code for regulated-environment security posture. Returns severity-graded findings (`CRITICAL`/`HIGH`/`MEDIUM`/`LOW`) and a deployment verdict. Required for `risk_tier: medium/high` before merge.

**`tutor.mdc`** — CoE-aware onboarding for engineers new to Ansible or SDD. Teaches concepts using actual repo files. Read-only — does not write or modify files. Invoke with: `@tutor walk me through how spec-driven development works`.

---

### `docs/` — Human-readable guides

**`01-implementation-plan.md`** — An 8-week CoE rollout plan covering tool deployment, team onboarding, pilot automation, and steady-state operation. Use this to plan an org-wide SDD adoption.

**`02-how-to-guide.md`** — Day-to-day workflow reference. Covers the eight-step cycle (intent → spec → approval → generate → test → lint → PR → deploy), common workflow patterns (modifying existing playbooks, reverse-engineering legacy automation, bulk spec audits), and anti-patterns to avoid.

**`03-spec-authoring-guide.md`** — How to write good specs. Covers the EARS notation for requirements, the nine sections every spec must have, risk-tier guidance (what changes at `low` vs `medium` vs `high`), and common spec authoring mistakes.

**`04-cursor-prompting.md`** — Prompt patterns that produce better Cursor outputs in this repo. Covers how to start a session, how to invoke rules, how to drive iteration, and how to ask for self-audits.

---

### `specs/` — The specification layer

This is the source of truth for all automation behaviour. No code is generated without a spec. No spec is implemented without approval.

**`specs/templates/BEST-PRACTICES-SPEC.md`** — The universal baseline. Applied to every playbook regardless of team or use case. Defines universal requirements (`REQ-UNI-*`) covering: module naming (FQCN), variable naming (snake_case, role-prefixed), idempotency, secrets handling (no inline secrets, Vault or AAP credential injection only), privilege scoping (`become` at task level), error handling (`block`/`rescue`/`always`), audit logging (session-start and session-end records), and supply-chain controls (pinned collection versions). When a new universal constraint is agreed by the CoE, it goes here and automatically applies to all future generation.

**`specs/templates/BASE-SPEC-TEMPLATE.md`** — The blank spec form. Nine sections: §1 Intent (why this automation exists), §2 Scope (in/out lists), §3 Requirements (EARS notation, each atomic and testable), §4 Inputs (the AAP job template survey contract), §5 Acceptance Criteria (become `assert` tasks in Molecule `verify.yml`), §6 Failure Modes (required for medium/high risk), §7 Approvals (scaled to risk tier), plus a Deviations table for any justified departures from best practices. Copy this template to `specs/AUTO-YYYY-NNNN-<title>.md` to start a new spec.

**`specs/examples/`** — Three fully worked reference specs:
- `AUTO-2026-0019-user-onboarding.md` — low-risk, illustrates a straightforward provisioning spec with SSH key management
- `AUTO-2026-0042-rhel-patching.md` — medium-risk, illustrates maintenance window constraints, rolling batch requirements, and rollback documentation
- `AUTO-2026-0055-eda-disk-remediation.md` — EDA-triggered remediation, illustrates event-driven requirements and the `use_case: eda` override layering

**`specs/team-overrides/`** — Team and use-case override files. See the original README structure for details on each override.

---

### `ci/` — Continuous integration

**`check-spec-coverage.sh`** — Enforces all four SDD invariants as a pre-merge CI gate:
1. Every playbook declares `spec_id`
2. Every role `meta/main.yml` references `spec_id`
3. Every `spec_id` used in code resolves to a spec file with `status: approved` or `in-use`
4. Every approved spec has at least one Molecule scenario (warning, not blocking — allows time to add tests after spec approval)

Run as part of your pipeline to prevent non-compliant PRs from merging. Exits non-zero on any blocking violation.

---

### `examples/` — Working reference implementation

**`examples/playbooks/`** — Generated playbooks linked to their specs via `spec_id`. Use `onboard_users.yml` as the canonical example of a properly structured wrapper playbook: spec header comment, `spec_id` var, audit pre/post tasks, and role invocation.

**`examples/roles/<role_name>/`** — Generated role structure with traceability tags, defaults, handlers, meta, templates, README, and optional Molecule scenarios.

## Quick Start (5 minutes)

```bash
# 1. Clone this scaffold into your automation repo
git clone <this-repo> sdd-ansible-scaffold
cp -r sdd-ansible-scaffold/{README.md,specs,.cursor,docs} your-automation-repo/

# 2. Open the repo in Cursor
# File → Open Folder → your-automation-repo

# 3. Try the canonical first prompt (in Cursor chat):
@tutor Walk me through how spec-driven development works in this repo.

# 4. Generate your first spec-driven playbook:
> Use the BASE-SPEC-TEMPLATE to draft a spec for automating RHEL package
> updates. Then @playbook-author generate the playbook and role structure
> that satisfy that spec. Lint everything before you finish.
```

## Key Concepts

### 1. The Spec Hierarchy

Three layers, applied in order of precedence (later overrides earlier):

```
BEST-PRACTICES-SPEC.md       (universal — applies to ALL playbooks)
        ↓
TEAM-<name>-overrides.md     (team-specific additions)
        ↓
USE-CASE-<x>-overrides.md    (use-case specific, e.g. EDA, network, security)
        ↓
<SPEC-ID>-<title>.md         (the actual playbook spec)
```

Cursor reads all four when generating code. The `@sdd-core` rule tells it how to layer them.

### 2. The Four Invariants

A spec-driven workflow must guarantee:

1. **Spec exists before code** — no playbook PR is approved without a referenced spec
2. **Spec is versioned and reviewed** — specs live in Git, go through PR review
3. **Code is traceable to spec** — every play, role, and task references a spec_id
4. *(Optional)* **Tests verify code against spec** — Molecule scenarios map to spec requirements; recommended for `risk_tier: medium/high`


## Workflows

Six patterns cover most day-to-day work. Full prompts and step-by-step detail for each are in [`docs/02-how-to-guide.md`](docs/02-how-to-guide.md).

| Workflow | When to use | Entry point |
|---|---|---|
| **Greenfield** | Net-new automation — no playbook exists yet | `> I need to automate X. Help me draft a spec.` |
| **Modify existing** | A requirement changes, a bug needs fixing, or a new input is added | `> Read spec AUTO-YYYY-NNNN, I need to add dry-run support.` |
| **Reverse-engineer legacy** | An undocumented playbook exists and needs a spec before it can be safely changed | `> Read this legacy playbook and produce a retrospective spec.` |
| **Spec drift investigation** | A job produced unexpected results — diagnose what diverged from the spec | `> Job logs are in /tmp/job-NNN.log. What diverged from the spec?` |
| **Bulk spec audit** | Compliance check — which specs are approved, which lack playbooks, which lack tests | `> Audit all specs/ and produce a compliance report.` |
| **Onboard new engineer** | First time in the repo — walk through one complete SDD cycle as a learning exercise | `@tutor Walk me through one complete spec-driven cycle using AUTO-YYYY-NNNN.` |

---

## Where to Go Next

- **New to SDD?** → `docs/02-how-to-guide.md`
- **Ready to roll out?** → `docs/01-implementation-plan.md`
- **Writing your first spec?** → `docs/03-spec-authoring-guide.md` + `specs/templates/BASE-SPEC-TEMPLATE.md`
- **Want better Cursor outputs?** → `docs/04-cursor-prompting.md`

---

## Note

This kit is designed for a CoE to publish, a CoP to consume, and teams to operate against.

The audit story is the differentiator: **every change traces from approved spec → reviewed PR → tested role → AAP-gated execution**, all in Git, all in plain text, all auditable.

Not all workflows have been tested. This framework is in progress.
