# Spec-Driven Ansible Development with Claude Code

> A complete implementation kit for running spec-driven Ansible playbook development using Claude Code as the AI development partner.

## What This Is

This repository scaffolds a **spec-driven development (SDD) discipline** for Ansible automation, using **Claude Code** as the AI coding partner.
The pattern is:

```
Human writes spec  →  Claude Code reads spec  →  Claude generates playbook + tests
                                ↓
                    ansible-lint + (Molecule) 
                                ↓
                               AAP
```

## Features

### Guided spec creation
Claude Code walks you through each spec section interactively — one section at a time, one question at a time — before writing any file. Alternatively, say "draft it for me" and Claude produces a full draft for you to review. Either way, no code is generated until the spec is approved.

### Three-layer spec hierarchy
Requirements are inherited in order: `BEST-PRACTICES-SPEC.md` (universal baseline) → `TEAM-<name>-overrides.md` (team conventions) → `USE-CASE-<x>-overrides.md` (domain-specific rules) → individual spec. Constraints defined once at a higher layer automatically apply to every playbook that inherits it. Conflicts are flagged and documented in the spec's Deviations table.

### Spec-gated approvals
Every spec includes an approval checklist signed off by the team lead before code is generated. The checklist lives inside the spec file itself, versioned in Git alongside the code it governs.

### Five specialised sub-agents
Claude Code sub-agents handle distinct stages of the workflow:
- **`spec-reviewer`** — audits a spec for completeness, ambiguity, and testability before any code is written
- **`playbook-author`** — generates lint-clean, traceable playbooks and roles from an approved spec
- **`test-author`** — produces Molecule scenarios mapped to spec requirements (optional)
- **`security-reviewer`** — reviews generated code for regulated-environment security posture with severity-graded findings
- **`cac-author`** — generates `infra.controller_configuration`-compatible YAML (job templates + surveys) from an approved spec's §4 Inputs
- **`tutor`** — CoE-aware onboarding agent that teaches SDD concepts using real repo files, at the learner's pace

### Full spec-to-code traceability
Every generated play declares `spec_id`, every role's `meta/main.yml` embeds `spec_id` and `spec_version`, and every task that implements a requirement is tagged `req:REQ-N`. The CI script `check-spec-coverage.sh` enforces this as a pre-merge gate — PRs that break traceability are blocked.

### SDD-aware ansible-lint profile
The `.ansible-lint` configuration enforces a production-grade profile with additional rules aligned to spec requirements: FQCN module names, variable naming conventions, no-log on secrets, risky file permissions, and more. Every lint skip must be justified — unannotated skips are treated as technical debt.

### Execution Environment-first testing
`.vscode/settings.json` configures the VS Code Ansible extension to run all playbook executions and Molecule tests inside the AAP-supported RHEL 9 EE. Local test results match what AAP produces in production. Molecule testing is optional but recommended.

### AAP-ready role READMEs
Every generated role README includes a complete AAP Usage section: job template field settings, a survey table mapped directly from spec §4 inputs, and an `aap job launch` CLI example. Testing instructions cover check-mode dry runs, `ansible-navigator` EE runs, and Molecule (where present).

### Plain-text audit trail
Every decision traces through Git: approved spec commit → playbook PR → AAP job execution, all in plain text, all auditable without additional tooling. Designed for regulated environments where auditability is a hard requirement.

---

## Repository Structure

