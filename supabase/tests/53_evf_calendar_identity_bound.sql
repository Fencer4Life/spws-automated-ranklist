-- =============================================================================
-- EVF durable identity + chronological calendar code plan
-- =============================================================================

BEGIN;
SELECT plan(13);

SELECT has_column(
  'public', 'tbl_event', 'id_evf_calendar_event',
  '53.1: public EVF calendar identity is stored separately from results DB id'
);

DO $setup$
DECLARE
  v_org INT;
  v_prior INT;
  v_curr INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_prior := fn_create_season('EVFCHRON-PRIOR', '2035-08-01', '2036-07-15');
  v_curr := fn_create_season('EVFCHRON-CURR', '2036-08-01', '2037-07-15');
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status
  ) VALUES
    (v_prior, v_org, 'PEW8es-EVFCHRON-PRIOR', 'EVF Circuit Chania',
     '2036-05-01', '2036-05-02', 'Chania', 'Greece', 'COMPLETED'),
    (v_curr, v_org, 'PEW2es-EVFCHRON-CURR', 'Inherited Madrid skeleton',
     NULL, NULL, 'Madrid', 'Spain', 'CREATED');

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status, txt_evf_slug
  ) VALUES
    (v_curr, v_org, 'PEW70es-EVFCHRON-CURR', 'Buggy Madrid import',
     '2036-10-31', '2036-11-01', 'Madrid', 'Spain', 'PLANNED', 'madrid'),
    (v_curr, v_org, 'PEW68efs-EVFCHRON-CURR', 'Buggy Samorin import',
     '2036-09-12', '2036-09-13', 'Samorin', 'Slovakia', 'PLANNED', 'samorin');
END;
$setup$;

SELECT throws_ok(
  $$ SELECT fn_ingest_evf_calendar(
       '[{"name":"EVF Training CAMP","dt_start":"2036-08-01","dt_end":"2036-08-02","weapons":["EPEE"],"evf_calendar_id":900,"desired_code":"PEW1e-EVFCHRON-CURR"}]'::JSONB,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR'), 1
     ) $$,
  NULL, NULL,
  '53.2: whole-word CAMP rows are rejected before persistence'
);

SELECT lives_ok(
  $$ SELECT fn_ingest_evf_calendar(
       '[
         {"name":"Athens","dt_start":"2037-05-22","dt_end":"2037-05-23","location":"Chania","country":"Greece","weapons":["SABRE","EPEE"],"evf_calendar_id":3438,"evf_slug":"athens","desired_code":"PEW3es-EVFCHRON-CURR"},
         {"name":"Samorin Cancelled","dt_start":"2036-09-12","dt_end":"2036-09-13","location":"Samorin","country":"Slovakia","weapons":["SABRE","FOIL","EPEE"],"is_cancelled":true,"evf_calendar_id":5074,"evf_slug":"samorin","desired_code":"PEW0efs-EVFCHRON-CURR"},
         {"name":"Madrid","dt_start":"2036-10-31","dt_end":"2036-11-01","location":"Madrid","country":"Spain","weapons":["SABRE","EPEE"],"evf_calendar_id":877,"evf_slug":"madrid","desired_code":"PEW2es-EVFCHRON-CURR"},
         {"name":"Foil Celebration","dt_start":"2036-09-19","dt_end":"2036-09-20","location":"Budapest","country":"Hungary","weapons":["FOIL"],"evf_calendar_id":5363,"evf_slug":"foil-celebration","desired_code":"PEW1f-EVFCHRON-CURR"}
       ]'::JSONB,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR'), 4
     ) $$,
  '53.3: shuffled payload applies as one server-validated chronological plan'
);

SELECT set_eq(
  $$ SELECT txt_code FROM tbl_event
      WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR')
        AND id_evf_calendar_event IS NOT NULL $$,
  $$ VALUES ('PEW0efs-EVFCHRON-CURR'::TEXT), ('PEW1f-EVFCHRON-CURR'::TEXT),
            ('PEW2es-EVFCHRON-CURR'::TEXT), ('PEW3es-EVFCHRON-CURR'::TEXT) $$,
  '53.4: zero plus positive codes are exact and suffixes are alphabetical'
);

SELECT row_eq(
  $$ SELECT enum_status::TEXT, id_evf_calendar_event
       FROM tbl_event WHERE txt_code = 'PEW0efs-EVFCHRON-CURR' $$,
  ROW('CANCELLED'::TEXT, 5074::BIGINT),
  '53.5: known first-import cancellation is repaired to zero and cancelled'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR')
      AND txt_code ~ '^PEW([5-9]|[1-9][0-9]+)'),
  0,
  '53.6: retained calendar has no PEW number above its source count'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR')
      AND txt_code LIKE 'EVFLEGACY%'),
  1,
  '53.7: an empty colliding duplicate is quarantined without deletion'
);

SELECT is(
  (SELECT id_prior_event FROM tbl_event WHERE txt_code = 'PEW3es-EVFCHRON-CURR'),
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW8es-EVFCHRON-PRIOR'),
  '53.8: Athens keeps the geographic rolling link to prior Chania'
);

SELECT lives_ok(
  $$ SELECT fn_record_evf_calendar_scrape(
       '00000000-0000-0000-0000-000000000053'::UUID,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR'),
       4, 1, 'SUCCEEDED', '{"ignored_camp_count":1}'::JSONB
     ) $$,
  '53.9: retained and cancelled counts are persisted'
);

SELECT throws_ok(
  $$ SELECT fn_ingest_evf_calendar(
       '[{"name":"Wrong","dt_start":"2037-06-01","dt_end":"2037-06-02","weapons":["EPEE"],"evf_calendar_id":9999,"desired_code":"PEW9e-EVFCHRON-CURR"}]'::JSONB,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR'), 1
     ) $$,
  NULL, NULL,
  '53.10: server rejects a caller-supplied non-chronological code'
);

SELECT throws_ok(
  $$ SELECT fn_ingest_evf_calendar(
       '[{"name":"No weapons","dt_start":"2037-06-01","dt_end":"2037-06-02","weapons":[],"evf_calendar_id":9998,"desired_code":"PEW1-EVFCHRON-CURR"}]'::JSONB,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR'), 1
     ) $$,
  NULL, NULL,
  '53.11: retained competition without weapons fails before write'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFCHRON-CURR')
      AND id_evf_calendar_event = 877),
  1,
  '53.12: durable calendar id owns exactly one row'
);

DO $mirror_identity$
DECLARE
  v_id INT := (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1f-EVFCHRON-CURR');
BEGIN
  UPDATE tbl_event SET id_evf_calendar_event = NULL WHERE id_event = v_id;
  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(jsonb_build_object(
      'id_event', v_id,
      'id_evf_calendar_event', 5363
    )),
    '[]'::JSONB
  );
END;
$mirror_identity$;

SELECT is(
  (SELECT id_evf_calendar_event FROM tbl_event WHERE txt_code = 'PEW1f-EVFCHRON-CURR'),
  5363::BIGINT,
  '53.13: CERT to PROD reconciliation carries calendar identity'
);

SELECT * FROM finish();
ROLLBACK;
