-- =============================================================================
-- Phase 2: EVF event code allocator + classifier tests
-- =============================================================================
-- Tests evf.25–evf.39 from doc/adr/043-evf-event-allocator.md (when written).
-- evf.25–evf.26: fn_normalize_city_key (NFKD fold + country alias)
-- evf.27–evf.29: fn_classify_evf_event (PEW / IMEW / DMEW dispatch)
-- evf.30–evf.36: fn_allocate_evf_event_code (3-step ladder + singletons + raises)
-- evf.37–evf.38: fn_import_evf_events_v2 (CREATED slot UPDATE + EVF organizer)
-- evf.39:        Data-migration 20260427000003 fixed MEW-COMPLEXESP slug row
-- =============================================================================

BEGIN;
SELECT plan(15);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_evf_org    INT;
  v_prior_id   INT;
  v_curr_id    INT;
  v_pew7_prior INT;
BEGIN
  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';

  -- Isolate from seed: deactivate, create two synthetic seasons
  UPDATE tbl_season SET bool_active = FALSE;
  v_prior_id := fn_create_season('EVFP2-PRIOR', '2030-09-01', '2031-06-30');
  v_curr_id  := fn_create_season('EVFP2-CURR',  '2031-09-01', '2032-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_curr_id;
  -- Generous carry window so seed-age tests aren't gated out (defensive)
  UPDATE tbl_season SET int_carryover_days = 9999
    WHERE id_season IN (v_prior_id, v_curr_id);

  -- Prior season seed: PEW7-Salzburg, PEW8-Krakow, slug PEW (ambiguous prefix), IMEW
  INSERT INTO tbl_event (id_season, id_organizer, txt_code, txt_name,
                         dt_start, dt_end, txt_location, txt_country, enum_status)
  VALUES
    (v_prior_id, v_evf_org, 'PEW7-EVFP2-PRIOR',         'Prior PEW7',
     '2031-04-15', '2031-04-16', 'Salzburg',  'Austria',  'COMPLETED'),
    (v_prior_id, v_evf_org, 'PEW8-EVFP2-PRIOR',         'Prior PEW8',
     '2031-05-15', '2031-05-16', 'Krakow',    'Poland',   'COMPLETED'),
    (v_prior_id, v_evf_org, 'PEW-LIEGESLUG-EVFP2-PRIOR', 'Prior slug',
     '2031-06-15', '2031-06-16', 'Liege',     'Belgium',  'COMPLETED'),
    (v_prior_id, v_evf_org, 'IMEW-EVFP2-PRIOR',          'Prior IMEW',
     '2031-04-01', '2031-04-03', NULL,        NULL,       'COMPLETED');

  -- Current season seed: one CREATED PEW7 slot for Salzburg (admin pre-created)
  -- + one slug event (legacy) that allocator must skip in MAX(N) computation
  INSERT INTO tbl_event (id_season, id_organizer, txt_code, txt_name,
                         dt_start, dt_end, txt_location, txt_country,
                         enum_status, id_prior_event)
  VALUES
    (v_curr_id, v_evf_org, 'PEW7-EVFP2-CURR', 'Pre-allocated PEW7 slot',
     '2032-04-15', '2032-04-16', 'Salzburg', 'Austria',
     'CREATED',
     (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-EVFP2-PRIOR')),
    (v_curr_id, v_evf_org, 'PEW-SALLEJEANZSLUG-EVFP2-CURR', 'Legacy slug',
     '2032-05-01', '2032-05-02', 'Faches',  'France',
     'PLANNED', NULL);
END;
$setup$;


-- =========================================================================
-- evf.25: fn_normalize_city_key folds diacritics + resolves country alias
-- =========================================================================
SELECT row_eq(
  $$ SELECT loc_key, country_key
       FROM fn_normalize_city_key('Jabłonna', 'Polska') $$,
  ROW('jablonna'::TEXT, 'poland'::TEXT),
  'evf.25: ("Jabłonna","Polska") → ("jablonna","poland")'
);


-- =========================================================================
-- evf.26: fn_normalize_city_key tolerates NULL location, alias-folds country
-- =========================================================================
SELECT row_eq(
  $$ SELECT loc_key, country_key
       FROM fn_normalize_city_key(NULL, 'Österreich') $$,
  ROW(''::TEXT, 'austria'::TEXT),
  'evf.26: (NULL,"Österreich") → ("","austria")'
);


-- =========================================================================
-- evf.27: classifier returns PEW for individual circuit event
-- =========================================================================
SELECT is(
  fn_classify_evf_event('EVF Circuit – Salzburg (AUT)', FALSE),
  'PEW',
  'evf.27: individual circuit → PEW'
);


-- =========================================================================
-- evf.28: classifier returns IMEW for individual championship
-- =========================================================================
SELECT is(
  fn_classify_evf_event('European Championships 2026', FALSE),
  'IMEW',
  'evf.28: individual championship → IMEW'
);


-- =========================================================================
-- evf.29: classifier returns DMEW when team flag is set (overrides name)
-- =========================================================================
SELECT is(
  fn_classify_evf_event('European Team Championships 2026 – Cognac', TRUE),
  'DMEW',
  'evf.29: is_team=TRUE always → DMEW (team flag wins)'
);


-- =========================================================================
-- evf.30: allocator returns CURRENT_SLOT_REUSE when CREATED slot matches city
-- =========================================================================
SELECT row_eq(
  $$ SELECT txt_code, alloc_path
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'PEW', 'Salzburg', 'Austria'
       ) $$,
  ROW('PEW7-EVFP2-CURR'::TEXT, 'CURRENT_SLOT_REUSE'::TEXT),
  'evf.30: CREATED Salzburg slot → CURRENT_SLOT_REUSE with existing code'
);


-- =========================================================================
-- evf.31: allocator returns PRIOR_SEASON_MATCH using prior PEWn number
-- =========================================================================
-- Krakow exists in prior season (PEW8) but NOT in current — must reuse "PEW8".
SELECT row_eq(
  $$ SELECT txt_code, alloc_path,
            id_prior_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8-EVFP2-PRIOR')
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'PEW', 'Krakow', 'Poland'
       ) $$,
  ROW('PEW8-EVFP2-CURR'::TEXT, 'PRIOR_SEASON_MATCH'::TEXT, TRUE),
  'evf.31: prior Krakow PEW8 → PRIOR_SEASON_MATCH with code PEW8-{curr} + FK set'
);


-- =========================================================================
-- evf.32: allocator returns NEXT_FREE_ALLOC with MAX(N)+1 when no match
-- =========================================================================
-- Berlin exists in neither season. MAX(N) in current = 7 (only PEW7); next = 8.
-- BUT prior has PEW8 (Krakow) — match must use PRIOR not NEXT_FREE for "Berlin".
-- So Berlin should land at PEW9 (since prior has PEW7, PEW8 → MAX is 8 → next 9).
-- Wait: Step C uses CURRENT season MAX. Current has only PEW7 → next is PEW8.
-- The slug PEW-SALLEJEANZSLUG... must NOT be counted (evf.33 covers).
SELECT row_eq(
  $$ SELECT txt_code, alloc_path, id_prior_event
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'PEW', 'Berlin', 'Germany'
       ) $$,
  ROW('PEW8-EVFP2-CURR'::TEXT, 'NEXT_FREE_ALLOC'::TEXT, NULL::INT),
  'evf.32: Berlin → NEXT_FREE_ALLOC PEW8-{curr} (MAX=7+1) with NULL prior'
);


