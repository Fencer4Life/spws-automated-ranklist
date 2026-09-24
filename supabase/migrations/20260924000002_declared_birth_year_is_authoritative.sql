-- =============================================================================
-- Every declared birth year is authoritative — including over a CONFIRMED one.
-- =============================================================================
--
-- ADR-093 §4 (amended 2026-09-24). The decision recorded three tiers: a NULL
-- birth year filled silently, an ESTIMATED one overwritten silently, and an
-- already-CONFIRMED one captured as a PENDING proposal that only an
-- administrator could apply. This collapses the third tier into the other two:
-- the declaration is applied, whatever is stored.
--
-- WHY. The entry list is the moment the association hears from the fencer
-- directly, and what they declare about themselves outranks what we hold.
-- Leaving a correction unapplied is not neutral: the birth year decides the
-- V-category, so an unapplied correction puts somebody in the wrong category
-- on the day. Live on PPW1 2026, with the files already being imported:
-- PĘCZEK Sandra had turned V1 and declared it, her proposal sat undecided, and
-- she was seeded into a category she no longer belongs to. Six such rows were
-- waiting; two of them moved a fencer between categories.
--
-- WHAT THIS COSTS, recorded rather than argued. ADR-093 §4 refused this write
-- because ADOPT_DECLARED is a PARAMETER, not a click: the server cannot
-- distinguish a fencer pressing a button from a crafted RPC call. That is still
-- true. With the CONFIRMED tier applied, somebody who creates a registration
-- for a name read off the public entry list — minting its edit token
-- themselves, since they created the row — can move that fencer's birth year,
-- and therefore their V-category and every score they hold. The alert still
-- fires, so the change is visible after the fact rather than prevented, and
-- fn_reject_identity_override below becomes the undo. ADR-093's rejected
-- alternative stays rejected for the reason it gives: a plausibility bound
-- stops 1900 and does nothing about 1979 -> 1982.
--
-- WHAT IS UNCHANGED. §1 (registration writes the birth year and nothing else),
-- §3's guards (the caller must present the row's uuid_edit_token and name a
-- fencer inside a candidate set the server recomputes), trg_audit_fencer, and
-- §5's self-heal — trg_fencer_change_enqueue re-queues every event the fencer
-- played, which is what actually carries their points into the new category.
-- The IS DISTINCT FROM guard stays so a no-op confirmation re-queues nothing.
--
-- The override table stops being an approval queue and becomes an AUDIT LOG:
-- rows are written APPLIED at the moment of the write. It keeps the
-- denormalised name for ADR-093's original reason — tbl_registration is
-- ephemeral and is purged once results are ingested, so a foreign key would
-- delete the evidence exactly when somebody asks why a birth year changed.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. The public write applies, and records what it did.
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
    -- Overwriting an already-CONFIRMED year is the one case worth recording: a
    -- NULL is a gap and an estimate is a guess, but this changes a value
    -- somebody checked, moves the fencer between V-categories and re-scores
    -- every event they played. It is APPLIED either way now (ADR-093 section 4
    -- as amended 2026-09-24); the audit row and the alert are how anyone finds
    -- out, and fn_reject_identity_override is the undo.
    IF v_fencer_by IS NOT NULL
       AND NOT v_was_est
       AND v_fencer_by IS DISTINCT FROM v_birth_year THEN
      INSERT INTO tbl_registration_identity_override (
        id_registration, id_fencer, txt_surname, txt_first_name,
        int_birth_year_before, int_birth_year_after, enum_status
      )
      VALUES (p_id_registration, p_id_fencer, v_surname, v_first_name,
              v_fencer_by, v_birth_year, 'APPLIED');

      RAISE WARNING
        'Confirmed birth year CHANGED by a public registration: fencer % (% %) % -> %',
        p_id_fencer, v_surname, v_first_name, v_fencer_by, v_birth_year;
    END IF;

    -- One write for all three tiers. A plain UPDATE, so
    -- trg_fencer_change_enqueue re-queues the affected events (section 5).
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

COMMENT ON FUNCTION fn_confirm_registration_identity(INT, UUID, INT, TEXT) IS
  'Records the fencer''s answer to the identity prompt. ADOPT_DECLARED applies '
  'the declared birth year to tbl_fencer in every case, including over an '
  'already-CONFIRMED value (ADR-093 §4 as amended 2026-09-24): the declaration '
  'is authoritative. Overwriting a confirmed year additionally writes an '
  'APPLIED audit row and raises a WARNING the recompute drain forwards. Gated '
  'on the registration''s uuid_edit_token and on a server-recomputed candidate '
  'set.';

-- ---------------------------------------------------------------------------
-- 2. Reject becomes an UNDO, not an approval refusal.
-- ---------------------------------------------------------------------------
-- There is no longer anything to withhold approval from; what an administrator
-- needs is a way to put a wrong year back. This restores the previous value
-- through the same plain UPDATE, so the re-queue happens again in the same way.
CREATE OR REPLACE FUNCTION fn_reject_identity_override(p_id_override INT)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_fencer INT;
  v_before    INT;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'Only an administrator may revert a birth-year change';
  END IF;

  SELECT id_fencer, int_birth_year_before
    INTO v_id_fencer, v_before
    FROM tbl_registration_identity_override
   WHERE id_override = p_id_override AND enum_status = 'APPLIED';

  IF v_id_fencer IS NULL THEN
    RETURN 0;
  END IF;

  UPDATE tbl_fencer
     SET int_birth_year = v_before
   WHERE id_fencer = v_id_fencer
     AND int_birth_year IS DISTINCT FROM v_before;

  UPDATE tbl_registration_identity_override
     SET enum_status = 'REJECTED'
   WHERE id_override = p_id_override;

  RETURN 1;
