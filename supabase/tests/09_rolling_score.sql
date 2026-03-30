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

-- R.1 — fn_event_position extracts PP1 from PP1-2024-2025
SELECT is(
  fn_event_position('PP1-2024-2025'),
  'PP1',
  'R.1: fn_event_position extracts PP1 from PP1-2024-2025'
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
-- Seed state: 2025-26 has PP1-PP3 COMPLETED, PP4+PP5+MPW SCHEDULED.
-- 2024-25 has PP1-PP5+MPW all COMPLETED with results.
-- =========================================================================

-- R.4 — p_rolling=FALSE regression: same as current non-rolling result
-- KORONA (117) is rank 1 at 195.05 in 2025-26 non-rolling
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = 117),
  195.05::NUMERIC,
  'R.4: p_rolling=FALSE regression — KORONA 195.05'
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
WHERE txt_code IN ('PP4-2025-2026', 'PP5-2025-2026', 'MPW-2025-2026');

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 117),
  195.05::NUMERIC,
  'R.6: p_rolling=TRUE, all completed — KORONA unchanged at 195.05'
);

-- Restore for subsequent tests
UPDATE tbl_event SET enum_status = 'SCHEDULED'
WHERE txt_code IN ('PP4-2025-2026', 'PP5-2025-2026', 'MPW-2025-2026');
ALTER TABLE tbl_event ENABLE TRIGGER trg_event_transition;

-- R.7 — p_rolling=TRUE, partial: carry-over from 2024-25
-- ZIELIŃSKI (266): current PP1=98.00 + PP3=43.22, carried PP4=65.67 + PP5=61.95 + MPW=115.62
-- Best-4 PPW: 98.00+65.67+61.95+43.22 = 268.84, MPW=115.62, Total=384.46
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 266),
  384.46::NUMERIC,
  'R.7: p_rolling=TRUE partial — ZIELIŃSKI 384.46 (current + carried PPW + MPW)'
);

-- R.8 — p_rolling=TRUE, best-K operates on merged pool
-- PARDUS (176): current PP1=7.78 + PP2=7.78 + PP3=2.85, carried PP4=27.33 + PP5=22.09
-- 5 PPW scores, best-4: 27.33+22.09+7.78+7.78 = 64.98 (drops PP3=2.85)
-- MPW carry: 1.20, Total: 66.18
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 176),
  66.18::NUMERIC,
  'R.8: p_rolling=TRUE best-K on merged pool — PARDUS 66.18 (drops lowest of 5)'
);

-- R.9 — p_rolling=TRUE, category crossing V2→V3
-- TRACZ (236) born 1966: V2 in 2024-25 (age 59), V3 in 2025-26 (age 60)
-- With rolling on V3: carried PP4=1.00 + MPW=7.18, Total=8.18
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V3',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 236),
  8.18::NUMERIC,
  'R.9: p_rolling=TRUE category crossing — TRACZ V2→V3 total 8.18'
);

-- R.10 — p_rolling=TRUE, new fencer → zero carryover
-- DROBIŃSKI (45) has no 2024-25 results at all → rolling adds nothing
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 45),
  101.18::NUMERIC,
  'R.10: p_rolling=TRUE new fencer — DROBIŃSKI same 101.18 (no carryover)'
);

-- R.11 — p_rolling=TRUE, no counterpart: PP5 not declared → PP5-prev not carried
-- Delete PP5-2025-2026 → PP5 position drops from declared set
-- ATANASSOW: without PP5 carry (96.35), pool = {PP3=124.02, PP1=65.67, PP4=40.11}
-- best-4 = all 3 = 229.80, no MPW → total 229.80
DELETE FROM tbl_event WHERE txt_code = 'PP5-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 5),
  229.80::NUMERIC,
  'R.11: p_rolling=TRUE no counterpart — PP5 not declared, ATANASSOW 229.80'
);

