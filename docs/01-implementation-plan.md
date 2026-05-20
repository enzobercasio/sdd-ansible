# Implementation Plan: Spec-Driven Ansible with Claude Code

> An 8-week rollout plan, designed for a CoE/CoP model with executive visibility.

## Overview

This plan moves a team or organisation from ad-hoc playbook authoring to spec-driven, AI-accelerated automation in 8 weeks. It maps cleanly onto a Crawl/Walk/Run maturity model.

| Phase | Weeks | Stage | Outcome |
|---|---|---|---|
| **Phase 1: Foundation** | Weeks 1–2 | Crawl | Repo scaffold, base specs, first playbook |
| **Phase 2: Pilot** | Weeks 3–5 | Walk | 3–5 specs delivered through full SDD flow |
| **Phase 3: Scale** | Weeks 6–8 | Run | Team-specific overrides, CI/CD enforcement, AAP integration |

---

## Phase 1: Foundation (Weeks 1–2)

### Goals

- Scaffold the SDD repo
- Onboard 2–3 core CoE engineers to Claude Code
- Produce the first end-to-end spec → playbook → tests artifact
- Demonstrate the workflow to leadership

### Week 1: Setup

#### Day 1–2: Repository Scaffold

```bash
# Create repo and copy scaffold
git init automation-sdd
cd automation-sdd
cp -r <this-kit>/{CLAUDE.md,specs,docs,.claude} .

# Initialise the lint config
cat > .ansible-lint <<'EOF'
exclude_paths:
  - .cache/
  - .github/
skip_list:
  - experimental
enable_list:
  - fqcn-builtins
  - no-changed-when
  - risky-shell-pipe
EOF

# First commit
git add .
git commit -m "[SDD-INIT] Initial spec-driven scaffold"
```

#### Day 3: Claude Code Onboarding

Have 2–3 CoE engineers install Claude Code and run the canonical first session:

```
> Read CLAUDE.md, then walk me through how spec-driven development works
> in this repo. List what you'll do for me, and what I'll do.
```

Engineers should leave the session understanding:
- The four invariants
- The spec hierarchy
- The "done" checklist

#### Day 4–5: Author the First Real Spec

Pick a low-risk, high-frequency automation use case (user account creation, log rotation, certificate renewal). Write the spec collaboratively with Claude Code:

```
> I want to automate <use case>. Walk me through the BASE-SPEC-TEMPLATE
> and help me draft each section. The risk tier is low. Target group
> is <group>. Ask me clarifying questions one at a time.
```

### Week 2: First Playbook

#### Day 1–2: Generate Playbook from Spec

```
> Read specs/AUTO-2026-0001-<name>.md. Use the playbook-author sub-agent
> to generate the role and playbook. Make sure all four invariants are
> satisfied before you finish.
```

#### Day 3: Generate Tests

```
> Use the test-author sub-agent to generate Molecule scenarios for
> AUTO-2026-0001. Each REQ in the spec must have at least one scenario.
```

#### Day 4: Run Through CI

Add a basic GitHub Actions / GitLab CI pipeline:

```yaml
# .github/workflows/sdd-validate.yml
name: SDD Validation
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install tooling
        run: pip install ansible ansible-lint molecule molecule-plugins[docker]
      - name: Spec coverage check
        run: |
          ./ci/check-spec-coverage.sh
      - name: Lint
        run: ansible-lint
      - name: Molecule
        run: |
          for role in roles/*/; do
            cd "$role" && molecule test && cd -
          done
```

#### Day 5: Executive Demo

30-minute walkthrough for leadership covering:
- A spec being written (10 min)
- Claude Code generating the playbook from the spec (5 min)
- The tests verifying the spec (5 min)
- Audit trail in Git (5 min)
- Q&A (5 min)

**Key talking point**: "Every line of automation we ship is now traceable to an approved, reviewed specification. AI accelerates the writing — governance ensures it stays safe."

### Phase 1 Exit Criteria

- [ ] Repo scaffold committed and shared
- [ ] 3 engineers can run the SDD workflow end-to-end
- [ ] One real spec → playbook → tests delivered
- [ ] Leadership has seen the demo
- [ ] CI pipeline runs on every PR

---

## Phase 2: Pilot (Weeks 3–5)

### Goals

- Deliver 3–5 production-ready playbooks via the SDD workflow
- Train an additional 5–8 engineers across 2–3 teams
- Identify and resolve workflow friction
- Begin team-override authoring

### Week 3: Scale to 3 Teams

Pick three teams with diverse use cases:

- **Platform team**: infrastructure provisioning automation
- **Security team**: compliance scanning automation
- **Application team**: deployment automation

Each team writes one spec under CoE guidance.

### Week 4: First Team-Specific Overrides

When teams find themselves repeatedly adding the same constraints to specs, codify those into team-override files:

```
specs/team-overrides/
├── TEAM-PLATFORM-overrides.md       # e.g., always uses HCP Vault for secrets
├── TEAM-SECURITY-overrides.md        # e.g., logging requirements, SIEM integration
└── TEAM-APPLICATION-overrides.md     # e.g., always uses ArgoCD for delivery
```

#### Example: When to create a team override

If three specs from the platform team all say *"All secrets must be retrieved from HashiCorp Vault using the `community.hashi_vault.vault_kv2_get` lookup"* — that's a team-override candidate. Move it once, reference it from now on.

### Week 5: Use-Case Overrides

Some patterns are use-case specific, not team specific:

