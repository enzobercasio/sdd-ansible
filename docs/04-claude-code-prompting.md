# Claude Code Prompting for Spec-Driven Ansible

> Patterns and prompts that produce consistently good results in this workflow.

## The Mental Model

Think of Claude Code in this repo as a **disciplined senior engineer who has read CLAUDE.md**. They don't need everything spelled out, but they need:

1. **Clear intent** — what business outcome you want
2. **Context anchors** — which spec, which role, which file
3. **Decision authority** — what they can decide vs. what they should ask
4. **Done definition** — when to stop

The CLAUDE.md handles 1–4 implicitly for SDD work. Your job is to refine.

## Core Prompt Patterns

### Pattern 1: Spec Drafting

```
I need to automate <use case>. Help me draft a spec using BASE-SPEC-TEMPLATE.

Context:
- Risk tier: <low/medium/high>
- Team: <team>
- Target environment: <dev/staging/prod>
- Constraints: <regulatory, technical, operational>

Walk me through each section, asking clarifying questions one at a time.
Don't generate code yet — we're focused on the spec.
```

### Pattern 2: Playbook Generation

```
Spec AUTO-2026-NNNN is approved. Use the playbook-author sub-agent to
generate the role and playbook.

Before you start:
1. Confirm you've read BEST-PRACTICES-SPEC, applicable team/use-case
   overrides, and the spec itself.
2. Tell me which override layers apply.
3. List the files you'll create.
4. Wait for my approval before generating.
```

### Pattern 3: Test Generation

```
Generate Molecule scenarios for AUTO-2026-NNNN.

Coverage requirements:
- One happy-path scenario covering all REQs that don't conflict
- One negative-test scenario per REQ that has a "shall refuse" or
  "shall not" clause
- Edge cases for any REQ marked critical

Each verify.yml task must be tagged with spec_id and req:.
```

### Pattern 4: Self-Audit

```
Run through the "done" checklist from CLAUDE.md against this role.
For each item:
- Mark complete or incomplete
- If incomplete, propose the fix
- Don't make any changes yet — just report
```

### Pattern 5: Conflict Resolution

```
I see a conflict: BEST-PRACTICES-SPEC §X says <constraint A>, but
USE-CASE-<x>-overrides says <constraint B>. Which applies for this spec,
and why? Update the spec's "Deviations" section if needed.
```

### Pattern 6: Spec Drift Investigation

```
Job <ID> for spec <ID> produced unexpected results.
- Job log: <path or paste>
- Spec: specs/<file>.md

Diagnose:
1. Which acceptance criterion failed?
2. Was this a code defect, environmental drift, or stale spec?
3. Recommend: amend spec, fix code, or escalate to owner?
```

## Anti-Patterns (and Recovery)

### Anti-Pattern: Vague Asks

> ❌ "Make this better"
> 
> ✅ "Refactor this role to use FQCN modules and add tags to every task per CLAUDE.md."

### Anti-Pattern: Trusting Without Verifying

> ❌ Accepting Claude's "All tests pass" without seeing the output
> 
> ✅ "Run molecule test and paste the full output. I want to see actual results."

### Anti-Pattern: Skipping the Spec

> ❌ "Just write me a quick playbook to restart nginx"
> 
> ✅ "Draft a minimal low-risk-tier spec for an nginx restart automation, then generate the playbook."

For genuine one-offs that don't merit a spec, be explicit:

> "This is a throwaway one-off for a debugging session. Skip the spec. I'll delete the playbook after."

### Anti-Pattern: Over-Specifying Implementation in Prompts

> ❌ "Use ansible.builtin.dnf with state=latest and security=true and a loop over groups['webservers']"
> 
> ✅ "Implement REQ-2 from the approved spec. Pick the appropriate module."

If you find yourself prompting at the task level, you're not doing SDD — you're doing assisted coding. Move the constraint to the spec.

## Sub-Agent Invocation Patterns

