-- =============================================================================
-- Overwriting a CONFIRMED birth year is loud
-- =============================================================================
-- fn_confirm_registration_identity (20260912000001) can write three ways, and
-- only one of them deserves attention:
--
--   populate a NULL      — a gap being filled. Contradicts nothing.
--   overwrite an ESTIMATE — a guess being corrected by the person themselves.
--                           That is the estimate working as intended.
--   overwrite a CONFIRMED year — a value somebody already checked, changed by
--                           an anonymous member of the public.
--
-- The third is different in kind. It is still the right thing to allow — a
-- fencer's own declaration about their own birth year outranks anything we
-- derived, which is the whole reason ADR-079's read-only invariant was
-- reversed — but allowing it quietly is not the same as allowing it. The change
-- moves a fencer between V-categories, re-scores every event they have played,
-- and nobody on the SPWS side would ever learn it happened.
--
-- trg_audit_fencer already records it, and that is exactly the problem: the
-- audit log records EVERY fencer update, so this one is indistinguishable from
-- an administrator fixing a typo unless someone already knows to look. Evidence
-- you have to know to go and find is not a signal.
--
-- So the loud case gets its own row. Narrow on purpose: alerting on the two
-- quiet cases as well would bury the one that matters in noise nobody reads.
--
-- WHY IT DENORMALISES THE DECLARED IDENTITY. ADR-079 makes tbl_registration
-- EPHEMERAL — purged once an event's results are ingested and reconciled. A
-- plain FK to it would therefore delete the evidence at precisely the moment
-- somebody asks why a fencer's birth year changed, because the purge happens
-- after the event the change was made for. The registration link is kept but
-- nullable (ON DELETE SET NULL), and the name is copied so the record stands on
-- its own afterwards.
--
-- Plan-test-ID 75.12-75.13.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

CREATE TABLE IF NOT EXISTS tbl_registration_identity_override (
    id_override           SERIAL PRIMARY KEY,
    -- Nullable by design: the registration is purged, this is not.
    id_registration       INT REFERENCES tbl_registration(id_registration) ON DELETE SET NULL,
    id_fencer             INT NOT NULL REFERENCES tbl_fencer(id_fencer) ON DELETE CASCADE,
    -- Copied from the registration so the row survives that purge intact.
    txt_surname           TEXT NOT NULL,
    txt_first_name        TEXT NOT NULL,
    int_birth_year_before SMALLINT NOT NULL,
    int_birth_year_after  SMALLINT NOT NULL,
    ts_created            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Claimed by the drain when the operator has been told. NULL = still owed
    -- an alert, which is what makes the send idempotent across retries.
    ts_notified           TIMESTAMPTZ
);

COMMENT ON TABLE tbl_registration_identity_override IS
  'One row per CONFIRMED master birth year overwritten through the public '
  'registration form (plan 2026-09-12 §4). Deliberately narrow: populating a '
  'NULL or correcting an estimate is policy and stays silent, because alerting '
  'on those would bury this case in noise. Denormalises the declared name '
  'because tbl_registration is ephemeral (ADR-079) and the evidence must '
  'outlive it. ts_notified NULL means the operator alert is still owed.';

CREATE INDEX IF NOT EXISTS idx_identity_override_unnotified
  ON tbl_registration_identity_override (ts_created)
  WHERE ts_notified IS NULL;

-- RLS: this names fencers and their birth years, so it is an ADR-078 surface.
-- No anon policy at all — the public writes it only through the SECURITY
-- DEFINER function below, and can never read it back.
ALTER TABLE tbl_registration_identity_override ENABLE ROW LEVEL SECURITY;
-- Dropped first so the whole file stays re-runnable, like its CREATE TABLE IF
-- NOT EXISTS and CREATE OR REPLACE neighbours. CREATE POLICY has no IF NOT
-- EXISTS, and a migration that aborts halfway through on its second run is the
-- kind of thing only discovered during an incident.
DROP POLICY IF EXISTS "Admin all identity overrides" ON tbl_registration_identity_override;
CREATE POLICY "Admin all identity overrides" ON tbl_registration_identity_override
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- Re-create the writer with the loud branch. Everything else is byte-identical
-- to 20260912000001 — the guards, the ordering and the plain UPDATE are
-- unchanged, and the fast path is still never consulted here.
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
  v_was_est    BOOLEAN;