-- Restore PP5 for next test
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'PP5-2025-2026', 'V Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED', '2026-05-10', 'Warszawa', 'Polska'
);

-- R.12 — p_rolling=TRUE, event deleted → carry-over drops
-- Delete PP4-2025-2026 → PP4 carry drops
-- ATANASSOW: pool = {PP3=124.02, PP5=96.35, PP1=65.67} = 286.04, no MPW → 286.04
DELETE FROM tbl_event WHERE txt_code = 'PP4-2025-2026';

SELECT is(
  (SELECT total_score FROM fn_ranking_ppw(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 5),
  286.04::NUMERIC,
  'R.12: p_rolling=TRUE event deleted — PP4 dropped, ATANASSOW 286.04'
);

-- Restore PP4 for subsequent tests
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_location, txt_country)
VALUES (
    'PP4-2025-2026', 'IV Puchar Polski Weteranów',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'),
    'SCHEDULED', '2026-03-15', 'Gdańsk', 'Polska'
);

-- =========================================================================
-- R.13–R.14: fn_ranking_kadra with p_rolling
-- =========================================================================
-- Kadra combines domestic (PPW/MPW) + international (PEW/MEW/MSW) buckets.
-- Rolling adds carry-over from 2024-25 for positions declared but not
-- completed in 2025-26: PP4, PP5, MPW (domestic) + IMEW (international).
-- =========================================================================

-- R.13 — p_rolling=TRUE, domestic + international carry-over
-- KORONA (117): born 1976, V1 in 2024-25 → V2 in 2025-26 (category crossing)
-- Current PPW: 98.00+69.72+27.33=195.05, PP4-V1 carry: 12.08
-- Best-4 PPW: 98.00+69.72+27.33+12.08=207.13, MPW-V1 carry: 32.53 → ppw_total=239.66
-- Current PEW: 138.87+38.02, IMSW=0.00 → IMEW-V1 carry: 119.38 (MEW type)
-- PEW/MEW/MSW best-3: 138.87+119.38+38.02=296.27 → pew_total=296.27
-- Total: 239.66+296.27=535.93
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := TRUE
  ) WHERE id_fencer = 117),
  535.93::NUMERIC,
  'R.13: kadra p_rolling=TRUE — KORONA 535.93 (domestic + international carry-over)'
);

-- R.14 — p_rolling=FALSE regression — same as current non-rolling result
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra(
    'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'),
    p_rolling := FALSE
  ) WHERE id_fencer = 117),
  371.94::NUMERIC,
  'R.14: kadra p_rolling=FALSE regression — KORONA 371.94'
);

-- =========================================================================
-- R.15–R.18: fn_fencer_scores_rolling
-- =========================================================================
-- Returns vw_score-like rows + bool_carried_over + txt_source_season_code.
-- ZIELIŃSKI (266): 3 current (PP1, PP3, IMSW) + 4 carried (PP4, PP5, MPW, IMEW)
-- =========================================================================

-- R.15 — carried-over rows have bool_carried_over = TRUE
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  4,
  'R.15: fn_fencer_scores_rolling — ZIELIŃSKI has 4 carried-over rows'
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

-- R.17 — position match: PP1-prev NOT in results (PP1 COMPLETED in current season)
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE txt_tournament_code = 'PP1-V2-M-EPEE-2024-2025'),
  0,
  'R.17: fn_fencer_scores_rolling — PP1-prev excluded (position completed in current)'
);

-- R.18 — no counterpart: delete IMEW-2025-2026 → IMEW carry drops
DELETE FROM tbl_event WHERE txt_code = 'IMEW-2025-2026';

SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
    266, 'EPEE', 'M', 'V2',
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
  ) WHERE bool_carried_over = TRUE),
  3,
  'R.18: fn_fencer_scores_rolling — IMEW dropped (no counterpart), 3 carried remain'
);

SELECT * FROM finish();
ROLLBACK;
