-- =============================================================================
-- CARRY.RS — a linked carry stops on results, per weapon and gender (ADR-108 §8, P6 A)
-- =============================================================================
-- The four EVENT_FK_MATCHING functions read vw_eligible_event, which keeps
-- carrying a previous edition until its linked current edition is SCORED or
-- COMPLETED. Promote leaves an event IN_PROGRESS until the end date has passed
-- (ADR-108 §7), so a fencer's result in the current edition and the carried one
-- would both count. A carried row now stops as soon as the linked current
-- edition has a scored result for that weapon and gender and itself counts
-- (any status the view counts: not CREATED, PLANNED or CANCELLED), whether it
-- is IN_PROGRESS, SCORED or COMPLETED (ADR-018's rule for the older engine).
-- The link decides, not the type: a linked PEW carry stops the same way as a
-- PPW one (decision A, 3 Oct 2026; ADR-018 §7). A weapon fenced on a later day
-- keeps its carry until then, and a COMPLETED edition still stops every carry.
-- The UI reads fn_ranking_ppw, fn_ranking_full (SPWS / EVF+) and the drilldown;
-- fn_ranking_kadra is not read by the UI and, under 2026/27's single EVF+
-- bucket, returns no rows, so it gets the same line but no assertion here.
--
-- The window is set relative to today so the test holds whenever it runs.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(11);

CREATE TEMP TABLE rs AS
SELECT (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026') AS s2526,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027') AS s2627,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS') AS spws,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF') AS evf;

-- Previous editions, held; current editions linked to them and IN_PROGRESS.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT c, 'CARRY.RS fixture', s2526, o, DATE '2026-05-10', DATE '2026-05-10', 'COMPLETED'
  FROM rs, (VALUES ('PPW97-2025-2026', 'spws'), ('PEW95efs-2025-2026', 'evf')) v(c, w)
  CROSS JOIN LATERAL (SELECT CASE w WHEN 'spws' THEN rs.spws ELSE rs.evf END AS o) x;
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status, id_prior_event)
SELECT c, 'CARRY.RS fixture', s2627, o, DATE '2026-10-10', DATE '2026-10-11', 'IN_PROGRESS',
       (SELECT id_event FROM tbl_event WHERE txt_code = p)
  FROM rs, (VALUES ('PPW97-2026-2027', 'PPW97-2025-2026', 'spws'), ('PEW95efs-2026-2027', 'PEW95efs-2025-2026', 'evf')) v(c, p, w)
  CROSS JOIN LATERAL (SELECT CASE w WHEN 'spws' THEN rs.spws ELSE rs.evf END AS o) x;

-- A PZSz senior event of 2026/27: kadra lists only fencers with a PPS or MPS result.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT 'PPS97-2026-2027', 'CARRY.RS fixture', s2627, COALESCE((SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSZ'), spws),
       DATE '2026-11-07', DATE '2026-11-07', 'COMPLETED'
  FROM rs;

-- The 2026/27 window reaches thirty days past today.
UPDATE tbl_season SET int_carryover_days = (CURRENT_DATE - DATE '2026-05-10') + 30 WHERE txt_code = 'SPWS-2026-2027';

-- Born 1984: V1 in 2026/27.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
VALUES (98401, 'CARRYRS', 'Test', 'PL', 1984, 'M');

INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count)
SELECT e.id_event, tc, ty::enum_tournament_type, w::enum_weapon_type, 'M', 'V1', e.dt_start, 10
  FROM (VALUES ('PPW97-2025-2026', 'PPW97-V1-M-EPEE-2025-2026', 'PPW', 'EPEE'),
               ('PPW97-2025-2026', 'PPW97-V1-M-FOIL-2025-2026', 'PPW', 'FOIL'),
               ('PPW97-2026-2027', 'PPW97-V1-M-EPEE-2026-2027', 'PPW', 'EPEE'),
               ('PEW95efs-2025-2026', 'PEW95efs-V1-M-EPEE-2025-2026', 'PEW', 'EPEE'),
               ('PEW95efs-2026-2027', 'PEW95efs-V1-M-EPEE-2026-2027', 'PEW', 'EPEE'),
               ('PPS97-2026-2027', 'PPS97-V1-M-EPEE-2026-2027', 'PPS', 'EPEE')) v(ec, tc, ty, w)
  JOIN tbl_event e ON e.txt_code = v.ec;

INSERT INTO tbl_result (id_tournament, id_fencer, int_place, num_final_score)
SELECT t.id_tournament, 98401, 1, s
  FROM (VALUES ('PPW97-V1-M-EPEE-2025-2026', 50.00), ('PPW97-V1-M-FOIL-2025-2026', 40.00),
               ('PPW97-V1-M-EPEE-2026-2027', 60.00),
               ('PEW95efs-V1-M-EPEE-2025-2026', 70.00), ('PEW95efs-V1-M-EPEE-2026-2027', 80.00),
               ('PPS97-V1-M-EPEE-2026-2027', 10.00)) v(tc, s)
  JOIN tbl_tournament t ON t.txt_code = v.tc;

-- ---------------------------------------------------------------- the drilldown
SELECT results_eq(
  $$SELECT txt_tournament_code, bool_carried_over, num_final_score
      FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'EPEE', 'M', 'V1', (SELECT s2627 FROM rs))
     WHERE txt_tournament_code LIKE 'PPW97-%' ORDER BY 1$$,
  $$VALUES ('PPW97-V1-M-EPEE-2026-2027'::TEXT, FALSE, 60.00::NUMERIC)$$,
  'CARRY.RS.01 while the current edition is IN_PROGRESS, its scored épée result stops the épée carry (no double count)');