-- =========================================================================
-- evf.33: allocator skips slug events in MAX(N)+1 computation
-- =========================================================================
-- The setup put PEW-SALLEJEANZSLUG-EVFP2-CURR in current season. If allocator
-- counted it, MAX would still be 7 (no digit suffix on slug). The proof here
-- is that evf.32 returned PEW8 — but to be explicit, allocate again for a
-- different city after first creating the row. We bump current PEW count by
-- inserting PEW8-EVFP2-CURR explicitly, then assert next = PEW9 (slug ignored).
DO $t33$ BEGIN
  INSERT INTO tbl_event (id_season, id_organizer, txt_code, txt_name,
                         dt_start, dt_end, txt_location, txt_country, enum_status)
  VALUES (
    (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'PEW8-EVFP2-CURR', 'Filler PEW8',
    '2032-05-15', '2032-05-16', 'Berlin', 'Germany', 'PLANNED'
  );
END $t33$;

SELECT row_eq(
  $$ SELECT txt_code, alloc_path
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'PEW', 'Madrid', 'Spain'
       ) $$,
  ROW('PEW9-EVFP2-CURR'::TEXT, 'NEXT_FREE_ALLOC'::TEXT),
  'evf.33: slug events ignored → MAX(N)=8 → next = PEW9 (Madrid)'
);


-- =========================================================================
-- evf.34: allocator returns singleton IMEW-{year} with prior FK when prior exists
-- =========================================================================
SELECT row_eq(
  $$ SELECT txt_code, alloc_path,
            id_prior_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-EVFP2-PRIOR')
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'IMEW', NULL, NULL
       ) $$,
  ROW('IMEW-EVFP2-CURR'::TEXT, 'PRIOR_SEASON_MATCH'::TEXT, TRUE),
  'evf.34: IMEW singleton → IMEW-{curr} with prior FK set'
);


