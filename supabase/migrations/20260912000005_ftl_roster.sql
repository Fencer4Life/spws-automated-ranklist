-- =============================================================================
-- fn_ftl_roster — the organizer's pick-list (ADR-080 amendment (e))
-- =============================================================================
-- Plan: doc/plans/ftl-export-page-2026-09-12.html §6. Tests: supabase/tests/77.
--
-- Somebody turns up at the venue who never entered. The organizer can type their
-- name into Fencing Time, or tick them out of a list we supplied. Typing is how
-- a duplicate identity is born: the name comes back on the results, matches
-- nothing we hold, and a second fencer record is created for a person we already
-- knew. ADR-065's 26 June amendment records exactly that, as fencer #330.
--
-- So each event's download carries one extra file per weapon: every fencer with
-- any result in that weapon, full history, all nationalities, imported as a
-- pick-list rather than as a competition (Fencing Time 4.7 Guide p.145,
-- Event Competitors → Import from XML). Its filename and its in-file title both
-- say "do not import as a competition", because that is the one mistake on this
-- surface that damages an event rather than merely wasting a minute.
--
-- SUPPRESSION IS TWO CLAUSES, AND THE SECOND IS WHY THIS FUNCTION IS NOT A VIEW
-- WITH A NOT EXISTS. The obvious rule — "leave out anyone whose name matches a
-- registration" — is wrong on live data. PROD holds two people called
-- MŁYNEK Janusz: #197 born 1951 with nineteen results, and #356 born 1984 with
-- none. If #356 enters, the naive rule deletes #197 from the roster, and #197 is
-- precisely the fencer an organizer might need to tick in. The name rule
-- therefore fires only when the name is unambiguous.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_ftl_roster(
  p_id_event INT,
  p_weapon   enum_weapon_type,
  p_token    UUID
)
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
  v_end_year INT;
BEGIN
  -- Same capability as the rest of the surface, same silent refusal.
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT
    INTO v_end_year
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;

  IF v_end_year IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH has_result AS (
    -- Full history and every nationality: the organizer is looking for a person,
    -- not for somebody eligible for this season's ranking.
    SELECT DISTINCT r.id_fencer
      FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     WHERE t.enum_weapon = p_weapon
       AND r.id_fencer IS NOT NULL
  ),
  entered AS (
    -- Clause 1's set: fencers this event's entry list already points at, for
    -- this weapon. Identity, not names — exact and unambiguous.
    SELECT DISTINCT reg.id_fencer
      FROM tbl_registration reg
      CROSS JOIN LATERAL unnest(reg.arr_weapons) AS w(weapon)
     WHERE reg.id_event = p_id_event
       AND reg.id_fencer IS NOT NULL
       AND w.weapon = p_weapon
  ),
  unmatched_names AS (
    -- Clause 2's set: names on unmatched registrations for this weapon, kept
    -- only when EXACTLY ONE fencer in the table bears that name. Two bearers and
    -- we cannot tell which one entered, so we suppress neither — leaving a
    -- duplicate on the pick-list costs a moment's confusion, while hiding the
    -- wrong one loses nineteen results' worth of a person.
    SELECT upper(reg.txt_surname) AS surname, upper(reg.txt_first_name) AS first_name
      FROM tbl_registration reg
      CROSS JOIN LATERAL unnest(reg.arr_weapons) AS w(weapon)
     WHERE reg.id_event = p_id_event
       AND reg.id_fencer IS NULL
       AND w.weapon = p_weapon
       AND (
         SELECT count(*) FROM tbl_fencer f2
          WHERE upper(f2.txt_surname)    = upper(reg.txt_surname)
            AND upper(f2.txt_first_name) = upper(reg.txt_first_name)
       ) = 1
  ),
  live AS (
    SELECT f.id_fencer,
           upper(f.txt_surname)       AS surname,
           initcap(f.txt_first_name)  AS first_name,
           f.enum_gender              AS gender,
           fn_age_category(f.int_birth_year, v_end_year) AS vcat
      FROM tbl_fencer f
      JOIN has_result hr ON hr.id_fencer = f.id_fencer
     WHERE NOT EXISTS (SELECT 1 FROM entered e WHERE e.id_fencer = f.id_fencer)
       AND NOT EXISTS (
         SELECT 1 FROM unmatched_names un
          WHERE un.surname    = upper(f.txt_surname)
            AND un.first_name = upper(f.txt_first_name)
       )
       -- A fencer with no gender or no derivable category cannot be written as a
       -- Tireur: the (N) marker IS the category, and there would be nothing to
       -- put in it. PROD holds 11 such rows and every one has zero results, so
       -- this excludes nobody today; it is here so that a future one is dropped
       -- deliberately rather than by a NULL propagating through a join.
       AND f.enum_gender IS NOT NULL
       AND fn_age_category(f.int_birth_year, v_end_year) IS NOT NULL
  )
  SELECT l.surname,
         l.first_name,
         l.gender,
         l.vcat,
         p_weapon,
         -- Alphabetical, not seeded. This is a list somebody scrolls looking for
         -- a name, and the seeding order of a pick-list means nothing.
         ROW_NUMBER() OVER (ORDER BY l.surname, l.first_name, l.id_fencer)::INT
    FROM live l
   ORDER BY 6;
END;
$$;

COMMENT ON FUNCTION fn_ftl_roster(INT, enum_weapon_type, UUID) IS
  'Pick-list of every fencer with any result in this weapon, minus those already entered for this event (by fencer id always; by name only when exactly one fencer bears it). Gated on the FTL export capability token. Publishes no birth year and no fencer id.';

REVOKE ALL ON FUNCTION fn_ftl_roster(INT, enum_weapon_type, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_roster(INT, enum_weapon_type, UUID)
  TO anon, authenticated, service_role;
