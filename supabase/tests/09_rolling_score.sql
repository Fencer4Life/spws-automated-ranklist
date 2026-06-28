-- =============================================================================
-- M10: Rolling Score Tests  (self-contained synthetic fixture)
-- =============================================================================
-- Tests R.1–R.24 covering the rolling carry-over engine (ADR-018 / ADR-021,
-- amended by 20260626120000 to be RESULTS-based / status-independent).
--
-- DESIGN (2026-06-28 robustness rewrite): every score/logic test builds its own
-- throwaway world in this transaction and ROLLBACKs. No named production fencers,
-- no "seed state" assumptions, no production magic-number scores. Expected values
-- are either ENGINE-DERIVED (read back the synthetic tournaments' own
-- num_final_score and assert the rolling/best-K/carry composition of THOSE) or
-- purely STRUCTURAL (carried-over counts, never-both, source season, rules toggle).
-- This makes the file immune to live-DB mutation and season rollover — it passes
-- against the current LOCAL DB with no reset, and stays green after any reingest.
--
-- Two synthetic, non-active seasons drive carry-over (prev resolved by DATE):
--   TST-PREV  2090-09-01 → 2091-08-31  (end year 2091)  — the carry SOURCE
--   TST-CURR  2091-09-01 → 2092-08-31  (end year 2092)  — the queried season
--   TST-ROOT  1850-09-01 → 1851-08-31  (end year 1851)  — earliest of all, so it
--                                                          has NO predecessor (R.5)
-- Scenarios are isolated on independent (weapon, gender) lanes because the
-- carry-stop key `completed_positions` is scoped to weapon+gender (not category).
-- =============================================================================

BEGIN;
SELECT plan(24);

-- =========================================================================
-- R.1–R.3: fn_event_position (pure string helper — already self-contained)
-- =========================================================================

SELECT is(fn_event_position('PPW1-2024-2025'), 'PPW1',
  'R.1: fn_event_position extracts PPW1 from PPW1-2024-2025');

SELECT is(fn_event_position('MPW-2024-2025'), 'MPW',
  'R.2: fn_event_position extracts MPW from MPW-2024-2025');

SELECT is(fn_event_position('PEW1-2025-2026'), 'PEW1',
  'R.3: fn_event_position extracts PEW1 from PEW1-2025-2026');

-- =========================================================================
-- Synthetic fixture
-- =========================================================================

-- Organizer (one is enough — domestic vs international is decided by the
-- tournament enum_type, not the organizer).
INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('TST-ORG', 'Test Organizer');

-- Seasons. enum_carryover_engine is set explicitly to EVENT_CODE_MATCHING (the
-- active results-based engine the dispatcher routes to) — the table default has
-- since moved to EVENT_FK_MATCHING, which is a different, inactive engine.
-- trg_season_auto_config auto-creates a default (NULL-rules) scoring_config row
-- for each.
INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active, enum_carryover_engine) VALUES
  ('TST-PREV', '2090-09-01', '2091-08-31', FALSE, 'EVENT_CODE_MATCHING'),
  ('TST-CURR', '2091-09-01', '2092-08-31', FALSE, 'EVENT_CODE_MATCHING'),
  ('TST-ROOT', '1850-09-01', '1851-08-31', FALSE, 'EVENT_CODE_MATCHING');

-- Clone a real season's full scoring config (real place-point formula + real
-- json_ranking_rules with domestic PPW/MPW + international PEW/MEW) into each
-- synthetic season → engine-real scores, our inputs.
UPDATE tbl_scoring_config dst SET
  int_mp_value             = src.int_mp_value,
  int_podium_gold          = src.int_podium_gold,
  int_podium_silver        = src.int_podium_silver,
  int_podium_bronze        = src.int_podium_bronze,
  num_ppw_multiplier       = src.num_ppw_multiplier,
  int_ppw_best_count       = src.int_ppw_best_count,
  int_ppw_total_rounds     = src.int_ppw_total_rounds,
  num_mpw_multiplier       = src.num_mpw_multiplier,
  bool_mpw_droppable       = src.bool_mpw_droppable,
  num_pew_multiplier       = src.num_pew_multiplier,
  int_pew_best_count       = src.int_pew_best_count,
  num_mew_multiplier       = src.num_mew_multiplier,
  bool_mew_droppable       = src.bool_mew_droppable,
  num_msw_multiplier       = src.num_msw_multiplier,
  num_psw_multiplier       = src.num_psw_multiplier,
  int_min_participants_evf = src.int_min_participants_evf,
  int_min_participants_ppw = src.int_min_participants_ppw,
  json_ranking_rules       = src.json_ranking_rules
