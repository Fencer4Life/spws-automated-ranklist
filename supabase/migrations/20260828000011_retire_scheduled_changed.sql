-- =============================================================================
-- Retire SCHEDULED and CHANGED; let an unweaponed event still be cancelled
-- =============================================================================
-- ADR-077 amendment / ADR-086 amendment.
--
-- 1 · SCHEDULED and CHANGED are retired.
--     ADR-077 documents both as "Set by: EVF sync (ADR-039)". Neither ever was:
--     zero rows carry either status in either environment, and no code path sets
--     them. The intended gradient -- we have a date -> EVF confirmed it -> EVF
--     moved it -- was designed and never built.
--
--     Deprecated BEHAVIOURALLY: every branch that could reach either state is
--     removed from fn_validate_event_transition, so nothing can arrive there.
--     The enum labels stay: dropping one means recreating enum_event_status and
--     cascading through vw_eligible_event and several migrations that name
--     SCHEDULED in NOT IN lists. With zero rows the outcome is identical for a
--     fraction of the blast radius. The universal rollback-to-CREATED branch
--     still lists them so a legacy row could be reset.
--
--     What CHANGED was meant to flag -- EVF moving a date -- becomes a visual
--     pill on the event card instead, anchored to dt_start_first_published. A
--     status was the wrong home for it: it would have collided with the results
--     lifecycle, and a second move produced no transition and therefore no
--     signal at all.
--
-- 2 · fn_guard_evf_event_weapons_known now permits -> CANCELLED.
--     Added this morning (20260828000004), it blocks an unsuffixed PEW event
--     from leaving PLANNED at all. PLANNED -> CANCELLED is now an automated
--     CERT->PROD transition, so that guard would abort the entire promote over
--     one row. Cancelling an event whose weapons were never established is
--     legitimate; only advancing it into a scoring state is not.
--
-- Plan-test-ID 66 (supabase/tests/66_event_status_deprecations.sql).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_validate_event_transition()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    v_valid := CASE
        -- From CREATED (new, Phase 1B)
        WHEN OLD.enum_status = 'CREATED'      AND NEW.enum_status = 'PLANNED'     THEN TRUE
        WHEN OLD.enum_status = 'CREATED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From PLANNED
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        WHEN OLD.enum_status = 'PLANNED'      AND NEW.enum_status = 'CREATED'     THEN TRUE  -- Phase 1B rollback
        -- From IN_PROGRESS
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'SCORED'      THEN TRUE  -- Phase 1B
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'PLANNED'     THEN TRUE
        WHEN OLD.enum_status = 'IN_PROGRESS'  AND NEW.enum_status = 'CANCELLED'   THEN TRUE
        -- From SCORED (new, Phase 1B)
        WHEN OLD.enum_status = 'SCORED'       AND NEW.enum_status = 'COMPLETED'   THEN TRUE
        WHEN OLD.enum_status = 'SCORED'       AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE  -- rollback
        -- From COMPLETED
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'SCORED'      THEN TRUE  -- Phase 1B rollback
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'IN_PROGRESS' THEN TRUE
        WHEN OLD.enum_status = 'COMPLETED'    AND NEW.enum_status = 'PLANNED'     THEN TRUE
        -- Phase 1B universal rollback to CREATED skeleton (admin reset / season-init reuse)
        WHEN NEW.enum_status = 'CREATED'      AND OLD.enum_status IN
             ('PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','SCORED','COMPLETED','CANCELLED') THEN TRUE
        -- SCHEDULED and CHANGED remain listed above only so any legacy row
        -- could still be reset; no branch can REACH either state any more.
        ELSE FALSE
    END;

    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid event status transition: % → %',
            OLD.enum_status, NEW.enum_status;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION fn_guard_evf_event_weapons_known()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  IF NEW.txt_code !~ '^PEW[0-9]+-' THEN
    RETURN NEW;
  END IF;

  -- Cancelling an event whose weapons were never established is legitimate --
  -- EVF cancels stubs too, and PLANNED -> CANCELLED is now an automated
  -- CERT->PROD transition, so refusing it here would abort the whole promote.
  -- Only ADVANCING into a state where tournaments and results can attach is
  -- barred.
  IF NEW.enum_status = 'CANCELLED' THEN
    RETURN NEW;
  END IF;

  IF NEW.enum_status IS DISTINCT FROM OLD.enum_status
     AND OLD.enum_status = 'PLANNED'
     AND NEW.enum_status <> 'PLANNED' THEN
    RAISE EXCEPTION
      'fn_guard_evf_event_weapons_known: % has no weapons in its code and may '
      'not leave PLANNED (attempted %). Establish the weapons first -- the code '
      'suffix is the authoritative record (ADR-046).',
      NEW.txt_code, NEW.enum_status;
  END IF;

  RETURN NEW;
END;
$fn$;

COMMIT;
