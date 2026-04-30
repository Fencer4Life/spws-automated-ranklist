"""
Layer 6 (combined-pool ingestion fix, 2026-04-30):
in-DB redo of V-cat invariant violations.

Strategy: for each row R in vw_vcat_violation that has a sibling tournament
under the same (event, weapon, gender) at the expected V-cat:
  * if the same fencer already has a row in the target tournament → DELETE R
    (combined-pool corruption produced a duplicate)
  * else → UPDATE R.id_tournament to the target

After moves/deletes, re-rank every affected tournament by current int_place
ASC (1..N) and call fn_calc_tournament_scores to refresh num_final_score.

Rows whose expected V-cat has NO sibling tournament under the event are
skipped (admin must create the sibling first; reported on stderr).

Operates as a single transaction. --dry-run prints the plan without
writing. --execute applies. Default is dry-run.

LOCAL only by default; --remote cert|prod uses Supabase Management API.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import httpx


CERT_REF = "sdomfjncmfydlkygzpgw"
PROD_REF = "ywgymtgcyturldazcpmw"


def _exec_sql(env: str, ref: str, token: str, sql_url: str, sql_key: str, sql: str) -> list[dict]:
    """Execute a SQL statement against LOCAL (PostgREST RPC-style) or via
    Management API (cloud). For LOCAL we go through a single SQL endpoint
    that's not generally exposed — so we keep cloud and local on the same
    Management-API surface (both work locally if user provides a token + ref).
    Simpler: for LOCAL we shell out to docker exec psql via the caller. This
    helper is only used for cloud.
    """
    resp = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "curl/8.7.1",
        },
        json={"query": sql},
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()


def build_replay_sql(execute: bool) -> str:
    """Return the single-transaction SQL script that does the replay.

    The script is the same for dry-run vs execute — `execute` only swaps
    the trailing COMMIT/ROLLBACK so dry-run leaves the DB untouched while
    still surfacing the per-step row counts via the temporary tables.
    """
    closing = "COMMIT;" if execute else "ROLLBACK;"
    return f"""
BEGIN;

-- 1. Snapshot the violator → target mapping.
CREATE TEMPORARY TABLE _replay_plan ON COMMIT DROP AS
SELECT
    v.id_result, v.id_fencer, v.id_tournament AS src_tour,
    v.tournament_code AS src_code,
    sib.id_tournament AS dst_tour,
    sib.txt_code      AS dst_code
  FROM vw_vcat_violation v
  JOIN tbl_tournament src ON src.id_tournament = v.id_tournament
  LEFT JOIN tbl_tournament sib
    ON sib.id_event       = src.id_event
   AND sib.enum_weapon    = src.enum_weapon
   AND sib.enum_gender    = src.enum_gender
   AND sib.enum_age_category = v.expected_vcat;

-- 2. Mark dupes. Two cases:
--    (a) the fencer already has a clean row in the destination tournament, OR
--    (b) multiple violator rows for the same fencer all target the same dst
--        (combined pool that ran across 3+ V-cats). Keep the one with the
--        lowest existing int_place; delete the rest.
CREATE TEMPORARY TABLE _replay_dupes ON COMMIT DROP AS
WITH p_meta AS (
    SELECT p.*, r.int_place
      FROM _replay_plan p
      JOIN tbl_result r ON r.id_result = p.id_result
     WHERE p.dst_tour IS NOT NULL
), pre_existing AS (
    SELECT pm.id_result
      FROM p_meta pm
     WHERE EXISTS (
        SELECT 1 FROM tbl_result r2
         WHERE r2.id_tournament = pm.dst_tour
           AND r2.id_fencer     = pm.id_fencer
           AND r2.id_result    <> pm.id_result
     )
), self_collision AS (
    SELECT id_result
      FROM (
        SELECT pm.id_result,
               ROW_NUMBER() OVER (
                   PARTITION BY pm.dst_tour, pm.id_fencer
                   ORDER BY pm.int_place ASC, pm.id_result ASC
               ) AS rn
          FROM p_meta pm
         WHERE pm.id_result NOT IN (SELECT id_result FROM pre_existing)
      ) ranked
     WHERE rn > 1
)
SELECT id_result FROM pre_existing
UNION
SELECT id_result FROM self_collision;

-- 3. Skip rows with no sibling at the expected V-cat.
CREATE TEMPORARY TABLE _replay_orphans ON COMMIT DROP AS
SELECT p.id_result, p.src_code, p.id_fencer
  FROM _replay_plan p
 WHERE p.dst_tour IS NULL;

-- 4. Movable rows: have target, not a duplicate.
CREATE TEMPORARY TABLE _replay_moves ON COMMIT DROP AS
SELECT p.id_result, p.src_tour, p.dst_tour
  FROM _replay_plan p
 WHERE p.dst_tour IS NOT NULL
   AND p.id_result NOT IN (SELECT id_result FROM _replay_dupes);

