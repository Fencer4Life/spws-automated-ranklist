#!/usr/bin/env bash
# =============================================================================
# Versioned season scoring — migration preflight over existing constants/data.
# =============================================================================
# Usage:  scripts/check-scoring-migration-preflight.sh <local|cert|prod>
#
# Implements §11 step 1 ("Contract tests and preflight") and the §11 hard gate
# ("Deployment preflight is a hard gate") of
# doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html.
#
# WHY THIS EXISTS.
#
# The versioned-scoring migration makes three assertions about data it did not
# write, and each one fails destructively if it is wrong in an environment it
# was not checked against:
#
#   1. §04 adds a CHECK that a result's place never exceeds its tournament's
#      participant count. A single violating row anywhere makes that migration
#      abort mid-deploy.
#   2. §04 assigns EVF_CLASSIC_V1_2025_2026 to every pre-2026/2027 season, and
#      that assignment is only truthful if those seasons were actually scored
#      with the flat base and the podium coefficients the classic engine
#      reproduces. Because those numbers are SEASON CONFIGURATION and not engine
#      constants, they must be READ per season, never assumed to be 50 / 3-2-1.
#   3. §11 forbids silently switching an already-scored season onto a new
#      engine. If the target season has scored results before the migration
#      lands, deployment stops.
#
# LOCAL passing proves nothing about CERT or PROD. That is the precise failure
# scripts/check-anon-allowlist-sync.sh exists to prevent for the anon allowlist:
# on 2026-09-12 pgTAP stayed green through the whole of CI and the disagreement
# surfaced in the deploy job, against the real database, blocking PROD. A data
# precondition has exactly the same shape, so RUN THIS AGAINST CERT AND PROD
# before the migration is promoted, not only against LOCAL.
#
# This script only ever reads. It runs no DDL and writes no row.
# =============================================================================

set -uo pipefail

TARGET="${1:-}"
case "$TARGET" in
  local|cert|prod) ;;
  *)
    echo "usage: scripts/check-scoring-migration-preflight.sh <local|cert|prod>" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# One way to run SQL against whichever environment was named, so the capability
# probe and the main query cannot reach different databases.
run_sql() {
  if [ "$TARGET" = "local" ]; then
    printf '%s' "$1" | docker exec -i "${SUPABASE_DB_CONTAINER:-supabase_db_SPWSranklist}" \
      psql -U postgres -d postgres -At -f - 2>&1
  else
    printf '%s' "$1" | "$REPO_ROOT/scripts/cloud-sql.sh" "$TARGET" 2>&1
  fi
}

# The season the field-scaled engine is being introduced for. The migration must
# not switch this season's engine if it already holds scored results.
TARGET_SEASON="${SCORING_TARGET_SEASON:-SPWS-2026-2027}"
# The engine that season is meant to end up on. SSP-06 treats scored results as
# safe when they were produced by this engine, and only as a blocker otherwise.
TARGET_ENGINE="${SCORING_TARGET_ENGINE:-SPWS_FIELD_SCALED_V1_2026_2027}"

# -----------------------------------------------------------------------------
# One query, one JSON array of probes. Kept as a single statement so it runs
# byte-identically through psql (LOCAL) and through the Management API
# (scripts/cloud-sql.sh), which is the only way this check can honestly claim to
# have asserted the same thing in all three environments.
#
# Each probe yields: code, verdict (PASS|FAIL|INFO), and a human detail string.
# -----------------------------------------------------------------------------
# THIS CHECK RUNS BEFORE THE MIGRATION IS DEPLOYED, so it must not name the
# objects that migration creates. Postgres resolves relations at PARSE time, so
# even a CASE guarded by to_regclass() fails on an environment where
# tbl_scoring_engine does not exist yet — which is every environment this check
# is most useful on. Probe first, then build SSP-06's engine lookup accordingly.
if [ "$TARGET" = "local" ]; then
  HAS_ENGINE=$(run_sql "SELECT to_regclass('public.tbl_scoring_engine') IS NOT NULL;")
else
  HAS_ENGINE=$(run_sql "SELECT to_regclass('public.tbl_scoring_engine') IS NOT NULL AS ok;" \
    | jq -r '.[0].ok // false' 2>/dev/null)
fi
case "$HAS_ENGINE" in
  t|true) ENGINE_LOOKUP="(SELECT e2.txt_code FROM tbl_season s2 LEFT JOIN tbl_scoring_engine e2 ON e2.id_engine = s2.id_scoring_engine WHERE s2.txt_code = '${TARGET_SEASON}')" ;;
  *)      ENGINE_LOOKUP="NULL::TEXT" ;;
esac

