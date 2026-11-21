-- =============================================================================
-- FR-167: a fencer's name in one form, titles apart, reversed fields caught
-- (ADR-079 amendment 2026-11-21; plan registration-form-names-year-country
-- rev 10, release 1)
-- =============================================================================
-- PROD on 21 Nov 2026, read-only, 193 entries: 11 newcomers' given names were
-- not in the form the organizer's files use („DZMITRY”, „dmytro”, „ESZTER
-- ZSUZSANNA”), two carried a title the way Austrian and Hungarian fencers write
-- it („DR SURNAME”, „Given Dr.”), and four newcomers had typed the given name
-- into the surname box.
--
-- 1. tbl_common_given_name — the EVF ranking's given names. With our fencer
--    table, read live, they are the KNOWN GIVEN NAMES the reversed-fields
--    question uses. Given names only: no surname, country, birth date or
--    ranking place. The EVF names are loaded by the next migration and kept up
--    to date by given-names-sync.yml.
-- 2. fn_python_title, fn_name_without_title, fn_registration_canonical_names —
--    the name form, the twin of frontend/src/lib/registrationName.ts. Both are
--    pinned on the same cases (130_registration_names.sql,
--    registrationName.test.ts).
-- 3. fn_trim_registration_names — now also writes the name form for a
--    newcomer's row (id_fencer NULL) whatever wrote it, so an old cached page
--    or a direct write cannot store „JOHN”. A linked row keeps the roster's
--    name (trg_registration_roster_name fires first, alphabetically, and this
--    trigger leaves a linked row's names alone).
-- 4. fn_match_registration_fencer, fn_registration_identity_candidates — a
--    title is not part of the surname they compare.
-- 5. fn_registration_name_check — the reversed-fields question's two answers.
-- 6. fn_registration_realign_names — the one-off rewrite of rows written
--    before this migration, run once below.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- ---------------------------------------------------------------------------
-- 1. The known given names that are not in our fencer table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_common_given_name (
  txt_name     TEXT        NOT NULL CHECK (btrim(txt_name) <> ''),
  txt_name_key TEXT        GENERATED ALWAYS AS (fn_fold_name(txt_name)) STORED PRIMARY KEY,
  txt_source   TEXT        NOT NULL CHECK (txt_source IN ('EVF')),
  ts_created   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tbl_common_given_name IS
  'FR-167: given names of the EVF ranking, read monthly by given-names-sync.yml '
  '(insert-only). With tbl_fencer''s given names they are the known given names '
  'fn_registration_name_check compares against. Given names only. Never read '
  'by a visitor: RLS on, no policy, no grant.';

ALTER TABLE tbl_common_given_name ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_common_given_name FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON tbl_common_given_name TO service_role;

-- ---------------------------------------------------------------------------
-- 2. The name form.
-- ---------------------------------------------------------------------------

-- Python's str.title(), the rule the organizer's files have always used: a
-- letter that follows a non-letter starts a word („o'neil” → „O'Neil”). Not
-- initcap(), which leaves „O'neil”.
CREATE OR REPLACE FUNCTION fn_python_title(p_value TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  v_lower  TEXT := lower(COALESCE(p_value, ''));
  v_out    TEXT := '';
  v_ch     TEXT;
  v_letter BOOLEAN := FALSE;
BEGIN
  FOR i IN 1 .. char_length(v_lower) LOOP
    v_ch := substr(v_lower, i, 1);
    IF v_ch ~ '[[:alpha:]]' THEN
      IF NOT v_letter THEN
        v_ch := upper(v_ch);
      END IF;
      v_letter := TRUE;
    ELSE
      v_letter := FALSE;
    END IF;
    v_out := v_out || v_ch;
  END LOOP;
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_python_title(TEXT) IS
  'FR-167: Python str.title() — the given name''s written form, as the '
  'organizer''s files write it. Twin of pythonTitle in registrationName.ts.';

-- A title is a whole word from a fixed list, with or without its dot, taken
-- off either end of the surname, never its last word. Self-contained (no
-- helper) because anon calls it through the two lookups below, which are
-- SECURITY INVOKER: every function it called would need its own grant.
CREATE OR REPLACE FUNCTION fn_name_without_title(p_surname TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  v_words TEXT[] := regexp_split_to_array(btrim(COALESCE(p_surname, '')), '\s+');
  v_keys  CONSTANT TEXT[] := ARRAY['dr', 'ddr', 'prof', 'ing', 'mag', 'mgr', 'doc', 'dipling'];
  v_out   TEXT := '';
  v_word  TEXT;
BEGIN
  WHILE array_length(v_words, 1) > 1
    AND lower(regexp_replace(v_words[1], '[.-]', '', 'g')) = ANY (v_keys) LOOP
    v_words := v_words[2:];
  END LOOP;
  WHILE array_length(v_words, 1) > 1
    AND lower(regexp_replace(v_words[array_length(v_words, 1)], '[.-]', '', 'g')) = ANY (v_keys) LOOP
    v_words := v_words[1:array_length(v_words, 1) - 1];
  END LOOP;
  -- Joined by hand: array_to_string is only STABLE, and this is IMMUTABLE.
  FOREACH v_word IN ARRAY v_words LOOP
    v_out := CASE WHEN v_out = '' THEN v_word ELSE v_out || ' ' || v_word END;
  END LOOP;
  RETURN v_out;
END;
$$;

COMMENT ON FUNCTION fn_name_without_title(TEXT) IS
  'FR-167: the surname with a title (dr, ddr, prof, ing, mag, mgr, doc, '
  'dipl-ing) taken off either end, never its last word. What every name '
  'comparison uses. Twin of surnameWithoutTitle in registrationName.ts.';

GRANT EXECUTE ON FUNCTION fn_name_without_title(TEXT) TO anon, authenticated, service_role;

-- Both boxes in their written form: titles found at either end of either box
-- go in front of the surname in their one form; surname in capitals; given
-- name in title case; outer spaces trimmed, doubled spaces collapsed.
CREATE OR REPLACE FUNCTION fn_registration_canonical_names(p_surname TEXT, p_first_name TEXT)
RETURNS TABLE (txt_surname TEXT, txt_first_name TEXT)
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  v_titles TEXT[] := '{}';
  v_back   TEXT[];
  v_s      TEXT[] := array_remove(regexp_split_to_array(btrim(COALESCE(p_surname, '')), '\s+'), '');
  v_f      TEXT[] := array_remove(regexp_split_to_array(btrim(COALESCE(p_first_name, '')), '\s+'), '');
  v_form   TEXT;
  v_pass   INT;
  v_words  TEXT[];
  v_head   TEXT;
  v_bare   TEXT;
BEGIN
  FOR v_pass IN 1 .. 2 LOOP
    v_words := CASE v_pass WHEN 1 THEN v_s ELSE v_f END;
    v_back := '{}';
    LOOP
      EXIT WHEN COALESCE(array_length(v_words, 1), 0) <= 1;
      v_form := CASE lower(regexp_replace(v_words[1], '[.-]', '', 'g'))
        WHEN 'dr' THEN 'Dr.' WHEN 'ddr' THEN 'DDr.' WHEN 'prof' THEN 'Prof.'
        WHEN 'ing' THEN 'Ing.' WHEN 'mag' THEN 'Mag.' WHEN 'mgr' THEN 'Mgr.'
        WHEN 'doc' THEN 'Doc.' WHEN 'dipling' THEN 'Dipl.-Ing.' END;
      EXIT WHEN v_form IS NULL;
      v_titles := v_titles || v_form;
      v_words := v_words[2:];
    END LOOP;
    LOOP
      EXIT WHEN COALESCE(array_length(v_words, 1), 0) <= 1;
      v_form := CASE lower(regexp_replace(v_words[array_length(v_words, 1)], '[.-]', '', 'g'))
        WHEN 'dr' THEN 'Dr.' WHEN 'ddr' THEN 'DDr.' WHEN 'prof' THEN 'Prof.'
        WHEN 'ing' THEN 'Ing.' WHEN 'mag' THEN 'Mag.' WHEN 'mgr' THEN 'Mgr.'
        WHEN 'doc' THEN 'Doc.' WHEN 'dipling' THEN 'Dipl.-Ing.' END;
      EXIT WHEN v_form IS NULL;
      v_back := v_form || v_back;
      v_words := v_words[1:array_length(v_words, 1) - 1];
    END LOOP;
    v_titles := v_titles || v_back;
    IF v_pass = 1 THEN
      v_s := v_words;
    ELSE
      v_f := v_words;
    END IF;
  END LOOP;

  -- Joined by hand: array_to_string is only STABLE, and this is IMMUTABLE.
  -- The titles keep their form; only the surname's words go to capitals.
  v_head := '';
  FOREACH v_form IN ARRAY v_titles LOOP
    v_head := CASE WHEN v_head = '' THEN v_form ELSE v_head || ' ' || v_form END;
  END LOOP;
  v_bare := '';
  FOREACH v_form IN ARRAY v_s LOOP
    v_bare := CASE WHEN v_bare = '' THEN v_form ELSE v_bare || ' ' || v_form END;
  END LOOP;
  txt_surname := CASE
    WHEN v_head = '' THEN upper(v_bare)
    WHEN v_bare = '' THEN v_head
    ELSE v_head || ' ' || upper(v_bare)
  END;
  txt_first_name := '';
  FOREACH v_form IN ARRAY v_f LOOP
    txt_first_name := CASE WHEN txt_first_name = '' THEN v_form ELSE txt_first_name || ' ' || v_form END;
  END LOOP;
  txt_first_name := fn_python_title(txt_first_name);
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION fn_registration_canonical_names(TEXT, TEXT) IS
  'FR-167: a declared name in its one written form — titles in front of the '
  'surname, surname in capitals, given name in title case, spaces collapsed. '
  'Twin of normaliseNames in registrationName.ts. Used by the registration '
  'trigger; not granted to visitors.';

REVOKE EXECUTE ON FUNCTION fn_python_title(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION fn_registration_canonical_names(TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. The trigger writes the name form for a newcomer's row. SECURITY DEFINER
--    so a signed-in administrator's direct write reaches the helper functions
--    without granting them.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trim_registration_names()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.id_fencer IS NULL THEN
    SELECT c.txt_surname, c.txt_first_name
      INTO NEW.txt_surname, NEW.txt_first_name
      FROM fn_registration_canonical_names(NEW.txt_surname, NEW.txt_first_name) c;
  ELSE
    IF NEW.txt_surname IS NOT NULL THEN
      NEW.txt_surname := btrim(NEW.txt_surname);
    END IF;
    IF NEW.txt_first_name IS NOT NULL THEN
      NEW.txt_first_name := btrim(NEW.txt_first_name);
    END IF;
  END IF;
  IF NEW.txt_club IS NOT NULL THEN
    NEW.txt_club := NULLIF(btrim(NEW.txt_club), '');
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_trim_registration_names() IS
  'BEFORE INSERT OR UPDATE trigger on tbl_registration. A newcomer''s row '
  '(id_fencer NULL) is written in the name form of fn_registration_canonical_'
  'names (FR-167, 2026-11-21); a linked row''s names are only trimmed, because '
  'trg_registration_roster_name has already given it the roster''s. txt_club '
  'is trimmed to NULL when blank (2026-09-13).';

-- ---------------------------------------------------------------------------
-- 4. The lookups compare the surname without its title.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_match_registration_fencer(
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year SMALLINT
)
RETURNS INT
LANGUAGE sql
STABLE
AS $$
  SELECT id_fencer FROM tbl_fencer
  WHERE upper(trim(txt_surname)) = upper(trim(fn_name_without_title(p_surname)))
    AND upper(trim(txt_first_name)) = upper(trim(p_first_name))
    AND int_birth_year = p_birth_year
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION fn_registration_identity_candidates(
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year SMALLINT
)
RETURNS TABLE (
  id_fencer                 INT,
  txt_surname               TEXT,
  txt_first_name            TEXT,
  int_birth_year            SMALLINT,
  bool_birth_year_estimated BOOLEAN,
  enum_kind                 TEXT
)
LANGUAGE sql
STABLE
AS $$
  -- Candidates in the order the fencer typed them.
  SELECT
    f.id_fencer,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    f.bool_birth_year_estimated,
    CASE
      WHEN f.int_birth_year IS NULL        THEN 'BY_NULL'
      WHEN f.int_birth_year = p_birth_year THEN 'EXACT'
      ELSE                                      'BY_DIFFERS'
    END AS enum_kind
  FROM tbl_fencer f
  WHERE fn_fold_name(f.txt_surname)    = fn_fold_name(fn_name_without_title(p_surname))
    AND fn_fold_name(f.txt_first_name) = fn_fold_name(p_first_name)

  UNION ALL

  -- The same lookup with the two name fields exchanged (rung 3, ADR-093).
  SELECT
    f.id_fencer,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    f.bool_birth_year_estimated,
    'SWAPPED' AS enum_kind
  FROM tbl_fencer f
  WHERE fn_fold_name(f.txt_surname)    = fn_fold_name(p_first_name)
    AND fn_fold_name(f.txt_first_name) = fn_fold_name(fn_name_without_title(p_surname))
    AND NOT (fn_fold_name(f.txt_surname)    = fn_fold_name(fn_name_without_title(p_surname))
         AND fn_fold_name(f.txt_first_name) = fn_fold_name(p_first_name))
$$;

COMMENT ON FUNCTION fn_registration_identity_candidates IS
  'Near-miss identity lookup for the registration form (plan 2026-09-12 §7). '
  'Scans by NAME, not by tuple, so unlike fn_match_registration_fencer it can '
  'see fencers whose birth year is NULL. Comparison goes through fn_fold_name '
  '(2026-09-25) and ignores a title in the surname (FR-167, 2026-11-21). '
  'Classifies every candidate as EXACT | SWAPPED | BY_NULL | BY_DIFFERS and '
  'DECIDES NOTHING. The caller applies the six-rung resolution order.';

-- ---------------------------------------------------------------------------
-- 5. The reversed-fields question's two answers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registration_name_check(p_surname TEXT, p_first_name TEXT)
RETURNS TABLE (bool_surname_is_given_name BOOLEAN, bool_given_name_known BOOLEAN)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH known AS (
    SELECT txt_name_key AS k FROM tbl_common_given_name
    UNION
    SELECT fn_fold_name(txt_first_name) FROM tbl_fencer WHERE txt_first_name IS NOT NULL
  ),
  typed AS (
    SELECT fn_fold_name(fn_name_without_title(p_surname)) AS s,
           fn_fold_name(p_first_name)                     AS f
  ),
  -- A double name is known when the whole is, or each of its parts is.
  judged AS (
    SELECT
      t.s IN (SELECT k FROM known)
        OR (t.s ~ '[ -]' AND NOT EXISTS (
              SELECT 1 FROM regexp_split_to_table(t.s, '[ -]+') p
               WHERE p <> '' AND p NOT IN (SELECT k FROM known))) AS s_known,
      t.f IN (SELECT k FROM known)
        OR (t.f ~ '[ -]' AND NOT EXISTS (
              SELECT 1 FROM regexp_split_to_table(t.f, '[ -]+') p
               WHERE p <> '' AND p NOT IN (SELECT k FROM known))) AS f_known,
      t.s = '' AS s_empty,
      t.f = '' AS f_empty
    FROM typed t
  )
  SELECT (s_known AND NOT s_empty), (f_known OR f_empty) FROM judged;
$$;

COMMENT ON FUNCTION fn_registration_name_check(TEXT, TEXT) IS
  'FR-167: two yes/no answers for the registration form — is the typed '
  'surname (title ignored) a known given name, and is the typed given name '
  'known. Known given names: tbl_common_given_name plus tbl_fencer''s, folded; '
  'a double name is known when the whole or each part is. SECURITY DEFINER so '
  'a visitor gets the answers and never the lists.';

REVOKE EXECUTE ON FUNCTION fn_registration_name_check(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_registration_name_check(TEXT, TEXT) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. Rows written before this migration: rewritten once. Newcomers' rows go
--    through the trigger above; linked rows are given the roster's name again.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registration_realign_names()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_newcomers INT;
  v_linked    INT;
BEGIN
  UPDATE tbl_registration r
     SET txt_surname = r.txt_surname
   WHERE r.id_fencer IS NULL
     AND EXISTS (
       SELECT 1 FROM fn_registration_canonical_names(r.txt_surname, r.txt_first_name) c
        WHERE (c.txt_surname, c.txt_first_name) IS DISTINCT FROM (r.txt_surname, r.txt_first_name));
  GET DIAGNOSTICS v_newcomers = ROW_COUNT;

  UPDATE tbl_registration r
     SET txt_surname = f.txt_surname, txt_first_name = f.txt_first_name
    FROM tbl_fencer f
   WHERE r.id_fencer = f.id_fencer
     AND (r.txt_surname, r.txt_first_name) IS DISTINCT FROM (f.txt_surname, f.txt_first_name);
  GET DIAGNOSTICS v_linked = ROW_COUNT;

  RETURN v_newcomers + v_linked;
END;
$$;

COMMENT ON FUNCTION fn_registration_realign_names() IS
  'FR-167: rewrites registrations written before the name form existed — '
  'newcomers'' rows into fn_registration_canonical_names, linked rows to the '
  'roster''s name. Returns the number of rows changed. Run once by migration '
  '20261121000001; idempotent.';

REVOKE EXECUTE ON FUNCTION fn_registration_realign_names() FROM PUBLIC, anon, authenticated;

SELECT fn_registration_realign_names();

COMMIT;
