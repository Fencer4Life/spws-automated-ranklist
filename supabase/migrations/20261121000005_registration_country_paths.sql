-- =============================================================================
-- FR-169: the declared country reaches every write path, the public entry list
-- and the organizer's export (ADR-079 amendment 2026-11-21; plan
-- registration-form-names-year-country rev 10, release 3)
-- =============================================================================
-- Follows 20261121000004 (tbl_fencing_country, tbl_registration.txt_country).
-- Each function is taken unchanged except for the country: a last optional
-- p_country on both write functions, so an old cached page's call still
-- resolves; the copy and the export carry the column; the view shows it, and
-- still no birth year or club. Grants are restored exactly as they were.
-- Tests: supabase/tests/132_registration_country.sql (RFCTRY.18–23).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

COMMENT ON COLUMN tbl_registration.txt_country IS
  'FR-169: the declared fencing country (three-letter code); NULL for entries made before 2026-11-21.';

-- ---------------------------------------------------------------------------
-- 1. fn_create_registration — DROP + CREATE: the argument list grows by a last
--    optional p_country, so an old cached page's call still resolves. Both
--    statements run in this transaction, so the function is never absent to a
--    concurrent caller (as in 20260913000001).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_create_registration(INT, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], INT, TEXT, TEXT, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_create_registration(p_event integer, p_surname text, p_first_name text, p_gender enum_gender_type, p_birth_year smallint, p_weapons enum_weapon_type[], p_id_fencer integer DEFAULT NULL::integer, p_email_hash text DEFAULT NULL::text, p_consent_version text DEFAULT NULL::text, p_edit_token uuid DEFAULT NULL::uuid, p_club text DEFAULT NULL::text, p_country text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id      INT;
  v_cutoff  DATE;
BEGIN
  SELECT COALESCE(dt_registration_deadline, dt_start) INTO v_cutoff
  FROM tbl_event WHERE id_event = p_event;

  IF v_cutoff IS NOT NULL AND now()::date > v_cutoff THEN
    RAISE EXCEPTION 'Registration window closed for event %', p_event;
  END IF;

  IF p_id_fencer IS NULL THEN
    -- Unmatched. A MATCHED row for this same declared identity means the
    -- lookup blipped rather than the entrant being new — update that row and
    -- keep its fencer link rather than writing an unlinked twin beside it.
    UPDATE tbl_registration SET
      txt_surname          = p_surname,
      txt_first_name       = p_first_name,
      enum_gender          = p_gender,
      arr_weapons          = p_weapons,
      txt_club             = COALESCE(p_club, txt_club),
      txt_country          = COALESCE(p_country, txt_country),
      txt_email_hash       = COALESCE(p_email_hash, txt_email_hash),
      ts_consent           = COALESCE(
                               CASE WHEN p_consent_version IS NOT NULL THEN now() END,
                               ts_consent),
      txt_consent_version  = COALESCE(p_consent_version, txt_consent_version),
      uuid_edit_token      = COALESCE(p_edit_token, uuid_edit_token)
    WHERE id_registration = (
      SELECT id_registration FROM tbl_registration
       WHERE id_event = p_event
         AND id_fencer IS NOT NULL
         AND upper(btrim(txt_surname))    = upper(btrim(p_surname))
         AND upper(btrim(txt_first_name)) = upper(btrim(p_first_name))
         AND int_birth_year               = p_birth_year
       ORDER BY id_registration
       LIMIT 1)
    RETURNING id_registration INTO v_id;

    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;

    INSERT INTO tbl_registration (
      id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
      int_birth_year, arr_weapons, txt_club, txt_country, txt_email_hash,
      ts_consent, txt_consent_version, uuid_edit_token
    ) VALUES (
      p_event, NULL, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_club, p_country, p_email_hash,
      CASE WHEN p_consent_version IS NOT NULL THEN now() END, p_consent_version,
      COALESCE(p_edit_token, gen_random_uuid())
    )
    ON CONFLICT (
      id_event,
      upper(btrim(txt_surname)),
      upper(btrim(txt_first_name)),
      int_birth_year
    ) WHERE id_fencer IS NULL DO UPDATE SET
      txt_surname          = EXCLUDED.txt_surname,
      txt_first_name       = EXCLUDED.txt_first_name,
      enum_gender          = EXCLUDED.enum_gender,
      arr_weapons          = EXCLUDED.arr_weapons,
      txt_club             = COALESCE(EXCLUDED.txt_club, tbl_registration.txt_club),
      txt_country          = COALESCE(EXCLUDED.txt_country, tbl_registration.txt_country),
      txt_email_hash       = COALESCE(EXCLUDED.txt_email_hash, tbl_registration.txt_email_hash),
      ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
      txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version),
      -- Rotate to the caller's handle. Only a caller that actually supplied one
      -- rotates it, so an older bundle re-submitting cannot wipe a live handle.
      uuid_edit_token      = COALESCE(p_edit_token, tbl_registration.uuid_edit_token)
    RETURNING id_registration INTO v_id;
  ELSE
    -- Matched. Absorb the unmatched twin first (see 20260828000002).
    IF EXISTS (
      SELECT 1 FROM tbl_registration
       WHERE id_event = p_event AND id_fencer = p_id_fencer
    ) THEN
      DELETE FROM tbl_registration
       WHERE id_event = p_event
         AND id_fencer IS NULL
         AND upper(btrim(txt_surname))    = upper(btrim(p_surname))
         AND upper(btrim(txt_first_name)) = upper(btrim(p_first_name))
         AND int_birth_year               = p_birth_year;
    ELSE
      UPDATE tbl_registration
         SET id_fencer = p_id_fencer
       WHERE id_event = p_event
         AND id_fencer IS NULL
         AND upper(btrim(txt_surname))    = upper(btrim(p_surname))
         AND upper(btrim(txt_first_name)) = upper(btrim(p_first_name))
         AND int_birth_year               = p_birth_year;
    END IF;

    INSERT INTO tbl_registration (
      id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
      int_birth_year, arr_weapons, txt_club, txt_country, txt_email_hash,
      ts_consent, txt_consent_version, uuid_edit_token
    ) VALUES (
      p_event, p_id_fencer, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_club, p_country, p_email_hash,
      CASE WHEN p_consent_version IS NOT NULL THEN now() END, p_consent_version,
      COALESCE(p_edit_token, gen_random_uuid())
    )
    ON CONFLICT (id_event, id_fencer) DO UPDATE SET
      txt_surname          = EXCLUDED.txt_surname,
      txt_first_name       = EXCLUDED.txt_first_name,
      enum_gender          = EXCLUDED.enum_gender,
      int_birth_year       = EXCLUDED.int_birth_year,
      arr_weapons          = EXCLUDED.arr_weapons,
      txt_club             = COALESCE(EXCLUDED.txt_club, tbl_registration.txt_club),
      txt_country          = COALESCE(EXCLUDED.txt_country, tbl_registration.txt_country),
      ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
      txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version),
      -- Rotate to the caller's handle. Only a caller that actually supplied one
      -- rotates it, so an older bundle re-submitting cannot wipe a live handle.
      uuid_edit_token      = COALESCE(p_edit_token, tbl_registration.uuid_edit_token)
    RETURNING id_registration INTO v_id;
  END IF;

  RETURN v_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION fn_create_registration(INT, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], INT, TEXT, TEXT, UUID, TEXT, TEXT) TO PUBLIC, service_role;

