-- =============================================================================
-- The seed order inside a tier follows the points, not the category
-- =============================================================================
-- interleave_mixall lays every true rank 1 down first, then every true rank 2,
-- and so on. WITHIN a tier the order was the fixed sequence FV0..FV4, MV0..MV4
-- (MIXALL_SUBRANKING_ORDER, ADR-080 Section 2), so a woman took the first seed
-- of every tier because 'F' sorts before 'M', and V0 led the women because '0'
-- sorts before '1'. Neither was earned. Measured on PPW1-2026-2027 EPEE, tier 1
-- opened with KAMINSKA on 363.20 while SEKOWSKI sat fifth on 435.96.
--
-- The generators now sort each tier by points. This projection is where the
-- points come from: the ranked CTE already calls fn_ranking_ppw for int_rank
-- and the row carries total_score, so this adds a column, not a query.
--
-- IT PUBLISHES NOTHING NEW. fn_ranking_ppw is anon-EXECUTEable (ADR-083's
-- allowlist, verified on PROD), so every one of these numbers can already be
-- read by anyone. No consent question and no allowlist change.
--
-- The fixed order is NOT deleted — it becomes the tie-break, because
-- fn_ranking_ppw gives two fencers on the same score the same rank and a sort
-- that is not total would let two downloads of one entry list disagree.
--
-- Plan-test-ID 76 (supabase/tests/76_ftl_export_entries.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- A DROP, not a CREATE OR REPLACE: Postgres refuses to change a function's OUT
-- columns in place, and this adds one. The REVOKE/GRANT block below is
-- therefore load-bearing rather than decorative — a DROP takes the grants with
-- it, and silence would hand EXECUTE back to PUBLIC. That default is exactly
-- what caught fn_claim_identity_override_alerts in 20260912000002, via
-- ADR-083's pgTAP 52.7.
DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT, UUID);

CREATE FUNCTION fn_ftl_export_entries(p_id_event INT, p_token UUID)
RETURNS TABLE (
  txt_surname       TEXT,
  txt_first_name    TEXT,
  enum_gender       enum_gender_type,
  enum_age_category enum_age_category,
  enum_weapon       enum_weapon_type,
  int_order         INT,
  int_rank          INT,
  num_rank_points   NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_season INT;
  v_end_year  INT;
  v_rolling   BOOLEAN;
BEGIN
  -- No token, no data. Returning empty rather than raising is deliberate: a
  -- stale link should look empty, not broken, and an error would confirm to a
  -- prober that they had found a real endpoint.
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  SELECT e.id_season, EXTRACT(YEAR FROM s.dt_end)::INT
    INTO v_id_season, v_end_year
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;

  -- An unknown event is an empty entry list, not an error: the page resolves
  -- an event from a URL parameter, and a stale link must not show a stack trace.
  IF v_id_season IS NULL THEN
    RETURN;
  END IF;

  v_rolling := COALESCE(fn_ftl_export_use_rolling(p_id_event), FALSE);

  RETURN QUERY
  WITH entries AS (
    -- One row per declared weapon. A registration for épée and foil is two
    -- entries in two competitions, and they can be seeded differently.
    --
    -- The category comes from tbl_fencer when the registration is matched,
    -- because that is the year fn_ranking_ppw ranks on. COALESCE falls back to
    -- the declared year for an unmatched row, which has no fencer to consult.
    SELECT r.id_fencer       AS fid,
           r.txt_surname     AS surname,
           r.txt_first_name  AS first_name,
           r.enum_gender     AS gender,
           fn_age_category(
             COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year
           )                 AS vcat,
           w.weapon          AS weapon,
           r.ts_created      AS created
      FROM tbl_registration r
      LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  ),
  live AS (
    -- A birth year below the veteran floor has no sub-ranking, so it has no
    -- seed position and no file to go in. Same rule as the exporter's
    -- registration_subranking_key.
    SELECT * FROM entries WHERE vcat IS NOT NULL
  ),
  groups AS (
    SELECT DISTINCT weapon, gender, vcat FROM live
  ),
  ranked AS (
    -- One fn_ranking_ppw call per sub-ranking that actually has entrants,
    -- rather than all thirty.
    SELECT g.weapon, g.gender, g.vcat, rk.id_fencer AS fid, rk.rank AS position,
           rk.total_score AS points
      FROM groups g
      CROSS JOIN LATERAL fn_ranking_ppw(
        g.weapon, g.gender, g.vcat, v_id_season, v_rolling
      ) rk
  )
  SELECT l.surname,
         l.first_name,
         l.gender,
         l.vcat,
         l.weapon,
         ROW_NUMBER() OVER (
           PARTITION BY l.weapon, l.gender, l.vcat
           -- Ranked registrants in ranking order; everyone else after them, in
           -- the order they entered. Name is the final tiebreak so that two
           -- registrations written in the same transaction still order
           -- deterministically — a seed file that changes between two downloads
           -- of the same entry list would be impossible to reconcile. This is
           -- no longer the seed position: it orders the UNRANKED tail, and
           -- exists so that tail is stable without publishing ts_created.
           ORDER BY rk.position NULLS LAST, l.created, l.surname, l.first_name
         )::INT,
         -- The seed tier. NULL means no ranking points at all, which is not
         -- rank 0 and not "last in the bucket": it is what sends the entry to
         -- the tail after every ranked fencer in every bucket.
         rk.position::INT,
         -- The points that rank is built on. Orders the entries INSIDE a tier
         -- (2026-09-26); the tier itself is still rk.position. NULL exactly
         -- when the rank is NULL, for the same reason.
         rk.points::NUMERIC
    FROM live l
    LEFT JOIN ranked rk
      ON  rk.weapon = l.weapon
      AND rk.gender = l.gender
      AND rk.vcat   = l.vcat
      AND rk.fid    = l.fid
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$$;

REVOKE ALL ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;

COMMENT ON FUNCTION fn_ftl_export_entries(INT, UUID) IS
  'Public seed projection for the FTL export page: one row per registration x '
  'declared weapon, carrying the canonical-name inputs, the sub-ranking key, '
  'the fencer''s TRUE rank in that sub-ranking (NULL when unranked) and a dense '
  'int_order used only to keep the unranked tail deterministic. Categorises on '
  'tbl_fencer''s birth year when the registration is matched, which is what '
  'fn_ranking_ppw ranks on. Publishes no birth year, fencer id, registration '
  'id, edit token or club. Also publishes the ranking points behind int_rank, '
  'which order the entries inside a seed tier (2026-09-26) — already public, '
  'since fn_ranking_ppw is anon-EXECUTEable.';
COMMIT;
