-- =============================================================================
-- M10: Rolling Score Tests
-- =============================================================================
-- Tests R.1–R.12 from doc/archive/MVP_development_plan.md §M10.
-- R.1-R.3:  fn_event_position helper
-- R.4-R.12: fn_ranking_ppw with p_rolling parameter
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
SELECT plan(21);

-- =========================================================================
-- Self-contained carry-over fixture (test-only; reverted by ROLLBACK).
--
-- The carried IMEW tournaments that R.13 (KORONA kadra) and R.20 (ZIELIŃSKI
-- exact IMEW score) depend on are CALIBRATED against the full 2024-25 IMEW
-- field, but seed_prod_latest.sql ships an incomplete snapshot of them
-- (only a few result rows, with int_participant_count truncated to that
-- handful: V2=3, V1=4). With a truncated count, fn_calc_tournament_scores
-- sees int_place > int_participant_count and yields 0 — so on a fresh seed
-- (CI) the carried IMEW score is 0 and R.13 lands at 733.50, R.20 at 0.00.
--
-- fn_ranking_ppw/_kadra recompute current-season scores on the fly, but the
-- carry-over path (R.13) and the direct num_final_score read (R.20) consume
-- the STORED column. So we (1) restore the real participant_count for the two
-- carried IMEW tournaments, then (2) recompute every SCORED tournament, making
-- both assertions deterministic regardless of the seed's snapshot.
-- Verified: counts 110/68 → R.13=739.46, R.20=85.59; counts 3/4 → 733.50/0.00.
UPDATE tbl_tournament SET int_participant_count = 110 WHERE txt_code = 'IMEW-V2-M-EPEE-2024-2025';
UPDATE tbl_tournament SET int_participant_count = 68  WHERE txt_code = 'IMEW-V1-M-EPEE-2024-2025';

DO $recompute_scores$
DECLARE t RECORD;
BEGIN
  FOR t IN SELECT id_tournament FROM tbl_tournament WHERE enum_import_status = 'SCORED' LOOP
    PERFORM fn_calc_tournament_scores(t.id_tournament);
  END LOOP;
END;
$recompute_scores$;

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
-- Recalibrated 2026-06-25 after the 2026-06-19 PROD export (PPW3 promotion)
-- corrected domestic EPEE participant counts (PPW3-V2-M-EPEE-2024-2025 10→11,
-- PPW3-V2-M-EPEE-2025-2026 20→19, PPW1-V2-M-EPEE-2024-2025 10→11) → slightly
-- lower place points. KORONA EPEE V2 M best-4 total 357.37 → 356.92.
-- (Prior 2026-06-03 calibration removed the PPW4/PPW5 joint-pool over-count.)
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  356.92::NUMERIC,
  'R.4: p_rolling=FALSE regression — KORONA 356.92'
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
  356.92::NUMERIC,
  'R.6: p_rolling=TRUE, all completed — KORONA unchanged at 356.92'
);

-- Restore for subsequent tests
UPDATE tbl_event SET enum_status = 'SCHEDULED'
WHERE txt_code IN ('PPW5-2025-2026', 'MPW-2025-2026');
ALTER TABLE tbl_event ENABLE TRIGGER trg_event_transition;

-- R.7 — p_rolling=TRUE, partial: carry-over from 2024-25
-- ZIELIŃSKI total rolling. Recalibrated 2026-06-25 after the 06-19 PPW3-promote
-- participant-count corrections: 257.30 → 256.84.
-- (Active-season PPW5 + MPW status set to SCHEDULED at R.5 setup; ZIELIŃSKI
-- current PPW1 + PPW3 + carried positions.)
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'ZIELIŃSKI' AND txt_first_name = 'Dariusz')),
  256.84::NUMERIC,
  'R.7: p_rolling=TRUE partial — ZIELIŃSKI 256.84 (current + carried MPW)'
);

