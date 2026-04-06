-- =============================================================================
-- M10: Rolling Score Tests
-- =============================================================================
-- Tests R.1–R.12 from doc/MVP_development_plan.md §M10.
-- R.1-R.3:  fn_event_position helper
-- R.4-R.12: fn_ranking_ppw with p_rolling parameter
-- =============================================================================

BEGIN;
SELECT plan(21);

-- =========================================================================
-- Helper: temp table for dynamic fencer ID lookups (immune to ID shifts)
-- =========================================================================
CREATE TEMP TABLE _fencer_ids AS
SELECT id_fencer, txt_surname FROM tbl_fencer WHERE txt_surname IN (
  'ATANASSOW','DROBIŃSKI','DUDEK','HAŚKO','HEŁKA','JENDRYŚ',
  'KORONA','PARDUS','PILUTKIEWICZ','TOMCZAK','TRACZ','WASIOŁKA',
  'WIERZBICKI','ZIELIŃSKI'
) AND txt_first_name IN (
  'Aleksander','Leszek','Mariusz','Sergiusz','Jacek','Marek',
  'Przemysław','Borys','Igor','Ireneusz','Jerzy','Sebastian',
  'Jacek','Dariusz'
);

-- =========================================================================
-- R.1–R.3: fn_event_position
-- =========================================================================

-- R.1 — fn_event_position extracts PPW1 from PPW1-2024-2025
SELECT is(
  fn_event_position('PPW1-2024-2025'),
  'PPW1',
  'R.1: fn_event_position extracts PPW1 from PPW1-2024-2025'
);

-- R.2 — fn_event_position extracts MPW from MPW-2024-2025
SELECT is(
  fn_event_position('MPW-2024-2025'),
  'MPW',
  'R.2: fn_event_position extracts MPW from MPW-2024-2025'
);

-- R.3 — fn_event_position extracts PEW1 from PEW1-2025-2026
SELECT is(
  fn_event_position('PEW1-2025-2026'),
  'PEW1',
  'R.3: fn_event_position extracts PEW1 from PEW1-2025-2026'
);

-- =========================================================================
-- R.4–R.12: fn_ranking_ppw with p_rolling
-- =========================================================================
-- Seed state: 2025-26 has PPW1-PPW4 COMPLETED, PPW5+MPW SCHEDULED.
-- 2024-25 has PPW1-PPW5+MPW all COMPLETED with results.
-- =========================================================================

-- R.4 — p_rolling=FALSE regression: same as current non-rolling result
-- KORONA has PPW1=27.33, PPW2=98.00, PPW3=69.72, PPW4=110.02 → best-4=305.07
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  305.07::NUMERIC,
  'R.4: p_rolling=FALSE regression — KORONA 305.07'
);

-- R.5 — p_rolling=TRUE, no previous season → same as non-rolling
-- 2023-2024 (id=1) is the earliest season — no predecessor to carry from
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    1,
    p_rolling := TRUE
  ) WHERE rank = 1),
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    1,
    p_rolling := FALSE
  ) WHERE rank = 1),
  'R.5: p_rolling=TRUE with no previous season — identical to FALSE'
);

-- R.6 — p_rolling=TRUE, all current completed → no carry-over
-- Disable transition trigger to allow direct status change in test
ALTER TABLE tbl_event DISABLE TRIGGER trg_event_transition;
UPDATE tbl_event SET enum_status = 'COMPLETED'
WHERE txt_code IN ('PPW5-2025-2026', 'MPW-2025-2026');

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  305.07::NUMERIC,
  'R.6: p_rolling=TRUE, all completed — KORONA unchanged at 305.07'
);

-- Restore for subsequent tests
UPDATE tbl_event SET enum_status = 'SCHEDULED'
WHERE txt_code IN ('PPW5-2025-2026', 'MPW-2025-2026');
ALTER TABLE tbl_event ENABLE TRIGGER trg_event_transition;

-- R.7 — p_rolling=TRUE, partial: carry-over from 2024-25
-- ZIELIŃSKI: current PPW1=98.00 + PPW3=43.22, carried MPW=115.62
-- PPW5-prev not carried (ZIELIŃSKI not in PPW5-V2-M-EPEE-2024-2025)
-- Best-4 PPW: 98.00+43.22 = 141.22, MPW=115.62, Total=256.84
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz')),
  256.84::NUMERIC,
  'R.7: p_rolling=TRUE partial — ZIELIŃSKI 256.84 (current + carried MPW)'
);

-- R.8 — p_rolling=TRUE, best-K operates on merged pool
-- PARDUS: current PPW1=7.78 + PPW2=7.78 + PPW3=2.85
-- PPW5-prev not carried (PARDUS not in PPW5-V2-M-EPEE-2024-2025)
-- Best-4 PPW: 7.78+7.78+2.85 = 18.41, MPW carry: 1.20, Total: 19.61
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PARDUS' AND txt_first_name = 'Borys')),
  19.61::NUMERIC,
  'R.8: p_rolling=TRUE best-K on merged pool — PARDUS 19.61'
);

