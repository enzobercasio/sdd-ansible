# SDD Kit — Changelog

All changes to this kit are recorded here. Updated automatically at the end of every session where files were modified.

Format: `[version/date] — commit hash (if committed) — summary`

---

## [2026-07-01] — Uncommitted (session 3)

### Added
- `.github/workflows/sdd-validate.yml` — GitHub Actions pre-merge workflow with three jobs: SDD invariants check (blocking), ansible-lint (blocking), Molecule tests (runs after both pass; skips gracefully if no scenarios exist)

---

## [2026-07-01] — Uncommitted (session 2)

### Added
- `playbooks/.gitkeep` — seeded top-level `playbooks/` directory as the canonical output location for generated playbooks
- `roles/.gitkeep` — seeded top-level `roles/` directory as the canonical output location for generated roles
- `CLAUDE.md` — new **Output Folder Conventions** section pinning all generated artifacts to explicit top-level paths (`specs/`, `playbooks/`, `roles/`, `aap_config/`)

### Changed
- `.claude/agents/playbook-author.md` — fixed three `examples/playbooks/` and `examples/roles/` references in the role README template (Sub-sections A, B, C and AAP Usage) to use `playbooks/` and `roles/` instead

---

## [2026-07-01] — Uncommitted (session 1)

### Added
- `specs/templates/BASE-SPEC-TEMPLATE.md` — `version` and `last_modified` fields in spec frontmatter
- `specs/templates/BASE-SPEC-TEMPLATE.md` — §8 Changelog table section; every spec now carries its own amendment history

### Changed
- `CLAUDE.md` — Step 0 (Frontmatter) now auto-populates `version: "1.0"`, `created`, and `last_modified` without asking the user
- `CLAUDE.md` — Final write step now seeds the §8 Changelog with the initial `1.0 / draft` row
- `CLAUDE.md` — "Modifying existing automation" workflow now requires appending a §8 Changelog row and updating `last_modified` on every spec amendment
- `CHANGELOG.md` — This file created; CLAUDE.md updated to maintain it automatically

---

## [2026-06-30] — `b580573`

### Changed
- `.claude/agents/playbook-author.md` — Added **Modification mode** section: pre-flight grep for affected `req:REQ-N` tasks, scope discipline (touch only changed requirement's files), post-edit diff review before declaring done
- `CLAUDE.md` — Reinforced modification workflow rules to match playbook-author changes

---

## [2026-06-18] — `8b2a630`

### Fixed
- `README.md` — Corrected test run command instructions that were being skipped

---

## [2026-06-18] — `2ddc8a6`

### Added
- `docs/05-aap-deployment-guide.md` — New guide: applying CaC YAML to a live AAP controller; covers prerequisites, `infra.controller_configuration dispatch` playbook, dry-run validation, rollback, per-environment deployments, and CI/CD pipeline integration

---

## [2026-06-18] — `d77757f` / `987cc96` / `22b66db`

### Added
- `.claude/agents/cac-author.md` — New sub-agent: generates `infra.controller_configuration`-compatible YAML (job templates + surveys) from an approved spec's §4 Inputs; cross-checks survey fields against `defaults/main.yml`

### Changed
- `README.md` — Added cac-author to sub-agents section and component reference
- `CLAUDE.md` — Added cac-author to Sub-Agents table

---

## [2026-06-04] — `28d91c0` / `24e3dba`

### Changed
- `CLAUDE.md` — Spec creation protocol now requires concrete recommendations and example answers at every step, not blank prompts
- `CLAUDE.md` — Removed risk-tiering from the approval workflow (was adding complexity without proportional value)

---

## [2026-05-21] — `b96d45d` / `2672f69` / `1ddfa82` / `db3009f`

### Added
- `.claude/agents/tutor.md` — New sub-agent: CoE-aware onboarding tutor; teaches SDD concepts using real repo files at the learner's pace; does not write or modify files; scoped to prefer CoE principles then official Red Hat documentation
- `specs/templates/BEST-PRACTICES-SPEC.md` — Universal baseline requirements (`REQ-UNI-*`): FQCN module naming, snake_case variables, idempotency, no inline secrets, task-level become, block/rescue/always error handling, session-start/end audit logging, pinned collection versions
- `specs/team-overrides/TEAM-PLATFORM-overrides.md` — Platform team overrides: HashiCorp Vault KV2, CMDB integration, SIEM requirements
- `specs/team-overrides/TEAM-RHEL-overrides.md` — RHEL team overrides: dnf/dnf5, RHEL System Roles, SELinux, subscription management, FIPS
- `specs/team-overrides/TEAM-AWS-overrides.md` — AWS team overrides: IAM credential injection, mandatory resource tagging, EC2 dynamic inventory, IaC boundary rules
- `specs/team-overrides/TEAM-WINDOWS-overrides.md` — Windows team overrides: WinRM vs SSH, ansible.windows modules, Chocolatey, registry handling
- `specs/team-overrides/TEAM-NETWORK-overrides.md` — Network team overrides: connection plugins, pre-change backup, commit-confirmation patterns, serial execution
- `specs/team-overrides/USE-CASE-NETWORK-overrides.md` — Network use-case overlay
- `specs/team-overrides/USE-CASE-EDA-overrides.md` — EDA use-case overlay: event validation, replay-attack prevention, rate limiting

---

## [2026-05-20] — `4cc871a` / `f323421`

### Changed
- `CLAUDE.md` — Auto-draft mode now shows a caveats confirmation prompt before Claude proceeds; user must explicitly confirm
- `CLAUDE.md` — Removed spec-drift EDA-specific references that were too narrowly scoped
- `README.md` — Multiple documentation updates

---

## [2026-05-19] — `6fe757b` / `0f76783`

### Changed
- `.claude/agents/test-author.md` — Updated Molecule scenario generation rules
- Various files — General updates from initial wiring-up phase

---

## [2026-05-19] — `7069d6b` Initial Commit

### Added
- `CLAUDE.md` — Project memory: role definition, spec creation protocol, three-layer spec hierarchy, Definition of Done checklist, required code patterns, coding defaults, workflows, sub-agent table, hard limits
- `README.md` — Full kit documentation
- `ansible.cfg` — Ansible configuration
- `requirements.yml` — Pinned collection dependencies (`ansible.posix 2.1.0`, `amazon.aws 9.5.0`)
- `.ansible-lint` — Production-grade lint profile
- `specs/templates/BASE-SPEC-TEMPLATE.md` — Nine-section spec template
- `specs/examples/AUTO-2026-0019-user-onboarding.md` — Low-risk reference spec
- `specs/examples/AUTO-2026-0042-rhel-patching.md` — Medium-risk reference spec
- `specs/examples/AUTO-2026-0055-eda-disk-remediation.md` — EDA use-case reference spec
- `ci/check-spec-coverage.sh` — CI gate: enforces spec_id presence, role meta references, approved spec resolution, and Molecule coverage warnings
- `.claude/agents/spec-reviewer.md` — Sub-agent: reviews specs for completeness, ambiguity, testability
- `.claude/agents/playbook-author.md` — Sub-agent: generates lint-clean, traceable playbooks and roles from approved specs
- `.claude/agents/test-author.md` — Sub-agent: generates Molecule scenarios mapped to spec requirements
- `.claude/agents/security-reviewer.md` — Sub-agent: regulated-environment security posture review