BEGIN
  IF p_action NOT IN ('ADOPT_DECLARED', 'FIX_REGISTRATION', 'DIFFERENT_PERSON') THEN
    RAISE EXCEPTION 'Unknown identity action %', p_action;
  END IF;

  IF p_edit_token IS NULL THEN
    RAISE EXCEPTION 'Edit token required';
  END IF;

  -- GUARD 1 — the capability.
  SELECT r.id_event, r.txt_surname, r.txt_first_name, r.int_birth_year
    INTO v_event, v_surname, v_first_name, v_birth_year
    FROM tbl_registration r
   WHERE r.id_registration = p_id_registration
     AND r.uuid_edit_token = p_edit_token;

  IF v_event IS NULL THEN
    RAISE EXCEPTION 'Registration not found or edit token invalid';
  END IF;

  SELECT COALESCE(dt_registration_deadline, dt_start) INTO v_cutoff
    FROM tbl_event WHERE id_event = v_event;

  IF v_cutoff IS NOT NULL AND now()::date > v_cutoff THEN
    RAISE EXCEPTION 'Registration window closed for event %', v_event;
  END IF;

  IF p_action = 'DIFFERENT_PERSON' THEN
    RETURN p_id_registration;
  END IF;

  IF p_id_fencer IS NULL THEN
    RAISE EXCEPTION 'A fencer must be named for action %', p_action;
  END IF;

  -- GUARD 2 — the candidate set, recomputed server-side from the
  -- registration's own stored declaration, never from caller input.
  SELECT c.enum_kind, c.int_birth_year, c.bool_birth_year_estimated
    INTO v_kind, v_fencer_by, v_was_est
    FROM fn_registration_identity_candidates(v_surname, v_first_name, v_birth_year) c
   WHERE c.id_fencer = p_id_fencer;

  IF v_kind IS NULL THEN
    RAISE EXCEPTION
      'Fencer % is not a candidate for registration %', p_id_fencer, p_id_registration;
  END IF;

  IF p_action = 'ADOPT_DECLARED' THEN
    -- THE LOUD BRANCH. Recorded BEFORE the update, while the old value is still
    -- readable, and only when a CONFIRMED year is actually being changed —
    -- v_was_est excludes the estimate correction, and IS DISTINCT FROM excludes
    -- a no-op confirmation that changes nothing and should alert nobody.
    IF v_fencer_by IS NOT NULL
       AND NOT v_was_est
       AND v_fencer_by IS DISTINCT FROM v_birth_year THEN
      INSERT INTO tbl_registration_identity_override (
        id_registration, id_fencer, txt_surname, txt_first_name,
        int_birth_year_before, int_birth_year_after
      ) VALUES (
        p_id_registration, p_id_fencer, v_surname, v_first_name,
        v_fencer_by, v_birth_year
      );

      -- Loud in the log as well as in the table, so anyone tailing the database
      -- sees it without having to know this table exists.
      RAISE WARNING
        'Confirmed birth year overwritten from a public registration: fencer % (% %) % -> %',
        p_id_fencer, v_surname, v_first_name, v_fencer_by, v_birth_year;
    END IF;

    -- GUARD 4 — a plain UPDATE, so trg_fencer_change_enqueue re-queues every
    -- event this fencer played and trg_audit_fencer records the change.
    UPDATE tbl_fencer
       SET int_birth_year            = v_birth_year,
           bool_birth_year_estimated = FALSE
     WHERE id_fencer = p_id_fencer
       AND (int_birth_year IS DISTINCT FROM v_birth_year
            OR bool_birth_year_estimated IS DISTINCT FROM FALSE);

  ELSIF p_action = 'FIX_REGISTRATION' THEN
    IF v_fencer_by IS NULL THEN
      RAISE EXCEPTION
        'Fencer % has no birth year to copy onto the registration', p_id_fencer;
    END IF;

    UPDATE tbl_registration
       SET int_birth_year = v_fencer_by
     WHERE id_registration = p_id_registration;
  END IF;

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
  'own declaration outranks a scraped value. Gated on uuid_edit_token and on a '
  'candidate set recomputed server-side, so no caller can name an arbitrary '
  'fencer. ADOPT_DECLARED corrects the master birth year and marks it '
  'confirmed; FIX_REGISTRATION corrects the registration; DIFFERENT_PERSON '
  'writes nothing. Overwriting an already-CONFIRMED year additionally records a '
  'row in tbl_registration_identity_override and raises a WARNING — that case '
  'is a member of the public changing a value somebody had already checked, and '
  'it is allowed but never silent.';

GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- The operator's read. Claims every override still owed an alert and stamps it
-- in the same statement, so two concurrent drains cannot both report the same
-- change and a crash after the send cannot replay it.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_claim_identity_override_alerts()
RETURNS TABLE (
  id_override           INT,
  id_fencer             INT,
  txt_surname           TEXT,
  txt_first_name        TEXT,
  int_birth_year_before SMALLINT,
  int_birth_year_after  SMALLINT,
  ts_created            TIMESTAMPTZ
)
LANGUAGE sql
AS $$
  -- Every column reference is qualified. RETURNS TABLE puts the output names
  -- in scope inside the body, so a bare `ts_created` binds to the OUT parameter
  -- rather than to the column — which ORDER BY then rejects as a constant.
  WITH claimed AS (
    UPDATE tbl_registration_identity_override o
       SET ts_notified = NOW()
     WHERE o.id_override IN (
       SELECT p.id_override FROM tbl_registration_identity_override p
        WHERE p.ts_notified IS NULL
        ORDER BY p.ts_created
        FOR UPDATE SKIP LOCKED
     )
     RETURNING o.id_override, o.id_fencer, o.txt_surname, o.txt_first_name,
               o.int_birth_year_before, o.int_birth_year_after, o.ts_created
  )
  SELECT c.id_override, c.id_fencer, c.txt_surname, c.txt_first_name,
         c.int_birth_year_before, c.int_birth_year_after, c.ts_created
    FROM claimed c ORDER BY c.ts_created;
$$;

-- Postgres grants EXECUTE on a new function to PUBLIC by default, so "I did not
-- write a GRANT" does not mean "anon cannot call it". Left as-is, an anonymous
-- visitor could claim-and-stamp every pending override and the operator would
-- simply never be told — the alert silenced by the same public surface that
-- triggers it. Caught by 52.7's set-equality allowlist, which is exactly the
-- failure mode a deny-list would have missed.
REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM anon;
GRANT EXECUTE ON FUNCTION fn_claim_identity_override_alerts() TO authenticated;

COMMENT ON FUNCTION fn_claim_identity_override_alerts IS
  'Claim-and-stamp the confirmed-birth-year overrides still owed an operator '
  'alert. Stamping inside the same statement (with SKIP LOCKED) is what makes '
  'the alert exactly-once under a drain that runs every fifteen minutes and can '
  'overlap itself. Admin-only: no anon grant.';

COMMIT;
