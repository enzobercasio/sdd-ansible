# Spec-Driven Ansible Development with Claude Code

> A complete implementation kit for running spec-driven Ansible playbook development using Claude Code as the AI development partner.

## What This Is

This repository scaffolds a **spec-driven development (SDD) discipline** for Ansible automation, using **Claude Code** as the AI coding partner instead of Spec Kit, Kiro, or other opinionated SDD tools.

The pattern is:

```
Human writes spec  →  Claude Code reads spec  →  Claude generates playbook + tests
                                ↓
            ansible-lint + Molecule + AAP enforce the spec
                                ↓
                EDA validates spec compliance at runtime
```

## Why Claude Code (vs. Lightspeed, Spec Kit, Kiro)

| Tool | Best For | Limitation |
|---|---|---|
| **Lightspeed/WCA** | Fast YAML synthesis from short prompts | Single-shot, no spec lifecycle |
| **Spec Kit** | Greenfield software projects | Opinionated; weak Ansible-native testing |
| **Kiro** | Agentic IDE workflows | Vendor-locked spec format |
| **Claude Code** | Long-context spec reasoning, agentic file ops, MCP integration | Requires team discipline to enforce |

**Claude Code wins for enterprise Ansible** because:

1. It reads and reasons over the **entire spec + repo context** in one session.
2. It executes **agentic workflows** — generate playbook, write Molecule tests, run ansible-lint, fix violations, commit.
3. **CLAUDE.md** makes your spec methodology discoverable and self-enforcing.
4. **Sub-agents** can specialise (spec-reviewer, playbook-author, test-author, security-reviewer).
5. It **integrates with your existing tooling** (Git, AAP API, Jira, Slack via MCP) — no parallel toolchain.

## Repository Structure

```
sdd-ansible/
├── README.md                          ← You are here
├── CLAUDE.md                          ← Project memory: tells Claude Code how to work here
├── ansible.cfg                        ← Sets roles_path = examples/roles
├── requirements.yml                   ← Ansible Galaxy collection dependencies
├── .ansible-lint                      ← SDD-aware lint profile
├── docs/
│   ├── 01-implementation-plan.md      ← 8-week rollout plan
│   ├── 02-how-to-guide.md             ← Step-by-step workflow
│   ├── 03-spec-authoring-guide.md     ← How to write good specs
│   └── 04-claude-code-prompting.md    ← Prompt patterns for SDD
├── specs/
│   ├── templates/
│   │   ├── BASE-SPEC-TEMPLATE.md      ← General template (any use case)
│   │   └── BEST-PRACTICES-SPEC.md     ← Universal Ansible best practices spec
│   ├── examples/
│   │   ├── AUTO-2026-0042-rhel-patching.md
│   │   ├── AUTO-2026-0019-user-onboarding.md
│   │   └── AUTO-2026-0055-eda-disk-remediation.md
│   └── team-overrides/
│       ├── TEAM-PLATFORM-overrides.md ← Platform team additions
│       ├── USE-CASE-NETWORK-overrides.md ← Network use-case additions
│       └── USE-CASE-EDA-overrides.md  ← EDA use-case additions
├── .claude/
│   └── agents/
│       ├── spec-reviewer.md           ← Sub-agent: reviews specs for completeness
│       ├── playbook-author.md         ← Sub-agent: generates playbooks from specs
│       ├── test-author.md             ← Sub-agent: generates Molecule tests
│       └── security-reviewer.md       ← Sub-agent: regulated-env security review
├── ci/
│   └── check-spec-coverage.sh        ← CI script: validates spec traceability
└── examples/
    ├── playbooks/                     ← Generated playbooks (linked to specs)
    └── roles/                         ← Generated roles (one per spec)
```

## Quick Start (5 minutes)

```bash
# 1. Clone this scaffold into your automation repo
git clone <this-repo> sdd-ansible-scaffold
cp -r sdd-ansible-scaffold/{CLAUDE.md,specs,.claude,docs} your-automation-repo/

# 2. Install Claude Code (if not already)
npm install -g @anthropic-ai/claude-code

# 3. Open Claude Code in your automation repo
cd your-automation-repo
claude

# 4. Try the canonical first prompt:
> Read CLAUDE.md, then walk me through how spec-driven development works in this repo.

# 5. Generate your first spec-driven playbook:
> Use the BASE-SPEC-TEMPLATE to draft a spec for automating RHEL package
> updates. Then generate the playbook, role structure, and Molecule tests
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

Claude Code reads all four when generating code. The CLAUDE.md tells it how to layer them.

### 2. The Four Invariants

A spec-driven workflow must guarantee:

1. **Spec exists before code** — no playbook PR is approved without a referenced spec
2. **Spec is versioned and reviewed** — specs live in Git, go through PR review
3. **Code is traceable to spec** — every play, role, and task references a spec_id
4. **Tests verify code against spec** — Molecule scenarios map to spec requirements

### 3. The Closed Loop

```
Spec  →  Playbook  →  Lint  →  Molecule  →  AAP execution  →  EDA validation  →  Outcome metric
  ↑                                                                                       │
  └───────────────────────  Drift detected → spec amendment ←───────────────────────────┘
```

## Where to Go Next

- **New to SDD?** → `docs/02-how-to-guide.md`
- **Ready to roll out?** → `docs/01-implementation-plan.md`
- **Writing your first spec?** → `docs/03-spec-authoring-guide.md` + `specs/templates/BASE-SPEC-TEMPLATE.md`
- **Want better Claude Code outputs?** → `docs/04-claude-code-prompting.md`

---

## Note

This kit is designed for a CoE to publish, a CoP to consume, and an AAP customer to operate against — all without licensing additional tooling beyond Claude Code and existing AAP entitlements.

The audit story is the differentiator: **every change traces from approved spec → reviewed PR → tested role → AAP-gated execution → EDA-validated outcome**, all in Git, all in plain text, all auditable.
