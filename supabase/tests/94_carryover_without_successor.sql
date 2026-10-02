-- =============================================================================
-- CARRY.NS — a result whose event has no row in the next season yet still carries
-- =============================================================================
-- ADR-042 amendment (2026-10-02, decision S B in
-- doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html).
-- vw_eligible_event carried a previous-season event only through the next
-- season's row linked to it (id_prior_event), until that row is held. A
-- cancelled or not yet held edition kept carrying; an event whose next edition
-- has no row at all dropped out at once. The Criterium Mondial Vétérans 2026
-- (EVF, July 2026) fell in that gap: EVF publishes the 2027 edition late in the
-- season, and ADR-091 forbids a placeholder row. Such an event now carries for
-- the same window, into the season right after its own.
--
-- The window is set relative to today so the test holds whenever it runs.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(7);

CREATE TEMP TABLE ns_ids AS
SELECT (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025') AS s2425,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026') AS s2526,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027') AS s2627,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF') AS evf;

-- Held, no 2026/27 row (the Criterium case); held with a linked 2026/27 row;
-- not held; held two seasons back.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'CARRY.NS fixture', CASE which WHEN 's2526' THEN s2526 ELSE s2425 END, evf, d, d,
       st::enum_event_status
  FROM ns_ids, (VALUES
    ('PEW97efs-2025-2026', 's2526', DATE '2026-07-05', 'COMPLETED'),
    ('PEW98efs-2025-2026', 's2526', DATE '2026-07-05', 'COMPLETED'),
    ('PEW99efs-2025-2026', 's2526', DATE '2026-07-05', 'PLANNED'),
    ('PEW96efs-2024-2025', 's2425', DATE '2025-07-05', 'COMPLETED')) v(c, which, d, st);

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, id_prior_event)
SELECT 'PEW98efs-2026-2027', 'CARRY.NS fixture', s2627, evf, 'PLANNED',
       (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW98efs-2025-2026')
  FROM ns_ids;

-- The 2026/27 window reaches thirty days past today.
UPDATE tbl_season SET int_carryover_days = (CURRENT_DATE - DATE '2026-07-05') + 30
 WHERE txt_code = 'SPWS-2026-2027';

CREATE TEMP VIEW ns_carried AS
SELECT e.txt_code, v.is_carried
  FROM vw_eligible_event v JOIN tbl_event e ON e.id_event = v.source_event_id
 WHERE v.effective_season_id = (SELECT s2627 FROM ns_ids) AND e.txt_name = 'CARRY.NS fixture';

SELECT results_eq(
  $$SELECT is_carried FROM ns_carried WHERE txt_code = 'PEW97efs-2025-2026'$$,
  $$VALUES (TRUE)$$,
  'CARRY.NS.01 a held event with no row in the next season is carried into it, once');

SELECT results_eq(
  $$SELECT count(*)::INT FROM ns_carried WHERE txt_code = 'PEW98efs-2025-2026'$$,
  $$VALUES (1)$$,
  'CARRY.NS.02 an event with a linked next-season row is carried once, through the link');

SELECT is_empty(
  $$SELECT 1 FROM ns_carried WHERE txt_code IN ('PEW99efs-2025-2026', 'PEW96efs-2024-2025')$$,
  'CARRY.NS.03 an event not held, or two seasons back, is not carried');

-- A fencer's result in the Criterium-like event, through the drilldown function.
INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
VALUES ('CARRYNS', 'Test', 'PL', 1964, 'M');
INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count)
SELECT id_event, 'PEW97efs-V3-M-SABRE-2025-2026', 'PEW', 'SABRE', 'M', 'V3', DATE '2026-07-05', 14
  FROM tbl_event WHERE txt_code = 'PEW97efs-2025-2026';
INSERT INTO tbl_result (id_tournament, id_fencer, int_place, num_final_score)
SELECT t.id_tournament, f.id_fencer, 1, 111.69
  FROM tbl_tournament t, tbl_fencer f
 WHERE t.txt_code = 'PEW97efs-V3-M-SABRE-2025-2026' AND f.txt_surname = 'CARRYNS';

SELECT results_eq(
  $$SELECT x.txt_tournament_code, x.bool_carried_over
      FROM tbl_fencer f, ns_ids,
           LATERAL fn_fencer_scores_rolling(f.id_fencer, 'SABRE', 'M', 'V3', ns_ids.s2627) x
     WHERE f.txt_surname = 'CARRYNS'$$,
  $$VALUES ('PEW97efs-V3-M-SABRE-2025-2026'::TEXT, TRUE)$$,
  'CARRY.NS.04 the drilldown lists the carried result for the next season');

UPDATE tbl_season SET int_carryover_days = (CURRENT_DATE - DATE '2026-07-05') - 1
 WHERE txt_code = 'SPWS-2026-2027';

SELECT is_empty(
  $$SELECT 1 FROM ns_carried WHERE txt_code = 'PEW97efs-2025-2026'$$,
  'CARRY.NS.05 past the carry-over window it is no longer carried');

UPDATE tbl_season SET int_carryover_days = (CURRENT_DATE - DATE '2026-07-05') + 30
 WHERE txt_code = 'SPWS-2026-2027';

-- The next edition appears: the carry continues through its link, once.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, id_prior_event)
SELECT 'PEW97efs-2026-2027', 'CARRY.NS successor', s2627, evf, 'PLANNED',
       (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW97efs-2025-2026')
  FROM ns_ids;

SELECT results_eq(
  $$SELECT count(*)::INT FROM ns_carried WHERE txt_code = 'PEW97efs-2025-2026'$$,
  $$VALUES (1)$$,
  'CARRY.NS.06 once the next edition has a row, the event is carried once, through it');

UPDATE tbl_event SET enum_status = 'IN_PROGRESS' WHERE txt_code = 'PEW97efs-2026-2027';
UPDATE tbl_event SET enum_status = 'COMPLETED' WHERE txt_code = 'PEW97efs-2026-2027';

SELECT is_empty(
  $$SELECT 1 FROM ns_carried WHERE txt_code = 'PEW97efs-2025-2026'$$,
  'CARRY.NS.07 once the next edition is held, the carry stops');

SELECT * FROM finish();
ROLLBACK;
