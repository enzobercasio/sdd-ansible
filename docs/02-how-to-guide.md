# How-To Guide: Spec-Driven Ansible with Cursor

> Step-by-step workflow for engineers using this kit day-to-day.

## Prerequisites

- [Cursor](https://cursor.com) installed
- Ansible 2.16+ (`ansible --version`)
- ansible-lint 24+ (`pip install ansible-lint`)
- Molecule with Docker driver (`pip install molecule molecule-plugins[docker]`)
- Docker or Podman for Molecule scenarios
- Git access to the SDD repo

## The Daily Workflow

### Step 1: Open the Repo in Cursor

```bash
cd ~/work/automation-sdd
```

Open the folder in Cursor (File → Open Folder). The `@sdd-core` rule applies automatically via `.cursor/rules/sdd-core.mdc` (`alwaysApply: true`). You do not need to paste project memory into every session.

### Step 2: Start with Intent, Not Code

**Bad first prompt:**
> "Write me an Ansible playbook to patch RHEL servers"

**Good first prompt:**
> "I need to automate monthly RHEL security patching. Help me draft a spec — risk tier is medium, target is the `webservers` group, and we have a maintenance window of 22:00–04:00 SGT."

The good prompt gives Cursor enough context to:
- Pick the right template (BASE-SPEC-TEMPLATE)
- Apply the right overrides (RHEL → no use-case override needed)
- Ask the right clarifying questions

### Step 3: Iterate on the Spec

Cursor will produce a draft spec. Read it carefully — **the spec is the contract**. If anything is wrong, fix it now, before code generation.

```
> The spec looks good, but REQ-3 should specify SGT timezone explicitly
> and REQ-5 needs to mention which Slack channel. Update those.
```

When you're satisfied, change the frontmatter:

```yaml
status: approved
approved_by: enzo.bercasio
approved_date: 2026-05-07
```

Commit the spec on its own:

```bash
git add specs/AUTO-2026-0042-rhel-patching.md
git commit -m "[AUTO-2026-0042] Spec approved: RHEL patching automation"
```

### Step 4: Generate the Playbook

```
> The spec AUTO-2026-0042 is approved. @playbook-author generate the role
> and playbook. Make sure all four invariants are satisfied before you finish.
```

Cursor will:

1. Read `BEST-PRACTICES-SPEC.md`, applicable team/use-case overrides, and `AUTO-2026-0042-*.md`
2. Scaffold the role under `roles/rhel_patching/`
3. Generate `tasks/main.yml`, `defaults/main.yml`, `handlers/main.yml`, `meta/main.yml`
4. Generate the wrapper playbook under `playbooks/`
5. Tag every play and task with `spec_id` and `req:` tags
6. Run `ansible-lint` and fix any violations
7. Report back what was created and any deviations from spec

### Step 5: Generate the Tests

```
> @test-author Generate Molecule scenarios for AUTO-2026-0042.
> Each REQ in the spec must have at least one scenario.
```

Cursor will:

1. Create `roles/rhel_patching/molecule/<scenario>/` for each requirement
2. Write `molecule.yml`, `converge.yml`, and `verify.yml` for each
3. Encode acceptance criteria as `assert` tasks tied to REQ tags
4. Include both happy-path and negative test scenarios

### Step 6: Run the Tests

```
> Run molecule test for the rhel_patching role and report the results.
> If anything fails, diagnose and propose a fix.
```

Cursor will execute Molecule, parse the output, and either:
- Report success ("All 5 scenarios passed")
- Diagnose failures ("REQ-3 scenario fails because the maintenance window check uses UTC instead of SGT — fix in `tasks/main.yml` line 23")

### Step 7: Review and PR

```
> Generate a PR description for this change. Include:
> - The spec_id
> - Summary of what was implemented
> - Test coverage report (REQ → scenario mapping)
> - Any deviations from the spec
> - Risk assessment based on spec risk_tier
```

### Step 8: Merge and Deploy

After human review and merge, AAP picks up the role from your project sync. The job template surveys are auto-synced from spec §4 (if you've completed Phase 3 of the implementation plan).

---

## Common Workflows

### Workflow: Modifying an Existing Playbook

```
> The customer wants to change AUTO-2026-0042 to support dry-run mode.
> Read the existing spec, propose an amendment, and walk me through what
> would change in the playbook and tests.
```

Cursor will:

1. Read the existing spec
2. Propose a `1.1` version with the new requirement
3. Show you the diff to the playbook + tests
4. Wait for you to approve before making changes

### Workflow: Reverse-Engineering a Legacy Playbook

```
> We have a legacy playbook at /tmp/legacy-patching.yml with no spec.
> Read it carefully and produce a retrospective spec that describes
> what it currently does. Don't try to improve it — just describe it.
```

Once the retrospective spec is approved, you can refactor against it with confidence.

### Workflow: Onboarding a New Engineer

```
@tutor Walk me through one complete spec-driven cycle using AUTO-2026-0001
as the example. Show me the spec, then the playbook, then the tests,
and explain the traceability.
```

### Workflow: Spec Drift Investigation

```
> A job for AUTO-2026-0042 produced unexpected results.
> The job logs are in /tmp/job-12345.log. Diagnose what diverged from
> the spec and recommend whether to amend the spec or fix the playbook.
```

### Workflow: Bulk Spec Audit

```
> Read every spec in specs/ and produce a compliance report:
> - Which specs are approved vs. draft
> - Which approved specs lack corresponding playbooks
> - Which playbooks reference specs that don't exist
> - Which Molecule scenarios are missing for approved specs
```

---

## Tips for Better Cursor Sessions

### Tip 1: Keep `@sdd-core` Current

When the team agrees on a new convention, update `.cursor/rules/sdd-core.mdc`. The rule applies every session — it's free continuous improvement.

### Tip 2: Use Rules Deliberately

Specialised rules are for well-defined tasks:
- `@spec-reviewer` for spec quality reviews
- `@playbook-author` for generation
- `@test-author` for test generation
- `@security-reviewer` for regulated reviews
- `@tutor` for onboarding (read-only)

For exploratory work or cross-cutting changes, use the default agent with `@sdd-core` already applied.

### Tip 3: Commit the Spec First

Always commit the approved spec **before** generating code. This makes the Git history match the SDD discipline:

```
commit 1: [AUTO-2026-0042] Spec approved
commit 2: [AUTO-2026-0042] Implement role rhel_patching
commit 3: [AUTO-2026-0042] Add Molecule scenarios
```

The history reads like the workflow itself.

### Tip 4: Ask Cursor to Self-Check

```
> Before you finish, run through the "done" checklist from @sdd-core
> and tell me which items are complete and which are not.
```

### Tip 5: Show, Don't Tell, for Style Preferences

Instead of: *"Use my preferred style for variables"*

Do: *"Look at roles/user_management/ for our team's style conventions, then apply the same patterns to this new role."*

### Tip 6: Plan Before Complex Changes

For any change touching multiple roles, ask Cursor to plan first:

```
> Before making any changes, produce a plan: which files will change,
> in what order, and what tests need to run. Wait for my approval.
```

---

## Troubleshooting

### "Cursor suggested a deprecated module"

Update your `BEST-PRACTICES-SPEC.md` to explicitly forbid deprecated modules. Cursor reads the spec hierarchy first.

### "ansible-lint passes but the playbook doesn't work"

Add a `pre-merge` Molecule scenario that runs `ansible-playbook --check` against a real test inventory. Linting is necessary but not sufficient.

### "The generated playbook doesn't match our team's style"

You haven't authored a `TEAM-<name>-overrides.md` yet. Spend an hour codifying the team's conventions and Cursor will respect them.

### "The spec is too long for our use case"

You can use a "lite" template for `risk_tier: low` specs. Create `BASE-SPEC-TEMPLATE-LITE.md` with only the essential sections.

### "Two specs conflict with each other"

This usually means a missing override layer. Either:
- The conflict is genuine → resolve via PR review
- The same constraint keeps appearing → promote to a use-case override

---

## Anti-Patterns to Avoid

### ❌ Writing the spec after the playbook

Defeats the entire purpose. The spec is a contract, not a description.

### ❌ Using Cursor as a YAML autocompleter

If you're only accepting inline completions without a spec, you're skipping the discipline. Use the spec.

### ❌ Skipping the human review of generated specs

Cursor is capable but not infallible. The spec must be human-approved.

### ❌ Treating overrides as a backdoor

Don't put a constraint in a team override just to avoid a difficult discussion with the CoE. If it should be universal, escalate it.

### ❌ Generating tests that always pass

Verify scenarios actually fail when the implementation is wrong. Negative tests are non-negotiable for `risk_tier: medium/high`.

---

## Where to Get Help

- Spec writing → `docs/03-spec-authoring-guide.md`
- Better prompts → `docs/04-cursor-prompting.md`
- Examples → `specs/examples/`
- Team patterns → `specs/team-overrides/`
- CoE escalation → your CoE lead (the spec authority)
