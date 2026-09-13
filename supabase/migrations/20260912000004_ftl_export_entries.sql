-- =============================================================================
-- fn_ftl_export_entries — the seed projection behind the public FTL export page
-- =============================================================================
-- Plan: doc/plans/ftl-xml-export-2026-09-12.html §1 (public delivery page),
-- §7 (naming), §9 (the download surface). Tests: supabase/tests/76.
--
-- The export page is public and holds only the anon key, but the data it needs
-- to build a seed file is not: tbl_registration carries the declared birth year
-- and the uuid_edit_token, and its RLS admits only `authenticated`. So the page
-- gets a SECURITY DEFINER projection instead of the table — the same columns
-- vw_registration_entry_list already publishes, plus one integer.
--
-- That integer is the whole point. Seeding a mix-all pool means interleaving the
-- ten sub-rankings by rank (ADR-080 §2), which needs fn_ranking_ppw for every
-- weapon x gender x category present — 22 of the 30 at PPW1. Returning a
-- resolved position instead of a fencer id means one round trip rather than 22,
-- and it keeps the join key (id_fencer) server-side, so the public surface never
-- has to name a person by database identity.
--
-- What is deliberately NOT returned: int_birth_year, id_fencer, id_registration,
-- uuid_edit_token, txt_email_hash. The exporter does not need any of them — the
-- (N) marker in a seed file is the V-CATEGORY digit, not the birth year — and
-- test 76.4 asserts their absence from the function signature so that a later
-- widening cannot happen quietly.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- The capability token.
--
-- ADR-090 §3 settled that administration stays on GitHub Pages and that a
-- sign-in modal is not reachable from a public page on the association's site.
-- Protecting this surface with a login would reverse that, so it is protected
-- by a CAPABILITY instead: a link of the shape /pliki-startowe/?k=<uuid>.
--
-- The check lives here and not in the page. The bundle is public, so a check in
-- JavaScript is decoration; a check inside a SECURITY DEFINER function is a
-- boundary.
--
-- Be precise about what it defends, because it is easy to overrate: every name,
-- gender, weapon and age category this surface shows is ALREADY public through
-- vw_registration_entry_list. The token does not keep a secret. It keeps an
-- organizer-only tool from sitting in front of four hundred fencers, and it
-- gives us something to rotate when a link goes astray — one UPDATE.
--
-- Shaped so it can later carry an organizer id and scope each link to its own
-- events without the URL changing. Not built: what was asked for is one
-- aggregate page.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_ftl_export_token (
  uuid_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  txt_label  TEXT NOT NULL,
  ts_created TIMESTAMPTZ NOT NULL DEFAULT now(),
  ts_revoked TIMESTAMPTZ
);

COMMENT ON TABLE tbl_ftl_export_token IS
  'Capability tokens for the public FTL export page. Revoke by setting ts_revoked; never DELETE, so a link that stops working can still be identified.';

ALTER TABLE tbl_ftl_export_token ENABLE ROW LEVEL SECURITY;

-- No policy for anon: the table is unreadable from the page. Only the DEFINER
-- functions below consult it, which is what stops a holder of one token from
-- enumerating the others.
DROP POLICY IF EXISTS "Admin manages FTL export tokens" ON tbl_ftl_export_token;
CREATE POLICY "Admin manages FTL export tokens" ON tbl_ftl_export_token
  FOR ALL USING (auth.role() = 'authenticated');

REVOKE ALL ON TABLE tbl_ftl_export_token FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON TABLE tbl_ftl_export_token TO authenticated;
GRANT SELECT ON TABLE tbl_ftl_export_token TO service_role;

CREATE OR REPLACE FUNCTION fn_ftl_export_token_valid(p_token UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM tbl_ftl_export_token
     WHERE uuid_token = p_token
       AND ts_revoked IS NULL
  );
$$;

COMMENT ON FUNCTION fn_ftl_export_token_valid(UUID) IS
  'Is this FTL export capability token live? Private: composed into the public projections, never called from a browser.';

