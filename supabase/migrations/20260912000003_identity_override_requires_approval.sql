-- =============================================================================
-- A confirmed birth year is PROPOSED by the public, never applied by it
-- =============================================================================
-- 20260912000002 made overwriting an already-confirmed birth year loud. Loud is
-- not the same as prevented, and the difference was demonstrated rather than
-- argued on 2026-09-12 against a PROD-mirrored LOCAL:
--
--   TARGET fencer #257 BY=1979 confirmed=t results=1
--   ATTACKER created registration 84 declaring 1900, holding its token
--   RESULT: master BY is now 1900 (was 1979)
--
-- No human answered anything. The reason is structural: `ADOPT_DECLARED` is a
-- PARAMETER, not a click. The server cannot distinguish a fencer pressing
-- "to ja — mój rocznik to 1982" from a crafted RPC call, so every protection
-- that lived in the form was worth nothing at the API boundary. Nor did the
-- edit token help — it authorises "the row you just created", and the attacker
-- created it, minting the token themselves.
--
-- ADR-093 claimed "rung 5 requires an explicit human answer". That was true of
-- the form and never of the server, and this migration makes the claim true of
-- both by removing the capability rather than narrowing it.
--
-- WHAT CHANGES. Only the confirmed case, and only its timing:
--
--   NULL birth year      -> populated immediately. A gap, contradicting nothing.
--   ESTIMATED birth year -> corrected immediately. A guess, and the person
--                           correcting it is the subject of the guess.
--   CONFIRMED birth year -> PROPOSED. Recorded, alerted, and applied only when
--                           an administrator says so.
--
-- The fencer's declaration is never lost — it is captured the moment they make
-- it. What they lose is immediacy, and the fifteen-minute alert already meant
-- an honest fencer gained little from an instant write. What an attacker loses
-- is the write entirely.
--
-- WHY NOT A PLAUSIBILITY BOUND INSTEAD. Rejecting a year outside the veteran
-- range stops `1900` and does nothing about `1979 -> 1982`, which is the change
-- an attacker would actually choose. It narrows the primitive; it does not
-- remove it.
--
-- STILL ACCEPTED, KNOWINGLY: an attacker can still vandalise one of the twenty
-- ESTIMATED birth years, because those are applied immediately by design. That
-- is the same residual ADR-093 recorded, it is loud in the audit log, and the
-- recompute queue repairs the ranking either way.
--
-- Plan-test-ID 75.8, 75.12, 75.14-75.16.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. A proposal has a lifecycle. TEXT with a CHECK rather than a PG enum, to
--    match tbl_recompute_queue.enum_status, which is also TEXT despite the
--    prefix this repo puts on such columns.
ALTER TABLE tbl_registration_identity_override
  ADD COLUMN IF NOT EXISTS enum_status TEXT NOT NULL DEFAULT 'PENDING',
  ADD COLUMN IF NOT EXISTS ts_decided  TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_identity_override_status') THEN
    ALTER TABLE tbl_registration_identity_override
      ADD CONSTRAINT chk_identity_override_status
      CHECK (enum_status IN ('PENDING', 'APPLIED', 'REJECTED'));
  END IF;
END $$;

COMMENT ON COLUMN tbl_registration_identity_override.enum_status IS
  'PENDING until an administrator decides. The public path can only ever create '
  'a PENDING row — applying is administrator-only, which is the whole point: '
  'ADOPT_DECLARED is a parameter a caller supplies, not a button only a human '
  'can press.';

COMMENT ON TABLE tbl_registration_identity_override IS
  'One row per CONFIRMED master birth year a public registration asked to '
  'change (plan 2026-09-12 §4; exposure closed 2026-09-12). The public creates '
  'the row and nothing more — tbl_fencer is not touched until '
  'fn_apply_identity_override runs as an administrator. Populating a NULL or '
  'correcting an estimate is still applied immediately and records nothing, '
  'because alerting on those would bury this case in noise. Denormalises the '
  'declared name because tbl_registration is ephemeral (ADR-079) and the '
  'evidence must outlive it.';

-- 1b. Table grants. The RLS policy added in 20260912000002 is the control, but
--     a policy grants nothing on its own — without these the administrator path
--     fails with "permission denied for table" while the policy looks correct.
--     Matches tbl_registration and tbl_fencer, which both give `authenticated`
--     full CRUD and rely on RLS. anon deliberately gets nothing at all: its only
--     route to this table is the SECURITY DEFINER writer below.
GRANT SELECT, INSERT, UPDATE, DELETE ON tbl_registration_identity_override TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE tbl_registration_identity_override_id_override_seq TO authenticated;

