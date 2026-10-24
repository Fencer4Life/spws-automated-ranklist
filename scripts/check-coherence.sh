#!/usr/bin/env bash
# check-coherence.sh — CI coherence gates.
#
# Four checks to ensure documentation stays in sync with code:
#   Gate 1: pyproject.toml version == package.json version          (hard fail)
#   Gate 2: ADR file count in doc/adr/ == ADR rows in Appendix C    (hard fail)
#   Gate 3: Sum of SELECT plan(N) in pgTAP == documented total      (hard fail)
#   Gate 4: Migration change without a documentation change         (hard fail)
#
# Exit 0 if all gates pass, 1 if any gate fails.

set -euo pipefail

ERRORS=0

echo "=== Coherence Checks ==="
echo ""

# ---------- Gate 1: Version sync ----------
echo "--- Gate 1: Version sync (pyproject.toml vs package.json) ---"

PY_VERSION=$(grep '^version' pyproject.toml | head -1 | sed 's/version *= *"\(.*\)"/\1/')
JS_VERSION=$(jq -r '.version' frontend/package.json)

if [ "$PY_VERSION" = "$JS_VERSION" ]; then
  echo "  PASS: Both at v$PY_VERSION"
else
  echo "  FAIL: pyproject.toml=$PY_VERSION, package.json=$JS_VERSION"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate 2: ADR file count == spec table rows ----------
echo "--- Gate 2: ADR file count vs spec Appendix C ---"

ADR_FILE_COUNT=$(ls -1 doc/adr/*.md 2>/dev/null | wc -l | tr -d ' ')
SPEC_FILE="doc/Project Specification. SPWS Automated Ranklist System.md"

# Count ADR rows in spec: lines matching "| [ADR-NNN" pattern in Appendix C.
# Matches any digit after the hyphen, not just "0" -- a leading-digit-only
# pattern silently undercounts once ADR numbering rolls past 099 (caught
# live going from ADR-099 to ADR-100, design step 6).
ADR_SPEC_COUNT=$(grep -c '| \[ADR-[0-9]' "$SPEC_FILE" 2>/dev/null || echo 0)

if [ "$ADR_FILE_COUNT" -eq "$ADR_SPEC_COUNT" ]; then
  echo "  PASS: $ADR_FILE_COUNT ADR files = $ADR_SPEC_COUNT spec rows"
else
  echo "  FAIL: $ADR_FILE_COUNT ADR files != $ADR_SPEC_COUNT spec rows"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate 3: pgTAP plan() sum == documented total ----------
echo "--- Gate 3: pgTAP assertion count ---"

# Sum all SELECT plan(N) values from test files
ACTUAL_SUM=0
for f in supabase/tests/*.sql; do
  if [ -f "$f" ]; then
    # Extract the number from SELECT plan(N)
    N=$(grep -o 'SELECT plan([0-9]*)' "$f" | grep -o '[0-9]*' || echo 0)
    if [ -n "$N" ]; then
      ACTUAL_SUM=$((ACTUAL_SUM + N))
    fi
  fi
done

# Extract documented total from Project Specification Appendix D: "pgTAP total: NNN assertions"
SPEC_DOC="doc/Project Specification. SPWS Automated Ranklist System.md"
DOCUMENTED_TOTAL=$(grep -o 'pgTAP total: [0-9]* assertions' "$SPEC_DOC" 2>/dev/null | grep -o '[0-9]*' || echo 0)

if [ "$ACTUAL_SUM" -eq "$DOCUMENTED_TOTAL" ]; then
  echo "  PASS: $ACTUAL_SUM assertions match documented total"
else
  echo "  FAIL: Actual $ACTUAL_SUM != Documented $DOCUMENTED_TOTAL"
  echo "  (Update the 'pgTAP total: N assertions' line in $SPEC_DOC Appendix D)"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate 4: Migration change without a documentation change ----------
echo "--- Gate 4: Migration ↔ documentation sync ---"

# The range is what this push or pull request brings. CI passes COHERENCE_BASE:
# the pull request's base, or the commit main stood at before the push. Without
# it (preflight), the branch's fork point from origin/main; the working tree is
# compared, so uncommitted changes count. An unusable base (zeros for a new
# branch, or a commit a rewritten history dropped) falls back to that fork point,
# and to the last commit when the fork point is HEAD itself. The gate used to
# compare against origin/main, which on a push to main IS the pushed commit, so
# it never fired there (test_coherence_migration_gate.py COH.01-04).
BASE="${COHERENCE_BASE:-}"
if [ -z "$BASE" ] || ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  BASE=""
  if git rev-parse --verify -q origin/main >/dev/null; then
    BASE="$(git merge-base origin/main HEAD 2>/dev/null || true)"
  fi
  if [ -z "$BASE" ] || [ "$BASE" = "$(git rev-parse HEAD)" ]; then
    BASE="$(git rev-parse --verify -q 'HEAD~1' || true)"
  fi
fi

CHANGED_FILES=""
if [ -n "$BASE" ]; then
  CHANGED_FILES=$(git diff --name-only "$BASE" -- .)
fi

MIGRATIONS=$(grep '^supabase/migrations/' <<<"$CHANGED_FILES" || true)
DOCUMENTATION=$(grep -E '^doc/(Project Specification|adr/|handbook/|governance/)' <<<"$CHANGED_FILES" || true)

if [ -n "$MIGRATIONS" ] && [ -z "$DOCUMENTATION" ]; then
  echo "  FAIL: migration(s) changed since ${BASE:0:12} without a specification, ADR, governance or handbook change:"
  sed 's/^/    /' <<<"$MIGRATIONS"
  ERRORS=$((ERRORS + 1))
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error::Migration changed without a specification, ADR, governance or handbook update"
  fi
else
  echo "  PASS: no migration changed, or its documentation changed with it"
fi
echo ""

# ---------- Summary ----------
echo "=== Summary: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED — fix coherence errors before merging."
  exit 1
fi

echo "All coherence checks passed."
exit 0
