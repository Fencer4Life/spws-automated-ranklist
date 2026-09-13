-- =============================================================================
-- pgTAP — a CREATED/PLANNED event carries event-level facts only
-- =============================================================================
-- Verifies migration 20260913000002_no_bracket_stubs.sql (ADR-096, amends
-- ADR-028, ADR-046; relates to ADR-091, ADR-081).
--
-- fn_import_evf_events (ADR-028, April 2026) minted one stub tbl_tournament
-- row per weapon x gender at calendar-import time, hardcoded to V2. Every
-- justification for that has expired (ADR-028 §Calendar Scraping), and
-- the predicted shape was always wrong -- a real EVF weekend ends with
-- 10-23 brackets across V1-V4, not 2-6 at V2 only. The stubs are also what
-- made run 34468447030 fail: the reflow rebuild in
-- fn_ingest_evf_calendar_identity_v1 wrote a third code dialect
-- (<event-code-with-season>-<Vcat>-<gender>-<weapon>) for these rows, and the
-- 2-arg fn_ingest_evf_calendar's insert guard tested that dialect's OLD
-- string, so it silently re-inserted a duplicate every time an event
-- renumbered -- 68 duplicate pairs on CERT by 2026-09-12.
--
-- The fix: fn_ingest_evf_calendar's weapon-loop stub INSERT is removed
-- entirely. fn_rebuild_tournament_codes is the one shared implementation of
-- ADR-046's canonical code formula, used by both the admin rename path
-- (fn_update_event) and the calendar reflow path
-- (fn_ingest_evf_calendar_identity_v1). fn_prune_bracket_stubs() removes the
-- rows already on CERT/PROD. No uniqueness index (see the migration's file
-- header): at least four pre-existing pgTAP fixtures deliberately share one
-- bracket tuple across several synthetic tournaments under a throwaway event,
-- and the four pieces above already remove the defect without one.
--
-- 79.1-79.4 exercise the public entry point (the 3-arg fn_ingest_evf_calendar
-- production calls through, per evf_sync.py) end to end. 79.5-79.6 unit-test
-- the two new pieces directly.
-- =============================================================================

BEGIN;

SELECT plan(7);

-- =============================================================================
-- 79.1 — a calendar ingest of a NEW EVF event creates the event, zero brackets
-- =============================================================================
DO $setup1$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-9300-9301', '9300-08-01', '9301-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT (txt_code) DO NOTHING;
END;
$setup1$;

DO $ing1$
DECLARE
  v_season INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9300-9301';
  PERFORM fn_ingest_evf_calendar(
    jsonb_build_array(jsonb_build_object(
      'name', 'Solo', 'dt_start', '9300-10-01', 'dt_end', '9300-10-01',
      'location', 'Solo City', 'country', 'Nowhere',
      'weapons', jsonb_build_array('EPEE', 'FOIL'), 'evf_calendar_id', 9101,
      'evf_slug', 'evf-slug-solo',
      'is_cancelled', false, 'desired_code', 'PEW1ef-9300-9301'
    )),
    v_season, 1
  );
END;
$ing1$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'PEW1ef-9300-9301'),
  0,
  '79.1 — a new EVF event lands via calendar ingest with zero child tournaments'
);

-- =============================================================================
-- 79.2 — an ingest of an event that already holds real brackets adds none,
--         deletes none, when the code does not change
-- =============================================================================
DO $setup2$
DECLARE
  v_event INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'PEW1ef-9300-9301';
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status
  ) VALUES
    (v_event, 'PEW1ef-9300-9301-V1-M-EPEE-9300-9301', 'PEW', 'EPEE', 'M', 'V1', 12, 'SCORED'),
    (v_event, 'PEW1ef-9300-9301-V2-M-EPEE-9300-9301', 'PEW', 'EPEE', 'M', 'V2', 9,  'SCORED'),
    (v_event, 'PEW1ef-9300-9301-V2-F-FOIL-9300-9301', 'PEW', 'FOIL', 'F', 'V2', 5,  'SCORED');
END;
$setup2$;

DO $ing2$
DECLARE
  v_season INT;
  v_event  INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9300-9301';
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'PEW1ef-9300-9301';
  PERFORM fn_ingest_evf_calendar(
    jsonb_build_array(jsonb_build_object(
      'name', 'Solo', 'dt_start', '9300-10-01', 'dt_end', '9300-10-01',
      'location', 'Solo City', 'country', 'Nowhere',
      'weapons', jsonb_build_array('EPEE', 'FOIL'), 'evf_calendar_id', 9101,
      'evf_slug', 'evf-slug-solo',
      'existing_id_event', v_event,
      'is_cancelled', false, 'desired_code', 'PEW1ef-9300-9301'
    )),
    v_season, 1
  );