FROM tbl_scoring_config src
WHERE src.id_season = (
        SELECT id_season FROM tbl_scoring_config
         WHERE json_ranking_rules ? 'domestic' AND json_ranking_rules ? 'international'
         ORDER BY id_season DESC LIMIT 1)
  AND dst.id_season IN (SELECT id_season FROM tbl_season
                         WHERE txt_code IN ('TST-PREV', 'TST-CURR', 'TST-ROOT'));

-- Helper lookups (session-scoped; created in pg_temp).
CREATE FUNCTION pg_temp.sid(p_code text) RETURNS int
  LANGUAGE sql STABLE AS $$ SELECT id_season FROM tbl_season WHERE txt_code = p_code $$;
CREATE FUNCTION pg_temp.fid(p_surname text) RETURNS int
  LANGUAGE sql STABLE AS $$ SELECT id_fencer FROM tbl_fencer WHERE txt_surname = p_surname LIMIT 1 $$;
CREATE FUNCTION pg_temp.sc(p_tcode text) RETURNS numeric
  LANGUAGE sql STABLE AS $$
    SELECT r.num_final_score FROM tbl_result r
      JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
     WHERE t.txt_code = p_tcode LIMIT 1 $$;

-- Create one synthetic tournament with a single placed fencer and score it.
-- Creates the parent event on first use of an event code (idempotent), so
-- lanes may share an event code while staying isolated by weapon+gender.
CREATE FUNCTION pg_temp.mk(
  p_evcode text, p_season int, p_status enum_event_status,
  p_tcode text, p_type enum_tournament_type,
  p_weapon enum_weapon_type, p_gender enum_gender_type, p_vcat enum_age_category,
  p_fencer int, p_place int, p_count int
) RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_eid int; v_tid int; v_start date;
BEGIN
  SELECT dt_start INTO v_start FROM tbl_season WHERE id_season = p_season;
  SELECT id_event INTO v_eid FROM tbl_event WHERE txt_code = p_evcode;
  IF v_eid IS NULL THEN
    INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
    VALUES (p_evcode, p_evcode, p_season,
            (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'TST-ORG'),
            p_status, v_start)
    RETURNING id_event INTO v_eid;
  END IF;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament,
                              int_participant_count, enum_import_status)
  VALUES (v_eid, p_tcode, p_tcode, p_type, p_weapon, p_gender, p_vcat,
          v_start, p_count, 'IMPORTED')
  RETURNING id_tournament INTO v_tid;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
  VALUES (p_fencer, v_tid, p_place, 'synthetic');
  PERFORM fn_calc_tournament_scores(v_tid);
  RETURN v_tid;
END; $$;

-- Synthetic fencers (one per lane; BYs chosen so each tournament's V-cat matches
-- fn_age_category(BY, season_end_year) — satisfies the FATAL trg_assert_result_vcat
-- without any trigger-disable hack).
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender) VALUES
  ('TSTMAIN',  'Main',  2037, 'M'),   -- EPEE/M  V2 (both seasons)
  ('TSTFOIL',  'Foil',  2037, 'M'),   -- FOIL/M  V2 (best-K)
  ('TSTSABRE', 'Sabre', 2032, 'M'),   -- SABRE/M V2→V3 (category crossing)
  ('TSTR10',   'Ten',   2037, 'F'),   -- EPEE/F  V2 (results-based carry-stop)
  ('TSTDEL',   'Del',   2037, 'F'),   -- EPEE/F  V2 (event deletion → carry resume)
  ('TSTROOT',  'Root',  1796, 'M');   -- EPEE/M  V2 in TST-ROOT (no predecessor)

