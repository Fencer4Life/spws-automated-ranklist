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
  # Expected: 133 FRs (FR-01..FR-134 minus FR-69 which was retired before assignment)
  # 2026-07-23: +FR-132 (dispatcher authenticates its caller, requires aal2)
  # 2026-09-02: +FR-134 (calendar dataset spans every season; a calendar failure is contained)
  #             +FR-133 (deny-by-default grants; anon surface is an allowlist) — ADR-083
  # 134 since 2026-09-03: FR-135 (PZSz as a fourth calendar organizer, ADR-087).
  # 135 since 2026-09-12: +FR-136 (public FTL export page, ADR-080 amendment (g)/(h)).
  #   The identity-candidate/override work the same day amended FR-124 in place
  #   rather than adding a row.
  # 141 since 2026-09-28: +FR-137–FR-142 (2026/2027 scoring engine, ADR-103).
  # 145 since 2026-10-01: +FR-146 (the chosen season's ranking rules, a pill
  #   pinned to the bottom of the ranklist screen and its modal).
  # 146 since 2026-10-02: +FR-147 (nationality per season, fixed for the
  #   season, ADR-106).
  # 150 since 2026-10-03: +FR-148–FR-151 (WordPress site navigation, PROD admin on
  #   WordPress, the framed documents, the environments split by host; ADR-090
  #   amendment 2026-10-03, ADR-109). Registered as Planned before code.
  # 151 since 2026-10-04: +FR-152 (the fencer table is the ranking entry,
  #   ADR-110; supersedes FR-141).
  # 153 since 2026-10-06: +FR-153 (the calendar drum reads downward and shows
  #   how it turns, ADR-084 amendment 2026-10-06), +FR-154 (every interface
  #   string in the reader's language). FR-148 amended in place. Registered as
  #   Planned before code (plan kalendarz-beben-strzalki §08 step 1).
  # 155 since 2026-10-06: +FR-155 (a PZSz result is kept only on surname, first
  #   name and birth year), +FR-156 (ingest for CERT, promote for PROD, for
  #   every organizer); ADR-111. Registered as Planned before code.
  # 156 since 2026-10-07: +FR-157 (PZSz start lists are stored inputs,
  #   captured while pzszerm.pl serves them; ADR-112).
  # 157 since 2026-10-17: +FR-158 (ingest starts from PROD's master data, and
  #   only ingest and promote write results; ADR-113).
  # 158 since 2026-10-18: +FR-159 (equal totals share a place; ADR-115).
  # 159 since 2026-10-25: +FR-160 (results links are set by a person; calendar
  #   automation writes only the organizer's letter; ADR-117).
  # 160 since 2026-10-31: +FR-161 (event details written on CERT reach PROD,
  #   one contract for every calendar scraper; ADR-118).
  # 161 since 2026-10-31: +FR-162 (only final brackets, one engine contract, one
  #   organizer registry; ADR-119 release 1).
  # 162 since 2026-10-31: +FR-163 (one apply on both sides and the promote
  #   ledger; ADR-119 release 2).
  # 163 since 2026-11-01: +FR-164 (the hourly results sync; ADR-119 release
  #   3, registered with 3a, the pause store, before the sync's code).
  # 164 since 2026-11-17: +FR-165 (the entry list's tiles show the selection;
  #   the name search folds diacritics). Registered as Planned before code
  #   (plan entry-list-tiles-follow-filters-tdd-plan §08 step 3).
  # 165 since 2026-11-17: +FR-166 (an administrator removes an entry from the
  #   entry list). Registered as Planned before code (plan
  #   entry-list-admin-removes-entry-tdd-plan §07 step 2).
  # 166 since 2026-11-21: +FR-167 (a fencer's name in one form, titles apart,
  #   reversed name fields caught). Registered as Planned before code (plan
  #   registration-form-names-year-country rev 10, release 1).
  # 167 since 2026-11-21: +FR-168 (a birth year inside the season's range,
  #   chosen from a decade grid). Registered as Planned before code (release 2).
  # 168 since 2026-11-21: +FR-169 (a declared country, its flag on the entry
  #   list and a „Kraj” filter). Registered as Planned before code (release 3).
  # 169 since 2026-11-22: +FR-171 (the EVF ranking's countries fill entries
  #   without one). FR-170 (release 4) is on its own branch; whichever lands
  #   second adds its one. Registered as Planned before code.
  # 170 since 2026-11-22: +FR-170 (a signed-in administrator edits an entry).
  #   Registered as Planned before code (release 4); landed after FR-171.
  # 171 since 2026-11-22: +FR-172 (the roster's nationality, one spelling,
  #   kept to the EVF ranking); landed after FR-170.
  # 172 since 2026-11-22: +FR-173 (the name list under the registration
  #   form's SURNAME box). Registered as Planned before code.
  # 173 since 2026-11-22: +FR-174 (an event's seed files follow its
  #   organiser's ranking; the EVF read keeps places). Registered as Planned
  #   before code (plan seeding-by-organiser-ranking, release 1).
  # 174 since 2026-11-22: +FR-175 (the entry list can show the ranking place,
  #   switched per event; plan seeding-by-organiser-ranking, release 2).
  # 175 since 2026-11-22: +FR-176 (the event revenue forecast, a report of
  #   declared fees opened by a per-event key; plan event-revenue-forecast).
  EXPECTED=175
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
