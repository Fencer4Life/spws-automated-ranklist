-- =============================================================================
-- CERT->PROD event reconciler (ADR pending sign-off — supersedes the
-- calendar-delta half of ADR-026)
-- =============================================================================
-- fn_mirror_events_to_prod(p_creates, p_updates, p_deletes) replaces
-- fn_import_evf_events. It is organizer-agnostic (no hardcoded organizer
-- literal — id_organizer arrives pre-resolved by txt_code) and implements
-- full Create/Update/Delete against the active-season event set, keyed on
-- txt_code. See doc/staging plan "piped-wishing-leaf" for the design.
-- =============================================================================

BEGIN;
SELECT plan(13);

-- ===== SETUP =====
-- A prior-season event to link via id_prior_event (migrated from
-- 48_season_skeleton_promotion.sql's retired 48.4 — id_prior_event
-- resolution is now the reconciler CREATE branch's responsibility).
DO $setup$
DECLARE
  v_prior_season INT;
  v_season       INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_prior_season := fn_create_season('RECON-PRIOR', '2033-09-01', '2034-06-30');
  v_season       := fn_create_season('RECON-TEST',  '2034-09-01', '2035-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status, arr_weapons
  ) VALUES (
    'PEW-RECON1-2033-2034', 'EVF Circuit Recon Test (prior)', v_prior_season,
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    '2034-03-15', 'Recon City', 'Germany', 'COMPLETED', '{EPEE}'::enum_weapon_type[]
  );
END;
$setup$;


-- =========================================================================
-- 51.1 — CREATE: faithful whole-row copy, organizer resolved by code
--        (pre-resolved id_organizer in the payload — no hardcode), childless
-- =========================================================================
DO $t511$
DECLARE
  v_season   INT;
  v_evf_org  INT;
  v_prior_id INT;
  v_result   JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'RECON-TEST';
  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_event INTO v_prior_id FROM tbl_event WHERE txt_code = 'PEW-RECON1-2033-2034';

  v_result := fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code',     'PEW-RECON1-2034-2035',
      'txt_name',     'EVF Circuit Recon Test',
      'id_season',    v_season,
      'id_organizer', v_evf_org,
      'dt_start',     '2035-03-15',
      'dt_end',       '2035-03-16',
      'txt_location', 'Recon City',
      'txt_country',  'Germany',
      'enum_status',  'PLANNED',
      'arr_weapons',  jsonb_build_array('EPEE', 'FOIL'),
      'id_prior_event', v_prior_id
    )),
    '[]'::JSONB,
    '[]'::JSONB
  );
END;
$t511$;

SELECT is(
  (SELECT id_organizer FROM tbl_event WHERE txt_code = 'PEW-RECON1-2034-2035'),
  (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
  '51.1a: CREATE resolves id_organizer from the payload — no hardcoded organizer'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament
     WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-RECON1-2034-2035')),
  0,
  '51.1b: CREATE is childless — no tournament rows created'
);

SELECT is(
  (SELECT id_prior_event FROM tbl_event WHERE txt_code = 'PEW-RECON1-2034-2035'),
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW-RECON1-2033-2034'),
  '51.1c: CREATE preserves id_prior_event, pre-resolved to the target id by the caller'
);


-- =========================================================================
-- 51.2 — CREATE fails loud on an unresolved/unknown organizer id
-- =========================================================================
SELECT throws_ok(
  $$SELECT fn_mirror_events_to_prod(
      jsonb_build_array(jsonb_build_object(
        'txt_code',     'PEW-RECON-BADORG-2034-2035',
        'txt_name',     'Bad Organizer Event',
        'id_season',    (SELECT id_season FROM tbl_season WHERE txt_code = 'RECON-TEST'),
        'id_organizer', 999999999,
        'dt_start',     '2035-03-20',
        'enum_status',  'PLANNED'
      )),
      '[]'::JSONB,
      '[]'::JSONB
    )$$,
  NULL, NULL,
  '51.2: CREATE raises rather than guessing when id_organizer does not resolve'
);


-- =========================================================================
-- 51.3 — UPDATE: overwrites identity fields from CERT (re-tags the
--        organizer mistake, e.g. SPWS -> EVF)
-- =========================================================================
DO $t513$
DECLARE
  v_season  INT;
  v_spws    INT;
  v_evf     INT;
  v_event   INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'RECON-TEST';
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_organizer INTO v_evf  FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status,
    url_registration, arr_weapons
  ) VALUES (
    'PEW-RECON2-2034-2035', 'Mistagged Event', v_season, v_spws,
    '2035-04-10', 'Old City', 'Slovakia', 'PLANNED',
    'https://admin-edit.example.com/register', '{EPEE}'::enum_weapon_type[]
  ) RETURNING id_event INTO v_event;

  PERFORM fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(jsonb_build_object(
      'id_event',     v_event,
      'txt_name',     'Corrected Event Name',
      'id_organizer', v_evf,
      'txt_location', 'Samorin',
      'txt_country',  'Slovakia',
      'url_invitation', 'https://scraped.example.com/invitation.pdf',
      'url_registration', 'https://SHOULD-NOT-WIN.example.com/reg'
    )),
    '[]'::JSONB
  );
