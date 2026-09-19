#!/usr/bin/env bash
# =============================================================================
# LOCAL-ONLY TEST FIXTURE — PPW1 2026/2027 from last season's placements.
# =============================================================================
# Usage:
#   scripts/local-fixture-ppw1-2026-2027.sh            # create (idempotent)
#   scripts/local-fixture-ppw1-2026-2027.sh --remove   # delete it again
#   scripts/local-fixture-ppw1-2026-2027.sh --report   # compare the two engines
#
# WHY THIS EXISTS.
#
# SPWS-2026-2027 is the first season assigned SPWS_FIELD_SCALED_V1_2026_2027 and
# it holds no results yet, so on LOCAL the new engine had nothing real to score.
# This copies the 23 PPW1 brackets and 85 placements of PPW1-2025-2026 onto the
# already-existing PPW1-2026-2027 calendar row and scores them with the new
# engine, so the ranklist, drilldown, export and calculator can all be exercised
# against realistic data before the real results arrive.
#
# PPW1 is an unusually good probe for this change. Its fields run from 1 to 11
# competitors, every one of them below the N = 32 crossover where the two
# engines converge, so EVERY bracket scores differently. Six of the 23 are
# one-competitor walkovers — the ADR-066 case that §04 re-prices from 59 to 19.
#
# THIS IS TEST DATA AND IT MUST NEVER LEAVE LOCAL.
#
#   * It is NOT a migration and NOT in any seed file, so no deploy carries it.
#   * It talks only to the local Docker container, never through cloud-sql.sh,
#     and refuses to run if that container is absent.
#   * `./scripts/reset-dev.sh` wipes it, because it is not in the seed dump.
#     Re-run this script afterwards if you still want it.
#   * `--remove` deletes exactly what it created and nothing else.
#
# THE REAL RESULTS, ~29 SEPTEMBER 2026. The real PPW1 2026/2027 results will be
# ingested on CERT and promoted to PROD by the ordinary path. They will use these
# same canonical tournament codes. Run --remove on LOCAL before ingesting the
# real ones there, or reset LOCAL, so the two can never be confused.
#
# ONE CONSEQUENCE TO EXPECT. Once this fixture is scored, LOCAL's
# SPWS-2026-2027 holds scored results, so probe SSP-06 of
# scripts/check-scoring-migration-preflight.sh changes its answer for LOCAL.
# That is correct: the season is already assigned the intended engine, which is
# the condition §11 actually requires, and the probe reports it that way.
# =============================================================================

set -uo pipefail

CONTAINER="${SUPABASE_DB_CONTAINER:-supabase_db_SPWSranklist}"
SRC_EVENT="PPW1-2025-2026"
DST_EVENT="PPW1-2026-2027"
MODE="create"

case "${1:-}" in
  --remove) MODE="remove" ;;
  --report) MODE="report" ;;
  "")       MODE="create" ;;
  *) echo "usage: $0 [--remove|--report]" >&2; exit 2 ;;
esac

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  echo "ERROR: local database container '$CONTAINER' is not running." >&2
  echo "       This script is LOCAL-ONLY and has no remote mode by design." >&2
  exit 2
fi

psql_local() { docker exec -i "$CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"; }

# A last guard against a container that is somehow not the disposable local one.
GUARD=$(psql_local -At -c "SELECT current_setting('server_version_num') IS NOT NULL AND inet_server_addr() IS NULL;" 2>/dev/null)
if [ "$GUARD" != "t" ]; then
  echo "WARNING: could not confirm this is a local unix-socket connection; continuing against '$CONTAINER'." >&2
fi

