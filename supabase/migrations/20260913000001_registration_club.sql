-- =============================================================================
-- tbl_registration.txt_club — the club field finally reaches the seed files
-- =============================================================================
-- The club input has existed on the public registration form since Phase 2
-- (2026-07-05, commit afbf04d2) but was always decorative: RegistrationForm's
-- `club` state was bound to the input and never read by anything. There is no
-- txt_club column, fn_create_registration has no club parameter, and both FTL
-- exporters hardcode `Club=""` unconditionally. Confirmed on PROD 2026-09-13:
-- 0 of 367 tbl_fencer rows carry a club either, so there is no fallback source
-- to substitute.
--
-- This implements ADR-080 amendment (f), which already specified the intended
-- behaviour ("asked again at registration per event, and emitted only when
-- given") and listed it as pending. It also closes ADR-079 open item 2, and
-- corrects the ADR-078 §1 inventory row that (accurately, until now) called
-- the field "collected and immediately discarded".
--
-- PRIVACY BOUNDARY, verified rather than assumed (2026-09-13):
--   * tbl_registration has RLS enabled with exactly one policy, "Admin all
--     registrations" USING (auth.role() = 'authenticated') — anon's
--     table-level SELECT grant therefore returns zero rows.
--   * vw_registration_entry_list is anon's only read path onto this table and
--     is NOT touched here — pgTAP 49.16 keeps asserting it excludes txt_club.
--   * fn_ftl_export_entries is the ONLY anon-reachable path that gains club
--     visibility, and it is already token-gated (fn_ftl_export_token_valid).
-- So this widens what an organizer with a live export token can see; it does
-- not widen what the four-hundred-fencer public entry list publishes.
--
-- fn_ftl_roster is deliberately NOT widened: its rows come from tbl_fencer,
-- which holds no club for any PROD fencer today (verified above), so adding
-- the column there would only ever emit Club="" — pure churn with no data
-- behind it. Revisit once/if the ADR-080 (a) scrape harvest is actually wired
-- up to tbl_fencer.txt_club.
--
-- Plan: doc/plans/ftl-xml-club-and-completeness-2026-09-13.html (Option A).
-- Tests: supabase/tests/78_registration_club.sql; amends 49, 57, 76.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- ---------------------------------------------------------------------------
-- 1. The column.
-- ---------------------------------------------------------------------------
ALTER TABLE tbl_registration ADD COLUMN IF NOT EXISTS txt_club TEXT;

COMMENT ON COLUMN tbl_registration.txt_club IS
  'Declared club, optional. Read only by fn_ftl_export_entries (organizer, '
  'token-gated) and the FTL seed exporters. Never selected by '
  'vw_registration_entry_list — pgTAP 49.16 pins that exclusion. Not the same '
  'column as tbl_fencer.txt_club, and never synchronised with it.';

-- ---------------------------------------------------------------------------
-- 2. Trim trigger — extend the existing one rather than add a second.
--    Blank input stores NULL, not '', so "no club given" and "empty string
--    typed" are the same row, matching how the exporters already treat an
--    absent value (Club="").
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trim_registration_names()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.txt_surname IS NOT NULL THEN
    NEW.txt_surname := btrim(NEW.txt_surname);
  END IF;
  IF NEW.txt_first_name IS NOT NULL THEN
    NEW.txt_first_name := btrim(NEW.txt_first_name);
  END IF;
  IF NEW.txt_club IS NOT NULL THEN
    NEW.txt_club := NULLIF(btrim(NEW.txt_club), '');
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_trim_registration_names() IS
  'BEFORE INSERT OR UPDATE trigger on tbl_registration that btrims '
  'txt_surname + txt_first_name, and btrims txt_club to NULL when blank '
  '(2026-09-13). Deliberately a separate function from fn_trim_fencer_names() '
  'rather than one shared helper: the two tables are independent and a shared '
  'function would couple a live public write path to the fencer master table '
  'for the sake of a few identical lines.';

DROP TRIGGER IF EXISTS trg_trim_registration_names ON tbl_registration;

CREATE TRIGGER trg_trim_registration_names
  BEFORE INSERT OR UPDATE OF txt_surname, txt_first_name, txt_club ON tbl_registration
  FOR EACH ROW
  EXECUTE FUNCTION fn_trim_registration_names();

-- ---------------------------------------------------------------------------
-- 3. fn_create_registration — DROP + CREATE, argument list changes.
--    Both statements run in this transaction, so the function is never absent
--    to a concurrent caller (same reasoning as 20260828000003).
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_create_registration(
  INT, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], INT, TEXT, TEXT, UUID);