END;
$ing2$;

SELECT results_eq(
  $$SELECT t.txt_code::TEXT FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.txt_code = 'PEW1ef-9300-9301'
     ORDER BY t.txt_code$$,
  $$VALUES ('PEW1ef-9300-9301-V1-M-EPEE-9300-9301'),
           ('PEW1ef-9300-9301-V2-F-FOIL-9300-9301'),
           ('PEW1ef-9300-9301-V2-M-EPEE-9300-9301')$$,
  '79.2 — an unchanged event code leaves its real brackets untouched: none added, none deleted, none renamed'
);

-- =============================================================================
-- 79.3 — two consecutive ingests that each renumber the tail still live
--         (the run-34468447030 regression, now against REAL brackets rather
--          than the stubs that no longer exist)
-- =============================================================================
DO $setup3$
DECLARE
  v_season INT;
  v_org    INT;
  v_alpha  INT;
  v_beta   INT;
  v_gamma  INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('SPWS-9400-9401', '9400-08-01', '9401-07-31', FALSE)
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9400-9401';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, id_evf_calendar_event, arr_weapons,
    txt_location, txt_country, txt_evf_slug
  ) VALUES
    ('PEW1e-9400-9401', 'Alpha', v_season, v_org, 'PLANNED',
     '9400-10-01', '9400-10-01', 9401, ARRAY['EPEE']::enum_weapon_type[],
     'Alpha City', 'Nowhere', 'evf-slug-alpha'),
    ('PEW2e-9400-9401', 'Beta',  v_season, v_org, 'PLANNED',
     '9400-11-01', '9400-11-01', 9402, ARRAY['EPEE']::enum_weapon_type[],
     'Beta City', 'Nowhere', 'evf-slug-beta'),
    ('PEW3e-9400-9401', 'Gamma', v_season, v_org, 'PLANNED',
     '9400-12-01', '9400-12-01', 9403, ARRAY['EPEE']::enum_weapon_type[],
     'Gamma City', 'Nowhere', 'evf-slug-gamma');

  SELECT id_event INTO v_alpha FROM tbl_event WHERE id_evf_calendar_event = 9401;
  SELECT id_event INTO v_beta  FROM tbl_event WHERE id_evf_calendar_event = 9402;
  SELECT id_event INTO v_gamma FROM tbl_event WHERE id_evf_calendar_event = 9403;

  -- Beta and Gamma already hold REAL (result-backed) brackets that must
  -- survive every renumber -- the case the hardened park-first rebuild in
  -- fn_rebuild_tournament_codes exists to protect.
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status
  ) VALUES
    (v_beta,  'PEW2e-9400-9401-V2-M-EPEE-9400-9401',  'PEW', 'EPEE', 'M', 'V2', 7, 'SCORED'),
    (v_gamma, 'PEW3e-9400-9401-V2-M-EPEE-9400-9401',  'PEW', 'EPEE', 'M', 'V2', 4, 'SCORED');
END;
$setup3$;

-- First ingest: a new event slots in between Alpha and Beta, shifting
-- Beta PEW2->PEW3 and Gamma PEW3->PEW4. Both carry real children.
SELECT lives_ok(
  $ing3a$
  DO $body3a$
  DECLARE
    v_season INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9400-9401';
    PERFORM fn_ingest_evf_calendar(
      jsonb_build_array(
        jsonb_build_object('name','Alpha','dt_start','9400-10-01','dt_end','9400-10-01',
          'location','Alpha City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9401,
          'evf_slug', 'evf-slug-alpha',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9401),
          'is_cancelled', false, 'desired_code','PEW1e-9400-9401'),
        jsonb_build_object('name','Inserted','dt_start','9400-10-15','dt_end','9400-10-15',
          'location','Inserted City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9404,
          'evf_slug', 'evf-slug-inserted',
          'is_cancelled', false, 'desired_code','PEW2e-9400-9401'),
        jsonb_build_object('name','Beta','dt_start','9400-11-01','dt_end','9400-11-01',
          'location','Beta City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9402,
          'evf_slug', 'evf-slug-beta',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9402),
          'is_cancelled', false, 'desired_code','PEW3e-9400-9401'),
        jsonb_build_object('name','Gamma','dt_start','9400-12-01','dt_end','9400-12-01',
          'location','Gamma City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9403,
          'evf_slug', 'evf-slug-gamma',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9403),
          'is_cancelled', false, 'desired_code','PEW4e-9400-9401')
      ), v_season, 4);
  END;
  $body3a$
  $ing3a$,
  '79.3a — first renumbering ingest lives with real (non-stub) children in the tail'
);