-- ---------------------------------------------------------------------------
-- 2. fn_update_registration — the same: a last optional p_country; without it
--    the stored country stays.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_update_registration(INT, UUID, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], TEXT);

CREATE OR REPLACE FUNCTION public.fn_update_registration(p_id_registration integer, p_edit_token uuid, p_surname text, p_first_name text, p_gender enum_gender_type, p_birth_year smallint, p_weapons enum_weapon_type[], p_club text DEFAULT NULL::text, p_country text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event   INT;
  v_cutoff  DATE;
BEGIN
  IF p_edit_token IS NULL THEN
    RAISE EXCEPTION 'Edit token required';
  END IF;

  -- Verify the capability and locate the event in one step. A wrong token and
  -- a non-existent row are deliberately indistinguishable to the caller.
  SELECT id_event INTO v_event
  FROM tbl_registration
  WHERE id_registration = p_id_registration
    AND uuid_edit_token = p_edit_token;

  IF v_event IS NULL THEN
    RAISE EXCEPTION 'Registration not found or edit token invalid';
  END IF;

  SELECT COALESCE(dt_registration_deadline, dt_start) INTO v_cutoff
  FROM tbl_event WHERE id_event = v_event;

  IF v_cutoff IS NOT NULL AND now()::date > v_cutoff THEN
    RAISE EXCEPTION 'Registration window closed for event %', v_event;
  END IF;

  -- Consent is deliberately untouched: it was given at submission, and
  -- correcting a typo is not a new consent event.
  BEGIN
    UPDATE tbl_registration SET
      txt_surname    = p_surname,
      txt_first_name = p_first_name,
      enum_gender    = p_gender,
      int_birth_year = p_birth_year,
      arr_weapons    = p_weapons,
      txt_club       = p_club,
      -- An old cached page sends no country: the stored one stays.
      txt_country    = COALESCE(p_country, txt_country)
    WHERE id_registration = p_id_registration;
  EXCEPTION WHEN unique_violation THEN
    -- The corrected identity is already held by another entry at this event.
    -- Fail loudly: silently merging would destroy one of two real declarations.
    RAISE EXCEPTION 'Another registration for this event already declares that identity';
  END;

  RETURN p_id_registration;
END;
$function$;

GRANT EXECUTE ON FUNCTION fn_update_registration(INT, UUID, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], TEXT, TEXT) TO PUBLIC, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. fn_replace_event_registrations — the PROD → CERT copy carries the country.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_replace_event_registrations(p_event_code text, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event    INT;
  v_bad      TEXT;
  v_deleted  INT;
  v_inserted INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = p_event_code;
  IF v_event IS NULL THEN
    RAISE EXCEPTION 'REG_EVENT_UNKNOWN: %', p_event_code;
  END IF;

  SELECT string_agg(DISTINCT x->>'id_fencer', ', ') INTO v_bad
    FROM jsonb_array_elements(COALESCE(p_rows, '[]'::JSONB)) x
   WHERE x->>'id_fencer' IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM tbl_fencer f WHERE f.id_fencer = (x->>'id_fencer')::INT);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'REG_FENCER_UNKNOWN: % (align fencer ids before copying registrations)', v_bad;
  END IF;

  DELETE FROM tbl_registration WHERE id_event = v_event;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
                                int_birth_year, arr_weapons, txt_ftl_name, txt_club, txt_country)
  SELECT v_event, r.id_fencer, r.txt_surname, r.txt_first_name, r.enum_gender,
         r.int_birth_year, r.arr_weapons, r.txt_ftl_name, r.txt_club, r.txt_country
    FROM jsonb_populate_recordset(NULL::tbl_registration, COALESCE(p_rows, '[]'::JSONB)) r;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted, 'inserted', v_inserted);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. fn_ftl_export_entries — DROP + CREATE: it returns the country, which the
