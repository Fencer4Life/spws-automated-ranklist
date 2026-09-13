-- =============================================================================
-- The registration-identity block — near-miss lookup + authorised correction
-- =============================================================================
-- fn_match_registration_fencer matches the exact tuple (upper(surname),
-- upper(first name), birth year). That is deliberate and it stays exactly as it
-- is: an exact-tuple matcher can never merge two different people, and on PROD
-- it resolves 36 of PPW1-2026-2027's 43 registrations. Neither function below
-- touches it, and neither touches fn_create_registration.
--
-- What it cannot do is tell anyone about a NEAR miss. Every discrepancy —
-- a birth year off by one, two name fields typed in the wrong boxes — falls
-- into the unmatched bucket silently, the fencer is created again at ingestion,
-- and the same person reaches the organizer's software twice. Measured on PROD
-- 2026-09-12, all seven PPW1 misses were near-misses, not newcomers:
--
--   BUJKO Paulina 1982     vs #30  1979 confirmed     → BY_DIFFERS
--   STAŃCZYK MARCIN 1979   vs #280 1980 confirmed     → BY_DIFFERS
--   KRZYSZTOF Łęcki 1991   vs #168 ŁĘCKI Krzysztof    → SWAPPED
--   KANIECKI, PERKOWSKI, SIEJKOWSKI, ZANEUSKAYA       → genuinely new
--
-- The fix is to show the near miss to a human, not to loosen the matcher.
--
-- THIS REVERSES A STANDING INVARIANT. ADR-079 made the declared birth year
-- read-only — it never wrote back to tbl_fencer — and ADR-080 §2 repeats that.
-- A registration is a first-hand declaration by a fencer about their own birth
-- year, which outranks anything we derived by scraping, so it is now allowed to
-- write back. That is a deliberate decision and is recorded as one.
--
-- WHAT THAT EXPOSES, AND THE FOUR GUARDS. The write is reachable by an
-- anonymous visitor, so "anyone who knows a fencer's name can change that
-- fencer's birth year" has to be false by construction, not by convention:
--
--   1. CAPABILITY. The write is gated on tbl_registration.uuid_edit_token
--      (20260828000003), so the caller must hold the handle for the row they
--      just created — not merely know a name. fn_create_registration is NOT
--      widened; it stays a registration-only function.
--   2. CANDIDATE SET, RECOMPUTED SERVER-SIDE from the registration's own
--      declared name. Without this a caller could name ANY id_fencer and
--      rewrite their birth year; with it the reachable set is the handful of
--      people who share the registrant's name.
--   3. A CONFIRMED BIRTH YEAR IS NEVER OVERWRITTEN SILENTLY. NULL and
--      estimated are overwritten by policy; confirmed only when a person
--      explicitly answers "it is me, my year is right". That is the whole
--      difference between the silent rung and the asking rung.
--   4. PLAIN UPDATE, never a trigger-disabling path — see below.
--
-- WHY THE PLAIN UPDATE IS LOAD-BEARING. trg_assert_result_vcat fires only on
-- tbl_result, so it does NOT guard a birth-year change on tbl_fencer: on its
-- own, such a change would leave every old result in its old V-cat with no
-- error raised anywhere. What saves it is trg_fencer_change_enqueue, which
-- fires AFTER UPDATE ON tbl_fencer and is column-aware (birth year /
-- nationality → enqueue; name / alias → nothing). It enqueues a recompute of
-- every event that fencer played (ADR-071, 20260615000001_cdc_recompute_dedup),
-- and the PROD drain runs every fifteen minutes, so the ranking heals itself.
-- Any path that disables triggers would leave the ranking inconsistent with no
-- error at all. trg_audit_fencer likewise records the write, which is what
-- makes guard 3 auditable after the fact.
--
-- Plan-test-ID 75 (supabase/tests/75_registration_identity_candidates.sql).
-- Plan: doc/plans/ftl-xml-export-2026-09-12.html §4, §5, §7.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- ---------------------------------------------------------------------------
-- 1. The lookup. ONE function, four classifications.
--
-- It scans BY NAME rather than by tuple, which is what lets it see the nine
-- NULL-birth-year rows on PROD that the exact matcher structurally cannot
-- reach — NULL is never equal to anything, so int_birth_year = p_birth_year is
-- never true for them. That removes the need for a second, dedicated
-- NULL-birth-year lookup.
--
-- It CLASSIFIES and never decides. Returning every candidate is what makes the
-- same-name case safe: tbl_fencer has no uniqueness constraint on name + birth
-- year (only the primary key and the non-unique idx_fencer_name), and PROD
-- carries two live same-name pairs — #197 MŁYNEK Janusz 1951 with 19 results
-- beside #356 …1984, and #354/#355 KRAWCZYK Paweł. A function that picked one
-- of them could write a birth year onto the wrong person, and that is
-- unrecoverable. The caller resolves by the six-rung order in the plan's §7,
-- where "exactly one" is the ORDER itself rather than a condition bolted onto
-- each rule.
--
-- Read-only, so no SECURITY DEFINER: tbl_fencer already carries a "Public read
-- fencers" RLS policy and anon can SELECT it directly today.
-- ---------------------------------------------------------------------------
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
      WHEN f.int_birth_year IS NULL              THEN 'BY_NULL'
      WHEN f.int_birth_year = p_birth_year       THEN 'EXACT'
      ELSE                                            'BY_DIFFERS'
    END AS enum_kind
  FROM tbl_fencer f
  WHERE upper(btrim(f.txt_surname))    = upper(btrim(p_surname))
    AND upper(btrim(f.txt_first_name)) = upper(btrim(p_first_name))

  UNION ALL

  -- The same lookup with the two name fields exchanged. A hit here is
  -- near-certain proof that they were typed into the wrong boxes — it is how
  -- KRZYSZTOF Łęcki reaches ŁĘCKI Krzysztof #168. The birth year is NOT
  -- required to agree: the prompt shows the candidate's year and lets the
  -- person judge. Rows already reported in the typed order are excluded so a
  -- palindromic name cannot be classified twice.
  SELECT
    f.id_fencer,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    f.bool_birth_year_estimated,
    'SWAPPED' AS enum_kind
  FROM tbl_fencer f
  WHERE upper(btrim(f.txt_surname))    = upper(btrim(p_first_name))
    AND upper(btrim(f.txt_first_name)) = upper(btrim(p_surname))
    AND NOT (upper(btrim(f.txt_surname))    = upper(btrim(p_surname))
         AND upper(btrim(f.txt_first_name)) = upper(btrim(p_first_name)))