-- R.9 — p_rolling=TRUE, category crossing V2→V3
-- TRACZ born 1966: V2 in 2024-25 (age 59), V3 in 2025-26 (age 60)
-- Current V3: PPW1=25.09+PPW3=4.15, carried MPW-V2=7.18
-- Best-4 PPW: 25.09+4.15=29.24, MPW=7.18, Total=36.42
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V3',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TRACZ' AND txt_first_name = 'Jerzy')),
  36.42::NUMERIC,
  'R.9: p_rolling=TRUE category crossing — TRACZ V2→V3 total 36.42'
);

-- R.10 — p_rolling=TRUE, carryover from PPW5-V2-M-EPEE-2024-2025
-- DROBIŃSKI has PPW5 result in 2024-25 (84.29) carried over to uncompleted PPW5 position
-- Current: PPW1=12.08 + PPW2=65.67 + PPW3=23.43 + PPW4=23.39 = 124.57
-- Carried: PPW5=84.29 → best-4 = 65.67+84.29+23.43+23.39 = 196.78
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DROBIŃSKI' AND txt_first_name = 'Leszek')),
  196.78::NUMERIC,
  'R.10: p_rolling=TRUE — DROBIŃSKI 196.78 with PPW5 carryover'
);

-- R.11 — p_rolling=TRUE, event deletion: PPW5 removed from current season
-- With rules-based carry-over (ADR-021), deleting the event does NOT block carry.
-- ATANASSOW has no PPW5-prev results, so no change: PPW1=65.67+PPW3=124.02+PPW4=79.18=268.87
DELETE FROM tbl_event WHERE txt_code = 'PPW5-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ATANASSOW' AND txt_first_name = 'Aleksander')),
  268.87::NUMERIC,
  'R.11: p_rolling=TRUE event deleted — ATANASSOW 268.87 (no PPW5-prev to carry)'
);

-- Restore PPW5 for next test
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'PPW5-2025-2026', 'V Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED', '2026-05-10', 'Warszawa', 'Polska'
);

-- R.12 — p_rolling=TRUE, event deleted → position carry-over resumes (ADR-021)
-- Delete PPW4-2025-2026 → PPW4 position no longer completed → PPW4-prev carries
-- ATANASSOW: current {PPW3=124.02, PPW1=65.67} + carried {PPW4-prev=98.00}
-- best-4: 124.02+98.00+65.67 = 287.69
DELETE FROM tbl_result WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'));
DELETE FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
DELETE FROM tbl_event WHERE txt_code = 'PPW4-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ATANASSOW' AND txt_first_name = 'Aleksander')),
  287.69::NUMERIC,
  'R.12: p_rolling=TRUE event deleted — PPW4-prev carries (ADR-021), ATANASSOW 287.69'
);

-- Restore PPW4 event + tournament + results for subsequent tests
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'PPW4-2025-2026', 'IV Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'COMPLETED', '2026-02-21', 'Gdańsk', 'Polska'
);
INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, url_results, enum_import_status)
VALUES (
    (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'),
    'PPW4-V2-M-EPEE-2025-2026', 'IV Puchar Polski Weteranów — Szpada M', 'PPW',
    'EPEE', 'M', 'V2', '2026-02-21', 11, NULL, 'SCORED'
);
INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
SELECT v.id_fencer, (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026'), v.place, v.name
FROM (VALUES
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław'), 1, 'KORONA Przemysław'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ATANASSOW' AND txt_first_name = 'Aleksander'), 2, 'ATANASSOW Aleksander'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'JENDRYŚ' AND txt_first_name = 'Marek'), 3, 'JENDRYŚ Marek'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DUDEK' AND txt_first_name = 'Mariusz'), 4, 'DUDEK Mariusz'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WASIOŁKA' AND txt_first_name = 'Sebastian'), 5, 'WASIOŁKA Sebastian'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DROBIŃSKI' AND txt_first_name = 'Leszek'), 6, 'DROBIŃSKI Leszek'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HAŚKO' AND txt_first_name = 'Sergiusz'), 7, 'HAŚKO Sergiusz'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WIERZBICKI' AND txt_first_name = 'Jacek'), 8, 'WIERZBICKI Jacek'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TOMCZAK' AND txt_first_name = 'Ireneusz'), 9, 'TOMCZAK Ireneusz'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PILUTKIEWICZ' AND txt_first_name = 'Igor'), 10, 'PILUTKIEWICZ Igor'),
    ((SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'HEŁKA' AND txt_first_name = 'Jacek'), 11, 'HEŁKA Jacek')
) AS v(id_fencer, place, name);
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026')
);

-- =========================================================================
-- R.13–R.14: fn_ranking_kadra with p_rolling
-- =========================================================================
-- Kadra combines domestic (PPW/MPW) + international (PEW/MEW/MSW) buckets.
-- Rolling: carry-over from 2024-25 for types in ranking rules whose
-- positions are NOT completed (ADR-021). IMEW (MEW) carries because
-- MEW is in international rules and no IMEW event exists in 2025-26
-- (biennial). PPW4 is COMPLETED — no carry.
-- =========================================================================