-- ---- EPEE/M lane (TSTMAIN): the rich rolling scenario -------------------
-- PREV results. Positions PPW1+PPW3 will be "completed" in CURR (so their prev
-- is suppressed); PPW2, PPW4, MPW, IMEW have no current result (so they carry).
SELECT pg_temp.mk('PPW1-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW1-V2-M-EPEE-TST-PREV', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 3, 20);
SELECT pg_temp.mk('PPW2-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW2-V2-M-EPEE-TST-PREV', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 2, 18);
SELECT pg_temp.mk('PPW4-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW4-V2-M-EPEE-TST-PREV', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 4, 16);
SELECT pg_temp.mk('MPW-TST-PREV',  pg_temp.sid('TST-PREV'), 'COMPLETED', 'MPW-V2-M-EPEE-TST-PREV',  'MPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 2, 22);
SELECT pg_temp.mk('IMEW-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'IMEW-V2-M-EPEE-TST-PREV', 'MEW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 5, 30);
-- CURR results (complete positions PPW1 + PPW3).
SELECT pg_temp.mk('PPW1-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'PPW1-V2-M-EPEE-TST-CURR', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 1, 24);
SELECT pg_temp.mk('PPW3-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'PPW3-V2-M-EPEE-TST-CURR', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 2, 19);
-- CURR MPW EVENT exists at COMPLETED status but carries NO result yet (R.6 proof
-- that status is a no-op; R.22 later gives it a result to flip the carry-stop).
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start)
VALUES ('MPW-TST-CURR', 'MPW-TST-CURR', pg_temp.sid('TST-CURR'),
        (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'TST-ORG'),
        'COMPLETED', '2091-09-01');

-- ---- EPEE/F lane (TSTR10): results-based carry-stop, status-independent --
-- PREV PPW5 (would carry) + PREV PPW2 (carries — never completed in CURR).
SELECT pg_temp.mk('PPW5-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW5-V2-F-EPEE-TST-PREV', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTR10'), 3, 15);
SELECT pg_temp.mk('PPW2-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW2-V2-F-EPEE-TST-PREV', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTR10'), 2, 14);
-- CURR PPW5 with a result but at SCHEDULED status → completes PPW5 by RESULT,
-- regardless of status (the whole point of the 20260626120000 amendment).
SELECT pg_temp.mk('PPW5-TST-CURR', pg_temp.sid('TST-CURR'), 'SCHEDULED', 'PPW5-V2-F-EPEE-TST-CURR', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTR10'), 1, 20);

-- ---- EPEE/F lane (TSTDEL): event deletion → carry-over resumes ----------
SELECT pg_temp.mk('PPW1-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW1-V2-F-EPEE-TST-PREV', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTDEL'), 2, 12);
SELECT pg_temp.mk('PPW1-TST-CURR', pg_temp.sid('TST-CURR'), 'SCHEDULED', 'PPW1-V2-F-EPEE-TST-CURR', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTDEL'), 1, 13);
SELECT pg_temp.mk('PPW3-TST-CURR', pg_temp.sid('TST-CURR'), 'SCHEDULED', 'PPW3-V2-F-EPEE-TST-CURR', 'PPW', 'EPEE', 'F', 'V2', pg_temp.fid('TSTDEL'), 1, 11);

-- ---- FOIL/M lane (TSTFOIL): best-K on the MERGED current+carried pool ----
SELECT pg_temp.mk('PPW1-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'PPW1-V2-M-FOIL-TST-CURR', 'PPW', 'FOIL', 'M', 'V2', pg_temp.fid('TSTFOIL'), 1, 30);
SELECT pg_temp.mk('PPW2-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'PPW2-V2-M-FOIL-TST-CURR', 'PPW', 'FOIL', 'M', 'V2', pg_temp.fid('TSTFOIL'), 1, 25);
SELECT pg_temp.mk('PPW3-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'PPW3-V2-M-FOIL-TST-CURR', 'PPW', 'FOIL', 'M', 'V2', pg_temp.fid('TSTFOIL'), 1, 20);
SELECT pg_temp.mk('PPW4-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW4-V2-M-FOIL-TST-PREV', 'PPW', 'FOIL', 'M', 'V2', pg_temp.fid('TSTFOIL'), 5, 10);
SELECT pg_temp.mk('PPW5-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW5-V2-M-FOIL-TST-PREV', 'PPW', 'FOIL', 'M', 'V2', pg_temp.fid('TSTFOIL'), 6, 8);

-- ---- SABRE/M lane (TSTSABRE): category crossing V2 (prev) → V3 (curr) ----
SELECT pg_temp.mk('PPW1-TST-PREV', pg_temp.sid('TST-PREV'), 'COMPLETED', 'PPW1-V2-M-SABRE-TST-PREV', 'PPW', 'SABRE', 'M', 'V2', pg_temp.fid('TSTSABRE'), 1, 16);

-- ---- ROOT lane (TSTROOT): earliest season, no predecessor ---------------
SELECT pg_temp.mk('PPW1-TST-ROOT', pg_temp.sid('TST-ROOT'), 'COMPLETED', 'PPW1-V2-M-EPEE-TST-ROOT', 'PPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTROOT'), 1, 20);

-- =========================================================================
-- R.4–R.14: fn_ranking_ppw / fn_ranking_kadra
-- =========================================================================

-- R.4 — p_rolling=FALSE: current season only (no carry). Best-4 PPW keeps both
-- current PPW; no current MPW result → MPW bucket contributes 0.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('EPEE','M','V2', pg_temp.sid('TST-CURR'), p_rolling := FALSE)
    WHERE id_fencer = pg_temp.fid('TSTMAIN')),
  pg_temp.sc('PPW1-V2-M-EPEE-TST-CURR') + pg_temp.sc('PPW3-V2-M-EPEE-TST-CURR'),
  'R.4: p_rolling=FALSE — total = current PPW1 + PPW3 only (engine-derived)');

-- R.5 — p_rolling=TRUE with NO previous season (TST-ROOT is the earliest of all
-- seasons by date) → identical to FALSE.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('EPEE','M','V2', pg_temp.sid('TST-ROOT'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTROOT')),
  (SELECT total_score FROM fn_ranking_ppw('EPEE','M','V2', pg_temp.sid('TST-ROOT'), p_rolling := FALSE)
    WHERE id_fencer = pg_temp.fid('TSTROOT')),
  'R.5: p_rolling=TRUE with no previous season — identical to FALSE');

-- R.6 — carry-stop is RESULTS-based, not status-based (ADR-018/021 amend). A
-- COMPLETED current-season MPW event with NO result is a no-op: the prior-season
-- MPW STILL carries. Guards status-independence of the rule.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE enum_type = 'MPW' AND bool_carried_over = TRUE),
  1,
  'R.6: COMPLETED-but-empty current MPW event is a no-op — MPW-prev still carries');

-- R.7 — p_rolling=TRUE: merged best-4 PPW (2 current + 2 carried) + carried MPW.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('EPEE','M','V2', pg_temp.sid('TST-CURR'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTMAIN')),
    pg_temp.sc('PPW1-V2-M-EPEE-TST-CURR') + pg_temp.sc('PPW3-V2-M-EPEE-TST-CURR')
  + pg_temp.sc('PPW2-V2-M-EPEE-TST-PREV') + pg_temp.sc('PPW4-V2-M-EPEE-TST-PREV')
  + pg_temp.sc('MPW-V2-M-EPEE-TST-PREV'),
  'R.7: p_rolling=TRUE — current PPW1+PPW3 + carried PPW2+PPW4 + carried MPW');

-- R.8 — best-K operates on the MERGED current+carried pool. TSTFOIL has 5 PPW
-- (3 current + 2 carried); best:4 keeps the top 4 across both sources.
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('FOIL','M','V2', pg_temp.sid('TST-CURR'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTFOIL')),
  (SELECT SUM(s) FROM (
     SELECT unnest(ARRAY[
       pg_temp.sc('PPW1-V2-M-FOIL-TST-CURR'), pg_temp.sc('PPW2-V2-M-FOIL-TST-CURR'),
       pg_temp.sc('PPW3-V2-M-FOIL-TST-CURR'), pg_temp.sc('PPW4-V2-M-FOIL-TST-PREV'),
       pg_temp.sc('PPW5-V2-M-FOIL-TST-PREV')]) AS s
     ORDER BY s DESC LIMIT 4) top4),
  'R.8: best-K on merged pool — top 4 of (3 current + 2 carried) PPW');

-- R.9 — category crossing. TSTSABRE is V2 in TST-PREV, V3 in TST-CURR; his PREV
-- V2 result carries into the V3 ranking (fn_age_category against CURR end year).
SELECT is(
  (SELECT total_score FROM fn_ranking_ppw('SABRE','M','V3', pg_temp.sid('TST-CURR'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTSABRE')),
  pg_temp.sc('PPW1-V2-M-SABRE-TST-PREV'),
  'R.9: category crossing V2→V3 — PREV V2 result carries into V3 ranking');

-- R.10 — results-based carry-stop, status-independent (ADR-018/021 amend).
-- TSTR10 has a current PPW5 result on a SCHEDULED event → PPW5-prev no longer
-- carries; PPW2-prev (no current result) still does.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTR10'), 'EPEE','F','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE AND txt_tournament_code LIKE 'PPW5-%'),
  0,
  'R.10: PPW5-prev stops carrying once current PPW5 has a result (SCHEDULED event)');

-- R.11 — event deletion when the prior season has nothing to carry. Deleting
-- TSTDEL''s current PPW3 (no PPW3-prev) leaves the position with no row at all.
DELETE FROM tbl_result WHERE id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-TST-CURR');
DELETE FROM tbl_tournament WHERE txt_code = 'PPW3-V2-F-EPEE-TST-CURR';
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTDEL'), 'EPEE','F','V2', pg_temp.sid('TST-CURR'))
    WHERE txt_tournament_code LIKE 'PPW3-%'),
  0,
  'R.11: current event deleted, no prior to carry — position disappears');

-- R.12 — event deletion → position carry-over RESUMES (ADR-021). Deleting
-- TSTDEL''s current PPW1 un-completes the position, so PPW1-prev now carries.
DELETE FROM tbl_result WHERE id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-TST-CURR');
DELETE FROM tbl_tournament WHERE txt_code = 'PPW1-V2-F-EPEE-TST-CURR';
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTDEL'), 'EPEE','F','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE AND txt_tournament_code LIKE 'PPW1-%'),
  1,
  'R.12: current event deleted → PPW1-prev carry-over resumes (ADR-021)');

-- R.13 — kadra p_rolling=TRUE: domestic (PPW best-4 + MPW) + international
-- (carried IMEW/MEW). total = R.7 domestic total + carried IMEW.
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra('EPEE','M','V2', pg_temp.sid('TST-CURR'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTMAIN')),
    pg_temp.sc('PPW1-V2-M-EPEE-TST-CURR') + pg_temp.sc('PPW3-V2-M-EPEE-TST-CURR')
  + pg_temp.sc('PPW2-V2-M-EPEE-TST-PREV') + pg_temp.sc('PPW4-V2-M-EPEE-TST-PREV')
  + pg_temp.sc('MPW-V2-M-EPEE-TST-PREV')  + pg_temp.sc('IMEW-V2-M-EPEE-TST-PREV'),
  'R.13: kadra p_rolling=TRUE — domestic + international + carried IMEW');

-- R.14 — kadra p_rolling=FALSE: no carry, no current international → domestic
-- current only.
SELECT is(
  (SELECT total_score FROM fn_ranking_kadra('EPEE','M','V2', pg_temp.sid('TST-CURR'), p_rolling := FALSE)
    WHERE id_fencer = pg_temp.fid('TSTMAIN')),
  pg_temp.sc('PPW1-V2-M-EPEE-TST-CURR') + pg_temp.sc('PPW3-V2-M-EPEE-TST-CURR'),
  'R.14: kadra p_rolling=FALSE — current domestic only');

-- =========================================================================
-- R.15–R.18: fn_fencer_scores_rolling drilldown (TSTMAIN EPEE/M/V2)
-- =========================================================================
-- Current rows: PPW1, PPW3 (2). Carried rows: PPW2, PPW4, MPW, IMEW (4).
-- PPW1-prev / PPW3-prev are suppressed (their positions completed in CURR).

-- R.15 — carried-over rows are flagged bool_carried_over = TRUE.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE),
  4,
  'R.15: drilldown — 4 carried-over rows (PPW2 + PPW4 + MPW + IMEW)');

-- R.16 — current rows are flagged bool_carried_over = FALSE.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = FALSE),
  2,
  'R.16: drilldown — 2 current rows (PPW1 + PPW3)');

-- R.17 — PPW1-prev excluded because position PPW1 is completed in current season.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE txt_tournament_code = 'PPW1-V2-M-EPEE-TST-PREV'),
  0,
  'R.17: PPW1-prev excluded (position completed in current)');

