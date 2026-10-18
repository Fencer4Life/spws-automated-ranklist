-- =============================================================================
-- RANK.TIE — equal totals share a place; the next place skips (ADR-115)
-- =============================================================================
-- Every ranking function numbered its rows with ROW_NUMBER() OVER (ORDER BY
-- total DESC), so two fencers on exactly the same total took consecutive places
-- in an order nothing fixed. The rule (decided by the user on 2026-10-18): a
-- fencer's place is one more than the number of fencers with a higher total —
-- two on equal points are both 16th, there is no 17th, the next fencer is 18th.
-- Fencers sharing a place are listed alphabetically (Q1 A), and the FTL seed
-- files keep that ranking order for them in both generators.
-- Plan: doc/plans/equal-totals-shared-place-2026-10-18.html.
--
-- The fixture totals (9000+) sit far above any real total, so the fixture
-- fencers take the top places of their sub-ranking whatever the seed holds.
-- Inside each tie the alphabetical order differs from the id order the old
-- functions happened to return (checked: all twelve tests failed before the
-- change), so an order that merely followed ids or insertion fails RANK.TIE.05.
-- Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(12);

CREATE TEMP TABLE tie AS
SELECT (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026') AS s2526,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027') AS s2627,
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS') AS spws;

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status)
SELECT v.c, 'RANK.TIE fixture', CASE v.w WHEN '2526' THEN tie.s2526 ELSE tie.s2627 END, tie.spws, v.d, v.d, 'COMPLETED'
  FROM tie, (VALUES ('PPW96-2025-2026', '2526', DATE '2026-03-14'),
                    ('PPW96-2026-2027', '2627', DATE '2026-10-10')) v(c, w, d);

INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category,
                            dt_tournament, int_participant_count)
SELECT e.id_event, v.tc, 'PPW', v.w::enum_weapon_type, 'M', 'V1', e.dt_start, 10
  FROM (VALUES ('PPW96-2025-2026', 'PPW96-V1-M-SABRE-2025-2026', 'SABRE'),
               ('PPW96-2026-2027', 'PPW96-V1-M-SABRE-2026-2027', 'SABRE'),
               ('PPW96-2026-2027', 'PPW96-V1-M-FOIL-2026-2027', 'FOIL')) v(ec, tc, w)
  JOIN tbl_event e ON e.txt_code = v.ec;

-- Born 1984: V1 in 2025/26 and in 2026/27.
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, txt_nationality, int_birth_year, enum_gender)
VALUES (98501, 'TIEONE',  'Test', 'PL', 1984, 'M'),
       (98502, 'TIEZULU', 'Test', 'PL', 1984, 'M'),
       (98503, 'TIEALFA', 'Test', 'PL', 1984, 'M'),
       (98504, 'TIEFOUR', 'Test', 'PL', 1984, 'M'),
       (98505, 'TRIOA',   'Test', 'PL', 1984, 'M'),
       (98506, 'TRIOB',   'Test', 'PL', 1984, 'M'),
       (98507, 'TRIOC',   'Test', 'PL', 1984, 'M'),
       (98508, 'TRIOD',   'Test', 'PL', 1984, 'M'),
       (98509, 'TRIOE',   'Test', 'PL', 1984, 'M');

-- Sabre: 9040, 9035, 9035, 9020 in both seasons. Foil 2026/27: 9003, 9001 × 3, 9000.50.
INSERT INTO tbl_result (id_tournament, id_fencer, int_place, enum_fencer_age_category,
                        enum_source_age_category, num_final_score)
SELECT t.id_tournament, v.f, v.p, 'V1', 'V1', v.s
  FROM (VALUES ('PPW96-V1-M-SABRE-2025-2026', 98501, 1, 9040.00), ('PPW96-V1-M-SABRE-2025-2026', 98502, 2, 9035.00),
               ('PPW96-V1-M-SABRE-2025-2026', 98503, 3, 9035.00), ('PPW96-V1-M-SABRE-2025-2026', 98504, 4, 9020.00),
               ('PPW96-V1-M-SABRE-2026-2027', 98501, 1, 9040.00), ('PPW96-V1-M-SABRE-2026-2027', 98502, 2, 9035.00),
               ('PPW96-V1-M-SABRE-2026-2027', 98503, 3, 9035.00), ('PPW96-V1-M-SABRE-2026-2027', 98504, 4, 9020.00),
               ('PPW96-V1-M-FOIL-2026-2027', 98505, 1, 9003.00), ('PPW96-V1-M-FOIL-2026-2027', 98506, 4, 9001.00),
               ('PPW96-V1-M-FOIL-2026-2027', 98507, 3, 9001.00), ('PPW96-V1-M-FOIL-2026-2027', 98508, 2, 9001.00),
               ('PPW96-V1-M-FOIL-2026-2027', 98509, 5, 9000.50)) v(tc, f, p, s)
  JOIN tbl_tournament t ON t.txt_code = v.tc;