END;
$t513$;

SELECT is(
  (SELECT id_organizer FROM tbl_event WHERE txt_code = 'PEW-RECON2-2034-2035'),
  (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
  '51.3a: UPDATE overwrites id_organizer from CERT — the mis-tag repair'
);

SELECT is(
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW-RECON2-2034-2035'),
  'Samorin',
  '51.3b: UPDATE overwrites identity field txt_location from CERT'
);


-- =========================================================================
-- 51.4 — UPDATE is fill-blank-only on admin-owned URL fields; never
--        touches enum_status
-- =========================================================================
SELECT is(
  (SELECT url_registration FROM tbl_event WHERE txt_code = 'PEW-RECON2-2034-2035'),
  'https://admin-edit.example.com/register',
  '51.4a: UPDATE does NOT overwrite an admin-set url_registration (fill-blank-only)'
);

SELECT is(
  (SELECT url_invitation FROM tbl_event WHERE txt_code = 'PEW-RECON2-2034-2035'),
  'https://scraped.example.com/invitation.pdf',
  '51.4b: UPDATE fills a blank url_invitation from CERT'
);

SELECT is(
  (SELECT enum_status::TEXT FROM tbl_event WHERE txt_code = 'PEW-RECON2-2034-2035'),
  'PLANNED',
  '51.4c: UPDATE never touches enum_status'
);


-- =========================================================================
-- 51.5 / 51.6 — DELETE: removes a PLANNED zero-result event + its empty
--        tournaments; refuses (skips) a results-bearing event
-- =========================================================================
DO $t515$
DECLARE
  v_season   INT;
  v_org      INT;
  v_fencer   INT;
  v_ev_empty INT;
  v_ev_res   INT;
  v_tourn    INT;
  v_result   JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'RECON-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  -- PLANNED, zero results — must be deleted
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status, arr_weapons
  ) VALUES (
    'PEW-RECON3-2034-2035', 'Orphan Event', v_season, v_org,
    '2035-05-01', 'Ghost City', 'Slovakia', 'PLANNED', '{EPEE}'::enum_weapon_type[]
  ) RETURNING id_event INTO v_ev_empty;

  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status
  ) VALUES (
    v_ev_empty, 'PEW-RECON3-2034-2035-M-EPEE', 'PEW', 'EPEE', 'M', 'V2',
    '2035-05-01', 0, 'PLANNED'
  );

  -- Has results — must be refused/skipped, never deleted
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status, arr_weapons
  ) VALUES (
    'PEW-RECON4-2034-2035', 'Completed Event', v_season, v_org,
    '2035-05-05', 'Real City', 'Slovakia', 'PLANNED', '{EPEE}'::enum_weapon_type[]
  ) RETURNING id_event INTO v_ev_res;

  INSERT INTO tbl_tournament (
    id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status
  ) VALUES (
    v_ev_res, 'PEW-RECON4-2034-2035-M-EPEE', 'PEW', 'EPEE', 'M', 'V2',
    '2035-05-05', 1, 'PLANNED'
  ) RETURNING id_tournament INTO v_tourn;

  INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality)
    VALUES ('Reconciler', 'Test', 'SVK') RETURNING id_fencer INTO v_fencer;

  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
    VALUES (v_fencer, v_tourn, 1);

  v_result := fn_mirror_events_to_prod(
    '[]'::JSONB,
    '[]'::JSONB,
    jsonb_build_array(v_ev_empty, v_ev_res)
  );