CREATE FUNCTION fn_create_registration(
  p_event           INT,
  p_surname         TEXT,
  p_first_name      TEXT,
  p_gender          enum_gender_type,
  p_birth_year      SMALLINT,
  p_weapons         enum_weapon_type[],
  p_id_fencer       INT DEFAULT NULL,
  p_email_hash      TEXT DEFAULT NULL,
  p_consent_version TEXT DEFAULT NULL,
  p_edit_token      UUID DEFAULT NULL,
  p_club            TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
      int_birth_year, arr_weapons, txt_club, txt_email_hash,
      ts_consent, txt_consent_version, uuid_edit_token
    ) VALUES (
      p_event, NULL, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_club, p_email_hash,
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
      int_birth_year, arr_weapons, txt_club, txt_email_hash,
      ts_consent, txt_consent_version, uuid_edit_token
    ) VALUES (
      p_event, p_id_fencer, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_club, p_email_hash,
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
      ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
      txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version),
      -- Rotate to the caller's handle. Only a caller that actually supplied one
      -- rotates it, so an older bundle re-submitting cannot wipe a live handle.
      uuid_edit_token      = COALESCE(p_edit_token, tbl_registration.uuid_edit_token)
    RETURNING id_registration INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_create_registration IS
  'Sole public CREATE path for tbl_registration (FR-122). Stamps consent when '
  'p_consent_version is given (D5); rejects the write once '
  'COALESCE(dt_registration_deadline, dt_start) has passed (D10). Upserts on '
  'UNIQUE(id_event, id_fencer) when matched and on the declared identity when '
  'not, absorbing the other branch''s twin first (2026-08-28). p_edit_token is '
  'retained but never rotated by a caller that did not supply one, so an older '
  'cached bundle cannot revoke a live edit capability. p_club (2026-09-13) is '
  'optional and stored verbatim (trimmed to NULL when blank); it is never '
  'published by vw_registration_entry_list, only by the token-gated '
  'fn_ftl_export_entries. Correcting a declared name or birth year is NOT '
  'possible here — they are the unmatched arbiter, so a change reads as a '
  'different entrant; use fn_update_registration.';

-- ---------------------------------------------------------------------------
-- 4. fn_update_registration — DROP + CREATE, argument list changes. Its
--    GRANTs name the full type list, so they must be re-issued.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_update_registration(
  INT, UUID, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[]);

CREATE FUNCTION fn_update_registration(
  p_id_registration INT,
  p_edit_token      UUID,
  p_surname         TEXT,
  p_first_name      TEXT,
  p_gender          enum_gender_type,
  p_birth_year      SMALLINT,
  p_weapons         enum_weapon_type[],
  p_club            TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
      txt_club       = p_club
    WHERE id_registration = p_id_registration;
  EXCEPTION WHEN unique_violation THEN
    -- The corrected identity is already held by another entry at this event.
    -- Fail loudly: silently merging would destroy one of two real declarations.
    RAISE EXCEPTION 'Another registration for this event already declares that identity';
  END;

  RETURN p_id_registration;
END;
$$;

COMMENT ON FUNCTION fn_update_registration IS
  'Public EDIT path for tbl_registration, authorised by uuid_edit_token. '
  'Updates by primary key, so unlike fn_create_registration it can correct the '
  'declared name and birth year — those are the create path''s dedupe arbiter, '
  'where a change reads as a different entrant and inserts a second row. '
  'Enforces the same D10 window as the create path. p_club (2026-09-13) is set '
  'directly, not COALESCEd, so an edit that clears the club field actually '
  'clears it. Never changes id_fencer (the link is re-derived at ingestion, '
  'ADR-079 §3) and never restamps consent. Raises rather than merging when '
  'the corrected identity collides with another entry at the same event.';

GRANT EXECUTE ON FUNCTION fn_update_registration(
  INT, UUID, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], TEXT) TO anon;
GRANT EXECUTE ON FUNCTION fn_update_registration(
  INT, UUID, TEXT, TEXT, enum_gender_type, SMALLINT, enum_weapon_type[], TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. fn_ftl_export_entries — RETURNS TABLE changes, DROP + CREATE. Argument
--    list (INT, UUID) is unchanged, so pgTAP 76.1's signature pin still holds.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT, UUID);

CREATE FUNCTION fn_ftl_export_entries(p_id_event INT, p_token UUID)
RETURNS TABLE (
  txt_surname       TEXT,
  txt_first_name    TEXT,
  enum_gender       enum_gender_type,
  enum_age_category enum_age_category,
  enum_weapon       enum_weapon_type,
  int_order         INT,
  txt_club          TEXT
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
           r.ts_created                                       AS created,
           r.txt_club                                         AS club
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
         )::INT,
         l.club
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
  'Public seed projection for the FTL export page: one row per registration x declared weapon, carrying the canonical-name inputs, the sub-ranking key, the resolved seed position and the declared club (2026-09-13, ADR-080 amendment (f)). Publishes no birth year, fencer id, registration id or edit token.';

REVOKE ALL ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;

COMMIT;
