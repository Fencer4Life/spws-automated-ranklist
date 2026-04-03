-- =============================================================================
-- M10: Rolling Score Tests
-- =============================================================================
-- Tests R.1–R.12 from doc/MVP_development_plan.md §M10.
-- R.1-R.3:  fn_event_position helper
-- R.4-R.12: fn_ranking_ppw with p_rolling parameter
-- =============================================================================

BEGIN;
SELECT plan(18);

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
-- KORONA (117) has PPW1=27.33, PPW2=98.00, PPW3=69.72, PPW4=110.02 → best-4=305.07
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = 117),
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
  ) WHERE id_fencer = 117),
  305.07::NUMERIC,
  'R.6: p_rolling=TRUE, all completed — KORONA unchanged at 305.07'
);

-- Restore for subsequent tests
UPDATE tbl_event SET enum_status = 'SCHEDULED'
WHERE txt_code IN ('PPW5-2025-2026', 'MPW-2025-2026');
ALTER TABLE tbl_event ENABLE TRIGGER trg_event_transition;

-- R.7 — p_rolling=TRUE, partial: carry-over from 2024-25
-- ZIELIŃSKI (266): current PPW1=98.00 + PPW3=43.22, carried MPW=115.62
-- PPW5-prev not carried (ZIELIŃSKI not in PPW5-V2-M-EPEE-2024-2025)
-- Best-4 PPW: 98.00+43.22 = 141.22, MPW=115.62, Total=256.84
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 266),
  256.84::NUMERIC,
  'R.7: p_rolling=TRUE partial — ZIELIŃSKI 256.84 (current + carried MPW)'
);

-- R.8 — p_rolling=TRUE, best-K operates on merged pool
-- PARDUS (176): current PPW1=7.78 + PPW2=7.78 + PPW3=2.85
-- PPW5-prev not carried (PARDUS not in PPW5-V2-M-EPEE-2024-2025)
-- Best-4 PPW: 7.78+7.78+2.85 = 18.41, MPW carry: 1.20, Total: 19.61
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 176),
  19.61::NUMERIC,
  'R.8: p_rolling=TRUE best-K on merged pool — PARDUS 19.61'
);

-- R.9 — p_rolling=TRUE, category crossing V2→V3
-- TRACZ (236) born 1966: V2 in 2024-25 (age 59), V3 in 2025-26 (age 60)
-- Current V3: PPW1=25.09+PPW3=4.15, carried MPW-V2=7.18
-- Best-4 PPW: 25.09+4.15=29.24, MPW=7.18, Total=36.42
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V3',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 236),
  36.42::NUMERIC,
  'R.9: p_rolling=TRUE category crossing — TRACZ V2→V3 total 36.42'
);

-- R.10 — p_rolling=TRUE, new fencer → zero carryover
-- DROBIŃSKI (45) has no 2024-25 results → rolling adds nothing
-- Current: PPW1=12.08 + PPW2=65.67 + PPW3=23.43 + PPW4=23.39 = 124.57
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 45),
  124.57::NUMERIC,
  'R.10: p_rolling=TRUE new fencer — DROBIŃSKI same 124.57 (no carryover)'
);

-- R.11 — p_rolling=TRUE, no counterpart: PPW5 not declared → PPW5-prev not carried
-- Delete PPW5-2025-2026 → PPW5 position drops from declared set
-- ATANASSOW: current PPW1=65.67, PPW3=124.02, PPW4=79.18
-- best-4 = all 3 = 268.87, no MPW → total 268.87
DELETE FROM tbl_event WHERE txt_code = 'PPW5-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 5),
  268.87::NUMERIC,
  'R.11: p_rolling=TRUE no counterpart — PPW5 not declared, ATANASSOW 268.87'
);

-- Restore PPW5 for next test
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'PPW5-2025-2026', 'V Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED', '2026-05-10', 'Warszawa', 'Polska'
);