```
specs/team-overrides/
├── USE-CASE-EDA-overrides.md         # EDA rulebook patterns
├── USE-CASE-NETWORK-overrides.md     # Network device automation patterns
├── USE-CASE-WINDOWS-overrides.md     # Windows-specific patterns
└── USE-CASE-CLOUD-overrides.md       # Cloud provisioning patterns
```

These are **horizontal** — any team writing an EDA rulebook applies the EDA overrides.

### Phase 2 Exit Criteria

- [ ] 5+ playbooks delivered via SDD
- [ ] 8+ engineers trained
- [ ] At least 2 team overrides authored
- [ ] At least 1 use-case override authored
- [ ] Lessons learned documented and folded back into BEST-PRACTICES-SPEC

---

## Phase 3: Scale (Weeks 6–8)

### Goals

- Make SDD the default workflow (CI enforces it)
- Integrate with AAP for runtime enforcement
- Roll out organisation-wide training

### Week 6: CI/CD Enforcement

Upgrade CI to **block** PRs that violate SDD discipline:

```bash
#!/bin/bash
# ci/check-spec-coverage.sh
# Reject any playbook that lacks a spec_id reference

VIOLATIONS=0

for play in playbooks/*.yml; do
  if ! grep -q "spec_id:" "$play"; then
    echo "VIOLATION: $play has no spec_id"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

for role in roles/*/; do
  if ! grep -q "spec_id:" "${role}meta/main.yml" 2>/dev/null; then
    echo "VIOLATION: ${role} meta/main.yml has no spec_id"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

# Verify each spec_id resolves to an approved spec
for spec_id in $(grep -roh "spec_id: \"[A-Z]*-[0-9]*-[0-9]*\"" --include="*.yml" | sort -u | sed 's/spec_id: "\(.*\)"/\1/'); do
  if ! grep -l "spec_id: $spec_id" specs/*.md > /dev/null; then
    echo "VIOLATION: $spec_id referenced in code but no spec found"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

exit $VIOLATIONS
```

### Week 7: AAP Integration

Configure AAP job templates to:

1. Pull surveys from spec §5 (Inputs) — keep them in sync
2. Map RBAC to spec `risk_tier`:
   - `low` → developers can run
   - `medium` → requires approval workflow node
   - `high` → requires CAB-approved scheduled execution only
3. Tag every job with the spec_id for audit reporting

```bash
# Sync spec inputs to AAP survey via API
ansible-playbook ci/sync-aap-surveys.yml \
  -e "spec_path=specs/AUTO-2026-0042-rhel-patching.md" \
  -e "aap_template_id=42"
```

### Week 8: Training and Adoption

Roll out organisation-wide training and confirm steady-state operation:

1. Run SDD walkthrough sessions for each team using their own `TEAM-<name>-overrides.md`
2. Validate that CI gates are blocking non-compliant PRs in all active repos
3. Confirm AAP job templates are synced to spec inputs (surveys match spec §4)
4. Review and close any outstanding draft specs from the pilot phase

### Phase 3 Exit Criteria

- [ ] CI blocks non-SDD PRs
- [ ] AAP surveys auto-sync from spec inputs
- [ ] Organisation-wide training complete

---

## Roles & Responsibilities

| Role | Responsibility |
|---|---|
| **CoE Lead** | Owns the BEST-PRACTICES-SPEC, approves changes |
| **CoE Engineers** | Author and maintain spec templates, sub-agents, CI tooling |
| **Team Leads (CoP)** | Author team-override specs; review team's playbook specs |
| **Engineers** | Write specs, generate playbooks via Claude Code, run tests |
| **Security/Compliance** | Review all `risk_tier: medium/high` specs |
| **Auditors** | Consume Git history + AAP logs as the audit trail |

## Metrics to Track

Track these from Week 2 onward:

| Metric | Target by Week 8 |
|---|---|
| % of playbooks with valid spec_id | 100% |
| % of specs with passing Molecule tests | >90% |
| Mean time from spec draft to approved | <3 days |
| Mean time from approved spec to deployed playbook | <2 days |
| Number of unplanned spec amendments per month | <5 (declining) |
| % of engineers trained on SDD | 100% |
| Audit findings on automation changes | 0 |

## Common Pitfalls and How to Avoid Them

### Pitfall 1: "The spec is too much overhead for simple tasks"

**Avoid by**: keeping the BASE-SPEC-TEMPLATE minimal for low-risk tier specs. A `risk_tier: low` spec can be 1 page.

### Pitfall 2: "Engineers skip writing tests"

**Avoid by**: making tests part of the playbook-author sub-agent's output by default. CI rejects roles without Molecule scenarios.

### Pitfall 3: "Specs go stale"

**Avoid by**: scheduling quarterly spec reviews and tracking unplanned amendments in your metrics. When job outcomes diverge from spec acceptance criteria, treat it as a signal to review and update the spec.

### Pitfall 4: "Team overrides become a dumping ground"

**Avoid by**: quarterly review of team overrides. Anything that's truly universal gets promoted to BEST-PRACTICES-SPEC.

### Pitfall 5: "Claude Code generates plausible but wrong code"

**Avoid by**: the four invariants. Generated code that doesn't pass lint + Molecule never reaches production. The discipline catches AI errors.

## Forward-Looking: Beyond Ansible

The same SDD pattern extends to:

- **OpenShift GitOps** (spec → ArgoCD ApplicationSet)
- **Terraform** (spec → HCL modules)
- **Kubernetes operators** (spec → CRD + controller)
- **Ansible Lightspeed model fine-tuning** (specs become training data)

Build the SDD muscle in Ansible first. It transfers everywhere.