```
sdd-ansible/
├── README.md
├── CLAUDE.md
├── ansible.cfg
├── requirements.yml
├── .ansible-lint
├── .vscode/
│   └── settings.json
├── docs/
│   ├── 01-implementation-plan.md
│   ├── 02-how-to-guide.md
│   ├── 03-spec-authoring-guide.md
│   └── 04-claude-code-prompting.md
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
├── .claude/
│   └── agents/
│       ├── spec-reviewer.md
│       ├── playbook-author.md
│       ├── test-author.md
│       ├── security-reviewer.md
│       ├── cac-author.md
│       └── tutor.md
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

### Root configuration files

**`CLAUDE.md`** — Project memory for Claude Code. Read automatically at the start of every session. Defines your role (AI development partner, not YAML autocompleter), the three-layer spec hierarchy, the Definition of Done checklist, required code patterns (play headers, task tagging, role meta), coding defaults (FQCN, snake_case, loop syntax, secrets handling), and the four hard limits. This is the single file that makes the SDD discipline self-enforcing without manual reminders. Update it when your team adopts a new convention.

---

### `docs/` — Human-readable guides

**`01-implementation-plan.md`** — An 8-week CoE rollout plan covering tool deployment, team onboarding, pilot automation, and steady-state operation. Use this to plan an org-wide SDD adoption.

**`02-how-to-guide.md`** — Day-to-day workflow reference. Covers the eight-step cycle (intent → spec → approval → generate → test → lint → PR → deploy), common workflow patterns (modifying existing playbooks, reverse-engineering legacy automation, bulk spec audits), and anti-patterns to avoid.

**`03-spec-authoring-guide.md`** — How to write good specs. Covers the EARS notation for requirements, the nine sections every spec must have, risk-tier guidance (what changes at `low` vs `medium` vs `high`), and common spec authoring mistakes.

**`04-claude-code-prompting.md`** — Prompt patterns that produce better Claude Code outputs in this repo. Covers how to start a session, how to delegate to sub-agents, how to drive iteration, and how to ask for self-audits.

---

### `specs/` — The specification layer

This is the source of truth for all automation behaviour. No code is generated without a spec. No spec is implemented without approval.

**`specs/templates/BEST-PRACTICES-SPEC.md`** — The universal baseline. Applied to every playbook regardless of team or use case. Defines universal requirements (`REQ-UNI-*`) covering: module naming (FQCN), variable naming (snake_case, role-prefixed), idempotency, secrets handling (no inline secrets, Vault or AAP credential injection only), privilege scoping (`become` at task level), error handling (`block`/`rescue`/`always`), audit logging (session-start and session-end records), and supply-chain controls (pinned collection versions). When a new universal constraint is agreed by the CoE, it goes here and automatically applies to all future generation.

**`specs/templates/BASE-SPEC-TEMPLATE.md`** — The blank spec form. Nine sections: §1 Intent (why this automation exists), §2 Scope (in/out lists), §3 Requirements (EARS notation, each atomic and testable), §4 Inputs (the AAP job template survey contract), §5 Acceptance Criteria (become `assert` tasks in Molecule `verify.yml`), §6 Failure Modes (required for medium/high risk), §7 Approvals (scaled to risk tier), plus a Deviations table for any justified departures from best practices. Copy this template to `specs/AUTO-YYYY-NNNN-<title>.md` to start a new spec.

**`specs/examples/`** — Three fully worked reference specs:
- `AUTO-2026-0019-user-onboarding.md` — low-risk, illustrates a straightforward provisioning spec with SSH key management
- `AUTO-2026-0042-rhel-patching.md` — medium-risk, illustrates maintenance window constraints, rolling batch requirements, and rollback documentation
- `AUTO-2026-0055-eda-disk-remediation.md` — EDA-triggered remediation, illustrates event-driven requirements and the `use_case: eda` override layering

**`specs/team-overrides/TEAM-PLATFORM-overrides.md`** — Platform team additions that layer on top of `BEST-PRACTICES-SPEC.md` for any spec declaring `team: platform`. Defines platform-specific secrets handling (HashiCorp Vault KV2, AppRole auth), CMDB integration, network policies, and SIEM integration requirements.

**`specs/team-overrides/TEAM-RHEL-overrides.md`** — Rules for RHEL-focused teams (`team: rhel`). Covers: `dnf`/`dnf5` package management, RHEL System Roles (`redhat.rhel_system_roles`) as the preferred implementation vehicle for 12+ common functions (SELinux, firewall, timesync, networking, storage, crypto policy), SELinux enforcement requirements, subscription management via `rhc`, and FIPS/cryptographic policy handling. References Red Hat RHEL 9 official documentation throughout.

**`specs/team-overrides/TEAM-AWS-overrides.md`** — Rules for AWS automation teams (`team: aws`). Covers: IAM credential injection (no hardcoded keys), mandatory resource tagging (spec_id, managed_by, environment), EC2 dynamic inventory requirements, resource deletion guards, network security group constraints, IaC boundary rules (no modifying Terraform/CFN-managed resources), and RDS snapshot requirements before deletion. References `amazon.aws` certified collection documentation.

**`specs/team-overrides/TEAM-WINDOWS-overrides.md`** — Rules for Windows automation teams (`team: windows`). Covers: WinRM vs SSH transport selection, `ansible.windows` module usage over legacy `win_*` forms, module selection table for 15 common Windows functions, `become_method: runas` for privilege, Chocolatey and Windows Update management, registry handling constraints, and certificate store operations. References `ansible.windows` official collection documentation.

**`specs/team-overrides/TEAM-NETWORK-overrides.md`** — Rules for network device automation teams (`team: network`). Covers: connection plugin selection per OS/vendor, mandatory pre-change configuration backup, commit-confirmation patterns (Junos confirmed-commit, IOS-XR commit confirmed), change window enforcement, serial execution (no parallel changes to network devices), resource modules over raw CLI push, NETCONF/httpapi conventions, and idempotency challenges unique to network devices. References `ansible.netcommon` and vendor collection documentation.

**`specs/team-overrides/USE-CASE-NETWORK-overrides.md`** and **`USE-CASE-EDA-overrides.md`** — Use-case overlays for automations that declare `use_case: network` or `use_case: eda`. Capture constraints specific to network device automation (connection plugins, idempotency challenges, rollback complexity) and EDA-triggered automation (event validation, replay-attack prevention, rate limiting) respectively.

---

### `.claude/agents/` — Claude Code sub-agents

Sub-agents are specialised Claude Code contexts invoked by name for well-defined tasks. Each is a markdown file with a frontmatter declaring its name, description, and permitted tools.

**`spec-reviewer.md`** — Reviews a spec for production readiness before any code is generated. Reads the full spec hierarchy (BEST-PRACTICES + applicable overrides + the spec itself) and evaluates completeness, requirement quality, hierarchy alignment, and testability. Returns a structured verdict (`APPROVE`, `APPROVE-WITH-CHANGES`, or `REJECT`) with specific, actionable issues. Invoke with: `> Use the spec-reviewer sub-agent to review specs/AUTO-YYYY-NNNN-*.md`.

**`playbook-author.md`** — Generates production-grade playbooks and roles from an approved spec. Will not start without `status: approved` in the spec frontmatter. Reads the full spec hierarchy, plans its output, waits for user approval of the plan, then generates: `tasks/main.yml`, `defaults/main.yml`, `handlers/main.yml`, `meta/main.yml`, `README.md`, and the wrapper playbook. Runs `ansible-lint` before finishing and produces a self-audit against the Definition of Done checklist.

**`test-author.md`** — Generates Molecule test scenarios from spec requirements. Molecule testing is optional; invoke this agent when you want test coverage. Produces a coverage matrix mapping each `REQ-N` to a scenario and assertion, waits for user approval, then generates `molecule.yml`, `converge.yml`, and `verify.yml` for each scenario. Includes positive (happy-path), negative ("shall refuse"/"shall not"), and idempotency scenarios. All tests run inside the configured EE via the VS Code Ansible extension.

**`security-reviewer.md`** — Reviews generated code for regulated-environment security posture.

**`cac-author.md`** — Generates `infra.controller_configuration`-compatible YAML for AAP job templates and surveys from an approved spec. Will not start without `status: approved`. Cross-checks every survey field against `defaults/main.yml` to enforce REQ-A2 (type and default alignment). Outputs to `aap_config/job_templates/`. Invoke with: `> Use the cac-author sub-agent to generate AAP config for AUTO-YYYY-NNNN. Project: "<project>", inventory: "<inventory>", credential: "<cred>"`.

**`tutor.md`** — CoE-aware onboarding agent for engineers new to Ansible or SDD. Teaches concepts using the actual files in this repo as examples, explains the "why" behind every rule, and walks through real specs and roles at the learner's pace. Does not write or modify any files. Invoke with: `> Use the tutor sub-agent to walk me through how spec-driven development works.` Covers secrets handling, privilege management, input validation, network security, audit logging, supply-chain hygiene, and a structured threat model (compromised exec env, compromised credentials, replay attacks, lateral movement, data exfiltration). Returns severity-graded findings (`CRITICAL`/`HIGH`/`MEDIUM`/`LOW`) and a deployment verdict.

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

**`examples/roles/<role_name>/`** — Generated role structure. Each role contains:
- `tasks/main.yml` — tasks tagged with `req:REQ-N` for traceability
- `defaults/main.yml` — all variables from the spec §4 input contract
- `handlers/main.yml` — named handlers for state changes requiring restarts
- `meta/main.yml` — `spec_id` and `spec_version` in `galaxy_info` for machine-readable traceability
- `templates/` — Jinja2 templates referenced by tasks
- `README.md` — links back to the spec, variable table, testing steps (check mode, ansible-navigator, Molecule), and AAP usage (job template settings, survey fields, CLI launch command)
- `molecule/<scenario>/` — one scenario per major requirement group, each containing `molecule.yml` (EE-backed provisioner), `converge.yml` (applies the role), and `verify.yml` (assertions tied to `REQ-N` tags)

## Quick Start (5 minutes)

```bash
# 1. Clone this scaffold into your automation repo
git clone <this-repo> sdd-ansible-scaffold
cp -r sdd-ansible-scaffold/{README.md,CLAUDE.md,specs,.claude,docs} your-automation-repo/