-- 5. Affected tournaments — for the rerank step. Source AND destination of every move,
--    plus source of every dupe (delete shrinks src_tour's row set).
CREATE TEMPORARY TABLE _replay_touched_tours ON COMMIT DROP AS
SELECT DISTINCT t FROM (
    SELECT src_tour AS t FROM _replay_moves
    UNION
    SELECT dst_tour AS t FROM _replay_moves
    UNION
    SELECT p.src_tour AS t FROM _replay_plan p
      JOIN _replay_dupes d ON d.id_result = p.id_result
) s;

-- Plan totals (always emitted, even on dry-run).
SELECT
    (SELECT COUNT(*) FROM _replay_plan)         AS plan_rows,
    (SELECT COUNT(*) FROM _replay_moves)        AS moves,
    (SELECT COUNT(*) FROM _replay_dupes)        AS dupes_to_delete,
    (SELECT COUNT(*) FROM _replay_orphans)      AS orphans_skipped,
    (SELECT COUNT(*) FROM _replay_touched_tours) AS tournaments_touched;

-- 6. Apply moves + deletes (only matters for execute; rolled back on dry-run).
-- tbl_match_candidate FKs id_result without CASCADE — clean up dependents
-- first so the result delete doesn't trip the constraint.
DELETE FROM tbl_match_candidate
 WHERE id_result IN (SELECT id_result FROM _replay_dupes);

DELETE FROM tbl_result WHERE id_result IN (SELECT id_result FROM _replay_dupes);

UPDATE tbl_result r
   SET id_tournament = m.dst_tour
  FROM _replay_moves m
 WHERE r.id_result = m.id_result;

-- 7. Re-rank every affected tournament: order by current int_place ASC,
--    renumber 1..N. (Stable on ties via id_result as tiebreaker.)
WITH ranked AS (
    SELECT r.id_result,
           ROW_NUMBER() OVER (
               PARTITION BY r.id_tournament
               ORDER BY r.int_place ASC, r.id_result ASC
           ) AS new_place
      FROM tbl_result r
     WHERE r.id_tournament IN (SELECT t FROM _replay_touched_tours)
)
UPDATE tbl_result r
   SET int_place = k.new_place
  FROM ranked k
 WHERE r.id_result = k.id_result
   AND r.int_place IS DISTINCT FROM k.new_place;

-- 8. Backfill int_participant_count where it's NULL (newly created sibling
--    tournaments don't have one). Use the count of result rows after the
--    move/dedupe; this is the SPWS-fencer count and the best approximation
--    we have without re-scraping the original combined-pool source.
UPDATE tbl_tournament t
   SET int_participant_count = (
       SELECT COUNT(*) FROM tbl_result r WHERE r.id_tournament = t.id_tournament
   )
 WHERE t.id_tournament IN (SELECT t FROM _replay_touched_tours)
   AND t.int_participant_count IS NULL
   AND EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament);

-- 9. Recompute scores for every affected tournament that has results.
DO $rescore$
DECLARE
  v_t INT;
BEGIN
  FOR v_t IN
      SELECT t FROM _replay_touched_tours
       WHERE EXISTS (SELECT 1 FROM tbl_result r WHERE r.id_tournament = t)
  LOOP
    PERFORM fn_calc_tournament_scores(v_t);
  END LOOP;
END;
$rescore$;

{closing}
"""


def render_orphans_for_admin(rows: list[dict]) -> str:
    if not rows:
        return ""
    lines = [f"\nWARN: {len(rows)} violators have NO sibling tournament at the expected V-cat:"]
    for r in rows[:25]:
        lines.append(f"  src={r['src_code']} (id_result={r['id_result']}, id_fencer={r['id_fencer']})")
    if len(rows) > 25:
        lines.append(f"  ... and {len(rows) - 25} more")
    lines.append("Admin must create the sibling tournament(s) first, then re-run the replay.")
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dry-run", action="store_true", default=True,
                   help="Print plan + counts; don't apply (default).")
    p.add_argument("--execute", action="store_true",
                   help="Apply the plan in a single transaction. Mutually exclusive with --dry-run.")
    p.add_argument("--remote", choices=["local", "cert", "prod"], default="local")
    args = p.parse_args()

    if args.execute:
        args.dry_run = False

    if args.remote != "local":
        token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
        if not token:
            tf = os.path.expanduser("~/.supabase_token")
            if os.path.exists(tf):
                with open(tf) as f:
                    token = f.read().strip()
        if not token:
            print("ERROR: SUPABASE_ACCESS_TOKEN required for cert|prod", file=sys.stderr)
            return 1
        ref = CERT_REF if args.remote == "cert" else PROD_REF
        sql = build_replay_sql(execute=args.execute)
        rows = _exec_sql(args.remote, ref, token, "", "", sql)
        # Management API returns the LAST result-set; we want the SELECT
        # totals which are emitted before the writes — so embed them in a
        # CTE the caller can introspect. For now, just print whatever came back.
        print(json.dumps(rows, indent=2))
        return 0

    # LOCAL: pipe through docker exec.
    import subprocess
    sql = build_replay_sql(execute=args.execute)
    cmd = [
        "docker", "exec", "-i", "supabase_db_SPWSranklist",
        "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1",
    ]
    print(f"Running replay {'(EXECUTE)' if args.execute else '(DRY-RUN)'} on LOCAL...",
          file=sys.stderr)
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        return res.returncode
    print(res.stdout)
    if res.stderr:
        print(res.stderr, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