-- R.12 — p_rolling=TRUE, event deleted → carry-over resumes
-- Delete PPW4-2025-2026 (with its tournament + results) → PPW4 carry resumes
-- ATANASSOW: pool = {PPW3=124.02, PPW1=65.67} = 189.69 (no PPW5-prev, no MPW)
DELETE FROM tbl_result WHERE id_tournament IN (SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026'));
DELETE FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PPW4-2025-2026');
DELETE FROM tbl_event WHERE txt_code = 'PPW4-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 5),
  189.69::NUMERIC,
  'R.12: p_rolling=TRUE event deleted — PPW4 dropped, carry resumes, ATANASSOW 189.69'
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
    (117, 1, 'KORONA Przemysław'), (5, 2, 'ATANASSOW Aleksander'),
    (96, 3, 'JENDRYŚ Marek'), (46, 4, 'DUDEK Mariusz'),
    (247, 5, 'WASIOŁKA Sebastian'), (45, 6, 'DROBIŃSKI Leszek'),
    (86, 7, 'HAŚKO Sergiusz'), (250, 8, 'WIERZBICKI Jacek'),
    (235, 9, 'TOMCZAK Ireneusz'), (181, 10, 'PILUTKIEWICZ Igor'),
    (87, 11, 'HEŁKA Jacek')
) AS v(id_fencer, place, name);
SELECT fn_calc_tournament_scores(
    (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW4-V2-M-EPEE-2025-2026')
);

-- =========================================================================
-- R.13–R.14: fn_ranking_kadra with p_rolling
-- =========================================================================
-- Kadra combines domestic (PPW/MPW) + international (PEW/MEW/MSW) buckets.
-- Rolling adds carry-over from 2024-25 for positions declared but not
-- completed in 2025-26: PPW5, MPW (domestic) + IMEW (international).
-- PPW4 is COMPLETED in current season — no carry.
-- =========================================================================

-- R.13 — p_rolling=TRUE, domestic + international carry-over
-- KORONA (117): born 1976, V1 in 2024-25 → V2 in 2025-26 (category crossing)
-- Current PPW: 27.33+98.00+69.72+110.02=305.07, MPW-V1 carry: 32.53 → ppw_total=337.60
-- Current PEW: 138.87+38.02, IMSW=0.00 → IMEW-V1 carry: 119.38 (MEW type)
-- PEW/MEW/MSW best-3: 138.87+119.38+38.02=296.27 → pew_total=296.27
-- Total: 337.60+296.27=633.87
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 117),
  633.87::NUMERIC,
  'R.13: kadra p_rolling=TRUE — KORONA 633.87 (domestic + international carry-over)'
);

-- R.14 — p_rolling=FALSE regression — same as current non-rolling result
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = 117),
  481.96::NUMERIC,
  'R.14: kadra p_rolling=FALSE regression — KORONA 481.96'
);

-- =========================================================================
-- R.15–R.18: fn_fencer_scores_rolling
-- =========================================================================
-- Returns vw_score-like rows + bool_carried_over + txt_source_season_code.
-- ZIELIŃSKI (266): 3 current (PPW1, PPW3, IMSW) + 3 carried (PPW5, MPW, IMEW)
-- PPW4 is COMPLETED in current season — no carry for PPW4.
-- =========================================================================

-- R.15 — carried-over rows have bool_carried_over = TRUE
-- ZIELIŃSKI: carried MPW + IMEW from 2024-25 (no PPW5 — he wasn't in it)
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  2,
  'R.15: fn_fencer_scores_rolling — ZIELIŃSKI has 2 carried-over rows'
);

-- R.16 — current rows have bool_carried_over = FALSE
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = FALSE),
  3,
  'R.16: fn_fencer_scores_rolling — ZIELIŃSKI has 3 current rows'
);

-- R.17 — position match: PPW1-prev NOT in results (PPW1 COMPLETED in current season)
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE txt_tournament_code = 'PPW1-V2-M-EPEE-2024-2025'),
  0,
  'R.17: fn_fencer_scores_rolling — PPW1-prev excluded (position completed in current)'
);

-- R.18 — no counterpart: delete IMEW-2025-2026 → IMEW carry drops
DELETE FROM tbl_event WHERE txt_code = 'IMEW-2025-2026';

SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  1,
  'R.18: fn_fencer_scores_rolling — IMEW dropped (no counterpart), 1 carried remains (MPW)'
);

SELECT * FROM finish();
ROLLBACK;