SELECT results_eq(
  $$SELECT txt_tournament_code, bool_carried_over, num_final_score
      FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'FOIL', 'M', 'V1', (SELECT s2627 FROM rs))
     WHERE txt_tournament_code LIKE 'PPW97-%'$$,
  $$VALUES ('PPW97-V1-M-FOIL-2025-2026'::TEXT, TRUE, 40.00::NUMERIC)$$,
  'CARRY.RS.02 a weapon not yet fenced in the current edition keeps its carry (no empty slot)');

SELECT results_eq(
  $$SELECT txt_tournament_code, bool_carried_over
      FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'EPEE', 'M', 'V1', (SELECT s2627 FROM rs))
     WHERE txt_tournament_code LIKE 'PEW95%'$$,
  $$VALUES ('PEW95efs-V1-M-EPEE-2026-2027'::TEXT, FALSE)$$,
  'CARRY.RS.03 a linked international (PEW) carry stops the same way: the link decides, not the type');

-- ---------------------------------------------------------------- the rankings
SELECT is((SELECT total_score FROM fn_ranking_ppw_event_fk_matching('EPEE', 'M', 'V1', (SELECT s2627 FROM rs), TRUE)
            WHERE id_fencer = 98401), 60.00::NUMERIC,
  'CARRY.RS.04 the PPW ranking counts the current épée result once, without the carried one');

SELECT results_eq(
  $$SELECT spws_total, evf_plus_total, bool_has_carryover
      FROM fn_ranking_full_event_fk_matching('EPEE', 'M', 'V1', (SELECT s2627 FROM rs), TRUE) WHERE id_fencer = 98401$$,
  $$VALUES (60.00::NUMERIC, 90.00::NUMERIC, FALSE)$$,
  'CARRY.RS.05 the full ranking counts the current editions only: PPW 60, PEW 80 + PPS 10, no carry');

SELECT is((SELECT bool_has_carryover FROM fn_ranking_ppw_event_fk_matching('FOIL', 'M', 'V1', (SELECT s2627 FROM rs), TRUE)
            WHERE id_fencer = 98401), TRUE,
  'CARRY.RS.06 the foil ranking still carries the previous edition');

SELECT results_eq(
  $$SELECT spws_total, bool_has_carryover
      FROM fn_ranking_full_event_fk_matching('FOIL', 'M', 'V1', (SELECT s2627 FROM rs), TRUE) WHERE id_fencer = 98401$$,
  $$VALUES (40.00::NUMERIC, TRUE)$$,
  'CARRY.RS.07 Ranking mode (fn_ranking_full, the UI''s SPWS / EVF+ source) keeps the foil carry');

-- ---------------------------------------------------------------- what does not stop a carry, and what still does
SAVEPOINT unscored;
UPDATE tbl_result SET num_final_score = NULL
 WHERE id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW97-V1-M-EPEE-2026-2027');
SELECT results_eq(
  $$SELECT txt_tournament_code, bool_carried_over
      FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'EPEE', 'M', 'V1', (SELECT s2627 FROM rs))
     WHERE txt_tournament_code LIKE 'PPW97-%'$$,
  $$VALUES ('PPW97-V1-M-EPEE-2025-2026'::TEXT, TRUE)$$,
  'CARRY.RS.08 a current result without a score does not stop the carry');
ROLLBACK TO SAVEPOINT unscored;

SAVEPOINT women;
UPDATE tbl_tournament SET enum_gender = 'F' WHERE txt_code = 'PPW97-V1-M-EPEE-2026-2027';
SELECT is((SELECT count(*)::INT FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'EPEE', 'M', 'V1', (SELECT s2627 FROM rs))
            WHERE txt_tournament_code = 'PPW97-V1-M-EPEE-2025-2026'), 1,
  'CARRY.RS.09 a scored result of the other gender does not stop the men''s carry');
ROLLBACK TO SAVEPOINT women;

SAVEPOINT created;
UPDATE tbl_event SET enum_status = 'CREATED' WHERE txt_code = 'PPW97-2026-2027';
SELECT is((SELECT count(*)::INT FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'EPEE', 'M', 'V1', (SELECT s2627 FROM rs))
            WHERE txt_tournament_code = 'PPW97-V1-M-EPEE-2025-2026' AND bool_carried_over), 1,
  'CARRY.RS.11 results of a current edition that does not count (CREATED) do not stop the carry: no empty slot');
ROLLBACK TO SAVEPOINT created;

UPDATE tbl_event SET enum_status = 'COMPLETED' WHERE txt_code = 'PPW97-2026-2027';
SELECT is_empty(
  $$SELECT 1 FROM fn_fencer_scores_rolling_event_fk_matching(98401, 'FOIL', 'M', 'V1', (SELECT s2627 FROM rs))
     WHERE txt_tournament_code LIKE 'PPW97-%'$$,
  'CARRY.RS.10 a COMPLETED current edition still stops every carry, as before');

SELECT * FROM finish();
ROLLBACK;
