-- =============================================================================
-- pgTAP — a European Championship is a singleton, not a chronological PEW
-- =============================================================================
-- Verifies migration 20261006000002_evf_singleton_championships.sql.
--
-- The 2027 Individual European Veterans Championships (Skopje, EVF calendar
-- post 5407) reached LOCAL, CERT and PROD as PEW16fs-2026-2027: the snapshot
-- planner and fn_ingest_evf_calendar_identity_v1 numbered every calendar entry
-- as a circuit event. fn_classify_evf_event already said IMEW; its answer was
-- used only for a prior-season lookup and then discarded.
--
-- 107.1–107.4 the singleton keeps its own code, out of the PEW sequence, and
--             the rename writes weapons and the series link with the code
-- 107.5       a PEW code for a European Championship is refused
-- 107.6–107.7 a link already set on a singleton is kept on the next run
-- 107.8–107.9 the classifier needs both words: European and Championship
--
-- Plan: doc/plans/evf-skopje-european-championships-2026-10-06.html
-- =============================================================================

BEGIN;

SELECT plan(9);

-- ----- fixtures --------------------------------------------------------------
-- Three earlier seasons hold the previous editions; the current season holds
-- the rows exactly as the bug left them (Skopje-like PEW2fs, foil and sabre).
DO $setup$
DECLARE
  v_org     INT;
  v_s96     INT;
  v_s98     INT;
  v_s99     INT;
  v_current INT;
BEGIN
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES
    ('SPWS-6296-6297', '6296-08-01', '6297-07-31'),
    ('SPWS-6298-6299', '6298-08-01', '6299-07-31'),
    ('SPWS-6299-6300', '6299-08-01', '6300-07-31'),
    ('SPWS-6300-6301', '6300-08-01', '6301-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_s96 FROM tbl_season WHERE txt_code = 'SPWS-6296-6297';
  SELECT id_season INTO v_s98 FROM tbl_season WHERE txt_code = 'SPWS-6298-6299';
  SELECT id_season INTO v_s99 FROM tbl_season WHERE txt_code = 'SPWS-6299-6300';
  SELECT id_season INTO v_current FROM tbl_season WHERE txt_code = 'SPWS-6300-6301';

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, arr_weapons
  ) VALUES
    ('IMEW-6296-6297', 'European Veterans Championships 6297', v_s96, v_org,
     'COMPLETED', '6297-05-01', '6297-05-05', ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]),
    ('IMEW-6298-6299', 'European Veterans Championships 6299', v_s98, v_org,
     'COMPLETED', '6299-05-01', '6299-05-05', ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]),
    ('DMEW-6299-6300', 'European Team Championships 6300', v_s99, v_org,
     'COMPLETED', '6300-05-14', '6300-05-17', ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]);

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer, enum_status,
    dt_start, dt_end, id_evf_calendar_event, txt_evf_slug, arr_weapons
  ) VALUES
    ('PEW1e-6300-6301', 'EVF Circuit – Alpha (AAA)', v_current, v_org, 'PLANNED',
     '6300-10-01', '6300-10-01', 911, 'alpha-6300', ARRAY['EPEE']::enum_weapon_type[]),
    ('PEW2fs-6300-6301', 'European Championships 6301', v_current, v_org, 'PLANNED',
     '6301-05-05', '6301-05-05', 912, 'european-championships-6301',
     ARRAY['FOIL','SABRE']::enum_weapon_type[]),
    ('PEW3e-6300-6301', 'EVF Circuit – Omega (OOO)', v_current, v_org, 'PLANNED',
     '6301-05-29', '6301-05-29', 913, 'omega-6300', ARRAY['EPEE']::enum_weapon_type[]);
END;
$setup$;

-- The corrected snapshot: Alpha gains foil (the Madrid case: code and weapons
-- change together), the individual championship becomes IMEW and leaves the
-- PEW sequence, Omega closes the gap, and a team championship is new.
CREATE TEMP TABLE t107_payload ON COMMIT DROP AS
SELECT jsonb_build_array(
  jsonb_build_object('name','EVF Circuit – Alpha (AAA)','dt_start','6300-10-01',
    'dt_end','6300-10-01','weapons', jsonb_build_array('EPEE','FOIL'),
    'evf_calendar_id', 911, 'evf_slug','alpha-6300','is_team', false,
    'is_cancelled', false, 'desired_code','PEW1ef-6300-6301'),
  jsonb_build_object('name','European Championships 6301','dt_start','6301-05-05',
    'dt_end','6301-05-09','weapons', jsonb_build_array('EPEE','FOIL','SABRE'),
    'evf_calendar_id', 912, 'evf_slug','european-championships-6301','is_team', false,
    'is_cancelled', false, 'desired_code','IMEW-6300-6301'),
  jsonb_build_object('name','EVF Circuit – Omega (OOO)','dt_start','6301-05-29',
    'dt_end','6301-05-30','weapons', jsonb_build_array('EPEE'),
    'evf_calendar_id', 913, 'evf_slug','omega-6300','is_team', false,
    'is_cancelled', false, 'desired_code','PEW2e-6300-6301'),
  jsonb_build_object('name','European Team Championships 6301','dt_start','6301-06-10',
    'dt_end','6301-06-13','weapons', jsonb_build_array('EPEE','FOIL','SABRE'),
    'evf_calendar_id', 914, 'evf_slug','european-team-championships-6301','is_team', true,
    'is_cancelled', false, 'desired_code','DMEW-6300-6301')
) AS events;

