-- ---------------------------------------------------------------------------
-- Layer 5 (combined-pool ingestion fix, 2026-04-30):
-- vw_vcat_violation — admin-facing view of V-cat invariant violators.
--
-- Surfaces every tbl_result row whose tournament's enum_age_category
-- disagrees with the BY-derived V-cat from fn_age_category, plus the
-- formatted message produced by fn_vcat_violation_msg (Layer 2 helper).
-- Read-only; no mutation. Powers the admin tool (CLI + future UI).
--
-- This is the post-Layer-2 audit surface: while the trigger emits NOTICE
-- on each new write, this view is the snapshot of all current violations
-- and is what Layer 6's replay tool uses to drive the redo loop.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_vcat_violation AS
SELECT
    r.id_result,
    r.id_fencer,
    r.id_tournament,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    t.txt_code              AS tournament_code,
    t.enum_age_category     AS tournament_vcat,
    fn_age_category(
        f.int_birth_year::INT,
        EXTRACT(YEAR FROM s.dt_end)::INT
    )                       AS expected_vcat,
    EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
    e.txt_code              AS event_code,
    s.txt_code              AS season_code,
    fn_vcat_violation_msg(
        f.int_birth_year::INT,
        t.enum_age_category,
        EXTRACT(YEAR FROM s.dt_end)::INT,
        f.txt_surname || ' ' || f.txt_first_name,
        t.txt_code
    )                       AS violation_msg
  FROM tbl_result    r
  JOIN tbl_fencer    f ON f.id_fencer    = r.id_fencer
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_event     e ON e.id_event     = t.id_event
  JOIN tbl_season    s ON s.id_season    = e.id_season
 WHERE f.int_birth_year IS NOT NULL
   AND fn_age_category(f.int_birth_year::INT, EXTRACT(YEAR FROM s.dt_end)::INT) IS NOT NULL
   AND fn_age_category(f.int_birth_year::INT, EXTRACT(YEAR FROM s.dt_end)::INT)
       <> t.enum_age_category;

COMMENT ON VIEW vw_vcat_violation IS
  'Admin-facing snapshot of V-cat invariant violators. Used by Layer 5 '
  'admin tool and Layer 6 replay loop. Output: the same message text the '
  'Layer 2 trigger would emit, plus the row coordinates needed to fix it.';

GRANT SELECT ON vw_vcat_violation TO authenticated;