-- Second, immediately following ingest: another new event slots in ahead of
-- the first insertion, shifting Beta and Gamma AGAIN (PEW3->PEW4, PEW4->PEW5)
-- in the very next sync -- the two-renumbers-in-a-row shape of 34468447030.
SELECT lives_ok(
  $ing3b$
  DO $body3b$
  DECLARE
    v_season INT;
  BEGIN
    SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9400-9401';
    PERFORM fn_ingest_evf_calendar(
      jsonb_build_array(
        jsonb_build_object('name','Alpha','dt_start','9400-10-01','dt_end','9400-10-01',
          'location','Alpha City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9401,
          'evf_slug', 'evf-slug-alpha',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9401),
          'is_cancelled', false, 'desired_code','PEW1e-9400-9401'),
        jsonb_build_object('name','Inserted2','dt_start','9400-10-08','dt_end','9400-10-08',
          'location','Inserted2 City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9405,
          'evf_slug', 'evf-slug-inserted2',
          'is_cancelled', false, 'desired_code','PEW2e-9400-9401'),
        jsonb_build_object('name','Inserted','dt_start','9400-10-15','dt_end','9400-10-15',
          'location','Inserted City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9404,
          'evf_slug', 'evf-slug-inserted',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9404),
          'is_cancelled', false, 'desired_code','PEW3e-9400-9401'),
        jsonb_build_object('name','Beta','dt_start','9400-11-01','dt_end','9400-11-01',
          'location','Beta City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9402,
          'evf_slug', 'evf-slug-beta',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9402),
          'is_cancelled', false, 'desired_code','PEW4e-9400-9401'),
        jsonb_build_object('name','Gamma','dt_start','9400-12-01','dt_end','9400-12-01',
          'location','Gamma City','country','Nowhere',
          'weapons', jsonb_build_array('EPEE'), 'evf_calendar_id', 9403,
          'evf_slug', 'evf-slug-gamma',
          'existing_id_event', (SELECT id_event FROM tbl_event WHERE id_evf_calendar_event=9403),
          'is_cancelled', false, 'desired_code','PEW5e-9400-9401')
      ), v_season, 5);
  END;
  $body3b$
  $ing3b$,
  '79.3b — a second, immediately-following renumbering ingest also lives'
);

-- =============================================================================
-- 79.4 — after every ingest above, no event anywhere holds two rows for the
--         same (age category, gender, weapon) bracket
-- =============================================================================
SELECT is(
  (SELECT COUNT(*)::INT FROM (
     SELECT 1 FROM tbl_tournament
      GROUP BY id_event, enum_age_category, enum_gender, enum_weapon
     HAVING COUNT(*) > 1
   ) dup),
  0,
  '79.4 — no event holds two tournament rows for the same bracket after any ingest'
);

-- =============================================================================
-- 79.5 — fn_rebuild_tournament_codes: canonical dialect rebuilds canonical,
--         placeholder dialect is preserved, not converted
-- =============================================================================
DO $setup5$
DECLARE
  v_season INT;
  v_org    INT;
  v_canon  INT;
  v_plain  INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9300-9301';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW90e-9300-9301', 'Canon child', v_season, v_org, 'PLANNED', '9300-06-01')
  RETURNING id_event INTO v_canon;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, enum_import_status
  ) VALUES (
    v_canon, 'PEW90e-9300-9301-V2-M-EPEE-9300-9301', 'PEW', 'EPEE', 'M', 'V2', 'PLANNED'
  );

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW91e-9300-9301', 'Placeholder child', v_season, v_org, 'PLANNED', '9300-06-02')
  RETURNING id_event INTO v_plain;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, enum_import_status
  ) VALUES (
    v_plain, 'PEW91e-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 'PLANNED'
  );

  -- fn_rebuild_tournament_codes only rebuilds the CHILDREN; the event's own
  -- txt_code is the caller's responsibility, exactly as in both real callers
  -- (fn_update_event's own UPDATE, identity_v1's own UPDATE).
  PERFORM fn_rebuild_tournament_codes(v_canon, 'PEW92e-9300-9301');
  UPDATE tbl_event SET txt_code = 'PEW92e-9300-9301' WHERE id_event = v_canon;
  PERFORM fn_rebuild_tournament_codes(v_plain, 'PEW93e-9300-9301');
  UPDATE tbl_event SET txt_code = 'PEW93e-9300-9301' WHERE id_event = v_plain;
END;
$setup5$;

SELECT results_eq(
  $$SELECT e.txt_code::TEXT, t.txt_code::TEXT FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.txt_code IN ('PEW92e-9300-9301', 'PEW93e-9300-9301')
     ORDER BY e.txt_code$$,
  $$VALUES ('PEW92e-9300-9301', 'PEW92e-V2-M-EPEE-9300-9301'),
           ('PEW93e-9300-9301', 'PEW93e-9300-9301-M-EPEE')$$,
  '79.5 — fn_rebuild_tournament_codes reproduces the canonical formula for a -V\d- child and preserves the placeholder shape for one without'
);

