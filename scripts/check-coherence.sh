#!/usr/bin/env bash
# check-coherence.sh — CI coherence gates.
#
# Four checks to ensure documentation stays in sync with code:
#   Gate 1: pyproject.toml version == package.json version          (hard fail)
#   Gate 2: ADR file count in doc/adr/ == ADR rows in Appendix C    (hard fail)
#   Gate 3: Sum of SELECT plan(N) in pgTAP == documented total      (hard fail)
#   Gate 4: New migration without spec/ADR change                   (warning)
#
# Exit 0 if all gates pass, 1 if any hard gate fails.

set -euo pipefail

ERRORS=0
WARNINGS=0

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

# Count ADR rows in spec: lines matching "| [ADR-0" pattern in Appendix C
ADR_SPEC_COUNT=$(grep -c '| \[ADR-0' "$SPEC_FILE" 2>/dev/null || echo 0)

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

# Extract documented total from POC plan: "pgTAP total: NNN assertions"
POC_PLAN="doc/POC_development_plan.md"
DOCUMENTED_TOTAL=$(grep -o 'pgTAP total: [0-9]* assertions' "$POC_PLAN" 2>/dev/null | grep -o '[0-9]*' || echo 0)

if [ "$ACTUAL_SUM" -eq "$DOCUMENTED_TOTAL" ]; then
  echo "  PASS: $ACTUAL_SUM assertions match documented total"
else
  echo "  FAIL: Actual $ACTUAL_SUM != Documented $DOCUMENTED_TOTAL"
  echo "  (Update the 'pgTAP total: N assertions' line in $POC_PLAN)"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate 4: New migration without spec/ADR change (warning) ----------
echo "--- Gate 4: Migration ↔ documentation sync ---"

# Compare current branch to main (or HEAD~1 if on main)
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  BASE="origin/main"
else
  BASE="HEAD~1"
fi

CHANGED_FILES=$(git diff --name-only "$BASE" -- . 2>/dev/null || echo "")

HAS_NEW_MIGRATION=$(echo "$CHANGED_FILES" | grep -c 'supabase/migrations/' || echo 0)
HAS_SPEC_CHANGE=$(echo "$CHANGED_FILES" | grep -c 'doc/Project Specification' || echo 0)
HAS_ADR_CHANGE=$(echo "$CHANGED_FILES" | grep -c 'doc/adr/' || echo 0)
HAS_POC_CHANGE=$(echo "$CHANGED_FILES" | grep -c 'doc/POC_development_plan' || echo 0)

if [ "$HAS_NEW_MIGRATION" -gt 0 ] && [ "$HAS_SPEC_CHANGE" -eq 0 ] && [ "$HAS_ADR_CHANGE" -eq 0 ] && [ "$HAS_POC_CHANGE" -eq 0 ]; then
  echo "  WARNING: New migration(s) without any doc/spec/ADR changes"
  WARNINGS=$((WARNINGS + 1))
  # Emit GitHub Actions warning annotation
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning::New migration added without spec/ADR/POC plan update"
  fi
else
  echo "  PASS: Documentation changes present (or no new migrations)"
fi
echo ""

# ---------- Summary ----------
echo "=== Summary: $ERRORS error(s), $WARNINGS warning(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED — fix coherence errors before merging."
  exit 1
fi

echo "All coherence checks passed."
exit 0