--    organizer's files write as Nation.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT, UUID);

CREATE OR REPLACE FUNCTION public.fn_ftl_export_entries(p_id_event integer, p_token uuid)
 RETURNS TABLE(txt_surname text, txt_first_name text, enum_gender enum_gender_type, enum_age_category enum_age_category, enum_weapon enum_weapon_type, int_order integer, int_rank integer, num_rank_points numeric, txt_country text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
           r.ts_created      AS created,
           r.txt_country     AS country
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
           rk.total_score AS points,
           rk.ordinality AS ord
      FROM groups g
      CROSS JOIN LATERAL fn_ranking_ppw(
        g.weapon, g.gender, g.vcat, v_id_season, v_rolling
      ) WITH ORDINALITY rk
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
           -- ADR-115: fencers sharing a place keep the ranking's own order (rk.ord),
           -- the same order the Python generator reads; registration time
           -- orders only the unranked tail.
           ORDER BY rk.position NULLS LAST, rk.ord NULLS LAST, l.created, l.surname, l.first_name
         )::INT,
         -- The seed tier. NULL means no ranking points at all, which is not
         -- rank 0 and not "last in the bucket": it is what sends the entry to
         -- the tail after every ranked fencer in every bucket.
         rk.position::INT,
         -- The points that rank is built on. Orders the entries INSIDE a tier
         -- (2026-09-26); the tier itself is still rk.position. NULL exactly
         -- when the rank is NULL, for the same reason.
         rk.points::NUMERIC,
         -- FR-169: the entry's declared country; NULL for an entry made
         -- before it was asked, which the files write as POL.
         l.country
    FROM live l
    LEFT JOIN ranked rk
      ON  rk.weapon = l.weapon
      AND rk.gender = l.gender
      AND rk.vcat   = l.vcat
      AND rk.fid    = l.fid
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$function$;

REVOKE EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;


-- ---------------------------------------------------------------------------
-- 5. vw_registration_entry_list — the public entry list shows the country,
--    and still no birth year or club.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_registration_entry_list AS
SELECT r.id_registration,
       r.id_event,
       r.txt_surname,
       r.txt_first_name,
       r.enum_gender,
       r.arr_weapons,
       fn_age_category(r.int_birth_year::INT, EXTRACT(year FROM s.dt_end)::INT) AS enum_age_category,
       r.txt_country
  FROM tbl_registration r
  JOIN tbl_event e ON e.id_event = r.id_event
  JOIN tbl_season s ON s.id_season = e.id_season;

COMMIT;