-- =============================================================================
-- 79.6 — fn_prune_bracket_stubs() deletes only the true stub
-- =============================================================================
DO $setup6$
DECLARE
  v_season   INT;
  v_org      INT;
  v_e_stub   INT;
  v_e_result INT;
  v_e_count  INT;
  v_e_url    INT;
  v_e_hist   INT;
  v_t_result INT;
  v_t_hist   INT;
  v_fencer   INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-9300-9301';

  -- A dedicated fixture fencer, not a seed row picked at random: the season
  -- ends 9301, and trg_assert_result_vcat enforces fn_age_category(birth_year,
  -- 9301) = V2, i.e. birth_year in [9242, 9251]. 9245 -> 9301-9245=56 -> V2.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
  VALUES ('Fixture79', 'Bracket', 9245)
  RETURNING id_fencer INTO v_fencer;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW94-STUB-9300-9301', 'True stub', v_season, v_org, 'PLANNED', '9300-06-03')
  RETURNING id_event INTO v_e_stub;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status, url_results
  ) VALUES (
    v_e_stub, 'PEW94-STUB-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 0, 'PLANNED', NULL
  );

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW95-RES-9300-9301', 'Has a result', v_season, v_org, 'PLANNED', '9300-06-04')
  RETURNING id_event INTO v_e_result;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status, url_results
  ) VALUES (
    v_e_result, 'PEW95-RES-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 0, 'PLANNED', NULL
  ) RETURNING id_tournament INTO v_t_result;
  INSERT INTO tbl_result (id_tournament, id_fencer, int_place)
  VALUES (v_t_result, v_fencer, 1);

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW96-CNT-9300-9301', 'Has a participant count', v_season, v_org, 'PLANNED', '9300-06-05')
  RETURNING id_event INTO v_e_count;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status, url_results
  ) VALUES (
    v_e_count, 'PEW96-CNT-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 3, 'PLANNED', NULL
  );

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW97-URL-9300-9301', 'Has a url_results', v_season, v_org, 'PLANNED', '9300-06-06')
  RETURNING id_event INTO v_e_url;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status, url_results
  ) VALUES (
    v_e_url, 'PEW97-URL-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 0, 'PLANNED',
    'https://fencingtimelive.com/events/results/999'
  );

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
  VALUES ('PEW98-HIST-9300-9301', 'Has ingest history', v_season, v_org, 'PLANNED', '9300-06-07')
  RETURNING id_event INTO v_e_hist;
  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    int_participant_count, enum_import_status, url_results
  ) VALUES (
    v_e_hist, 'PEW98-HIST-9300-9301-M-EPEE', 'PEW', 'EPEE', 'M', 'V2', 0, 'PLANNED', NULL
  ) RETURNING id_tournament INTO v_t_hist;
  INSERT INTO tbl_tournament_ingest_history (id_tournament, txt_run_id, enum_parser_kind, txt_source_url)
  VALUES (v_t_hist, gen_random_uuid(), 'FTL', 'https://fencingtimelive.com/events/results/998');

  PERFORM fn_prune_bracket_stubs();
END;
$setup6$;

SELECT results_eq(
  $$SELECT e.txt_code::TEXT, (SELECT COUNT(*)::INT FROM tbl_tournament t WHERE t.id_event = e.id_event)
      FROM tbl_event e
     WHERE e.txt_code IN (
       'PEW94-STUB-9300-9301', 'PEW95-RES-9300-9301', 'PEW96-CNT-9300-9301',
       'PEW97-URL-9300-9301', 'PEW98-HIST-9300-9301'
     )
     ORDER BY e.txt_code$$,
  $$VALUES ('PEW94-STUB-9300-9301', 0), ('PEW95-RES-9300-9301', 1),
           ('PEW96-CNT-9300-9301', 1), ('PEW97-URL-9300-9301', 1),
           ('PEW98-HIST-9300-9301', 1)$$,
  '79.6 — fn_prune_bracket_stubs deletes only the childless true stub, refusing a result, a participant count, a url_results, or ingest history'
);

-- No 79.7 / no uniqueness index: at least four pre-existing pgTAP fixtures
-- (01_database_foundation, 02_scoring_engine, 03_views_api, 05_calendar_view)
-- deliberately share one throwaway event across several synthetic tournaments
-- at the same (V2, M, EPEE), distinguished only by enum_type. A uniqueness
-- index on that tuple broke all four. Pieces 1-4 above (79.1-79.6) fully
-- remove the defect without it — see the migration's file header for the
-- full reasoning.

SELECT * FROM finish();
ROLLBACK;