-- ---------------------------------------------------------------- the shared place
SELECT results_eq(
  $$SELECT rank FROM fn_ranking_ppw_event_fk_matching('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer BETWEEN 98501 AND 98504 ORDER BY rank, id_fencer$$,
  $$VALUES (1), (2), (2), (4)$$,
  'RANK.TIE.01 PPW: 9040, 9035, 9035, 9020 are placed 1, 2, 2, 4');

SELECT results_eq(
  $$SELECT rank FROM fn_ranking_full_event_fk_matching('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer BETWEEN 98501 AND 98504 ORDER BY rank, id_fencer$$,
  $$VALUES (1), (2), (2), (4)$$,
  'RANK.TIE.02a Ranking (fn_ranking_full): the same totals are placed 1, 2, 2, 4');

SELECT results_eq(
  $$SELECT rank FROM fn_ranking_kadra_event_fk_matching('SABRE', 'M', 'V1', (SELECT s2526 FROM tie), FALSE)
     WHERE id_fencer BETWEEN 98501 AND 98504 ORDER BY rank, id_fencer$$,
  $$VALUES (1), (2), (2), (4)$$,
  'RANK.TIE.02b Kadra, the parity oracle: the same totals are placed 1, 2, 2, 4');

SELECT results_eq(
  $$SELECT 'ppw' AS f, rank FROM fn_ranking_ppw('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    UNION ALL
    SELECT 'full', rank FROM fn_ranking_full('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    UNION ALL
    SELECT 'kadra', rank FROM fn_ranking_kadra('SABRE', 'M', 'V1', (SELECT s2526 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    ORDER BY 1, 2$$,
  $$VALUES ('full', 1), ('full', 2), ('full', 2), ('full', 4),
           ('kadra', 1), ('kadra', 2), ('kadra', 2), ('kadra', 4),
           ('ppw', 1), ('ppw', 2), ('ppw', 2), ('ppw', 4)$$,
  'RANK.TIE.02c the dispatchers the site calls return the shared places');

SELECT results_eq(
  $$SELECT rank FROM fn_ranking_ppw_event_fk_matching('FOIL', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer BETWEEN 98505 AND 98509 ORDER BY rank, id_fencer$$,
  $$VALUES (1), (2), (2), (2), (5)$$,
  'RANK.TIE.03 a three-way tie: 9003, 9001 × 3, 9000.50 are placed 1, 2, 2, 2, 5');

SELECT results_eq(
  $$SELECT 'full_code' AS f, rank FROM fn_ranking_full_event_code_matching('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    UNION ALL
    SELECT 'kadra_code', rank FROM fn_ranking_kadra_event_code_matching('SABRE', 'M', 'V1', (SELECT s2526 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    UNION ALL
    SELECT 'ppw_code', rank FROM fn_ranking_ppw_event_code_matching('SABRE', 'M', 'V1', (SELECT s2526 FROM tie), FALSE) WHERE id_fencer BETWEEN 98501 AND 98504
    ORDER BY 1, 2$$,
  $$VALUES ('full_code', 1), ('full_code', 2), ('full_code', 2), ('full_code', 4),
           ('kadra_code', 1), ('kadra_code', 2), ('kadra_code', 2), ('kadra_code', 4),
           ('ppw_code', 1), ('ppw_code', 2), ('ppw_code', 2), ('ppw_code', 4)$$,
  'RANK.TIE.04 the event-code variants share places the same way');

-- ---------------------------------------------------------------- the order inside a shared place
SELECT results_eq(
  $$SELECT fencer_name FROM fn_ranking_ppw('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer IN (98502, 98503)$$,
  $$VALUES ('TIEALFA Test'::TEXT), ('TIEZULU Test')$$,
  'RANK.TIE.05a PPW lists fencers sharing a place alphabetically');

SELECT results_eq(
  $$SELECT fencer_name FROM fn_ranking_full('SABRE', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer IN (98502, 98503)$$,
  $$VALUES ('TIEALFA Test'::TEXT), ('TIEZULU Test')$$,
  'RANK.TIE.05b Ranking lists fencers sharing a place alphabetically');

SELECT results_eq(
  $$SELECT fencer_name FROM fn_ranking_ppw('FOIL', 'M', 'V1', (SELECT s2627 FROM tie), FALSE)
     WHERE id_fencer IN (98506, 98507, 98508)$$,
  $$VALUES ('TRIOB Test'::TEXT), ('TRIOC Test'), ('TRIOD Test')$$,
  'RANK.TIE.05c a three-way tie is listed alphabetically');

-- ---------------------------------------------------------------- the definition, on the seed's own lists
SELECT is(
  (WITH combos AS (
     SELECT w::enum_weapon_type AS w, g::enum_gender_type AS g, c::enum_age_category AS c
       FROM unnest(ARRAY['EPEE', 'FOIL', 'SABRE']) w, unnest(ARRAY['M', 'F']) g,
            unnest(ARRAY['V0', 'V1', 'V2', 'V3', 'V4']) c
   ), r AS (
     SELECT x.w, x.g, x.c, p.rank, p.total_score
       FROM combos x CROSS JOIN LATERAL fn_ranking_ppw(x.w, x.g, x.c, (SELECT s2526 FROM tie), FALSE) p
   )
   SELECT count(*)::INT FROM r a
    WHERE a.rank <> 1 + (SELECT count(*) FROM r b
                          WHERE b.w = a.w AND b.g = a.g AND b.c = a.c AND b.total_score > a.total_score)),
  0,
  'RANK.TIE.06 every place is one more than the number of higher totals (2025/26, all 30 PPW lists): a list without ties keeps 1..n');

-- ---------------------------------------------------------------- the FTL seed export (ADR-080)
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_ev     INT;
  v_t      INT;
BEGIN
  -- A finished synthetic season, as in test 76: the export reads its own results.
  v_season := fn_create_season('TIES111', '2019-09-01', '2020-06-30');
  UPDATE tbl_season SET enum_carryover_engine = 'EVENT_CODE_MATCHING' WHERE id_season = v_season;
  INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('TIESORG111', 'Ties org 111') RETURNING id_organizer INTO v_org;
  v_ev := fn_create_event('TIES111EVT', 'Ties 111', v_season, v_org, NULL, '2019-10-05', '2019-10-05');
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category,
                              enum_import_status, num_multiplier, int_participant_count)
    VALUES (v_ev, 'TIES111T', 'Ties 111 tournament', 'PPW', 'EPEE', 'M', 'V2', 'SCORED', 1.0, 8)
    RETURNING id_tournament INTO v_t;
  -- Born 1965: V2 in a season ending in 2020. ZULU and ALFA tie on 90.
  INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender, bool_birth_year_estimated)
    VALUES (98511, 'TIE7TOP', 'Test', 1965, 'M', FALSE),
           (98512, 'TIE7ZULU', 'Test', 1965, 'M', FALSE),
           (98513, 'TIE7ALFA', 'Test', 1965, 'M', FALSE);
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, enum_fencer_age_category, enum_source_age_category, num_final_score)
    VALUES (98511, v_t, 1, 'V2', 'V2', 100.0), (98512, v_t, 2, 'V2', 'V2', 90.0), (98513, v_t, 3, 'V2', 'V2', 90.0);
  -- ZULU registers first: an order by registration time would put him ahead of ALFA.
  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name, enum_gender, int_birth_year, arr_weapons, ts_created)
    VALUES (v_ev, 98512, 'TIE7ZULU', 'Test', 'M', 1965, ARRAY['EPEE']::enum_weapon_type[], '2019-10-01T00:00:00Z'),
           (v_ev, 98513, 'TIE7ALFA', 'Test', 'M', 1965, ARRAY['EPEE']::enum_weapon_type[], '2019-10-02T00:00:00Z'),
           (v_ev, 98511, 'TIE7TOP',  'Test', 'M', 1965, ARRAY['EPEE']::enum_weapon_type[], '2019-10-03T00:00:00Z');
  INSERT INTO tbl_ftl_export_token (uuid_token, txt_label) VALUES ('11100000-0000-4000-8000-000000000001', 'pgTAP 111');
END
$setup$;

SELECT results_eq(
  $$SELECT txt_surname, int_rank FROM fn_ftl_export_entries(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'TIES111EVT'), '11100000-0000-4000-8000-000000000001')
     ORDER BY int_order$$,
  $$VALUES ('TIE7TOP'::TEXT, 1), ('TIE7ALFA', 2), ('TIE7ZULU', 2)$$,
  'RANK.TIE.07a the seed export gives tied fencers the same tier (no tier 3)');

SELECT is(
  (SELECT string_agg(txt_surname, ',' ORDER BY int_order) FROM fn_ftl_export_entries(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'TIES111EVT'), '11100000-0000-4000-8000-000000000001')
    WHERE int_rank = 2),
  'TIE7ALFA,TIE7ZULU',
  'RANK.TIE.07b inside a shared tier the seed export keeps the ranking''s order, not registration time');

SELECT * FROM finish();
ROLLBACK;