-- 107.1 — the plan with singleton codes is accepted
SELECT lives_ok(
  $$SELECT fn_ingest_evf_calendar(
      (SELECT events FROM t107_payload),
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301'), 4)$$,
  '107.1 — a European Championship is accepted under IMEW-/DMEW-{season}'
);

-- 107.2 — singletons hold their own codes; the PEW sequence closes the gap
SELECT results_eq(
  $$SELECT id_evf_calendar_event::INT, txt_code::TEXT
      FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301')
       AND id_evf_calendar_event IS NOT NULL
     ORDER BY id_evf_calendar_event$$,
  $$VALUES (911, 'PEW1ef-6300-6301'), (912, 'IMEW-6300-6301'),
           (913, 'PEW2e-6300-6301'), (914, 'DMEW-6300-6301')$$,
  '107.2 — IMEW and DMEW sit outside the PEW sequence, which stays 1..N'
);

-- 107.3 — weapons are written together with the code (renamed and new rows)
SELECT results_eq(
  $$SELECT id_evf_calendar_event::INT, arr_weapons::TEXT
      FROM tbl_event
     WHERE id_evf_calendar_event IN (911, 912, 914)
       AND id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301')
     ORDER BY id_evf_calendar_event$$,
  $$VALUES (911, '{EPEE,FOIL}'), (912, '{EPEE,FOIL,SABRE}'), (914, '{EPEE,FOIL,SABRE}')$$,
  '107.3 — arr_weapons follows the scraped weapons whenever the code is written'
);

-- 107.4 — an unlinked singleton links to the latest earlier edition of its kind
SELECT results_eq(
  $$SELECT e.id_evf_calendar_event::INT, p.txt_code::TEXT
      FROM tbl_event e
      JOIN tbl_event p ON p.id_event = e.id_prior_event
     WHERE e.id_evf_calendar_event IN (912, 914)
       AND e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301')
     ORDER BY e.id_evf_calendar_event$$,
  $$VALUES (912, 'IMEW-6298-6299'), (914, 'DMEW-6299-6300')$$,
  '107.4 — IMEW links to the previous IMEW, DMEW to the previous DMEW'
);

-- 107.5 — a European Championship may not be numbered as a circuit event
SELECT throws_like(
  $$SELECT fn_ingest_evf_calendar(
      jsonb_build_array(
        jsonb_build_object('name','EVF Circuit – Alpha (AAA)','dt_start','6300-10-01',
          'dt_end','6300-10-01','weapons', jsonb_build_array('EPEE','FOIL'),
          'evf_calendar_id', 911, 'evf_slug','alpha-6300','is_team', false,
          'is_cancelled', false, 'desired_code','PEW1ef-6300-6301'),
        jsonb_build_object('name','European Championships 6301','dt_start','6301-05-05',
          'dt_end','6301-05-09','weapons', jsonb_build_array('FOIL','SABRE'),
          'evf_calendar_id', 912, 'evf_slug','european-championships-6301','is_team', false,
          'is_cancelled', false, 'desired_code','PEW2fs-6300-6301'),
        jsonb_build_object('name','EVF Circuit – Omega (OOO)','dt_start','6301-05-29',
          'dt_end','6301-05-30','weapons', jsonb_build_array('EPEE'),
          'evf_calendar_id', 913, 'evf_slug','omega-6300','is_team', false,
          'is_cancelled', false, 'desired_code','PEW3e-6300-6301')
      ),
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301'), 3)$$,
  '%code plan mismatch%',
  '107.5 — PEW2fs for a European Championship is a code plan mismatch'
);

-- 107.6 / 107.7 — a link already on a singleton is never overwritten
UPDATE tbl_event
   SET id_prior_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'IMEW-6296-6297')
 WHERE id_evf_calendar_event = 912
   AND id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301');

SELECT lives_ok(
  $$SELECT fn_ingest_evf_calendar(
      (SELECT events FROM t107_payload),
      (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301'), 4)$$,
  '107.6 — a repeated run of the same snapshot is accepted'
);

SELECT results_eq(
  $$SELECT e.txt_code::TEXT, p.txt_code::TEXT
      FROM tbl_event e
      JOIN tbl_event p ON p.id_event = e.id_prior_event
     WHERE e.id_evf_calendar_event = 912
       AND e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6300-6301')$$,
  $$VALUES ('IMEW-6300-6301', 'IMEW-6296-6297')$$,
  '107.7 — the existing series link survives the run'
);

-- 107.8 / 107.9 — both words are required, and the team flag alone is not enough
SELECT is(
  fn_classify_evf_event('World Veterans Championships 6301', FALSE),
  'PEW',
  '107.8 — a world championship is not IMEW'
);

SELECT is(
  fn_classify_evf_event('Veterans Team Cup 6301', TRUE),
  'PEW',
  '107.9 — a team event that is not a European Championship is not DMEW'
);

SELECT * FROM finish();
ROLLBACK;