read -r -d '' SQL <<SQLEOF
WITH
-- SSP-01 — §04: place > N blocks the CHECK constraint.
p01 AS (
  SELECT count(*) AS n
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE r.int_place > t.int_participant_count
),
-- SSP-02 — §04: place < 1 is invalid input, rejected rather than scored.
p02 AS (
  SELECT count(*) AS n FROM tbl_result WHERE int_place < 1
),
-- SSP-03 — §04: the classic engine reproduces a FLAT base. Assigning it to a
-- historical season is only truthful if that season's stored configuration is
-- the one the engine reproduces. Read per season; assume nothing.
p03 AS (
  SELECT count(*) AS n,
         coalesce(string_agg(
           s.txt_code || ' (mp=' || c.int_mp_value ||
           ', podium=' || c.int_podium_gold || '/' || c.int_podium_silver ||
           '/' || c.int_podium_bronze || ')', '; ' ORDER BY s.txt_code), '') AS detail
    FROM tbl_season s
    JOIN tbl_scoring_config c ON c.id_season = s.id_season
   WHERE s.txt_code < '${TARGET_SEASON}'
     AND (c.int_mp_value <> 50 OR c.int_podium_gold <> 3
          OR c.int_podium_silver <> 2 OR c.int_podium_bronze <> 1)
),
-- SSP-04 — §02/§07 fail-closed precondition: every tournament type that
-- actually carries rows must resolve to a NON-NULL multiplier in its own
-- season's configuration. The six-way CASE has no ELSE, so a type it does not
-- list writes num_final_score = NULL with no exception raised.
types_in_use AS (
  SELECT DISTINCT s.id_season, s.txt_code AS season_code, t.enum_type
    FROM tbl_tournament t
    JOIN tbl_event e  ON e.id_event  = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
),
p04 AS (
  SELECT count(*) AS n,
         coalesce(string_agg(u.season_code || '/' || u.enum_type, '; '
                             ORDER BY u.season_code, u.enum_type), '') AS detail
    FROM types_in_use u
    LEFT JOIN tbl_scoring_config c ON c.id_season = u.id_season
   WHERE CASE u.enum_type
           WHEN 'PPW' THEN c.num_ppw_multiplier
           WHEN 'MPW' THEN c.num_mpw_multiplier
           WHEN 'PEW' THEN c.num_pew_multiplier
           WHEN 'MEW' THEN c.num_mew_multiplier
           WHEN 'MSW' THEN c.num_msw_multiplier
           WHEN 'PSW' THEN c.num_psw_multiplier
         END IS NULL
),
-- SSP-05 — INFO. Empty brackets carry N = 0 and no result rows. Recorded so
-- that nobody proposes a blanket CHECK (int_participant_count >= 1): it would
-- abort against live rows. A place <= N constraint on tbl_result is unaffected,
-- because these tournaments hold no results at all.
p05 AS (
  SELECT count(*) AS n,
         count(*) FILTER (WHERE res.c > 0) AS with_results
    FROM tbl_tournament t
    CROSS JOIN LATERAL (
      SELECT count(*) AS c FROM tbl_result r WHERE r.id_tournament = t.id_tournament
    ) res
   WHERE t.int_participant_count IS NULL OR t.int_participant_count < 1
),
-- SSP-06 — §11 hard gate: never switch an ALREADY-SCORED season's engine.
--
-- The condition is not "no scored result" but "no scored result under a
-- DIFFERENT engine". Once the season is already assigned the engine this
-- migration intends, scoring against it is the expected steady state, not a
-- blocker — and on LOCAL that is exactly what the PPW1 test fixture produces.
-- This mirrors the guard inside fn_backfill_scoring_engines() so the preflight
-- and the migration cannot disagree about what is safe.
p06 AS (
  SELECT count(*) AS n,
         ${ENGINE_LOOKUP} AS assigned
    FROM tbl_tournament t
    JOIN tbl_event e  ON e.id_event  = t.id_event
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_result r ON r.id_tournament = t.id_tournament
   WHERE s.txt_code = '${TARGET_SEASON}'
     AND r.ts_points_calc IS NOT NULL
),
-- SSP-07 — §02: the silent-NULL leak. A scored result with no final score is
-- the signature of the multiplier CASE falling through.
p07 AS (
  SELECT count(*) AS n
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.enum_import_status = 'SCORED' AND r.num_final_score IS NULL
),
-- SSP-08 — §04: num_podium_bonus carries no place > N guard, so an
-- out-of-range place can still collect a podium bonus. Counts rows where that
-- has actually happened.
p08 AS (
  SELECT count(*) AS n
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE r.int_place > t.int_participant_count
     AND coalesce(r.num_podium_bonus, 0) <> 0
),
-- SSP-09 — INFO. The exact per-season multiplier set the normalized type
-- policy must migrate. These differ between seasons; defaults would be wrong.
p09 AS (
  SELECT coalesce(string_agg(
           s.txt_code || ': ppw=' || c.num_ppw_multiplier || ' mpw=' || c.num_mpw_multiplier ||
           ' pew=' || c.num_pew_multiplier || ' mew=' || c.num_mew_multiplier ||
           ' msw=' || c.num_msw_multiplier || ' psw=' || c.num_psw_multiplier ||
           ' min_ppw=' || c.int_min_participants_ppw || ' min_evf=' || c.int_min_participants_evf,
           ' | ' ORDER BY s.txt_code), '(no scoring config rows)') AS detail
    FROM tbl_season s JOIN tbl_scoring_config c ON c.id_season = s.id_season
)
SELECT json_agg(x ORDER BY x.code) AS probes FROM (
  SELECT 'SSP-01' AS code,
         CASE WHEN p01.n = 0 THEN 'PASS' ELSE 'FAIL' END AS verdict,
         p01.n || ' tbl_result row(s) with place > participant count'
           || CASE WHEN p01.n = 0 THEN ' — the §04 CHECK can be added safely'
                   ELSE ' — the §04 CHECK WOULD ABORT; repair these rows first' END AS detail
    FROM p01
  UNION ALL
  SELECT 'SSP-02', CASE WHEN p02.n = 0 THEN 'PASS' ELSE 'FAIL' END,
         p02.n || ' tbl_result row(s) with place < 1' FROM p02
  UNION ALL
  SELECT 'SSP-03', CASE WHEN p03.n = 0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN p03.n = 0
              THEN 'every pre-${TARGET_SEASON} season stores the flat base the classic engine reproduces (mp=50, podium 3/2/1)'
              ELSE p03.n || ' season(s) deviate and need their own frozen engine rather than silent coercion: ' || p03.detail
         END FROM p03
  UNION ALL
  SELECT 'SSP-04', CASE WHEN p04.n = 0 THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN p04.n = 0
              THEN 'every tournament type in use resolves to a non-NULL multiplier in its own season'
              ELSE p04.n || ' season/type pair(s) resolve to NULL and would write NULL scores: ' || p04.detail
         END FROM p04
  UNION ALL
  SELECT 'SSP-05', 'INFO',
         p05.n || ' tournament(s) with participant count < 1, of which ' || p05.with_results ||
         ' hold result rows — a blanket CHECK (int_participant_count >= 1) would abort against these'
    FROM p05
  UNION ALL
  SELECT 'SSP-06',
         CASE WHEN p06.n = 0 OR p06.assigned = '${TARGET_ENGINE}' THEN 'PASS' ELSE 'FAIL' END,
         CASE WHEN p06.n = 0
              THEN '${TARGET_SEASON} holds no scored result — its engine may still be assigned'
              WHEN p06.assigned = '${TARGET_ENGINE}'
              THEN '${TARGET_SEASON} holds ' || p06.n || ' scored result(s), already under ${TARGET_ENGINE} — expected steady state, not a blocker'
              ELSE '${TARGET_SEASON} already holds ' || p06.n || ' scored result(s) under ' || coalesce(p06.assigned, 'NO ENGINE')
                   || ' — §11 forbids switching its engine; deployment must stop'
         END FROM p06
  UNION ALL
  SELECT 'SSP-07', CASE WHEN p07.n = 0 THEN 'PASS' ELSE 'FAIL' END,
         p07.n || ' result row(s) in SCORED tournaments carry a NULL final score' FROM p07
  UNION ALL
  SELECT 'SSP-08', CASE WHEN p08.n = 0 THEN 'PASS' ELSE 'FAIL' END,
         p08.n || ' out-of-range place(s) currently hold a non-zero podium bonus' FROM p08
  UNION ALL
  SELECT 'SSP-09', 'INFO',
         'per-season values the normalized type policy must migrate EXACTLY -- ' || p09.detail FROM p09
) x;
SQLEOF

