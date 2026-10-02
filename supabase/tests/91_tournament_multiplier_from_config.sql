-- =============================================================================
-- TT.MULT — a tournament's stored multiplier is its season's type multiplier
-- =============================================================================
-- Scoring takes the multiplier from tbl_scoring_type_config; the drilldown
-- prints tbl_tournament.num_multiplier (through vw_score). On 2 Oct 2026 the
-- re-ingested Plovdiv (MEW, 1.2) and Manama (MSW, 1.2) were stored with 1.0:
-- the points used 1.2, the drilldown said 1.0. The stored copy is now derived
-- from the season's type config on every write, so the two cannot disagree.
-- =============================================================================

BEGIN;

SELECT plan(4);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'IMSW-2095-2096', 'TT.MULT fixture',
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
       (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1),
       'PLANNED';

INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, num_multiplier)
SELECT id_event, 'IMSW-V2-M-EPEE-2095-2096', 'MSW', 'EPEE', 'M', 'V2', '2025-11-14', 1.0
  FROM tbl_event WHERE txt_code = 'IMSW-2095-2096';

SELECT is(
  (SELECT num_multiplier FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2095-2096'),
  (SELECT tc.num_multiplier FROM tbl_scoring_type_config tc JOIN tbl_scoring_config c USING (id_config)
    JOIN tbl_season s USING (id_season) WHERE s.txt_code = 'SPWS-2025-2026' AND tc.enum_type = 'MSW'),
  'TT.MULT.01 an MSW tournament written with 1.0 stores its season''s MSW multiplier');

UPDATE tbl_tournament SET num_multiplier = 3.0 WHERE txt_code = 'IMSW-V2-M-EPEE-2095-2096';
SELECT is(
  (SELECT num_multiplier FROM tbl_tournament WHERE txt_code = 'IMSW-V2-M-EPEE-2095-2096'),
  (SELECT tc.num_multiplier FROM tbl_scoring_type_config tc JOIN tbl_scoring_config c USING (id_config)
    JOIN tbl_season s USING (id_season) WHERE s.txt_code = 'SPWS-2025-2026' AND tc.enum_type = 'MSW'),
  'TT.MULT.02 a later edit of the stored multiplier keeps the configured value');

SELECT is(
  (SELECT count(*) FROM tbl_tournament t JOIN tbl_event e USING (id_event)
     JOIN tbl_scoring_config c ON c.id_season = e.id_season
     JOIN tbl_scoring_type_config tc ON tc.id_config = c.id_config AND tc.enum_type = t.enum_type
    WHERE t.num_multiplier IS DISTINCT FROM tc.num_multiplier),
  0::BIGINT,
  'TT.MULT.03 every stored tournament multiplier equals its season''s type multiplier');

INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
VALUES ('TTMULT', 'Test', 'PL', 1970, 'M');
INSERT INTO tbl_result (id_tournament, id_fencer, int_place)
SELECT t.id_tournament, f.id_fencer, 1
  FROM tbl_tournament t, tbl_fencer f
 WHERE t.txt_code = 'IMSW-V2-M-EPEE-2095-2096' AND f.txt_surname = 'TTMULT';

SELECT results_eq(
  $$SELECT v.num_multiplier FROM vw_score v JOIN tbl_tournament t USING (id_tournament)
     WHERE t.txt_code = 'IMSW-V2-M-EPEE-2095-2096'$$,
  $$SELECT tc.num_multiplier FROM tbl_scoring_type_config tc JOIN tbl_scoring_config c USING (id_config)
     JOIN tbl_season s USING (id_season) WHERE s.txt_code = 'SPWS-2025-2026' AND tc.enum_type = 'MSW'$$,
  'TT.MULT.04 what the drilldown reads (vw_score) is the configured multiplier');

SELECT * FROM finish();
ROLLBACK;