$$;

COMMENT ON FUNCTION fn_registration_identity_candidates IS
  'Near-miss identity lookup for the registration form (plan 2026-09-12 §7). '
  'Scans by NAME, not by tuple, so unlike fn_match_registration_fencer it can '
  'see fencers whose birth year is NULL. Classifies every candidate as EXACT | '
  'SWAPPED | BY_NULL | BY_DIFFERS and DECIDES NOTHING — returning all of them '
  'is what keeps the same-name case (MŁYNEK Janusz 1951 vs 1984) safe. The '
  'caller applies the six-rung resolution order. Does not replace or relax '
  'fn_match_registration_fencer, which keeps serving the exact-match fast path.';

GRANT EXECUTE ON FUNCTION fn_registration_identity_candidates(TEXT, TEXT, SMALLINT) TO anon;
GRANT EXECUTE ON FUNCTION fn_registration_identity_candidates(TEXT, TEXT, SMALLINT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. The write. Three actions, mapping to the three buttons on the D prompt.
--
--   ADOPT_DECLARED   — "it is me, my year is right": link the registration and
--                      correct the MASTER birth year, marking it confirmed.
--   FIX_REGISTRATION — "it is me, I mistyped": correct the REGISTRATION to the
--                      table's year and leave the fencer row untouched.
--   DIFFERENT_PERSON — link nothing, write nothing; the fencer is created at
--                      scraping time exactly as today.
--
-- SECURITY DEFINER because it writes tbl_fencer and tbl_registration, neither
-- of which anon may write directly. Every guard above is enforced here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_confirm_registration_identity(
  p_id_registration INT,
  p_edit_token      UUID,
  p_id_fencer       INT,
  p_action          TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event      INT;
  v_surname    TEXT;
  v_first_name TEXT;
  v_birth_year SMALLINT;
  v_cutoff     DATE;
  v_kind       TEXT;
  v_fencer_by  SMALLINT;
BEGIN
  IF p_action NOT IN ('ADOPT_DECLARED', 'FIX_REGISTRATION', 'DIFFERENT_PERSON') THEN
    RAISE EXCEPTION 'Unknown identity action %', p_action;
  END IF;

  IF p_edit_token IS NULL THEN
    RAISE EXCEPTION 'Edit token required';
  END IF;

  -- GUARD 1 — the capability. Verify the token and read the registration's own
  -- declared identity in one step. As in fn_update_registration, a wrong token
  -- and a non-existent row are deliberately indistinguishable to the caller.
  SELECT r.id_event, r.txt_surname, r.txt_first_name, r.int_birth_year
    INTO v_event, v_surname, v_first_name, v_birth_year
    FROM tbl_registration r
   WHERE r.id_registration = p_id_registration
     AND r.uuid_edit_token = p_edit_token;

  IF v_event IS NULL THEN
    RAISE EXCEPTION 'Registration not found or edit token invalid';
  END IF;

  -- The same D10 window the create and edit paths enforce. Identity
  -- confirmation is part of registering, so it closes when registration does.
  SELECT COALESCE(dt_registration_deadline, dt_start) INTO v_cutoff
    FROM tbl_event WHERE id_event = v_event;

  IF v_cutoff IS NOT NULL AND now()::date > v_cutoff THEN
    RAISE EXCEPTION 'Registration window closed for event %', v_event;
  END IF;

  -- Nothing to authorise and nothing to write. The registration stays
  -- unmatched and identity is resolved at ingestion, as it is today.
  IF p_action = 'DIFFERENT_PERSON' THEN
    RETURN p_id_registration;
  END IF;

  IF p_id_fencer IS NULL THEN
    RAISE EXCEPTION 'A fencer must be named for action %', p_action;
  END IF;

  -- GUARD 2 — the one without which this function would be a
  -- rewrite-any-fencer's-birth-year primitive. The candidate set is recomputed
  -- HERE, from the registration's own stored declaration, never from anything
  -- the caller passed in. A fencer outside it cannot be reached at all.
  SELECT c.enum_kind, c.int_birth_year
    INTO v_kind, v_fencer_by
    FROM fn_registration_identity_candidates(v_surname, v_first_name, v_birth_year) c
   WHERE c.id_fencer = p_id_fencer;

  IF v_kind IS NULL THEN
    RAISE EXCEPTION
      'Fencer % is not a candidate for registration %', p_id_fencer, p_id_registration;
  END IF;

  IF p_action = 'ADOPT_DECLARED' THEN
    -- GUARD 4 — a PLAIN UPDATE, so trg_fencer_change_enqueue fires and every
    -- event this fencer played is queued for recompute, and trg_audit_fencer
    -- records the change. Never a trigger-disabling path: trg_assert_result_vcat
    -- does not fire on tbl_fencer, so bypassing the enqueue would leave the
    -- ranking silently inconsistent.
    --
    -- Guarded on IS DISTINCT FROM so a no-op confirmation does not enqueue a
    -- recompute of every event the fencer ever played for no reason.
    UPDATE tbl_fencer
       SET int_birth_year            = v_birth_year,
           bool_birth_year_estimated = FALSE
     WHERE id_fencer = p_id_fencer
       AND (int_birth_year IS DISTINCT FROM v_birth_year
            OR bool_birth_year_estimated IS DISTINCT FROM FALSE);

  ELSIF p_action = 'FIX_REGISTRATION' THEN
    -- The mirror image: the declaration was the typo, so the registration
    -- moves and the master row is not touched at all — not even when its birth
    -- year is merely estimated. The person said the table was right.
    IF v_fencer_by IS NULL THEN
      RAISE EXCEPTION
        'Fencer % has no birth year to copy onto the registration', p_id_fencer;
    END IF;

    UPDATE tbl_registration
       SET int_birth_year = v_fencer_by
     WHERE id_registration = p_id_registration;
  END IF;

  -- Both surviving actions mean "this is me", so the registration links to the
  -- fencer. UNIQUE(id_event, id_fencer) can refuse: that means a registration
  -- for this fencer already exists at this event. Fail loudly rather than
  -- merging, exactly as fn_update_registration does — silently collapsing two
  -- real declarations destroys one of them.
  BEGIN
    UPDATE tbl_registration
       SET id_fencer = p_id_fencer
     WHERE id_registration = p_id_registration;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Another registration for this event is already linked to that fencer';
  END;

  RETURN p_id_registration;
END;
$$;

COMMENT ON FUNCTION fn_confirm_registration_identity IS
  'Authorised identity confirmation for a registration (plan 2026-09-12 §7). '
  'Deliberately reverses ADR-079''s read-only-birth-year invariant: a fencer''s '
  'own declaration outranks a scraped value. Gated on uuid_edit_token (the '
  'caller must hold the handle for that row) and on a candidate set recomputed '
  'server-side from the registration''s own declared name, so no caller can '
  'name an arbitrary fencer. ADOPT_DECLARED corrects the master birth year and '
  'marks it confirmed; FIX_REGISTRATION corrects the registration and leaves '
  'the fencer untouched; DIFFERENT_PERSON writes nothing. Writes tbl_fencer by '
  'plain UPDATE so trg_fencer_change_enqueue re-queues every affected event and '
  'trg_audit_fencer records it.';

GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO authenticated;

COMMIT;
