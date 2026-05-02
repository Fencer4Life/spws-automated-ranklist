-- =============================================================================
-- Phase 4 (ADR-046, ADR-050) — Stage 8b PEW cascade-rename hook
--
-- fn_pew_recompute_event_code(p_id_event INT) computes the current weapon-
-- letter suffix from child tournaments and cascade-renames the event +
-- its children if the suffix has changed. Idempotent. No-op for non-PEW
-- events. Stage 8b of the unified pipeline calls this post-commit when the
-- Stage 7 weapon-mismatch flag (pew_cascade_pending) was set.
--
-- Tests:
--   31.1   fn_pew_recompute_event_code(INT) exists
--   31.2   non-PEW event is no-op
--   31.3   PEW event with already-correct letters is no-op (idempotent)
--   31.4   PEW event whose child weapon set expanded → cascade-renames
--   31.5   children inherit the new code structure
-- =============================================================================

BEGIN;
SELECT plan(5);


-- ===== 31.1 — function exists =====
SELECT has_function(
  'fn_pew_recompute_event_code',
  ARRAY['integer'],
  '31.1: fn_pew_recompute_event_code(INT) exists'
);


-- =============================================================================
-- Fixture
-- =============================================================================
DO $fix$
DECLARE
  v_org INT;
  v_season INT;
  v_e_pew  INT;  -- PEW event with weapons foil + sabre
  v_e_other INT; -- non-PEW event
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF' LIMIT 1;
  IF v_org IS NULL THEN
    INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('EVF', 'EVF') RETURNING id_organizer INTO v_org;
  END IF;
  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  IF v_season IS NULL THEN
    INSERT INTO tbl_season (txt_code, dt_start, dt_end)
    VALUES ('TEST31', '2026-01-01','2026-12-31') RETURNING id_season INTO v_season;
  END IF;

  -- PEW event with foil + sabre children only
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start)
  VALUES ('PEW99fs-2025-2026', 'Test PEW', v_season, v_org, '2026-06-01')
  RETURNING id_event INTO v_e_pew;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count)
  VALUES (v_e_pew, 'PEW99fs-V2-M-FOIL-2025-2026',  'PEW', 'FOIL',  'M', 'V2', '2026-06-01', 5);
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count)
  VALUES (v_e_pew, 'PEW99fs-V2-M-SABRE-2025-2026', 'PEW', 'SABRE', 'M', 'V2', '2026-06-01', 5);

  -- non-PEW event
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start)
  VALUES ('TEST31-NONPEW-2025-2026', 'Test non-PEW', v_season, v_org, '2026-06-02')
  RETURNING id_event INTO v_e_other;
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count)
  VALUES (v_e_other, 'TEST31-NONPEW-V2-M-EPEE-2025-2026', 'PPW', 'EPEE', 'M', 'V2', '2026-06-02', 5);
END;
$fix$;


-- ===== 31.2 — non-PEW event is no-op =====
SELECT is(
  fn_pew_recompute_event_code(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'TEST31-NONPEW-2025-2026')
  ),
  0,
  '31.2: non-PEW event is a no-op (returns 0 changes)'
);


-- ===== 31.3 — PEW event already correctly suffixed (idempotent) =====
SELECT is(
  fn_pew_recompute_event_code(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW99fs-2025-2026')
  ),
  0,
  '31.3: PEW event with correct suffix is no-op'
);


-- ===== 31.4 — add an epee tournament; recompute should cascade =====
DO $$
DECLARE v_e INT;
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'PEW99fs-2025-2026';
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count)
  VALUES (v_e, 'PEW99fs-V2-M-EPEE-2025-2026',  'PEW', 'EPEE', 'M', 'V2', '2026-06-01', 5);
END$$;

DO $$
DECLARE v_e INT;
BEGIN
  SELECT id_event INTO v_e FROM tbl_event WHERE txt_code = 'PEW99fs-2025-2026';
  PERFORM fn_pew_recompute_event_code(v_e);
END$$;

SELECT ok(
  EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = 'PEW99efs-2025-2026'),
  '31.4: PEW event whose child weapon set expanded was cascade-renamed (PEW99fs → PEW99efs)'
);


-- ===== 31.5 — children inherit the new code structure =====
SELECT is(
  (SELECT count(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'PEW99efs-2025-2026'
      AND t.txt_code LIKE 'PEW99efs-%'),
  3,
  '31.5: all 3 child tournaments now use the new event code prefix'
);


SELECT * FROM finish();
ROLLBACK;
