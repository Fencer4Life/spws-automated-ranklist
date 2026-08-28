-- =============================================================================
-- Unmatched-registration dedupe — ADR-079 amendment (2026-08-17), open item 1.
--
-- tbl_registration carries UNIQUE(id_event, id_fencer), which dedupes the
-- matched fast path. Postgres treats NULLs as distinct, so it has never
-- constrained unmatched rows — and until 2026-08-17 that was harmless, because
-- the form dead-ended every non-exact match and no NULL-id_fencer row could be
-- written at all. Opening that path (ADR-079 amendment a) made the hole
-- reachable: a newcomer who submits twice would appear twice on the public
-- entry list and twice in the organizer's FTL seed file.
--
-- The dedupe key is the DECLARED identity — (event, surname, first name, birth
-- year) — normalised exactly as fn_match_registration_fencer normalises when it
-- looks a fencer up, so the two agree on what "the same person" means. Birth
-- year is part of the key by design (ADR-079 §2): a same-name namesake born in a
-- different year is a different entrant and keeps their own row.
--
-- A single INSERT cannot carry two ON CONFLICT arbiters, so fn_create_registration
-- branches on whether the registration is matched. Both branches keep the D10
-- registration-window guard and the COALESCE consent semantics unchanged.
-- =============================================================================

-- Fail fast rather than queue behind a conflicting lock. Supabase runs each
-- migration inside a transaction, so CREATE INDEX CONCURRENTLY is unavailable;
-- a short timeout is the alternative. tbl_registration is small (single-digit
-- rows on PROD at time of writing), so the index build itself is instant — the
-- timeout guards against blocking live registrations if something else holds a
-- lock, in which case the deploy fails loudly instead of stalling writes.
SET LOCAL lock_timeout = '2s';

-- 1. Collapse any pre-existing duplicates so the unique index can be built.
--    Keeps the HIGHEST id_registration per identity — the most recent
--    submission is the entrant's current intent, and the upsert below would
--    have produced exactly that row had it existed at the time.
WITH ranked AS (
  SELECT id_registration,
         row_number() OVER (
           PARTITION BY id_event,
                        upper(btrim(txt_surname)),
                        upper(btrim(txt_first_name)),
                        int_birth_year
           ORDER BY id_registration DESC
         ) AS rn
  FROM tbl_registration
  WHERE id_fencer IS NULL
)
DELETE FROM tbl_registration r
USING ranked
WHERE r.id_registration = ranked.id_registration
  AND ranked.rn > 1;

-- 2. The partial unique index. Scoped to id_fencer IS NULL so it never competes
--    with UNIQUE(id_event, id_fencer), which still owns the matched path.
CREATE UNIQUE INDEX IF NOT EXISTS uq_registration_unmatched_identity
  ON tbl_registration (
    id_event,
    upper(btrim(txt_surname)),
    upper(btrim(txt_first_name)),
    int_birth_year
  )
  WHERE id_fencer IS NULL;

COMMENT ON INDEX uq_registration_unmatched_identity IS
  'Dedupes UNMATCHED registrations (id_fencer IS NULL) on the declared identity, '
  'normalised as fn_match_registration_fencer normalises. UNIQUE(id_event, '
  'id_fencer) cannot do this because Postgres treats NULLs as distinct. '
  'ADR-079 amendment 2026-08-17, open item 1.';

-- 3. fn_create_registration — branch on matched vs unmatched. Signature is
--    unchanged, so CREATE OR REPLACE is sufficient (no DROP).
CREATE OR REPLACE FUNCTION fn_create_registration(
  p_event           INT,
  p_surname         TEXT,
  p_first_name      TEXT,
  p_gender          enum_gender_type,
  p_birth_year      SMALLINT,
  p_weapons         enum_weapon_type[],
  p_id_fencer       INT DEFAULT NULL,
  p_email_hash      TEXT DEFAULT NULL,
  p_consent_version TEXT DEFAULT NULL
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
    -- Unmatched: arbitrate on the declared identity via the partial index. The
    -- WHERE clause is required for Postgres to infer a PARTIAL index.
    INSERT INTO tbl_registration (
      id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
      int_birth_year, arr_weapons, txt_email_hash,
      ts_consent, txt_consent_version
    ) VALUES (
      p_event, NULL, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_email_hash,
      CASE WHEN p_consent_version IS NOT NULL THEN now() END, p_consent_version
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
      txt_email_hash       = COALESCE(EXCLUDED.txt_email_hash, tbl_registration.txt_email_hash),
      ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
      txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version)
    RETURNING id_registration INTO v_id;
  ELSE
    -- Matched: unchanged behaviour, arbitrated by UNIQUE(id_event, id_fencer).
    INSERT INTO tbl_registration (
      id_event, id_fencer, txt_surname, txt_first_name, enum_gender,
      int_birth_year, arr_weapons, txt_email_hash,
      ts_consent, txt_consent_version
    ) VALUES (
      p_event, p_id_fencer, p_surname, p_first_name, p_gender,
      p_birth_year, p_weapons, p_email_hash,
      CASE WHEN p_consent_version IS NOT NULL THEN now() END, p_consent_version
    )
    ON CONFLICT (id_event, id_fencer) DO UPDATE SET
      txt_surname          = EXCLUDED.txt_surname,
      txt_first_name       = EXCLUDED.txt_first_name,
      enum_gender          = EXCLUDED.enum_gender,
      int_birth_year       = EXCLUDED.int_birth_year,
      arr_weapons          = EXCLUDED.arr_weapons,
      ts_consent           = COALESCE(EXCLUDED.ts_consent, tbl_registration.ts_consent),
      txt_consent_version  = COALESCE(EXCLUDED.txt_consent_version, tbl_registration.txt_consent_version)
    RETURNING id_registration INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION fn_create_registration IS
  'Sole public write path for tbl_registration (FR-122). p_consent_version '
  'stamps ts_consent+txt_consent_version when given (RODO accept, D5). '
  'Rejects the write once COALESCE(dt_registration_deadline, dt_start) has '
  'passed (D10 registration-window guard); NULL dates are always open. '
  'Upserts on UNIQUE(id_event, id_fencer) when matched, and on the declared '
  'identity via uq_registration_unmatched_identity when not — a single INSERT '
  'cannot carry two ON CONFLICT arbiters, hence the branch. Note the unmatched '
  'branch does NOT update int_birth_year: it is part of that arbiter, so a '
  'different year is a different entrant, not an edit.';