if [ "$TARGET" = "local" ] \
   && ! docker ps --format '{{.Names}}' 2>/dev/null \
        | grep -qx "${SUPABASE_DB_CONTAINER:-supabase_db_SPWSranklist}"; then
  echo "ERROR: local database container is not running." >&2
  echo "       Start the stack (supabase start) or set SUPABASE_DB_CONTAINER." >&2
  exit 2
fi

echo "=== Versioned-scoring migration preflight — target: $(echo "$TARGET" | tr '[:lower:]' '[:upper:]') ==="
echo "    introducing season: ${TARGET_SEASON}"
echo ""

if [ "$TARGET" = "local" ]; then
  PROBES=$(run_sql "$SQL")
  STATUS=$?
else
  PROBES=$(run_sql "$SQL" | jq -r '.[0].probes // empty' 2>/dev/null)
  STATUS=$?
fi

if [ $STATUS -ne 0 ] || [ -z "${PROBES// /}" ]; then
  echo "ERROR: preflight query failed against ${TARGET}:" >&2
  echo "$PROBES" >&2
  exit 1
fi

FAILED=0
while IFS=$'\t' read -r code verdict detail; do
  [ -z "$code" ] && continue
  printf '  %-6s %-4s  %s\n' "$code" "$verdict" "$detail"
  [ "$verdict" = "FAIL" ] && FAILED=1
done < <(printf '%s' "$PROBES" | jq -r '.[] | [.code, .verdict, .detail] | @tsv')

echo ""
if [ $FAILED -eq 1 ]; then
  echo "PREFLIGHT FAILED against ${TARGET} — do not promote the versioned-scoring"
  echo "migration to this environment until every FAIL above is resolved."
  exit 1
fi

echo "Preflight clean against ${TARGET}."
echo "This asserts ONE environment. CERT and PROD must each be checked on their own"
echo "before promotion — LOCAL being clean is not evidence about either."
