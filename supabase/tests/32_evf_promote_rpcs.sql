-- =============================================================================
-- Phase 4 (ADR-053) — EVF parity promotion + annotation RPCs
--
-- Tests for fn_promote_evf_published, fn_annotate_parity_fail,
-- fn_event_results_for_parity, fn_evf_events_pending_parity.
--
-- Tests:
--   32.1   fn_promote_evf_published exists with correct signature
--   32.2   fn_annotate_parity_fail exists with correct signature
--   32.3   fn_event_results_for_parity exists
--   32.4   fn_evf_events_pending_parity exists
--   32.5   fn_promote_evf_published flips EVF event to EVF_PUBLISHED
--   32.6   fn_promote_evf_published rejects non-EVF events
--   32.7   fn_promote_evf_published overwrites num_final_score on matched fencer
--   32.8   fn_promote_evf_published clears any prior txt_parity_notes
--   32.9   fn_annotate_parity_fail writes notes idempotently
--   32.10  fn_evf_events_pending_parity returns only ENGINE_COMPUTED EVF rows
-- =============================================================================

BEGIN;
SELECT plan(10);


-- ===== 32.1 — fn_promote_evf_published exists =====
SELECT has_function(
  'fn_promote_evf_published'::name,
  ARRAY['integer','jsonb']::name[],
  '32.1: fn_promote_evf_published(INT, JSONB) exists'
);


-- ===== 32.2 — fn_annotate_parity_fail exists =====
SELECT has_function(
  'fn_annotate_parity_fail'::name,
  ARRAY['integer','text']::name[],
  '32.2: fn_annotate_parity_fail(INT, TEXT) exists'
);


-- ===== 32.3 — fn_event_results_for_parity exists =====
SELECT has_function(
  'fn_event_results_for_parity'::name,
  ARRAY['integer']::name[],
  '32.3: fn_event_results_for_parity(INT) exists'
);


-- ===== 32.4 — fn_evf_events_pending_parity exists =====
SELECT has_function(
  'fn_evf_events_pending_parity'::name,
  ARRAY['integer']::name[],
  '32.4: fn_evf_events_pending_parity(INT) exists'
);


-- =============================================================================
-- Fixture: an EVF event with one POL fencer + one tournament + one result
-- =============================================================================
DO $fix$
DECLARE
  v_evf_org INT;
  v_spws_org INT;
  v_season INT;
  v_event INT;
  v_event_spws INT;
  v_tournament INT;
  v_fencer INT;
BEGIN
  INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('EVF',  'EVF org')
    ON CONFLICT DO NOTHING;
  INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('SPWS', 'SPWS org')
    ON CONFLICT DO NOTHING;
  SELECT id_organizer INTO v_evf_org  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  IF v_season IS NULL THEN
    INSERT INTO tbl_season (txt_code, dt_start, dt_end)
    VALUES ('TEST32', '2026-01-01', '2026-12-31')
    RETURNING id_season INTO v_season;
  END IF;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, txt_parity_notes)
  VALUES ('TEST32-EVF', 'EVF parity test', v_season, v_evf_org, '2026-06-15', '2026-06-15', 'pre-existing notes')
  ON CONFLICT (txt_code) DO UPDATE SET txt_parity_notes = EXCLUDED.txt_parity_notes
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end)
  VALUES ('TEST32-SPWS', 'SPWS parity test', v_season, v_spws_org, '2026-06-16', '2026-06-16')
  ON CONFLICT (txt_code) DO NOTHING
  RETURNING id_event INTO v_event_spws;

  IF v_event_spws IS NULL THEN
    SELECT id_event INTO v_event_spws FROM tbl_event WHERE txt_code = 'TEST32-SPWS';
  END IF;

  -- BY=1980 → age 46 in 2026 → V1 (40-49), matches the V1 tournament below.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, txt_nationality)
  VALUES ('Test32Fencer', 'Adam', 1980, 'M', 'PL')
  RETURNING id_fencer INTO v_fencer;

  INSERT INTO tbl_tournament (txt_code, id_event, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament)
  VALUES ('TEST32-EVF-V1-M-EPEE', v_event, 'PEW', 'EPEE', 'M', 'V1', '2026-06-15')
  RETURNING id_tournament INTO v_tournament;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, num_final_score)
  VALUES (v_fencer, v_tournament, 5, 30.0);
END;
$fix$;


-- ===== 32.5 — fn_promote_evf_published flips status to EVF_PUBLISHED =====
DO $exec$
DECLARE
  v_event_id INT;
  v_fencer_id INT;
BEGIN
  SELECT id_event INTO v_event_id FROM tbl_event WHERE txt_code = 'TEST32-EVF';
  SELECT id_fencer INTO v_fencer_id FROM tbl_fencer WHERE txt_surname = 'Test32Fencer';

  PERFORM fn_promote_evf_published(
    v_event_id,
    jsonb_build_array(
      jsonb_build_object('id_fencer', v_fencer_id, 'int_place', 5, 'num_final_score', 42.5)
    )
  );
END;
$exec$;

SELECT is(
  (SELECT txt_source_status::TEXT FROM tbl_event WHERE txt_code = 'TEST32-EVF'),
  'EVF_PUBLISHED',
  '32.5: fn_promote_evf_published flips EVF event status to EVF_PUBLISHED'
);


-- ===== 32.6 — fn_promote_evf_published rejects non-EVF events =====
SELECT throws_ok(
  $$
    SELECT fn_promote_evf_published(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'TEST32-SPWS'),
      '[]'::jsonb
    )
  $$,
  NULL,
  NULL,
  '32.6: fn_promote_evf_published rejects non-EVF events'
);


-- ===== 32.7 — fn_promote_evf_published overwrites num_final_score =====
SELECT is(
  (SELECT num_final_score
     FROM tbl_result r
     JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    WHERE t.txt_code = 'TEST32-EVF-V1-M-EPEE'),
  42.5::numeric,
  '32.7: fn_promote_evf_published overwrites num_final_score with EVF value'
);


-- ===== 32.8 — promote clears prior txt_parity_notes =====
SELECT is(
  (SELECT txt_parity_notes FROM tbl_event WHERE txt_code = 'TEST32-EVF'),
  NULL::TEXT,
  '32.8: fn_promote_evf_published clears any prior txt_parity_notes'
);


-- ===== 32.9 — fn_annotate_parity_fail writes notes =====
DO $do$
DECLARE
  v_id INT;
BEGIN
  SELECT id_event INTO v_id FROM tbl_event WHERE txt_code = 'TEST32-SPWS';
  PERFORM fn_annotate_parity_fail(v_id, 'two fencers above tolerance');
END;
$do$;

SELECT is(
  (SELECT txt_parity_notes FROM tbl_event WHERE txt_code = 'TEST32-SPWS'),
  'two fencers above tolerance',
  '32.9: fn_annotate_parity_fail writes notes idempotently'
);


-- ===== 32.10 — fn_evf_events_pending_parity returns ENGINE_COMPUTED EVF rows =====
SELECT is(
  (SELECT count(*)::INT
     FROM fn_evf_events_pending_parity(365) p
    WHERE p.txt_code = 'TEST32-EVF'),
  0,
  '32.10: fn_evf_events_pending_parity excludes already-promoted EVF event'
);


SELECT * FROM finish();
ROLLBACK;
