-- =============================================================================
-- Phase 5.5 (5.18.D) — vw_fencer_aliases.latest_source_bracket_url
-- =============================================================================
-- Plan-test-ID 5.18.D. Companion to 20260503000007 (which added
-- latest_source_category_hint).
--
-- Adds the source-bracket URL to the view + RPC signature. The frontend
-- modal renders this as "verify on FTL ↗" so the operator can confirm
-- the V-cat on FTL before confirming the new fencer's BY.
--
-- Source: tbl_tournament_draft.txt_source_url_used (drafts) /
--         tbl_tournament.txt_source_url_used        (live).
-- The URL is the actual fetched endpoint, e.g.
--   /events/results/data/{UUID}  (FTL JSON data endpoint, what the parser
--                                used)
-- For the user-facing link we strip the `/data/` prefix so it lands on
-- the human-readable page:
--   /events/results/{UUID}
-- The `replace()` is idempotent — non-FTL URLs are unchanged.
-- =============================================================================

BEGIN;

DROP VIEW IF EXISTS vw_fencer_aliases;

CREATE VIEW vw_fencer_aliases AS
WITH safe_aliases AS (
  SELECT
    f.id_fencer,
    f.txt_first_name,
    f.txt_surname,
    CASE WHEN jsonb_typeof(f.json_name_aliases) = 'array'
         THEN f.json_name_aliases ELSE '[]'::jsonb END AS json_name_aliases,
    CASE WHEN jsonb_typeof(f.json_revoked_aliases) = 'array'
         THEN f.json_revoked_aliases ELSE '[]'::jsonb END AS json_revoked_aliases,
    CASE WHEN jsonb_typeof(f.json_user_confirmed_aliases) = 'array'
         THEN f.json_user_confirmed_aliases ELSE '[]'::jsonb END AS json_user_confirmed_aliases,
    f.ts_updated AS ts_last_alias_added
  FROM tbl_fencer f
),
context AS (
  SELECT DISTINCT ON (id_fencer)
    id_fencer,
    enum_age_category::TEXT        AS category_hint,
    enum_source_age_category::TEXT AS source_category_hint,
    season_end_year,
    -- 5.18.D: human-readable bracket URL. Strip `/data/` so the link
    -- lands on the rendered FTL page, not the JSON endpoint.
    replace(txt_source_url_used, '/events/results/data/', '/events/results/')
      AS source_bracket_url
  FROM (
    SELECT
      d.id_fencer,
      td.enum_age_category,
      d.enum_source_age_category,
      td.txt_source_url_used,
      EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
      td.dt_tournament,
      0 AS source_priority
    FROM tbl_result_draft d
    JOIN tbl_tournament_draft td ON td.id_tournament_draft = d.id_tournament_draft
    JOIN tbl_event e             ON e.id_event = td.id_event
    JOIN tbl_season s            ON s.id_season = e.id_season
    WHERE d.id_fencer IS NOT NULL
      AND td.enum_age_category IS NOT NULL
    UNION ALL
    SELECT
      r.id_fencer,
      t.enum_age_category,
      r.enum_source_age_category,
      t.txt_source_url_used,
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
  ctx.category_hint        AS latest_category_hint,
  ctx.source_category_hint AS latest_source_category_hint,
  ctx.source_bracket_url   AS latest_source_bracket_url,
  ctx.season_end_year      AS latest_season_end_year
FROM safe_aliases sa
LEFT JOIN context ctx ON ctx.id_fencer = sa.id_fencer;

COMMENT ON VIEW vw_fencer_aliases IS
  'Phase 5.5 (5.18.D) — exposes latest_source_bracket_url alongside '
  'source-V-cat. The Create-new-fencer-from-alias modal renders the URL '
  'as a "verify on FTL ↗" link so the operator can confirm the V-cat '
  'before saving. URL is normalised from /data/ to the human page form.';


DROP FUNCTION IF EXISTS fn_list_fencer_aliases();

CREATE OR REPLACE FUNCTION fn_list_fencer_aliases()
RETURNS TABLE (
  id_fencer                     INT,
  txt_first_name                TEXT,
  txt_surname                   TEXT,
  json_name_aliases             JSONB,
  json_revoked_aliases          JSONB,
  json_user_confirmed_aliases   JSONB,
  alias_count                   INT,
  int_unreviewed_alias_count    INT,
  ts_last_alias_added           TIMESTAMPTZ,
  latest_category_hint          TEXT,
  latest_source_category_hint   TEXT,
  latest_source_bracket_url     TEXT,
  latest_season_end_year        INT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT id_fencer, txt_first_name, txt_surname,
         json_name_aliases, json_revoked_aliases, json_user_confirmed_aliases,
         alias_count, int_unreviewed_alias_count,
         ts_last_alias_added,
         latest_category_hint, latest_source_category_hint,
         latest_source_bracket_url, latest_season_end_year
    FROM vw_fencer_aliases
    ORDER BY int_unreviewed_alias_count DESC, alias_count DESC,
             txt_surname, txt_first_name;
$$;

REVOKE EXECUTE ON FUNCTION fn_list_fencer_aliases() FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_list_fencer_aliases() TO authenticated;

COMMENT ON FUNCTION fn_list_fencer_aliases() IS
  'Phase 5.5 (5.18.D) — adds latest_source_bracket_url to the return shape '
  'so the modal can render a "verify on FTL" link.';

COMMIT;