# -----------------------------------------------------------------------------
remove_sql() {
cat <<SQL
DO \$remove\$
DECLARE v_event INT; v_n INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = '${DST_EVENT}';
  IF v_event IS NULL THEN RAISE NOTICE 'no ${DST_EVENT} event; nothing to remove'; RETURN; END IF;

  DELETE FROM tbl_result r USING tbl_tournament t
   WHERE t.id_tournament = r.id_tournament AND t.id_event = v_event;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'removed % result row(s)', v_n;

  DELETE FROM tbl_tournament t WHERE t.id_event = v_event;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'removed % tournament(s)', v_n;

  -- Walk the status back to PLANNED, the state the calendar row was found in.
  -- One step at a time: the transition trigger rejects a jump.
  IF (SELECT enum_status FROM tbl_event WHERE id_event = v_event) = 'SCORED' THEN
    UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE id_event = v_event;
  END IF;
  IF (SELECT enum_status FROM tbl_event WHERE id_event = v_event) = 'IN_PROGRESS' THEN
    UPDATE tbl_event SET enum_status = 'PLANNED' WHERE id_event = v_event;
  END IF;
  RAISE NOTICE 'event restored to %', (SELECT enum_status FROM tbl_event WHERE id_event = v_event);
END
\$remove\$;
SQL
}

create_sql() {
cat <<SQL
DO \$fixture\$
DECLARE
  v_src_event INT;
  v_dst_event INT;
  v_dst_start DATE;
  v_t         RECORD;
  v_new_t     INT;
  v_tourns    INT := 0;
  v_results   INT := 0;
  v_n         INT;
BEGIN
  SELECT id_event INTO v_src_event FROM tbl_event WHERE txt_code = '${SRC_EVENT}';
  SELECT id_event, dt_start INTO v_dst_event, v_dst_start
    FROM tbl_event WHERE txt_code = '${DST_EVENT}';

  IF v_src_event IS NULL THEN
    RAISE EXCEPTION 'source event ${SRC_EVENT} not found — is the seed loaded?';
  END IF;
  IF v_dst_event IS NULL THEN
    RAISE EXCEPTION 'target event ${DST_EVENT} not found — expected the calendar row to exist already';
  END IF;

  FOR v_t IN
    SELECT t.* FROM tbl_tournament t WHERE t.id_event = v_src_event ORDER BY t.txt_code
  LOOP
    INSERT INTO tbl_tournament (
      id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
      enum_age_category, dt_tournament, int_participant_count, enum_import_status)
    VALUES (
      v_dst_event,
      replace(v_t.txt_code, '2025-2026', '2026-2027'),
      v_t.txt_name || ' [LOCAL TEST FIXTURE]',
      v_t.enum_type, v_t.enum_weapon, v_t.enum_gender, v_t.enum_age_category,
      v_dst_start, v_t.int_participant_count, 'IMPORTED')
    RETURNING id_tournament INTO v_new_t;
    v_tourns := v_tourns + 1;

    -- enum_source_age_category carries the SOURCE BRACKET LABEL, which is what
    -- real ingestion writes and what ADR-056's "bracket-label wins" revision
    -- asks for. Without it, trg_assert_result_vcat re-derives each fencer's
    -- category from birth year against the NEW season's end year, and anyone
    -- who aged into the next category between the two seasons would be rejected
    -- — the precise cross-season conflict that revision exists to prevent.
    INSERT INTO tbl_result (
      id_fencer, id_tournament, int_place, enum_fencer_age_category,
      enum_source_age_category, txt_scraped_name, num_match_confidence,
      enum_match_method)
    SELECT r.id_fencer, v_new_t, r.int_place, v_t.enum_age_category,
           v_t.enum_age_category, r.txt_scraped_name, r.num_match_confidence,
           r.enum_match_method
      FROM tbl_result r
     WHERE r.id_tournament = v_t.id_tournament;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_results := v_results + v_n;

    PERFORM fn_calc_tournament_scores(v_new_t);
  END LOOP;

  -- The event must leave PLANNED or its results are invisible to the ranking.
  -- vw_eligible_event excludes CREATED/PLANNED/SCHEDULED/CHANGED/CANCELLED, so a
  -- PLANNED event holding scored results contributes nothing — which is correct:
  -- an event with results in it is no longer merely planned. Real ingestion
  -- advances the status the same way, and the transition trigger requires the
  -- sequence to be walked one step at a time rather than jumped.
  IF (SELECT enum_status FROM tbl_event WHERE id_event = v_dst_event) = 'PLANNED' THEN
    UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE id_event = v_dst_event;
  END IF;
  IF (SELECT enum_status FROM tbl_event WHERE id_event = v_dst_event) = 'IN_PROGRESS' THEN
    UPDATE tbl_event SET enum_status = 'SCORED' WHERE id_event = v_dst_event;
  END IF;

  RAISE NOTICE 'created and scored % tournament(s), % result row(s); event now %',
    v_tourns, v_results, (SELECT enum_status FROM tbl_event WHERE id_event = v_dst_event);
END
\$fixture\$;
SQL
}

