-- =============================================================================
-- Tournament url_results populated during ingestion (ADR-073 amendment, N14)
-- =============================================================================
-- The Commit plugin persists tbl_tournament.url_results from the parsed web
-- source via fn_find_or_create_tournament's new p_url_results arg.
--   46.1 — p_url_results sets url_results on INSERT (new tournament)
--   46.2 — a non-NULL p_url_results OVERWRITES on idempotent re-call
--   46.3 — a NULL p_url_results PRESERVES the existing value
--   46.4 — vw_score still exposes url_results (drilldown regression)
--   46.5 — vw_score returns the persisted url_results for a scored row
-- =============================================================================

BEGIN;
SELECT plan(5);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('URLRES-INGEST', '2034-09-01', '2035-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('SPWS', 'SPWS') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
    VALUES ('URLRES1-2034-2035', 'URL Res Test', v_season, v_org,
            '2035-03-15', '2035-03-15', 'PLANNED');
END;
$setup$;


-- =========================================================================
-- 46.1 — p_url_results sets url_results on INSERT
-- =========================================================================
DO $t461$
DECLARE
  v_event INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'URLRES1-2034-2035';
  PERFORM fn_find_or_create_tournament(
    v_event, 'EPEE'::enum_weapon_type, 'M'::enum_gender_type,
    'V2'::enum_age_category, '2035-03-15'::DATE, 'PPW'::enum_tournament_type,
    p_url_results := 'http://ftl/v2'
  );
END;
$t461$;

SELECT is(
  (SELECT url_results FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'URLRES1-2034-2035' AND t.enum_age_category = 'V2'),
  'http://ftl/v2',
  '46.1: fn_find_or_create_tournament sets url_results on insert'
);


-- =========================================================================
-- 46.2 — a non-NULL p_url_results OVERWRITES on idempotent re-call
-- =========================================================================
DO $t462$
DECLARE
  v_event INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'URLRES1-2034-2035';
  PERFORM fn_find_or_create_tournament(
    v_event, 'EPEE'::enum_weapon_type, 'M'::enum_gender_type,
    'V2'::enum_age_category, '2035-03-15'::DATE, 'PPW'::enum_tournament_type,
    p_url_results := 'http://ftl/v2-REINGESTED'
  );
END;
$t462$;

SELECT is(
  (SELECT url_results FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'URLRES1-2034-2035' AND t.enum_age_category = 'V2'),
  'http://ftl/v2-REINGESTED',
  '46.2: a non-NULL p_url_results overwrites on re-ingest'
);


-- =========================================================================
-- 46.3 — a NULL p_url_results PRESERVES the existing value
-- =========================================================================
DO $t463$
DECLARE
  v_event INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'URLRES1-2034-2035';
  PERFORM fn_find_or_create_tournament(
    v_event, 'EPEE'::enum_weapon_type, 'M'::enum_gender_type,
    'V2'::enum_age_category, '2035-03-15'::DATE, 'PPW'::enum_tournament_type,
    p_url_results := NULL
  );
END;
$t463$;

SELECT is(
  (SELECT url_results FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'URLRES1-2034-2035' AND t.enum_age_category = 'V2'),
  'http://ftl/v2-REINGESTED',
  '46.3: a NULL p_url_results preserves the existing url_results (never wipes)'
);


-- =========================================================================
-- 46.4 — vw_score still exposes url_results (drilldown regression)
-- =========================================================================
SELECT has_column('vw_score', 'url_results',
  '46.4: vw_score exposes url_results for the drilldown');


-- =========================================================================
-- 46.5 — vw_score returns the persisted url_results for a scored row
-- =========================================================================
DO $t465$
DECLARE
  v_event INT;
  v_tourn INT;
  v_fencer INT;
BEGIN
  SELECT id_event INTO v_event FROM tbl_event WHERE txt_code = 'URLRES1-2034-2035';
  SELECT id_tournament INTO v_tourn FROM tbl_tournament t
    WHERE t.id_event = v_event AND t.enum_age_category = 'V2';
  INSERT INTO tbl_fencer (txt_first_name, txt_surname, enum_gender, int_birth_year)
    VALUES ('Url', 'Tester', 'M', 1980) RETURNING id_fencer INTO v_fencer;
  INSERT INTO tbl_result (id_tournament, id_fencer, int_place, num_final_score)
    VALUES (v_tourn, v_fencer, 1, 100);
END;
$t465$;

SELECT is(
  (SELECT url_results FROM vw_score
    WHERE txt_tournament_code IN (
      SELECT t.txt_code FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
       WHERE e.txt_code = 'URLRES1-2034-2035' AND t.enum_age_category = 'V2')
    LIMIT 1),
  'http://ftl/v2-REINGESTED',
  '46.5: vw_score surfaces the persisted url_results to the drilldown'
);


SELECT * FROM finish();
ROLLBACK;