# 2. Install Claude Code (if not already)
npm install -g @anthropic-ai/claude-code

# 3. Open Claude Code in your automation repo
cd your-automation-repo
claude

# 4. Try the canonical first prompt:
> Read CLAUDE.md, then walk me through how spec-driven development works in this repo.

# 5. Generate your first spec-driven playbook:
> Use the BASE-SPEC-TEMPLATE to draft a spec for automating RHEL package
> updates. Then generate the playbook and role structure that satisfy that
> spec. Lint everything before you finish.
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

Claude Code reads all four when generating code. The CLAUDE.md tells it how to layer them.

### 2. The Four Invariants

A spec-driven workflow must guarantee:

1. **Spec exists before code** — no playbook PR is approved without a referenced spec
2. **Spec is versioned and reviewed** — specs live in Git, go through PR review
3. **Code is traceable to spec** — every play, role, and task references a spec_id
4. *(Optional)* **Tests verify code against spec** — Molecule scenarios map to spec requirements; recommended


## Workflows

Six patterns cover most day-to-day work. Full prompts and step-by-step detail for each are in [`docs/02-how-to-guide.md`](docs/02-how-to-guide.md).

| Workflow | When to use | Entry point |
|---|---|---|
| **Greenfield** | Net-new automation — no playbook exists yet | `> I need to automate X. Help me draft a spec.` |
| **Modify existing** | A requirement changes, a bug needs fixing, or a new input is added | `> Read spec AUTO-YYYY-NNNN, I need to add dry-run support.` |
| **Reverse-engineer legacy** | An undocumented playbook exists and needs a spec before it can be safely changed | `> Read this legacy playbook and produce a retrospective spec.` |
| **Spec drift investigation** | A job produced unexpected results — diagnose what diverged from the spec | `> Job logs are in /tmp/job-NNN.log. What diverged from the spec?` |
| **Bulk spec audit** | Compliance check — which specs are approved, which lack playbooks, which lack tests | `> Audit all specs/ and produce a compliance report.` |
| **Onboard new engineer** | First time in the repo — walk through one complete SDD cycle as a learning exercise | `> Walk me through one complete spec-driven cycle using AUTO-YYYY-NNNN.` |

---

## Where to Go Next

- **New to SDD?** → `docs/02-how-to-guide.md`
- **Ready to roll out?** → `docs/01-implementation-plan.md`
- **Writing your first spec?** → `docs/03-spec-authoring-guide.md` + `specs/templates/BASE-SPEC-TEMPLATE.md`
- **Want better Claude Code outputs?** → `docs/04-claude-code-prompting.md`

---

## Note

This kit is designed for a CoE to publish, a CoP to consume, and teams to operate against.

The audit story is the differentiator: **every change traces from approved spec → reviewed PR → tested role → AAP-gated execution**, all in Git, all in plain text, all auditable.

Not all workflows have been tested. This framework is in progress.