-- R.13 — p_rolling=TRUE, domestic + international carry-over (ADR-021)
-- KORONA: born 1976, V1 in 2024-25 → V2 in 2025-26 (category crossing)
-- Current PPW: 27.33+98.00+69.72+110.02=305.07, carried MPW-V1=32.53 → ppw_total=337.60
-- Current PEW: 143.16+138.87+86.03+71.95+71.33+38.02
-- Carried IMEW-V1=119.38 (MEW in rules, IMEW position not completed — biennial, ADR-021)
-- PEW/MEW/MSW best-3: 143.16+138.87+119.38=401.41 → pew_total=401.41
-- Total: 337.60+401.41=739.01
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  686.17::NUMERIC,
  'R.13: kadra p_rolling=TRUE — KORONA 686.17 (domestic + international + IMEW carry-over)'
);

-- R.14 — p_rolling=FALSE regression — no carry-over, no IMEW in current season
-- PPW best-4=305.07, no MPW �� ppw_total=305.07
-- PEW/MEW/MSW best-3: 143.16+138.87+86.03=368.06 → pew_total=368.06
-- Total: 305.07+368.06=673.13
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  606.21::NUMERIC,
  'R.14: kadra p_rolling=FALSE regression — KORONA 606.21 (no IMEW this season)'
);

-- =========================================================================
-- R.15–R.18: fn_fencer_scores_rolling
-- =========================================================================
-- Returns vw_score-like rows + bool_carried_over + txt_source_season_code.
-- ZIELIŃSKI: 2 current (PPW1, PPW3) + 2 carried (MPW, IMEW from 2024-25).
-- IMEW carries because MEW is in ranking rules (ADR-021), no IMEW event
-- in 2025-26 (biennial — happened in 2024-25, not this year).
-- PPW4 is COMPLETED in current season — no carry for PPW4.
-- =========================================================================

-- R.15 — carried-over rows have bool_carried_over = TRUE
-- ZIELIŃSKI: carried MPW + IMEW from 2024-25 (ADR-021 rules-based carry-over)
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  2,
  'R.15: fn_fencer_scores_rolling — ZIELIŃSKI has 2 carried-over rows (MPW + IMEW)'
);

-- R.16 — current rows have bool_carried_over = FALSE
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = FALSE),
  2,
  'R.16: fn_fencer_scores_rolling — ZIELIŃSKI has 2 current rows (PPW1 + PPW3)'
);

-- R.17 — position match: PPW1-prev NOT in results (PPW1 COMPLETED in current season)
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE txt_tournament_code = 'PPW1-V2-M-EPEE-2024-2025'),
  0,
  'R.17: fn_fencer_scores_rolling — PPW1-prev excluded (position completed in current)'
);

-- R.18 — COMPLETED event blocks carry-over for that position (ADR-021)
-- Add a COMPLETED IMEW event → IMEW position becomes completed → IMEW-prev stops carrying
ALTER TABLE tbl_event DISABLE TRIGGER trg_event_transition;
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'IMEW-2025-2026', 'IMEW (test placeholder)',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
    'COMPLETED', '2026-06-01', 'Test', 'Test'
);
ALTER TABLE tbl_event ENABLE TRIGGER trg_event_transition;

SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  1,
  'R.18: COMPLETED IMEW blocks carry — only MPW remains carried'
);

-- Clean up: remove test IMEW event
DELETE FROM tbl_event WHERE txt_code = 'IMEW-2025-2026';

-- =========================================================================
-- R.19–R.21: IMEW biennial carry-over (ADR-021, FR-68)
-- =========================================================================
-- IMEW is biennial: happened in 2024-25, NOT in 2025-26 (DMEW/team instead).
-- Rules-based carry-over: MEW is in json_ranking_rules->international,
-- so IMEW from 2024-25 automatically carries without needing an event.
-- =========================================================================

-- R.19 — IMEW from 2024-25 carries with correct source season
SELECT is(
  (SELECT txt_source_season_code FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  'SPWS-2024-2025',
  'R.19: IMEW carried from 2024-25 — source season is SPWS-2024-2025 (biennial)'
);

-- R.20 — IMEW carried score matches exact 2024-25 value
SELECT is(
  (SELECT num_final_score FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  85.59::NUMERIC,
  'R.20: IMEW carried score = 85.59 (exact 2024-25 value for ZIELIŃSKI V2 M EPEE)'
);

-- R.21 — removing MEW from ranking rules stops IMEW carry-over
-- Temporarily update json_ranking_rules to exclude MEW from international bucket
UPDATE tbl_scoring_config SET json_ranking_rules = jsonb_set(
  json_ranking_rules,
  '{international,2,types}',
  '["PEW", "MSW"]'::JSONB
) WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026');

SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz'),
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  0,
  'R.21: MEW removed from rules — IMEW no longer carries (ADR-021 rules-based)'
);

-- Restore original rules (ROLLBACK handles this, but be explicit)
UPDATE tbl_scoring_config SET json_ranking_rules = jsonb_set(
  json_ranking_rules,
  '{international,2,types}',
  '["PEW", "MEW", "MSW"]'::JSONB
) WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026');

SELECT * FROM finish();
ROLLBACK;