-- R.18 — a current-season RESULT (not status) blocks carry-over for that
-- position. Add a current IMEW result on a SCHEDULED event → IMEW-prev stops.
SELECT pg_temp.mk('IMEW-TST-CURR', pg_temp.sid('TST-CURR'), 'SCHEDULED', 'IMEW-V2-M-EPEE-TST-CURR', 'MEW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 4, 12);
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE),
  3,
  'R.18: current IMEW result (SCHEDULED event) blocks carry — IMEW-prev dropped');

-- Remove the test IMEW current result so R.19–R.21 see IMEW-prev carrying again.
DELETE FROM tbl_result WHERE id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-TST-CURR');
DELETE FROM tbl_tournament WHERE txt_code = 'IMEW-V2-M-EPEE-TST-CURR';
DELETE FROM tbl_event WHERE txt_code = 'IMEW-TST-CURR';

-- =========================================================================
-- R.19–R.21: biennial IMEW carry-over (ADR-021, FR-68)
-- =========================================================================
-- IMEW happened in TST-PREV, not TST-CURR. Rules-based carry-over: MEW is in
-- json_ranking_rules->international, so IMEW carries with no current event.

-- R.19 — carried IMEW reports the SOURCE season code (TST-PREV).
SELECT is(
  (SELECT txt_source_season_code FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  'TST-PREV',
  'R.19: carried IMEW source season is TST-PREV (biennial)');

-- R.20 — carried IMEW score equals the synthetic tournament''s engine score.
SELECT is(
  (SELECT num_final_score FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  pg_temp.sc('IMEW-V2-M-EPEE-TST-PREV'),
  'R.20: carried IMEW score = the source tournament''s num_final_score');

-- R.21 — removing MEW from ranking rules stops the IMEW carry-over.
UPDATE tbl_scoring_config SET json_ranking_rules = jsonb_set(
  json_ranking_rules, '{international,2,types}', '["PEW", "MSW"]'::JSONB)
 WHERE id_season = pg_temp.sid('TST-CURR');
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE bool_carried_over = TRUE AND enum_type = 'MEW'),
  0,
  'R.21: MEW removed from rules — IMEW no longer carries (ADR-021 rules-based)');