END;
$t515$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW-RECON3-2034-2035'),
  0,
  '51.5: DELETE removes a PLANNED zero-result event and its empty tournaments'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW-RECON4-2034-2035'),
  1,
  '51.6: DELETE refuses a results-bearing event — it is never erased'
);


-- =========================================================================
-- 51.7 — orphan-cleanup regression: the live PROD bug this ships to fix.
-- Simulates 7 PROD Samorin duplicates (mistagged SPWS, like the real ones)
-- reconciling in ONE call against a single CERT-truth Samorin event: the
-- canonical row is UPDATEd (re-tagged EVF) and the 6 duplicates are DELETEd.
-- =========================================================================
DO $t517$
DECLARE
  v_season   INT;
  v_spws     INT;
  v_evf      INT;
  v_keep     INT;
  v_dupe_ids INT[] := '{}';
  v_new_id   INT;
  i          INT;
  v_result   JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'RECON-TEST';
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_organizer INTO v_evf  FROM tbl_organizer WHERE txt_code = 'EVF';

  -- The row that survives (mirrors CERT's single canonical Samorin code)
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    dt_start, txt_location, txt_country, enum_status, arr_weapons
  ) VALUES (
    'PEW68-2034-2035', 'EVF Circuit - Samorin (SVK)', v_season, v_spws,
    '2035-09-12', '', '', 'PLANNED', '{EPEE}'::enum_weapon_type[]
  ) RETURNING id_event INTO v_keep;

  -- 6 dead duplicates PROD accumulated (PLANNED, no results, absent from
  -- CERT's now-deduped set)
  FOR i IN 69..74 LOOP
    INSERT INTO tbl_event (
      txt_code, txt_name, id_season, id_organizer,
      dt_start, txt_location, txt_country, enum_status, arr_weapons
    ) VALUES (
      'PEW' || i || '-2034-2035', 'EVF Circuit - Samorin (SVK)', v_season, v_spws,
      '2035-09-12', '', '', 'PLANNED', '{EPEE}'::enum_weapon_type[]
    ) RETURNING id_event INTO v_new_id;
    v_dupe_ids := v_dupe_ids || v_new_id;
  END LOOP;

  v_result := fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(jsonb_build_object('id_event', v_keep, 'id_organizer', v_evf)),
    to_jsonb(v_dupe_ids)
  );
END;
$t517$;

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'RECON-TEST')
       AND txt_code = ANY(ARRAY[
         'PEW68-2034-2035', 'PEW69-2034-2035', 'PEW70-2034-2035', 'PEW71-2034-2035',
         'PEW72-2034-2035', 'PEW73-2034-2035', 'PEW74-2034-2035'
       ])),
  1,
  '51.7a: orphan-cleanup regression — 7-row Samorin fixture reconciles to exactly 1 row'
);

SELECT is(
  (SELECT o.txt_code FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
     WHERE e.txt_code = 'PEW68-2034-2035'),
  'EVF',
  '51.7b: orphan-cleanup regression — the surviving row is EVF-tagged, not SPWS'
);


SELECT * FROM finish();
ROLLBACK;