REVOKE ALL ON FUNCTION fn_ftl_export_token_valid(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_token_valid(UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- The rolling rule, as a named function rather than an inline expression.
--
-- This is the SQL twin of frontend/src/lib/rolling.ts (ADR-018/021): the live
-- or upcoming season ranks on carry-over, a finished season on its own results.
-- It is not a detail here. PPW1-2026-2027 is the first event of its season, so
-- SPWS-2026-2027 has no results of its own; without carry-over fn_ranking_ppw
-- returns an empty ranking, every registrant is "unranked", and the mix-all
-- file seeds the entire field in the order people happened to fill in the form.
-- Measured on the PROD mirror 2026-09-12: EPEE/M/V2 returns 0 rows non-rolling
-- and 22 rolling.
--
-- Private: it exists to be composed into the projection below, and to be
-- testable on its own, not to be called from a browser.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ftl_export_use_rolling(p_id_event INT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT s.bool_active OR s.dt_end >= CURRENT_DATE
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;
$$;

COMMENT ON FUNCTION fn_ftl_export_use_rolling(INT) IS
  'ADR-018/021 rolling decision for an event''s season — the SQL twin of frontend/src/lib/rolling.ts. Live or upcoming season → carry-over ranking; finished season → its own results.';

REVOKE ALL ON FUNCTION fn_ftl_export_use_rolling(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_use_rolling(INT) TO service_role;

-- ---------------------------------------------------------------------------
-- The projection.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT);
CREATE OR REPLACE FUNCTION fn_ftl_export_entries(p_id_event INT, p_token UUID)
RETURNS TABLE (
  txt_surname       TEXT,
  txt_first_name    TEXT,
  enum_gender       enum_gender_type,
  enum_age_category enum_age_category,
  enum_weapon       enum_weapon_type,
  int_order         INT
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
    SELECT r.id_fencer                                        AS fid,
           r.txt_surname                                      AS surname,
           r.txt_first_name                                   AS first_name,
           r.enum_gender                                      AS gender,
           fn_age_category(r.int_birth_year::INT, v_end_year) AS vcat,
           w.weapon                                           AS weapon,
           r.ts_created                                       AS created
      FROM tbl_registration r
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  ),
  live AS (
    -- A declared birth year below the veteran floor has no sub-ranking, so it
    -- has no seed position and no file to go in. Same rule as the exporter's
    -- registration_subranking_key.
    SELECT * FROM entries WHERE vcat IS NOT NULL
  ),
  groups AS (
    SELECT DISTINCT weapon, gender, vcat FROM live
  ),
  ranked AS (
    -- One fn_ranking_ppw call per sub-ranking that actually has entrants,
    -- rather than all thirty.
    SELECT g.weapon, g.gender, g.vcat, rk.id_fencer AS fid, rk.rank AS position
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
           -- of the same entry list would be impossible to reconcile.
           ORDER BY rk.position NULLS LAST, l.created, l.surname, l.first_name
         )::INT
    FROM live l
    LEFT JOIN ranked rk
      ON  rk.weapon = l.weapon
      AND rk.gender = l.gender
      AND rk.vcat   = l.vcat
      AND rk.fid    = l.fid
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$$;

COMMENT ON FUNCTION fn_ftl_export_entries(INT, UUID) IS
  'Public seed projection for the FTL export page: one row per registration x declared weapon, carrying the canonical-name inputs, the sub-ranking key and the resolved seed position. Publishes no birth year, fencer id, registration id or edit token.';

REVOKE ALL ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The event picker.
--
-- The download page is one page, not one page per event: an organizer running
-- more than one competition — and the association always has more than one open
-- at a time — should not need a different link for each. This lists every event
-- that has anybody entered, so the page can offer a choice rather than depend on
-- whoever sent the link having picked the right event code.
--
-- An event drops off the list the day after it ends. No grace period: the seed
-- files are for setting a competition up, and once it has been fenced there is
-- nothing left to seed. Everything returned is already public through
-- vw_calendar; the count is already derivable from the public entry list.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ftl_export_events();
CREATE OR REPLACE FUNCTION fn_ftl_export_events(p_token UUID)
RETURNS TABLE (
  id_event          INT,
  txt_code          TEXT,
  txt_name          TEXT,
  txt_location      TEXT,
  dt_start          DATE,
  int_registrations INT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  -- Every source column is aliased and the count is a scalar subquery rather
  -- than a GROUP BY. This function's RETURNS TABLE columns carry the same names
  -- as tbl_event's, and a bare name in GROUP BY or ORDER BY resolves against the
  -- OUTPUT PARAMETER instead of the column — an ambiguity that stays invisible
  -- until the day the ordering quietly changes.
  RETURN QUERY
  WITH live AS (
    SELECT e.id_event      AS ev_id,
           e.txt_code      AS ev_code,
           e.txt_name      AS ev_name,
           e.txt_location  AS ev_loc,
           e.dt_start      AS ev_start,
           (SELECT count(*)::INT FROM tbl_registration r WHERE r.id_event = e.id_event)
                           AS ev_count
      FROM tbl_event e
     WHERE EXISTS (SELECT 1 FROM tbl_registration r WHERE r.id_event = e.id_event)
       AND (COALESCE(e.dt_end, e.dt_start) IS NULL
            OR COALESCE(e.dt_end, e.dt_start) >= CURRENT_DATE)
  )
  SELECT l.ev_id, l.ev_code, l.ev_name, l.ev_loc, l.ev_start, l.ev_count
    FROM live l
   ORDER BY l.ev_start NULLS LAST, l.ev_code;
END;
$$;

COMMENT ON FUNCTION fn_ftl_export_events(UUID) IS
  'Events with at least one registration whose end date has not passed, for the FTL export page''s event picker. Gated on a capability token; an absent, unknown or revoked token lists nothing. Public facts only.';

REVOKE ALL ON FUNCTION fn_ftl_export_events(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_events(UUID) TO anon, authenticated, service_role;