-- Restore rules (ROLLBACK would also handle this).
UPDATE tbl_scoring_config SET json_ranking_rules = jsonb_set(
  json_ranking_rules, '{international,2,types}', '["PEW", "MEW", "MSW"]'::JSONB)
 WHERE id_season = pg_temp.sid('TST-CURR');

-- =========================================================================
-- R.22–R.24: never-both — a current-season result supersedes the carried
-- prior-season equivalent REGARDLESS of event status (ADR-018/021 amend).
-- The MPW-TST-CURR event is SCHEDULED-equivalent (created COMPLETED, but the
-- carry-stop ignores status); give it a result and the carried MPW drops.
-- =========================================================================
SELECT pg_temp.mk('MPW-TST-CURR', pg_temp.sid('TST-CURR'), 'COMPLETED', 'MPW-V2-M-EPEE-TST-CURR', 'MPW', 'EPEE', 'M', 'V2', pg_temp.fid('TSTMAIN'), 1, 26);

-- R.22 — exactly one MPW row for TSTMAIN (was 2 under the old status-based rule).
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE enum_type = 'MPW'),
  1,
  'R.22: never both — exactly one MPW row when current MPW has a result');

-- R.23 — the prior-season MPW carry is dropped once the current result exists.
SELECT is(
  (SELECT COUNT(*)::INT FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE enum_type = 'MPW' AND bool_carried_over = TRUE),
  0,
  'R.23: carried MPW dropped once current-season MPW result exists');

-- R.24 — ranking mpw_score = THIS year''s MPW (the drilldown current MPW row),
-- not the carried prior-season one.
SELECT is(
  (SELECT mpw_score FROM fn_ranking_ppw('EPEE','M','V2', pg_temp.sid('TST-CURR'), p_rolling := TRUE)
    WHERE id_fencer = pg_temp.fid('TSTMAIN')),
  (SELECT num_final_score FROM fn_fencer_scores_rolling(
      pg_temp.fid('TSTMAIN'), 'EPEE','M','V2', pg_temp.sid('TST-CURR'))
    WHERE enum_type = 'MPW' AND bool_carried_over = FALSE),
  'R.24: ranking mpw_score = current-season MPW (carried no longer double-counts)');

SELECT * FROM finish();
ROLLBACK;
