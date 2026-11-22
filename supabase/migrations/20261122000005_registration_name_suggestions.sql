-- =============================================================================
-- FR-173 · The name list under the registration form SURNAME box
-- Plan doc/plans/registration-name-list-under-surname-2026-11-22.html, rev 1,
-- Part B (signed 22 Nov 2026). Amends ADR-079 and FR-171.
--
-- 1. fn_registration_name_suggestions: what a visitor typing a surname may
--    read. At most 8 people for two or more typed letters, from tbl_fencer,
--    the EVF ranking (tbl_evf_ranking_fencer) and earlier entries of people on
--    neither. Name, gender, country, age category, club (ours only), source,
--    and whether the person is already entered in the event. Never a birth
--    year and never an id: every person gives their own year, which is the
--    only check on an entry (the user rule of 22 Nov).
-- 2. tbl_registration.txt_name_source records how the name arrived (TYPED,
--    ROSTER, EVF, ENTRY), set after the entry is saved by
--    fn_set_registration_name_source with the entry own edit handle.
-- 3. The EVF table comment names its one reader for visitors; its grants stay.
-- =============================================================================

SET lock_timeout = '2s';

CREATE OR REPLACE FUNCTION fn_registration_name_suggestions(p_id_event INT, p_typed TEXT)
RETURNS TABLE (
  txt_surname       TEXT,
  txt_first_name    TEXT,
  enum_gender       enum_gender_type,
  txt_country       TEXT,
  enum_age_category enum_age_category,
  txt_club          TEXT,
  txt_source        TEXT,
  bool_entered      BOOLEAN
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH q AS (
    SELECT fn_fold_name(p_typed) AS k
  ),
  ev AS (
    SELECT EXTRACT(year FROM s.dt_end)::INT AS end_year
      FROM tbl_event e
      JOIN tbl_season s ON s.id_season = e.id_season
     WHERE e.id_event = p_id_event
  ),
  roster AS (
    SELECT f.txt_surname, f.txt_first_name, f.enum_gender,
           f.txt_nationality AS txt_country,
           fn_age_category(f.int_birth_year::INT, ev.end_year) AS cat,
           NULLIF(btrim(f.txt_club), '') AS txt_club,
           'ROSTER'::TEXT AS src, 1 AS ord,
           fn_fold_name(f.txt_surname)    AS sk,
           fn_fold_name(f.txt_first_name) AS gk
      FROM tbl_fencer f
      CROSS JOIN ev
  ),
  evf AS (
    SELECT x.txt_surname, x.txt_first_name, x.enum_gender,
           NULLIF(x.txt_country, 'OTH') AS txt_country,
           -- EVF category k is ages 30+10k to 39+10k: the middle age of that span
           -- gives the same category through the one rule (fn_age_category).
           fn_age_category(ev.end_year - (35 + 10 * x.int_category), ev.end_year) AS cat,
           NULL::TEXT AS txt_club,
           'EVF'::TEXT AS src, 2 AS ord,
           fn_fold_name(x.txt_surname)    AS sk,
           fn_fold_name(x.txt_first_name) AS gk
      FROM tbl_evf_ranking_fencer x
      CROSS JOIN ev
  ),
  -- Earlier entries of people on no list, newest first per person. The keys
  -- carry their own names (sk, gk, g) so DISTINCT ON never names a column
  -- that is also an output column of this function.
  entry_rows AS (
    SELECT fn_name_without_title(r.txt_surname) AS bare_surname, r.txt_first_name AS given, r.enum_gender AS g,
           r.txt_country AS country,
           fn_age_category(r.int_birth_year::INT, ev.end_year) AS cat,
           fn_fold_name(fn_name_without_title(r.txt_surname)) AS sk,
           fn_fold_name(r.txt_first_name)                     AS gk,
           r.ts_created AS created
      FROM tbl_registration r
      CROSS JOIN ev
     WHERE r.id_fencer IS NULL
  ),
  entry AS (
    SELECT DISTINCT ON (sk, gk, g)
           bare_surname, given, g, country, cat, NULL::TEXT AS club, 'ENTRY'::TEXT AS src, 3 AS ord, sk, gk
      FROM entry_rows
     ORDER BY sk, gk, g, created DESC
  ),
  people AS (
    SELECT * FROM roster
    UNION ALL
    SELECT * FROM evf v
     WHERE NOT EXISTS (SELECT 1 FROM roster o
                        WHERE o.sk = v.sk AND o.gk = v.gk AND o.enum_gender = v.enum_gender)
    UNION ALL
    SELECT * FROM entry n
     WHERE NOT EXISTS (SELECT 1 FROM roster o WHERE o.sk = n.sk AND o.gk = n.gk)
       AND NOT EXISTS (SELECT 1 FROM evf v WHERE v.sk = n.sk AND v.gk = n.gk)
  )
  SELECT p.txt_surname, p.txt_first_name, p.enum_gender, p.txt_country, p.cat, p.txt_club, p.src,
         EXISTS (
           SELECT 1 FROM tbl_registration r
            WHERE r.id_event = p_id_event
              AND fn_fold_name(fn_name_without_title(r.txt_surname)) = p.sk
              AND fn_fold_name(r.txt_first_name) = p.gk
         )
    FROM people p
    CROSS JOIN q
    CROSS JOIN ev
   WHERE char_length(q.k) >= 2
     AND (   left(p.sk || ' ' || p.gk, char_length(q.k)) = q.k
          OR left(p.gk || ' ' || p.sk, char_length(q.k)) = q.k)
   ORDER BY (left(p.sk || ' ' || p.gk, char_length(q.k)) = q.k) DESC, p.ord, p.sk, p.gk
   LIMIT 8;
$$;

COMMENT ON FUNCTION fn_registration_name_suggestions(INT, TEXT) IS
  'FR-173: the name list under the registration form SURNAME box. At most 8 people for two or more typed '
  'letters, from tbl_fencer, tbl_evf_ranking_fencer and earlier entries of people on neither: name, gender, '
  'country, age category, club, source and whether already entered in the event. Never a birth year, never an id.';

REVOKE EXECUTE ON FUNCTION fn_registration_name_suggestions(INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_registration_name_suggestions(INT, TEXT) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION fn_set_registration_name_source(p_id_registration INT, p_edit_token UUID, p_source TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_edit_token IS NULL OR p_source IS NULL OR p_source NOT IN ('TYPED', 'ROSTER', 'EVF', 'ENTRY') THEN
    RAISE EXCEPTION 'REG_NAME_SOURCE_REFUSED';
  END IF;
  UPDATE tbl_registration r
     SET txt_name_source = p_source
   WHERE r.id_registration = p_id_registration
     AND r.uuid_edit_token = p_edit_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REG_NAME_SOURCE_REFUSED';
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_set_registration_name_source(INT, UUID, TEXT) IS
  'FR-173: records how an entry name arrived, authorised by the entry own edit handle (uuid_edit_token).';

REVOKE EXECUTE ON FUNCTION fn_set_registration_name_source(INT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_set_registration_name_source(INT, UUID, TEXT) TO anon, authenticated, service_role;

-- I28: the PROD to CERT copy of an event entries carries how each name arrived;
-- a row without it (an older caller) reads TYPED. Otherwise as migration
-- 20261121000005 left it; its grants (service_role only) are unchanged.
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
                                int_birth_year, arr_weapons, txt_ftl_name, txt_club, txt_country, txt_name_source)
  SELECT v_event, r.id_fencer, r.txt_surname, r.txt_first_name, r.enum_gender,
         r.int_birth_year, r.arr_weapons, r.txt_ftl_name, r.txt_club, r.txt_country,
         COALESCE(r.txt_name_source, 'TYPED')
    FROM jsonb_populate_recordset(NULL::tbl_registration, COALESCE(p_rows, '[]'::JSONB)) r;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted, 'inserted', v_inserted);
END;
$function$;

COMMENT ON TABLE tbl_evf_ranking_fencer IS
  'FR-171: each fencer on the EVF ranking as last read by evf-ranking-sync.yml (EVF id, names, gender, '
  'category, country). Fills the country of an entry that has none; FR-173: fn_registration_name_suggestions '
  'offers its names on the registration form. No grant to a visitor or a signed-in user; links nothing.';

-- The column last, as the one statement that takes the table lock (as FR-172
-- migration does), so nothing else runs while the lock is held. It holds how
-- the entry name arrived: TYPED, or picked from the list (ROSTER, EVF, ENTRY).
ALTER TABLE tbl_registration
  ADD COLUMN IF NOT EXISTS txt_name_source TEXT NOT NULL DEFAULT 'TYPED',
  DROP CONSTRAINT IF EXISTS ck_registration_name_source,
  ADD CONSTRAINT ck_registration_name_source CHECK (txt_name_source IN ('TYPED', 'ROSTER', 'EVF', 'ENTRY'));