-- R.8 — p_rolling=TRUE, best-K operates on merged pool.
-- PARDUS total rolling. Recalibrated 2026-06-25 after the 06-19 PPW3-promote
-- participant-count corrections: 39.07 → 22.56. Larger swing than the KORONA
-- cases because PARDUS has few qualifying V2 events, so a ±1 count change is a
-- big fraction and shifts which events make the best-K cut.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'PARDUS' AND txt_first_name = 'Borys')),
  22.56::NUMERIC,
  'R.8: p_rolling=TRUE best-K on merged pool — PARDUS 22.56'
);

-- R.9 — p_rolling=TRUE, category crossing V2→V3.
-- TRACZ born 1966: V2 in 2024-25, V3 in 2025-26. Recalibrated 2026-06-25 after
-- the 06-19 PPW3-promote participant-count corrections (incl. V3 counts
-- PPW3-V3-M-EPEE-2025-2026 9→8, PPW4-V3-M-EPEE-2024-2025 9→10): 48.87 → 36.42.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V3',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'TRACZ' AND txt_first_name = 'Jerzy')),
  36.42::NUMERIC,
  'R.9: p_rolling=TRUE category crossing — TRACZ V2→V3 total 36.42'
);

-- R.10 — p_rolling=TRUE.
-- DROBIŃSKI total rolling. Recalibrated 2026-06-25 after the 06-19 PPW3-promote
-- participant-count corrections: 197.41 → 196.78.
-- (PPW5 has results in new seed even with status=SCHEDULED; engine picks
-- them up so the carry-over-from-prior-PPW5 path doesn't fire here.)
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'DROBIŃSKI' AND txt_first_name = 'Leszek')),
  196.78::NUMERIC,
  'R.10: p_rolling=TRUE — DROBIŃSKI 196.78'
);

-- R.11 — p_rolling=TRUE, event deletion: PPW5 removed from current season.
-- Recalibrated 2026-06-25 after the 06-19 PPW3-promote participant-count
-- corrections: ATANASSOW total after PPW5 wipe 269.28 → 268.87.
DELETE FROM tbl_match_candidate WHERE id_result IN (SELECT id_result FROM tbl_result WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2025-2026')));
DELETE FROM tbl_result WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2025-2026'));
DELETE FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW5-2025-2026');
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

-- R.12 — p_rolling=TRUE, event deleted → position carry-over resumes (ADR-021).
-- Delete PPW4-2025-2026 → PPW4 position no longer completed → PPW4-prev carries.
-- Recalibrated 2026-06-25 after the 06-19 PPW3-promote participant-count
-- corrections: ATANASSOW total after PPW4 wipe 288.10 → 287.69.
DELETE FROM tbl_match_candidate WHERE id_result IN (SELECT id_result FROM tbl_result WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026')));
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

-- R.13 — p_rolling=TRUE, domestic + international carry-over (ADR-021).
-- Re-derived AT THIS TEST'S MID-TRANSACTION STATE: R.11/R.12 have
-- deleted-and-partially-restored PPW4 (one M-EPEE tournament with 4 fencers)
-- and PPW5 (event-only placeholder, no tournaments). Recalibrated 2026-06-25
-- after the 06-19 PPW3-promote participant-count corrections: 739.46 → 739.01.
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  739.01::NUMERIC,
  'R.13: kadra p_rolling=TRUE — KORONA 739.01 (domestic + international + IMEW carry-over)'
);

-- R.14 — p_rolling=FALSE regression — no carry-over, no IMEW in current season.
-- Re-derived against the same mid-transaction state. Recalibrated 2026-06-25
-- after the 06-19 PPW3-promote participant-count corrections: 686.51 → 686.06.
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KORONA' AND txt_first_name = 'Przemysław')),
  686.06::NUMERIC,
  'R.14: kadra p_rolling=FALSE regression — KORONA 686.06'
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
  3,
  'R.15: fn_fencer_scores_rolling — ZIELIŃSKI has 3 carried-over rows (MPW + IMEW + PEW14e; epee circuit position not completed in current per ADR-046 per-weapon split)'
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
  2,
  'R.18: COMPLETED IMEW blocks carry — MPW + PEW14e remain (post-Phase4: epee PEW14 position not completed in current season)'
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