report_sql() {
cat <<SQL
SELECT
  regexp_replace(t.txt_code, '-2026-2027\$', '')       AS bracket,
  t.int_participant_count                             AS n,
  old.num_final_score                                 AS classic_2025_26,
  new.num_final_score                                 AS field_scaled_2026_27,
  ROUND(new.num_final_score - old.num_final_score, 2) AS delta,
  ROUND(100 * (new.num_final_score - old.num_final_score) / NULLIF(old.num_final_score, 0), 1) AS pct
FROM tbl_tournament t
JOIN tbl_event e   ON e.id_event = t.id_event AND e.txt_code = '${DST_EVENT}'
JOIN tbl_result new ON new.id_tournament = t.id_tournament AND new.int_place = 1
JOIN tbl_tournament ot ON ot.txt_code = replace(t.txt_code, '2026-2027', '2025-2026')
JOIN tbl_result old ON old.id_tournament = ot.id_tournament AND old.int_place = 1
ORDER BY t.int_participant_count, bracket;

WITH brackets AS (
  SELECT t.id_tournament, t.txt_code, t.int_participant_count AS n
    FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event AND e.txt_code = '${DST_EVENT}'
),
placements AS (
  SELECT b.id_tournament, new.int_place, new.num_final_score AS new_score,
         old.num_final_score AS old_score
    FROM brackets b
    JOIN tbl_result new ON new.id_tournament = b.id_tournament
    JOIN tbl_tournament ot ON ot.txt_code = replace(b.txt_code, '2026-2027', '2025-2026')
    JOIN tbl_result old ON old.id_tournament = ot.id_tournament
                       AND old.int_place = new.int_place
)
SELECT (SELECT count(*) FROM brackets)                                AS brackets,
       (SELECT sum(n) FROM brackets)                                  AS competitors,
       (SELECT count(*) FROM brackets WHERE n = 1)                    AS walkovers,
       (SELECT count(*) FROM placements)                              AS placements,
       ROUND((SELECT sum(old_score) FROM placements), 2)              AS classic_total,
       ROUND((SELECT sum(new_score) FROM placements), 2)              AS field_scaled_total,
       ROUND(100 * ((SELECT sum(new_score) FROM placements)
                  - (SELECT sum(old_score) FROM placements))
             / NULLIF((SELECT sum(old_score) FROM placements), 0), 1) AS pct;
SQL
}

echo "=== PPW1 2026/2027 LOCAL test fixture — mode: ${MODE} ==="
echo "    LOCAL ONLY. Not a migration, not in any seed. reset-dev.sh wipes it."
echo ""

case "$MODE" in
  remove)
    remove_sql | psql_local -q -f - && echo "" && echo "Fixture removed."
    ;;
  report)
    report_sql | psql_local -P pager=off -f -
    ;;
  create)
    # Idempotent: clear anything a previous run left before recreating.
    remove_sql | psql_local -q -f - || exit 1
    create_sql | psql_local -q -f - || exit 1
    echo ""
    report_sql | psql_local -P pager=off -f -
    echo ""
    echo "Done. Remove it again with: scripts/local-fixture-ppw1-2026-2027.sh --remove"
    ;;
esac
