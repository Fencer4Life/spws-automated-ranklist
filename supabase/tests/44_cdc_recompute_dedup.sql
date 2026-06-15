-- =============================================================================
-- ADR-072 (CDC recompute) + ADR-071 (dedup) — the self-healing DB layer.
-- NEW ingestion pipeline build, milestone 5.
--
-- Tests 44.1–44.11: queue/watermark schema, column-aware enqueue trigger
-- (BY/nationality -> enqueue; name -> nothing), dedup coalescing, and
-- fn_merge_fencers (re-point + fold aliases + delete dup + enqueue both sides).
-- =============================================================================

BEGIN;
SELECT plan(11);

-- ===== fixtures: 1 season, 2 events/tournaments (V1), 3 V1 fencers ==========
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_e1     INT;
  v_e2     INT;
  v_t1     INT;
  v_t2     INT;
  v_fa     INT;  -- survivor
  v_fb     INT;  -- duplicate
  v_fc     INT;  -- trigger subject
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('CDC44', '2099-09-01', '2100-06-30');  -- end year 2100 (free range)
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('CDCORG44', 'CDC org 44')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'CDCORG44';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, txt_location,
                         dt_start, dt_end, enum_status)
       VALUES ('CDC44E1', 'CDC event 1', v_season, v_org, 'City', '2100-03-15',
               '2100-03-15', 'COMPLETED') RETURNING id_event INTO v_e1;
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, txt_location,
                         dt_start, dt_end, enum_status)
       VALUES ('CDC44E2', 'CDC event 2', v_season, v_org, 'City', '2100-04-15',
               '2100-04-15', 'COMPLETED') RETURNING id_event INTO v_e2;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender,
                              enum_age_category, dt_tournament)
       VALUES (v_e1, 'CDC44E1-V1-M-EPEE', 'PPW', 'EPEE', 'M', 'V1', '2100-03-15')
    RETURNING id_tournament INTO v_t1;
  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender,
                              enum_age_category, dt_tournament)
       VALUES (v_e2, 'CDC44E2-V1-M-EPEE', 'PPW', 'EPEE', 'M', 'V1', '2100-04-15')
    RETURNING id_tournament INTO v_t2;

  -- BY 2055 in season ending 2100 -> age 45 -> V1 (matches the tournaments).
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality,
                          json_name_aliases)
       VALUES ('MERGE', 'Adam', 2055, 'PL', '["MERGE Adam"]'::jsonb)
    RETURNING id_fencer INTO v_fa;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, txt_nationality,
                          json_name_aliases)
       VALUES ('MERGE', 'Adamus', 2055, 'PL', '["MERGE Adamus"]'::jsonb)
    RETURNING id_fencer INTO v_fb;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('TRIG', 'Cee', 2055) RETURNING id_fencer INTO v_fc;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_fa, v_t1, 1);
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_fc, v_t1, 2);
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_fb, v_t2, 1);
END;
$setup$;

-- ---- 44.1 schema ----------------------------------------------------------
SELECT has_table('tbl_recompute_queue', '44.1: tbl_recompute_queue exists');

-- ---- 44.2 enqueue the fencer's events -------------------------------------
SELECT lives_ok(
  $$ SELECT fn_enqueue_affected_events(
       (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='TRIG')) $$,
  '44.2: fn_enqueue_affected_events runs');
SELECT is(
  (SELECT count(*)::int FROM tbl_recompute_queue q
   JOIN tbl_event e ON e.id_event = q.id_event
   WHERE e.txt_code = 'CDC44E1' AND q.enum_status = 'PENDING'),
  1, '44.3: fencer TRIG''s event CDC44E1 is enqueued PENDING');

-- ---- 44.4 dedup: re-enqueue coalesces to one PENDING row ------------------
SELECT fn_enqueue_affected_events((SELECT id_fencer FROM tbl_fencer WHERE txt_surname='TRIG'));
SELECT is(
  (SELECT count(*)::int FROM tbl_recompute_queue q
   JOIN tbl_event e ON e.id_event = q.id_event
   WHERE e.txt_code = 'CDC44E1' AND q.enum_status = 'PENDING'),
  1, '44.4: re-enqueue of the same event coalesces (still 1 PENDING)');

-- ---- 44.5 watermark bumped on enqueue ------------------------------------
CREATE TEMP TABLE _wm AS SELECT ts_last_master_change AS old FROM tbl_recompute_watermark;
SELECT fn_enqueue_affected_events((SELECT id_fencer FROM tbl_fencer WHERE txt_surname='TRIG'));
SELECT ok(
  (SELECT ts_last_master_change FROM tbl_recompute_watermark) > (SELECT old FROM _wm),
  '44.5: enqueue bumps the debounce watermark');

-- ---- 44.6 trigger fires on BY change -------------------------------------
DELETE FROM tbl_recompute_queue;
UPDATE tbl_fencer SET int_birth_year = 2056 WHERE txt_surname = 'TRIG';
SELECT is(
  (SELECT count(*)::int FROM tbl_recompute_queue q
   JOIN tbl_event e ON e.id_event = q.id_event WHERE e.txt_code = 'CDC44E1'),
  1, '44.6: a birth-year change enqueues the affected event');

-- ---- 44.7 trigger does NOT fire on a name change -------------------------
DELETE FROM tbl_recompute_queue;
UPDATE tbl_fencer SET txt_surname = 'TRIGREN' WHERE txt_surname = 'TRIG';
SELECT is(
  (SELECT count(*)::int FROM tbl_recompute_queue), 0,
  '44.7: a name change enqueues nothing (FK is durable)');

-- ---- 44.8 trigger fires on a nationality change --------------------------
DELETE FROM tbl_recompute_queue;
UPDATE tbl_fencer SET txt_nationality = 'GER' WHERE txt_surname = 'TRIGREN';
SELECT is(
  (SELECT count(*)::int FROM tbl_recompute_queue q
   JOIN tbl_event e ON e.id_event = q.id_event WHERE e.txt_code = 'CDC44E1'),
  1, '44.8: a nationality change enqueues the affected event');

-- ---- 44.9 / 44.10 / 44.11 fn_merge_fencers --------------------------------
DELETE FROM tbl_recompute_queue;
SELECT fn_merge_fencers(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='MERGE' AND txt_first_name='Adam'),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='MERGE' AND txt_first_name='Adamus'));

SELECT is(
  (SELECT id_fencer FROM tbl_result r
   JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
   WHERE t.txt_code = 'CDC44E2-V1-M-EPEE'),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='MERGE' AND txt_first_name='Adam'),
  '44.9: merge re-points the duplicate''s result to the survivor');

SELECT ok(
  (SELECT json_name_aliases FROM tbl_fencer
   WHERE txt_surname='MERGE' AND txt_first_name='Adam') @> '["MERGE Adamus"]'::jsonb,
  '44.10: merge folds the duplicate''s name into the survivor''s aliases');

SELECT is(
  (SELECT count(*)::int FROM tbl_fencer
   WHERE txt_surname='MERGE' AND txt_first_name='Adamus'),
  0, '44.11: merge deletes the duplicate fencer');

SELECT * FROM finish();
ROLLBACK;
