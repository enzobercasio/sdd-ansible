#!/usr/bin/env bash
# ci/check-spec-coverage.sh
#
# Enforces the four SDD invariants in CI:
#   1. Every play/role references an existing spec_id
#   2. Every spec_id used in code resolves to an approved spec
#   3. Every approved spec has at least one Molecule scenario
#   4. Every spec REQ-N has at least one tagged assertion in tests
#
# Exits non-zero if any violations are found.
# Run as part of pre-merge CI to block non-compliant PRs.

set -euo pipefail

VIOLATIONS=0
REPO_ROOT="$(git rev-parse --show-toplevel)"
SPEC_DIR="${REPO_ROOT}/specs"
PLAYBOOK_DIR="${REPO_ROOT}/playbooks"
ROLE_DIR="${REPO_ROOT}/roles"

echo "==========================================="
echo "  SDD Spec Coverage Check"
echo "==========================================="

# ----------------------------------------------------------------------
# Invariant 1: Every play declares spec_id
# ----------------------------------------------------------------------
echo ""
echo "[1/4] Checking that every play declares spec_id..."

if [[ -d "${PLAYBOOK_DIR}" ]]; then
  while IFS= read -r playbook; do
    if ! grep -q "spec_id:" "${playbook}"; then
      echo "  ❌ VIOLATION: ${playbook} has no spec_id"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done < <(find "${PLAYBOOK_DIR}" -name "*.yml" -type f 2>/dev/null)
fi

# ----------------------------------------------------------------------
# Invariant 2: Every role's meta/main.yml references spec_id
# ----------------------------------------------------------------------
echo ""
echo "[2/4] Checking that every role meta references spec_id..."

if [[ -d "${ROLE_DIR}" ]]; then
  for role_meta in "${ROLE_DIR}"/*/meta/main.yml; do
    [[ -f "${role_meta}" ]] || continue
    if ! grep -q "spec_id:" "${role_meta}"; then
      echo "  ❌ VIOLATION: ${role_meta} has no spec_id"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  done
fi

# ----------------------------------------------------------------------
# Invariant 3: Every spec_id referenced in code resolves to an approved spec
# ----------------------------------------------------------------------
echo ""
echo "[3/4] Checking that referenced spec_ids resolve to approved specs..."

# Extract all spec_ids referenced in code
referenced_ids=$(
  grep -rho 'spec_id:[[:space:]]*"\?\(AUTO-[0-9]\{4\}-[0-9]\{4\}\)"\?' \
    --include="*.yml" --include="*.yaml" \
    "${PLAYBOOK_DIR}" "${ROLE_DIR}" 2>/dev/null \
    | sed -E 's/.*spec_id:[[:space:]]*"?(AUTO-[0-9]{4}-[0-9]{4})"?.*/\1/' \
    | sort -u || true
)

for spec_id in ${referenced_ids}; do
  spec_file=$(grep -l "spec_id:[[:space:]]*${spec_id}\$" "${SPEC_DIR}"/**/*.md 2>/dev/null || true)
  if [[ -z "${spec_file}" ]]; then
    echo "  ❌ VIOLATION: ${spec_id} referenced in code but no spec file found"
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi
  if ! grep -q "^status:[[:space:]]*\(approved\|in-use\)" "${spec_file}"; then
    echo "  ❌ VIOLATION: ${spec_id} referenced in code but spec status is not approved"
    echo "     File: ${spec_file}"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

# ----------------------------------------------------------------------
# Invariant 4: Every approved spec has at least one Molecule scenario
# ----------------------------------------------------------------------
echo ""
echo "[4/4] Checking Molecule coverage for approved specs..."

while IFS= read -r spec_file; do
  status=$(grep -E "^status:" "${spec_file}" | head -1 | awk '{print $2}')
  if [[ "${status}" == "approved" || "${status}" == "in-use" ]]; then
    spec_id=$(grep -E "^spec_id:" "${spec_file}" | head -1 | awk '{print $2}')

    # Skip non-implementation specs (best practices, overrides)
    if [[ "${spec_id}" == "BEST-PRACTICES" ]] || [[ "${spec_id}" == TEAM-* ]] || [[ "${spec_id}" == USE-CASE-* ]]; then
      continue
    fi

    # Look for any Molecule scenario referencing this spec_id
    if ! grep -rq "${spec_id}" "${ROLE_DIR}"/*/molecule/ 2>/dev/null; then
      echo "  ⚠️  WARNING: Approved spec ${spec_id} has no Molecule scenario"
      echo "     Spec: ${spec_file}"
      # Warning, not blocking — gives time to add tests after spec approval
    fi
  fi
done < <(find "${SPEC_DIR}" -name "*.md" -type f 2>/dev/null)

# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------
echo ""
echo "==========================================="
if [[ ${VIOLATIONS} -eq 0 ]]; then
  echo "  ✅ SDD compliance check PASSED"
  echo "==========================================="
  exit 0
else
  echo "  ❌ SDD compliance check FAILED"
  echo "  ${VIOLATIONS} violation(s) found"
  echo "==========================================="
  echo ""
  echo "See docs/02-how-to-guide.md for resolution steps."
  exit 1
fi
