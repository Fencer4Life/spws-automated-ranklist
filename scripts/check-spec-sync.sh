#!/usr/bin/env bash
# check-spec-sync.sh — Phase 0.5 spec-sync CI gate.
#
# Verifies the post-Phase-0.5 spec layout stays consistent:
#   Gate A: externalized files exist (RTM, SuperFive backlog)
#   Gate B: spec does not regress FR table back into Appendix C
#   Gate C: spec does not regress NFR table back into Appendix C
#   Gate D: spec line count ≤ 1620 (Phase 0.5 reduction target)
#   Gate E: RTM file contains expected FR count
#
# Exit 0 if all gates pass, 1 if any gate fails.

set -euo pipefail

ERRORS=0

SPEC="doc/Project Specification. SPWS Automated Ranklist System.md"
RTM="doc/requirements-traceability-matrix.md"
BACKLOG="doc/backlog/superfive-phase-3.md"

echo "=== Phase 0.5 Spec-Sync Checks ==="
echo ""

# ---------- Gate A: externalized files exist ----------
echo "--- Gate A: Externalized files present ---"

for f in "$RTM" "$BACKLOG"; do
  if [ -f "$f" ]; then
    echo "  PASS: $f exists"
  else
    echo "  FAIL: $f missing (Phase 0.5 externalization broken)"
    ERRORS=$((ERRORS + 1))
  fi
done
echo ""

# ---------- Gate B: spec doesn't re-host FR table ----------
echo "--- Gate B: FR table not in spec ---"

FR_ROWS_IN_SPEC=$({ grep -E '^\| FR-[0-9]' "$SPEC" 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$FR_ROWS_IN_SPEC" -eq 0 ]; then
  echo "  PASS: 0 FR rows in spec"
else
  echo "  FAIL: $FR_ROWS_IN_SPEC FR rows found in spec — RTM should hold them, not the spec"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate C: spec doesn't re-host NFR table ----------
echo "--- Gate C: NFR table not in spec ---"

NFR_ROWS_IN_SPEC=$({ grep -E '^\| NFR-[0-9]' "$SPEC" 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$NFR_ROWS_IN_SPEC" -eq 0 ]; then
  echo "  PASS: 0 NFR rows in spec"
else
  echo "  FAIL: $NFR_ROWS_IN_SPEC NFR rows found in spec — RTM should hold them, not the spec"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate D: spec line count budget ----------
echo "--- Gate D: Spec line count ≤ 1620 ---"

SPEC_LINES=$(wc -l < "$SPEC" | tr -d ' ')
if [ "$SPEC_LINES" -le 1620 ]; then
  echo "  PASS: $SPEC_LINES lines (target ≤ 1620)"
else
  echo "  FAIL: $SPEC_LINES lines > 1620 — Phase 0.5 reduction regressed"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# ---------- Gate E: RTM has the expected FR count ----------
echo "--- Gate E: RTM FR count ---"

if [ -f "$RTM" ]; then
  RTM_FR_COUNT=$({ grep -E '^\| FR-[0-9]' "$RTM" 2>/dev/null || true; } | wc -l | tr -d ' ')
  # Expected: 100 FRs (FR-01..FR-101 minus FR-69 which was retired before assignment)
  EXPECTED=100
  if [ "$RTM_FR_COUNT" -eq "$EXPECTED" ]; then
    echo "  PASS: $RTM_FR_COUNT FR rows in RTM (matches expected $EXPECTED)"
  else
    echo "  FAIL: $RTM_FR_COUNT FR rows in RTM, expected $EXPECTED"
    echo "  (If the FR roster legitimately changed, update EXPECTED in this script.)"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  SKIP: $RTM missing (already failed in Gate A)"
fi
echo ""

# ---------- Summary ----------
echo "=== Summary: $ERRORS error(s) ==="

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED — Phase 0.5 spec-sync invariants violated."
  exit 1
fi

echo "All Phase 0.5 spec-sync checks passed."
exit 0