-- 2. The public writer: propose, do not apply.
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

  SELECT c.enum_kind, c.int_birth_year, c.bool_birth_year_estimated
    INTO v_kind, v_fencer_by, v_was_est
    FROM fn_registration_identity_candidates(v_surname, v_first_name, v_birth_year) c
   WHERE c.id_fencer = p_id_fencer;

  IF v_kind IS NULL THEN
    RAISE EXCEPTION
      'Fencer % is not a candidate for registration %', p_id_fencer, p_id_registration;
  END IF;

  IF p_action = 'ADOPT_DECLARED' THEN
    IF v_fencer_by IS NOT NULL
       AND NOT v_was_est
       AND v_fencer_by IS DISTINCT FROM v_birth_year THEN
      -- CONFIRMED and different. Record the request; change nothing. One open
      -- proposal per fencer per registration, so a caller cannot flood the
      -- operator's alert channel by re-submitting.
      INSERT INTO tbl_registration_identity_override (
        id_registration, id_fencer, txt_surname, txt_first_name,
        int_birth_year_before, int_birth_year_after
      )
      SELECT p_id_registration, p_id_fencer, v_surname, v_first_name,
             v_fencer_by, v_birth_year
      WHERE NOT EXISTS (
        SELECT 1 FROM tbl_registration_identity_override
         WHERE id_registration = p_id_registration
           AND id_fencer       = p_id_fencer
           AND enum_status     = 'PENDING'
      );

      RAISE WARNING
        'Birth-year change PROPOSED from a public registration: fencer % (% %) % -> % (awaiting approval)',
        p_id_fencer, v_surname, v_first_name, v_fencer_by, v_birth_year;
    ELSE
      -- NULL or estimated: applied immediately, as before. A plain UPDATE, so
      -- trg_fencer_change_enqueue re-queues the affected events.
      UPDATE tbl_fencer
         SET int_birth_year            = v_birth_year,
             bool_birth_year_estimated = FALSE
       WHERE id_fencer = p_id_fencer
         AND (int_birth_year IS DISTINCT FROM v_birth_year
              OR bool_birth_year_estimated IS DISTINCT FROM FALSE);
    END IF;

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
  'Records a fencer''s answer to the identity prompt (plan 2026-09-12 §7). '
  'Gated on uuid_edit_token and on a candidate set recomputed server-side. A '
  'NULL or ESTIMATED birth year is corrected immediately; an already-CONFIRMED '
  'one is only PROPOSED — the public can never change it, because the action is '
  'a parameter a caller supplies rather than a button only a human can press. '
  'FIX_REGISTRATION corrects the registration; DIFFERENT_PERSON writes nothing.';

GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) TO authenticated;

-- 3. The administrator's decision. NOT SECURITY DEFINER and never granted to
--    anon: if the public could call this, the exposure would simply move here.
CREATE OR REPLACE FUNCTION fn_apply_identity_override(p_id_override INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_fencer INT;
  v_after  SMALLINT;
BEGIN
  SELECT id_fencer, int_birth_year_after INTO v_fencer, v_after
    FROM tbl_registration_identity_override
   WHERE id_override = p_id_override AND enum_status = 'PENDING'
   FOR UPDATE;

  IF v_fencer IS NULL THEN
    RAISE EXCEPTION 'No pending identity override %', p_id_override;
  END IF;

  -- A plain UPDATE for the same reason the original write was one:
  -- trg_assert_result_vcat does not fire on tbl_fencer, so only
  -- trg_fencer_change_enqueue keeps the ranking consistent, and
  -- trg_audit_fencer records who moved it.
  UPDATE tbl_fencer
     SET int_birth_year            = v_after,
         bool_birth_year_estimated = FALSE
   WHERE id_fencer = v_fencer;

  UPDATE tbl_registration_identity_override
     SET enum_status = 'APPLIED', ts_decided = NOW()
   WHERE id_override = p_id_override;

  RETURN p_id_override;
END;
$$;

CREATE OR REPLACE FUNCTION fn_reject_identity_override(p_id_override INT)
RETURNS INT
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE tbl_registration_identity_override
     SET enum_status = 'REJECTED', ts_decided = NOW()
   WHERE id_override = p_id_override AND enum_status = 'PENDING';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pending identity override %', p_id_override;
  END IF;

  RETURN p_id_override;
END;
$$;

COMMENT ON FUNCTION fn_apply_identity_override IS
  'Administrator-only. Applies a PENDING birth-year proposal to tbl_fencer by '
  'plain UPDATE, so the recompute queue and the audit trigger both fire. '
  'Closing the row to APPLIED is what stops it being applied twice.';

COMMENT ON FUNCTION fn_reject_identity_override IS
  'Administrator-only. Closes a PENDING proposal without touching tbl_fencer. '
  'This is the attacker''s path, and it must leave the fencer untouched.';

-- Postgres grants EXECUTE to PUBLIC by default, so silence here would hand the
-- apply path straight back to anon and undo this entire migration. The same
-- default caught fn_claim_identity_override_alerts in 20260912000002, via
-- ADR-083's pgTAP 52.7.
REVOKE ALL ON FUNCTION fn_apply_identity_override(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_apply_identity_override(INT) FROM anon;
REVOKE ALL ON FUNCTION fn_reject_identity_override(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_reject_identity_override(INT) FROM anon;
GRANT EXECUTE ON FUNCTION fn_apply_identity_override(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_reject_identity_override(INT) TO authenticated;

-- 4. The alert claims only PENDING rows now: an applied or rejected proposal
--    has already had a human's attention and must not be re-announced.
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
  WITH claimed AS (
    UPDATE tbl_registration_identity_override o
       SET ts_notified = NOW()
     WHERE o.id_override IN (
       SELECT p.id_override FROM tbl_registration_identity_override p
        WHERE p.ts_notified IS NULL
          AND p.enum_status = 'PENDING'
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

REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM anon;
GRANT EXECUTE ON FUNCTION fn_claim_identity_override_alerts() TO authenticated;

COMMIT;
