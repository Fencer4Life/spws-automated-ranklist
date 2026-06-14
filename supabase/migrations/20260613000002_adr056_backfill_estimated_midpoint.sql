-- =============================================================================
-- ADR-056 — one-time backfill: re-midpoint existing ESTIMATED birth years
-- =============================================================================
-- Stage-0 reconciliation (2026-06-13) changes the birth-year ESTIMATE
-- convention from the band youngest-edge to the band MIDPOINT anchor
-- (V0→35, V1→45, V2→55, V3→65, V4→75; BY = season_end − anchor). This
-- migration brings already-stored `bool_birth_year_estimated = TRUE` fencers
-- onto the new convention so the data is internally consistent.
--
-- RANKING-NEUTRAL BY CONSTRUCTION. The ranklist derives a fencer's category
-- per season via fn_age_category(int_birth_year, EXTRACT(YEAR FROM s.dt_end))
-- joined through e.id_season (see fn_ranking_ppw). This UPDATE rewrites a BY
-- ONLY when fn_age_category is UNCHANGED for EVERY season the fencer has a
-- result in — so no result can move between rankings. Boundary fencers whose
-- midpoint would cross a band are left untouched (conservative skip).
--
-- IDEMPOTENT: once a BY equals its band midpoint, re-deriving the midpoint at
-- the same reference yields the same value, so a re-run changes nothing.
--
-- The audit trigger (trg_audit_fencer) records every change, preserving the
-- prior value for restore.
-- =============================================================================

WITH refyear AS (
  SELECT MAX(EXTRACT(YEAR FROM dt_end))::INT AS global_ref FROM tbl_season
),
cand AS (
  -- Reference year per fencer: the latest season they have a result in
  -- (the season that currently governs their active category), else the
  -- newest season in the DB for result-less estimated fencers.
  SELECT
    f.id_fencer,
    f.int_birth_year AS old_by,
    COALESCE(
      (SELECT MAX(EXTRACT(YEAR FROM s.dt_end))::INT
         FROM tbl_result r
         JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
         JOIN tbl_event e      ON e.id_event = t.id_event
         JOIN tbl_season s     ON s.id_season = e.id_season
        WHERE r.id_fencer = f.id_fencer),
      (SELECT global_ref FROM refyear)
    ) AS ref_year
  FROM tbl_fencer f
  WHERE f.bool_birth_year_estimated = TRUE
    AND f.int_birth_year IS NOT NULL
),
cand2 AS (
  SELECT
    id_fencer, old_by, ref_year,
    ref_year - CASE fn_age_category(old_by, ref_year)
      WHEN 'V0' THEN 35
      WHEN 'V1' THEN 45
      WHEN 'V2' THEN 55
      WHEN 'V3' THEN 65
      WHEN 'V4' THEN 75
      ELSE NULL
    END AS new_by
  FROM cand
)
UPDATE tbl_fencer f
SET int_birth_year = c.new_by,
    ts_updated = NOW()
FROM cand2 c
WHERE f.id_fencer = c.id_fencer
  AND c.new_by IS NOT NULL
  AND c.new_by <> c.old_by
  -- Neutrality guard: skip if any result-season's category would change.
  AND NOT EXISTS (
    SELECT 1
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event = t.id_event
    JOIN tbl_season s     ON s.id_season = e.id_season
    WHERE r.id_fencer = c.id_fencer
      AND fn_age_category(c.new_by, EXTRACT(YEAR FROM s.dt_end)::INT)
          IS DISTINCT FROM
          fn_age_category(c.old_by, EXTRACT(YEAR FROM s.dt_end)::INT)
  );
