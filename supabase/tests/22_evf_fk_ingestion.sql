-- =============================================================================
-- EVF FK ingestion plumbing
-- =============================================================================
-- Tests 22.1–22.3: the three EVF RPCs propagate id_evf_event /
-- id_evf_competition into tbl_event / tbl_tournament when supplied; remain
-- backwards-compatible (NULL when not supplied).
-- =============================================================================

BEGIN;
SELECT plan(4);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('EVFFK-INGEST', '2032-09-01', '2033-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT (txt_code) DO NOTHING;
END;
$setup$;


-- =========================================================================
-- 22.1 — fn_import_evf_events_v2 with evf_id key sets tbl_event.id_evf_event
-- =========================================================================
DO $t221$
DECLARE
  v_season  INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST';
  v_payload := jsonb_build_array(jsonb_build_object(
    'name',     'EVF FK Test Event 22.1',
    'dt_start', '2033-03-15',
    'dt_end',   '2033-03-16',
    'location', 'TestCity221',
    'country',  'Poland',
    'weapons',  jsonb_build_array('EPEE'),
    'is_team',  false,
    'evf_id',   1234567
  ));
  PERFORM fn_import_evf_events_v2(v_payload, v_season);
END;
$t221$;

SELECT is(
  (SELECT id_evf_event FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST')
      AND dt_start = '2033-03-15'),
  1234567,
  '22.1: fn_import_evf_events_v2 writes evf_id from JSONB into tbl_event.id_evf_event'
);


-- =========================================================================
-- 22.2 — fn_import_evf_events_v2 without evf_id leaves the column NULL
-- =========================================================================
DO $t222$
DECLARE
  v_season  INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST';
  v_payload := jsonb_build_array(jsonb_build_object(
    'name',     'EVF FK Test Event 22.2 (no evf_id)',
    'dt_start', '2033-04-15',
    'dt_end',   '2033-04-16',
    'location', 'TestCity222',
    'country',  'Hungary',
    'weapons',  jsonb_build_array('SABRE'),
    'is_team',  false
  ));
  PERFORM fn_import_evf_events_v2(v_payload, v_season);
END;
$t222$;

SELECT is(
  (SELECT id_evf_event FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST')
      AND dt_start = '2033-04-15'),
  NULL::INT,
  '22.2: fn_import_evf_events_v2 leaves id_evf_event NULL when JSONB has no evf_id'
);


-- =========================================================================
-- 22.3 — fn_create_evf_event_from_results stores p_id_evf_event
-- =========================================================================
DO $t223$
DECLARE
  v_season INT;
  v_id     INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST';
  SELECT id_event INTO v_id
    FROM fn_create_evf_event_from_results(
      v_season, 'EVF FK Test Event 22.3', '2033-05-15'::DATE,
      'TestCity223', 'Italy', false, 7654321
    );
END;
$t223$;

SELECT is(
  (SELECT id_evf_event FROM tbl_event
    WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST')
      AND dt_start = '2033-05-15'),
  7654321,
  '22.3: fn_create_evf_event_from_results stores p_id_evf_event'
);


-- =========================================================================
-- 22.4 — fn_find_or_create_tournament stores p_id_evf_competition (and
--        backfills NULL on idempotent re-call)
-- =========================================================================
DO $t224$
DECLARE
  v_season INT;
  v_event  INT;
  v_t1     INT;
  v_t2     INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFFK-INGEST';
  SELECT id_event INTO v_event
    FROM fn_create_evf_event_from_results(
      v_season, 'EVF FK Test Event 22.4', '2033-06-15'::DATE,
      'TestCity224', 'France', false, NULL
    );
  -- First call without comp id (column stays NULL)
  v_t1 := fn_find_or_create_tournament(
    v_event, 'EPEE'::enum_weapon_type, 'M'::enum_gender_type,
    'V2'::enum_age_category, '2033-06-15'::DATE, 'PEW'::enum_tournament_type
  );
  -- Second call with comp id (backfills the row found above)
  v_t2 := fn_find_or_create_tournament(
    v_event, 'EPEE'::enum_weapon_type, 'M'::enum_gender_type,
    'V2'::enum_age_category, '2033-06-15'::DATE, 'PEW'::enum_tournament_type,
    98765
  );
END;
$t224$;

SELECT is(
  (SELECT id_evf_competition FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.dt_start = '2033-06-15' AND t.enum_weapon = 'EPEE'
      AND t.enum_gender = 'M' AND t.enum_age_category = 'V2'),
  98765,
  '22.4: fn_find_or_create_tournament backfills id_evf_competition on idempotent re-call'
);


SELECT * FROM finish();
ROLLBACK;