END;
$$;

REVOKE ALL ON FUNCTION fn_reject_identity_override(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_reject_identity_override(INT) TO authenticated, service_role;

COMMENT ON FUNCTION fn_reject_identity_override(INT) IS
  'Administrator-only UNDO for a birth-year change a registration applied '
  '(ADR-093 §4 as amended 2026-09-24). Restores int_birth_year_before with a '
  'plain UPDATE so the affected events re-queue, and marks the audit row '
  'REJECTED. Returns 0 when the row is not an APPLIED change.';

-- ---------------------------------------------------------------------------
-- 3. The alert claims APPLIED rows — they are changes, not requests.
-- ---------------------------------------------------------------------------
-- DROP first: the OUT parameters gain id_override, and Postgres refuses to
-- change the row type of an existing function in place.
DROP FUNCTION IF EXISTS fn_claim_identity_override_alerts();

CREATE FUNCTION fn_claim_identity_override_alerts()
RETURNS TABLE (
  id_override           INT,
  id_fencer             INT,
  txt_surname           TEXT,
  txt_first_name        TEXT,
  int_birth_year_before INT,
  int_birth_year_after  INT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH claimed AS (
    SELECT p.id_override
      FROM tbl_registration_identity_override p
     WHERE p.ts_notified IS NULL
       AND p.enum_status = 'APPLIED'
     FOR UPDATE SKIP LOCKED
  )
  UPDATE tbl_registration_identity_override o
     SET ts_notified = now()
    FROM claimed
   WHERE o.id_override = claimed.id_override
  RETURNING o.id_override, o.id_fencer, o.txt_surname, o.txt_first_name,
            o.int_birth_year_before, o.int_birth_year_after;
$$;

-- Re-assert the grants the DROP above discarded. The drain calls this with the
-- service role; anon must never reach it, and a DROP takes the REVOKEs with it.
REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_claim_identity_override_alerts() FROM anon;
GRANT EXECUTE ON FUNCTION fn_claim_identity_override_alerts() TO service_role;

COMMENT ON FUNCTION fn_claim_identity_override_alerts() IS
  'Claims the confirmed-birth-year changes still owed an operator alert, '
  'stamping ts_notified in the same statement that selects them so two drains '
  'cannot both report one change. These are APPLIED changes, not requests: the '
  'alert says what happened, and fn_reject_identity_override is the undo.';

COMMENT ON COLUMN tbl_registration_identity_override.enum_status IS
  'APPLIED the moment a declaration overwrites a CONFIRMED birth year — the '
  'table is an audit log, not an approval queue (ADR-093 §4 as amended '
  '2026-09-24). REJECTED once an administrator reverts one. PENDING survives '
  'only as history: rows written before the amendment.';

-- ---------------------------------------------------------------------------
-- 4. Backfill — every declared year that still differs from the master one.
-- ---------------------------------------------------------------------------
-- The amendment applies from now on; these are the declarations made while the
-- old rule held them back. Six on PROD at the time of writing, all on PPW1
-- 2026-2027, two of which move a fencer between categories (PĘCZEK V0->V1,
-- CHUDY V1->V2) two days before the event.
--
-- A no-op on a fresh bootstrap: tbl_registration is ephemeral and is not
-- carried by the PROD export (ADR-079), so CI applies this to an empty table.
-- Idempotent by construction — it only touches rows that still differ, so a
-- re-run after the drain has settled changes nothing.
--
-- DISTINCT ON picks the most recent declaration when a fencer has entered more
-- than one event with different years: last word wins, deterministically.
DO $$
DECLARE
  v_rows INT;
BEGIN
  WITH latest AS (
    SELECT DISTINCT ON (r.id_fencer)
           r.id_fencer, r.id_registration, r.txt_surname, r.txt_first_name,
           r.int_birth_year AS declared,
           f.int_birth_year AS master,
           COALESCE(f.bool_birth_year_estimated, FALSE) AS was_est
      FROM tbl_registration r
      JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE r.int_birth_year IS DISTINCT FROM f.int_birth_year
     ORDER BY r.id_fencer, r.ts_created DESC
  )
  INSERT INTO tbl_registration_identity_override (
    id_registration, id_fencer, txt_surname, txt_first_name,
    int_birth_year_before, int_birth_year_after, enum_status
  )
  SELECT l.id_registration, l.id_fencer, l.txt_surname, l.txt_first_name,
         l.master, l.declared, 'APPLIED'
    FROM latest l
   -- Only a CONFIRMED overwrite is worth an audit row; filling a NULL or
   -- correcting an estimate is the policy working, not an event.
   WHERE l.master IS NOT NULL AND NOT l.was_est;

  -- The write itself. A plain UPDATE so trg_fencer_change_enqueue re-queues
  -- every event each fencer played and their points land in the right category.
  WITH latest AS (
    SELECT DISTINCT ON (r.id_fencer) r.id_fencer, r.int_birth_year AS declared
      FROM tbl_registration r
      JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
     WHERE r.int_birth_year IS DISTINCT FROM f.int_birth_year
     ORDER BY r.id_fencer, r.ts_created DESC
  )
  UPDATE tbl_fencer f
     SET int_birth_year            = l.declared,
         bool_birth_year_estimated = FALSE
    FROM latest l
   WHERE f.id_fencer = l.id_fencer;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RAISE NOTICE 'Declared birth years adopted into tbl_fencer: %', v_rows;
END;
$$;
