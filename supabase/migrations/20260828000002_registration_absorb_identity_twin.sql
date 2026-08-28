-- =============================================================================
-- One person, one event, one registration row — absorb the matched/unmatched twin
-- =============================================================================
-- fn_create_registration dedupes on two DIFFERENT arbiters:
--   * matched   → UNIQUE(id_event, id_fencer)
--   * unmatched → uq_registration_unmatched_identity, WHERE id_fencer IS NULL
-- Nothing spanned them, so one person could hold one row of each kind for the
-- same event. Both reach vw_registration_entry_list and the organizer's FTL
-- seed file. Confirmed on LOCAL 2026-08-28: an unmatched registration followed
-- by a matched one produced rows 21 and 24 side by side.
--
-- Reachable in both directions, and by design rather than by accident:
--   * unmatched → matched: unmatched registration became the normal path for
--     newcomers (ADR-079 amendment 2026-08-17), and a fencer's tbl_fencer row
--     is created during the window in which registration is still open — by
--     result ingestion of an earlier event, or by an administrator adding them
--     by hand.
--   * matched → unmatched: RegistrationForm.submitIdentity() deliberately
--     treats a failed lookup as "no match" so a network blip never blocks an
--     entry. A fencer who IS in tbl_fencer can therefore be written unmatched,
--     beside their own matched row.
--
-- Each branch now absorbs the twin from the other before inserting.
-- PROMOTION is preferred over delete-and-insert: ts_created and the consent
-- stamp are the RODO evidence, and consent was given at the FIRST submission,
-- so that row must survive rather than be replaced.
--
-- Plan-test-ID 58 (supabase/tests/58_registration_identity_twins.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. Collapse twins that already exist, so the invariant holds from here on.
--    Promote the unmatched row where its fencer has no matched row yet...
WITH twin AS (
  SELECT u.id_registration AS unmatched_id, m.id_fencer
  FROM tbl_registration u
  JOIN tbl_registration m
    ON m.id_event = u.id_event
   AND m.id_fencer IS NOT NULL
   AND upper(btrim(m.txt_surname))    = upper(btrim(u.txt_surname))
   AND upper(btrim(m.txt_first_name)) = upper(btrim(u.txt_first_name))
   AND m.int_birth_year               = u.int_birth_year
  WHERE u.id_fencer IS NULL
)
-- ...and since a matched row demonstrably exists for each of these, the
-- unmatched twin is the redundant one. Delete it, keeping the richer row.
DELETE FROM tbl_registration r
USING twin
WHERE r.id_registration = twin.unmatched_id;

-- 2. fn_create_registration — absorb before inserting. Signature unchanged,
--    so CREATE OR REPLACE is sufficient (no DROP).
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
    -- Unmatched. A MATCHED row for this same declared identity means the
    -- lookup blipped rather than the entrant being new — update that row and
    -- keep its fencer link rather than writing an unlinked twin beside it.
    -- Scoped to a single row: tbl_fencer can hold two people with the same
    -- name and birth year, so this could otherwise match more than one.
    UPDATE tbl_registration SET
      txt_surname          = p_surname,
      txt_first_name       = p_first_name,
      enum_gender          = p_gender,
      arr_weapons          = p_weapons,
      txt_email_hash       = COALESCE(p_email_hash, txt_email_hash),
      ts_consent           = COALESCE(
                               CASE WHEN p_consent_version IS NOT NULL THEN now() END,
                               ts_consent),
      txt_consent_version  = COALESCE(p_consent_version, txt_consent_version)
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

    -- Arbitrate on the declared identity via the partial index. The WHERE
    -- clause is required for Postgres to infer a PARTIAL index.
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
    -- Matched. Absorb the unmatched twin first. The partial unique index
    -- guarantees at most one such row per identity per event.
    IF EXISTS (
      SELECT 1 FROM tbl_registration
       WHERE id_event = p_event AND id_fencer = p_id_fencer
    ) THEN
      -- This fencer already holds a matched row, so the twin is redundant.
      DELETE FROM tbl_registration
       WHERE id_event = p_event
         AND id_fencer IS NULL
         AND upper(btrim(txt_surname))    = upper(btrim(p_surname))
         AND upper(btrim(txt_first_name)) = upper(btrim(p_first_name))
         AND int_birth_year               = p_birth_year;
    ELSE
      -- PROMOTE in place. Setting id_fencer lifts the row out of the partial
      -- index and into UNIQUE(id_event, id_fencer), where the upsert below
      -- then finds it — so ts_created and the original consent stamp survive.
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
  'different year is a different entrant, not an edit. Each branch absorbs the '
  'other''s twin for the same declared identity before inserting (2026-08-28), '
  'because the two arbiters cannot see each other and one person could '
  'otherwise hold a matched AND an unmatched row for the same event; promotion '
  'is preferred over delete-and-insert so the original consent stamp survives.';

COMMIT;
