-- =============================================================================
-- Phase 5.5 — vw_fencer_aliases extension: alias staging context + reviewed counts
-- =============================================================================
-- Adds 4 columns to vw_fencer_aliases for the new alias triage UX:
--   * latest_category_hint TEXT       — V0..V4 from the most recent (draft|live)
--                                        result for any of the fencer's aliases
--   * latest_season_end_year INT      — corresponding season's end year
--   * json_user_confirmed_aliases JSONB — passthrough so UI can decide per-alias
--                                          whether it's reviewed
--   * int_unreviewed_alias_count INT  — cardinality(name) - cardinality(name ∩ confirmed)
--
-- The latest-context resolution prefers tbl_result_draft (lives until commit)
-- over tbl_result (post-commit). Sourced via lateral join on a UNION ALL.
--
-- fn_list_fencer_aliases is republished with the extended TABLE signature.
--
-- Backwards-compatible: existing consumers reading only the original columns
-- are unaffected. Plan-test-ID 5.10. ADR amendment of ADR-050.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Extend vw_fencer_aliases — DROP first because column order changes
--    (CREATE OR REPLACE rejects column-position changes per Postgres rules).
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_fencer_aliases;

CREATE VIEW vw_fencer_aliases AS
WITH safe_aliases AS (
  SELECT
    f.id_fencer,
    f.txt_first_name,
    f.txt_surname,
    CASE
      WHEN jsonb_typeof(f.json_name_aliases) = 'array'
        THEN f.json_name_aliases
      ELSE '[]'::jsonb
    END AS json_name_aliases,
    CASE
      WHEN jsonb_typeof(f.json_revoked_aliases) = 'array'
        THEN f.json_revoked_aliases
      ELSE '[]'::jsonb
    END AS json_revoked_aliases,
    CASE
      WHEN jsonb_typeof(f.json_user_confirmed_aliases) = 'array'
        THEN f.json_user_confirmed_aliases
      ELSE '[]'::jsonb
    END AS json_user_confirmed_aliases,
    f.ts_updated AS ts_last_alias_added
  FROM tbl_fencer f
),
-- For each fencer, find the most-recent occurrence of any alias name
-- across drafts and live results. Drafts take precedence (more recent
-- staging context); fall back to live tbl_result.
context AS (
  SELECT DISTINCT ON (id_fencer)
    id_fencer,
    enum_age_category::TEXT AS category_hint,
    season_end_year
  FROM (
    -- Drafts first
    SELECT
      d.id_fencer,
      td.enum_age_category,
      EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
      td.dt_tournament,
      0 AS source_priority  -- drafts win when both exist
    FROM tbl_result_draft d
    JOIN tbl_tournament_draft td ON td.id_tournament_draft = d.id_tournament_draft
    JOIN tbl_event e             ON e.id_event = td.id_event
    JOIN tbl_season s            ON s.id_season = e.id_season
    WHERE d.id_fencer IS NOT NULL
      AND td.enum_age_category IS NOT NULL
    UNION ALL
    -- Live results
    SELECT
      r.id_fencer,
      t.enum_age_category,
      EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
      t.dt_tournament,
      1 AS source_priority
    FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e      ON e.id_event = t.id_event
    JOIN tbl_season s     ON s.id_season = e.id_season
    WHERE r.id_fencer IS NOT NULL
      AND t.enum_age_category IS NOT NULL
  ) ctx
  ORDER BY id_fencer, source_priority, dt_tournament DESC NULLS LAST
)
SELECT
  sa.id_fencer,
  sa.txt_first_name,
  sa.txt_surname,
  sa.json_name_aliases,
  sa.json_revoked_aliases,
  sa.json_user_confirmed_aliases,
  jsonb_array_length(sa.json_name_aliases) AS alias_count,
  -- int_unreviewed_alias_count = aliases - (aliases ∩ user_confirmed)
  GREATEST(
    0,
    jsonb_array_length(sa.json_name_aliases)
    - (
        SELECT COUNT(*)::INT
        FROM jsonb_array_elements_text(sa.json_name_aliases) AS a(name)
        WHERE EXISTS (
          SELECT 1
          FROM jsonb_array_elements_text(sa.json_user_confirmed_aliases) AS c(name)
          WHERE c.name = a.name
        )
      )
  ) AS int_unreviewed_alias_count,
  sa.ts_last_alias_added,
  ctx.category_hint AS latest_category_hint,
  ctx.season_end_year AS latest_season_end_year
FROM safe_aliases sa
LEFT JOIN context ctx ON ctx.id_fencer = sa.id_fencer;

COMMENT ON VIEW vw_fencer_aliases IS
  'Phase 5.5 — extended with alias staging context (latest_category_hint, '
  'latest_season_end_year), json_user_confirmed_aliases passthrough, and '
  'int_unreviewed_alias_count for unreviewed-first sort in the UI. '
  'Defensive against scalar/NULL JSONB. ADR-058 + plan-test-ID 5.10.';


-- ---------------------------------------------------------------------------
-- 2. fn_list_fencer_aliases — gain the 4 new columns in TABLE signature
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_list_fencer_aliases();

CREATE OR REPLACE FUNCTION fn_list_fencer_aliases()
RETURNS TABLE (
  id_fencer                    INT,
  txt_first_name               TEXT,
  txt_surname                  TEXT,
  json_name_aliases            JSONB,
  json_revoked_aliases         JSONB,
  json_user_confirmed_aliases  JSONB,
  alias_count                  INT,
  int_unreviewed_alias_count   INT,
  ts_last_alias_added          TIMESTAMPTZ,
  latest_category_hint         TEXT,
  latest_season_end_year       INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id_fencer, txt_first_name, txt_surname,
         json_name_aliases, json_revoked_aliases, json_user_confirmed_aliases,
         alias_count, int_unreviewed_alias_count,
         ts_last_alias_added,
         latest_category_hint, latest_season_end_year
    FROM vw_fencer_aliases
    -- Unreviewed first (DESC), then alphabetical
    ORDER BY int_unreviewed_alias_count DESC, alias_count DESC,
             txt_surname, txt_first_name;
$$;

REVOKE EXECUTE ON FUNCTION fn_list_fencer_aliases() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_list_fencer_aliases() TO authenticated;

COMMENT ON FUNCTION fn_list_fencer_aliases() IS
  'Phase 5.5 — extended return with latest staging context + reviewed counts. '
  'Default order is unreviewed-first (int_unreviewed_alias_count DESC) so the '
  'UI surfaces aliases needing operator action at the top. Plan-test-ID 5.10.';

COMMIT;