```
> Delegate to spec-reviewer: review specs/AUTO-2026-NNNN.md for
> completeness, ambiguity, and missing requirements. Produce a written
> review with specific suggestions.

> Delegate to playbook-author: generate the implementation for
> AUTO-2026-NNNN. Stop after generating files; don't run tests.

> Delegate to test-author: generate Molecule scenarios for AUTO-2026-NNNN.
> Then run molecule test and report.

> Delegate to security-reviewer: review the generated role
> roles/<name>/ for regulated-environment security posture. Focus on:
> secrets handling, audit logging, RBAC integration, supply chain.
```

## Long-Running Workflow Pattern

For a full spec-to-PR cycle, structure the session in stages:

```
> Stage 1: Spec drafting
> ----------------------
> Help me draft a spec for <use case>. Risk tier: medium.

[work the spec to completion]

> Stage 2: Generation
> -------------------
> Spec is approved. Generate the role and tests. Self-audit when done.

[review generated code]

> Stage 3: Validation
> -------------------
> Run lint and molecule. Fix any issues. Report results.

[review test output]

> Stage 4: PR prep
> ----------------
> Generate a PR description that traces every change to the spec.
> Include the test coverage matrix.
```

This staged approach prevents Claude from running ahead and producing partial outputs.

## Useful "Stop Conditions"

Add these to long prompts to control scope:

- *"Stop after generating the spec — don't write code yet."*
- *"Stop after the first failing test — let me investigate before continuing."*
- *"Limit changes to the rhel_patching role; don't touch shared roles."*
- *"Don't modify CLAUDE.md or any spec template without my explicit approval."*
- *"If you encounter ambiguity, ask rather than guess."*

## Handling Hallucinations

Claude Code will occasionally invent module names, collection paths, or AAP API endpoints. Defend against this:

```
> Before using any module, verify it exists in the collections we have
> declared in the spec (ansible_collections_required). If a module
> doesn't exist, tell me and propose alternatives.
```

For fact-sensitive work:

```
> Don't rely on memory for AAP API endpoints. Search the docs first
> or ask me to provide them.
```

## Prompt Hygiene Checklist

Before sending a non-trivial prompt, ask yourself:

- [ ] Have I named the spec_id?
- [ ] Have I specified which sub-agent (or "no sub-agent")?
- [ ] Have I set a clear stop condition?
- [ ] Am I asking for output that can be verified (vs. opinion)?
- [ ] Am I prompting at the right level of abstraction (intent, not implementation)?

## A Reference Session

Here's what a high-quality session looks like end-to-end:

```
[Engineer] I need to automate certificate renewal for our internal CA.
           Risk tier medium, network team, target is the loadbalancers
           group. Help me draft the spec.

[Claude]   Reading CLAUDE.md and BASE-SPEC-TEMPLATE... Before drafting,
           I need to know: (1) which CA tool issues the certs, (2)
           what's the renewal trigger — calendar or expiry threshold,
           (3) what's the rollback if a renewal fails mid-deploy?

[Engineer] (1) Hashicorp Vault PKI, (2) renew when <30 days to expiry,
           (3) keep old cert in place, alert on-call.

[Claude]   [drafts spec covering REQ-1 through REQ-7, with EARS notation,
           input contract, acceptance criteria, and failure modes]

[Engineer] REQ-3 should specify SGT explicitly. Otherwise approved.

[Claude]   [updates REQ-3, asks for status approval]

[Engineer] Approved. Generate role and tests via sub-agents.

[Claude]   Delegating to playbook-author... [generates role]
           Delegating to test-author... [generates molecule scenarios]
           Running molecule test... [output]
           
           Done checklist:
           ✅ spec_id in all plays
           ✅ REQ tags on all tasks
           ✅ ansible-lint passes
           ✅ 5/5 molecule scenarios pass
           ✅ README links to spec
           
           Ready for PR. Want me to draft the PR description?

[Engineer] Yes.

[Claude]   [generates PR description with REQ→scenario coverage matrix]
```

This session takes 20–30 minutes for a medium-risk automation. That's the right pace for production-grade work.