-- =========================================================================
-- evf.35: allocator returns singleton DMEW-{year} with NULL prior (alternation)
-- =========================================================================
-- Prior season has no DMEW (biennial alternation per ADR-021) → NULL prior.
SELECT row_eq(
  $$ SELECT txt_code, alloc_path, id_prior_event
       FROM fn_allocate_evf_event_code(
         (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
         'DMEW', NULL, NULL
       ) $$,
  ROW('DMEW-EVFP2-CURR'::TEXT, 'NEXT_FREE_ALLOC'::TEXT, NULL::INT),
  'evf.35: DMEW singleton → DMEW-{curr} with NULL prior (no prior DMEW)'
);


-- =========================================================================
-- evf.36: allocator raises when 2 CREATED PEW slots match the same city
-- =========================================================================
DO $t36$ BEGIN
  INSERT INTO tbl_event (id_season, id_organizer, txt_code, txt_name,
                         dt_start, dt_end, txt_location, txt_country, enum_status)
  VALUES (
    (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'PEW10-EVFP2-CURR', 'Duplicate Salzburg',
    '2032-04-20', '2032-04-21', 'Salzburg', 'Austria', 'CREATED'
  );
END $t36$;

SELECT throws_ok(
  $$ SELECT * FROM fn_allocate_evf_event_code(
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR'),
       'PEW', 'Salzburg', 'Austria'
     ) $$,
  NULL,
  NULL,
  'evf.36: 2 CREATED Salzburg slots in current season → raises'
);

-- Clean up the duplicate so subsequent tests are deterministic
DO $cleanup$ BEGIN
  DELETE FROM tbl_event WHERE txt_code = 'PEW10-EVFP2-CURR';
END $cleanup$;


-- =========================================================================
-- evf.37: fn_import_evf_events_v2 UPDATEs CREATED slot in place
-- =========================================================================
-- Salzburg again (matches PEW7-EVFP2-CURR which is CREATED).
-- After import: row should be PLANNED, name + dates filled, child tournaments exist.
DO $t37$
DECLARE
  v_season INT;
  v_payload JSONB;
BEGIN
  v_season := (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR');
  v_payload := jsonb_build_array(jsonb_build_object(
    'name', 'EVF Circuit – Salzburg (AUT)',
    'dt_start', '2032-04-15',
    'dt_end',   '2032-04-16',
    'location', 'Salzburg',
    'country',  'Austria',
    'weapons',  jsonb_build_array('EPEE'),
    'is_team',  FALSE
  ));
  PERFORM fn_import_evf_events_v2(v_payload, v_season);
END $t37$;

SELECT row_eq(
  $$ SELECT enum_status::TEXT, txt_name, dt_start::TEXT,
            (SELECT COUNT(*)::INT FROM tbl_tournament t
               WHERE t.id_event = e.id_event)
       FROM tbl_event e WHERE txt_code = 'PEW7-EVFP2-CURR' $$,
  ROW('PLANNED'::TEXT, 'EVF Circuit – Salzburg (AUT)'::TEXT, '2032-04-15'::TEXT, 2),
  'evf.37: CREATED PEW7 slot updated → PLANNED, name+date filled, 2 tournaments (EPEE × M/F)'
);


-- =========================================================================
-- evf.38: fn_import_evf_events_v2 INSERTs new row with EVF organizer (not SPWS)
-- =========================================================================
-- Madrid (no current slot, no prior match) → new PEW{N+1} with EVF organizer.
DO $t38$
DECLARE
  v_season INT;
  v_payload JSONB;
BEGIN
  v_season := (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR');
  v_payload := jsonb_build_array(jsonb_build_object(
    'name', 'EVF Circuit – Madrid (ESP)',
    'dt_start', '2032-06-01',
    'dt_end',   '2032-06-02',
    'location', 'Madrid',
    'country',  'Spain',
    'weapons',  jsonb_build_array('EPEE'),
    'is_team',  FALSE
  ));
  PERFORM fn_import_evf_events_v2(v_payload, v_season);
END $t38$;

SELECT is(
  (SELECT id_organizer FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFP2-CURR')
       AND txt_location = 'Madrid'),
  (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
  'evf.38: new EVF event INSERTed with id_organizer = EVF (not SPWS)'
);


-- =========================================================================
-- evf.39: data-migration 20260427000003 fixed MEW-COMPLEXESP slug row
-- =========================================================================
-- Note: this assertion runs against migrations applied to the DEFAULT schema
-- state (i.e. the seed already loaded). The migration UPDATEs the slug rows
-- in seed_prod_latest.sql. Both the event + child tournaments must be renamed.
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'MEW-COMPLEXESP-2025-2026')
  + (SELECT COUNT(*)::INT FROM tbl_tournament WHERE txt_code LIKE 'MEW-COMPLEXESP-%'),
  '=', 0,
  'evf.39: MEW-COMPLEXESP-* event and tournaments no longer exist after migration'
);


SELECT * FROM finish();
ROLLBACK;
