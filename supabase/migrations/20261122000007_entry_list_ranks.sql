-- =============================================================================
-- FR-175 — the entry list may show each fencer's place in the organiser's ranking
-- =============================================================================
-- Plan doc/plans/seeding-by-organiser-ranking-2026-11-22.html, rev 1, release 2.
--
-- fn_registration_entry_ranks is what the public entry list reads: each start
-- (entry × weapon) with its place in the organiser's ranking and its seed order,
-- taken from fn_event_seed_ranks (FR-174), and only for an event whose switch
-- and our registration are both on. It returns no birth year, no points and no
-- fencer id (ELRANK.05).
--
-- The column comes last, as the one statement that takes the table lock (as the
-- FR-172 and FR-173 migrations do), so nothing else runs while the lock is held.
-- The function is PL/pgSQL so that it can be created before the column it names
-- (a SQL-language body is checked against the table when it is created).
-- =============================================================================

SET lock_timeout = '2s';

CREATE OR REPLACE FUNCTION fn_registration_entry_ranks(p_id_event INT)
RETURNS TABLE (
  id_registration   INT,
  enum_weapon       enum_weapon_type,
  enum_age_category enum_age_category,
  int_rank          INT,
  int_seed_order    INT,
  txt_ranking       TEXT,
  ts_ranking_read   TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tbl_event e
                  WHERE e.id_event = p_id_event AND e.bool_show_seed AND e.bool_use_spws_registration) THEN
    RETURN;
  END IF;
  RETURN QUERY
    SELECT s.id_registration, s.enum_weapon, s.enum_age_category, s.int_rank, s.int_seed_order,
           s.txt_ranking, s.ts_ranking_read
      FROM fn_event_seed_ranks(p_id_event) s;
END;
$$;

COMMENT ON FUNCTION fn_registration_entry_ranks(INT) IS
  'FR-175: for an event whose bool_show_seed and bool_use_spws_registration are set, each start with its '
  'place in the organiser ranking and its seed order; no row for any other event. Never a birth year, never points.';

REVOKE EXECUTE ON FUNCTION fn_registration_entry_ranks(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_registration_entry_ranks(INT) TO anon, authenticated, service_role;

-- The administrator's switch: the entry list of this event shows each fencer's
-- place in the organiser's ranking once a weapon, a gender and a category are
-- chosen. Set per environment; fn_mirror_events_to_prod names its columns one
-- by one and not this one, so CERT never writes PROD's switch (ELRANK.01).
ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS bool_show_seed BOOLEAN NOT NULL DEFAULT FALSE;
