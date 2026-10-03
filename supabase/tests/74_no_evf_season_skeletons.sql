-- =============================================================================
-- pgTAP — a season is bootstrapped only with skeletons nobody discovers for us
-- =============================================================================
-- Verifies migration 20260906000001_no_evf_season_skeletons.sql.
--
-- `fn_init_season` provisioned a skeleton for the whole EVF circuit — PEW1-n
-- plus the IMEW/DMEW singleton. Those events are not scheduled by SPWS; EVF
-- publishes them and `evf_calendar.py` / `evf_sync.py` discover them within the
-- same season. The skeleton is therefore a PREDICTION of a row that is going to
-- arrive anyway, and it carries none of the four identities the ADR-039 dedup
-- ladder can use: no date, no EVF calendar id, no EVF results id, no slug.
--
-- Its only handle is the prior season's city, copied at bootstrap, which is
-- what `fn_allocate_evf_event_code` Step A matches on. Measured on PROD
-- 2026-09-05: all 23 skeletons had an EMPTY location, because the season was
-- bootstrapped on 2026-06-28 and ADR-088 — the work that made txt_location
-- reliably hold a city — was accepted on 2026-09-04. Step A could never fire,
-- the allocator fell through to Step C (next-free PEW{N+1}), and every scrape
-- minted a fresh row beside the skeleton: 8 duplicate pairs, with 15 more due
-- as EVF published the rest of the season.
--
-- Even with cities present the guess is only as good as EVF staying put, and
-- EVF moves its circuit between seasons. So the rule is not "keep skeletons for
-- SPWS events" but "keep skeletons for events nobody will discover for us":
--
--   PPW1-n  SPWS  no scraper  -> kept
--   MPW     SPWS  no scraper  -> kept
--   MSW     FIE   no scraper  -> kept (organiser is FIE, but nothing creates it)
--   PEW1-n  EVF   evf_sync    -> dropped
--   IMEW    EVF   evf_sync    -> dropped
--   DMEW    EVF   evf_sync    -> dropped
--
-- Amends ADR-077 §3. Plan-test-ID 74.
-- =============================================================================

BEGIN;

SELECT plan(9);

-- What an FTL import leaves behind in a live season: a 2026/27 tournament, a
-- result, and an identity-match candidate pointing at the result. Every
-- fixture that clears SPWS-2026-2027 must clear that candidate too —
-- tbl_match_candidate_id_result_fkey has no cascade (seen on LOCAL 2026-10-01
-- after the PPW1-2026-2027 import; doc/plans/pgtap-2026-27-data-2026-10-01.html).
-- Called inside each such savepoint, so the rollback removes it again.
CREATE FUNCTION pg_temp.seed_imported_2026_27_result(p_tag TEXT) RETURNS VOID
LANGUAGE plpgsql AS $imported$
DECLARE
  v_t INT;
  v_f INT;
  v_r INT;
BEGIN
  -- The seed holds the real PPW1 2026/27 since its promote (3 Oct 2026); reuse
  -- its tournament when present, and create it on a seed without it.
  SELECT id_tournament INTO v_t FROM tbl_tournament WHERE txt_code = 'PPW1-V2-M-EPEE-2026-2027';
  IF v_t IS NULL THEN
    INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                                enum_gender, enum_age_category, dt_tournament,
                                int_participant_count)
         VALUES ((SELECT e.id_event FROM tbl_event e
                    JOIN tbl_season s ON s.id_season = e.id_season
                   WHERE s.txt_code = 'SPWS-2026-2027' AND e.txt_code = 'PPW1-2026-2027'),
                 'PPW1-V2-M-EPEE-2026-2027', 'PPW', 'EPEE', 'M', 'V2', '2026-09-26', 1)
      RETURNING id_tournament INTO v_t;
  END IF;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('IMPORTED ' || p_tag, 'Fixture', 1970)
    RETURNING id_fencer INTO v_f;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place)
       VALUES (v_f, v_t, 1)
    RETURNING id_result INTO v_r;
  INSERT INTO tbl_match_candidate (id_result, txt_scraped_name, id_fencer, num_confidence, enum_status)
       VALUES (v_r, 'IMPORTED ' || p_tag || ' Fixture', v_f, 100, 'AUTO_MATCHED');
END;
$imported$;

-- ---------------------------------------------------------------------------
-- A freshly initialised season: what fn_init_season provisions now.
-- Mirrors the 19_phase3_wizard.sql fixture — SPWS-2026-2027 exists in the seed
-- (ADR-077 Phase C promoted skeleton), so remove it and let the wizard rebuild.
-- ---------------------------------------------------------------------------
SAVEPOINT s_init;

SELECT pg_temp.seed_imported_2026_27_result('74.init');

-- Clear the dependants first (match candidates, results, tournaments,
-- events). When this fixture was written SPWS-2026-2027 was
-- a bare promoted skeleton, so deleting its events was safe; the season has
-- since acquired real competitions with tournaments and results behind them,
-- and tbl_tournament_id_event_fkey has no ON DELETE CASCADE — so the bare
-- event delete now aborts the file. All inside the savepoint; the ROLLBACK
-- at the end restores every row.
DELETE FROM tbl_match_candidate WHERE id_result IN (
  SELECT r.id_result FROM tbl_result r
    JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));
DELETE FROM tbl_result WHERE id_tournament IN (
  SELECT t.id_tournament FROM tbl_tournament t
    JOIN tbl_event e ON e.id_event = t.id_event
   WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));
DELETE FROM tbl_tournament WHERE id_event IN (
  SELECT id_event FROM tbl_event
   WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));
DELETE FROM tbl_event          WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');
-- Scored since its first promote (3 Oct 2026): the season has a scoring revision.
UPDATE tbl_season SET id_active_scoring_revision = NULL WHERE txt_code = 'SPWS-2026-2027';
DELETE FROM tbl_scoring_config_revision WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');
DELETE FROM tbl_scoring_config WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027');
DELETE FROM tbl_season         WHERE txt_code = 'SPWS-2026-2027';
INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2026-2027', '2026-09-01', '2027-07-31', 'IMEW');

CREATE TEMP TABLE _init74 AS
  SELECT * FROM fn_init_season(
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
  );

-- 74.1 — the EVF circuit is no longer predicted.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^PEW\d+[efs]*-'),
  0,
  '74.1 — fn_init_season creates no PEW skeleton; evf_sync discovers the circuit'
);

-- 74.2 — nor the European singleton, even in an IMEW year. This is the case
-- that would slip through a PEW-only fix: the fixture season is declared IMEW.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND (txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%')),
  0,
  '74.2 — no IMEW/DMEW skeleton either, in a season declared IMEW'
);

-- 74.3 — what is kept, stated positively rather than by absence. PPW is the
-- one whose count varies with the prior season, so assert the relationship.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^PPW\d+-'),
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026')
       AND txt_code ~ '^PPW\d+-'),
  '74.3 — PPW skeletons still provisioned, one per prior-season PPW'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^MPW-'),
  1,
  '74.4 — the MPW skeleton is kept: SPWS runs it, nothing discovers it'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code ~ '^MSW-'),
  1,
  '74.5 — the MSW skeleton is kept although FIE organises it: no FIE scraper exists'
);

-- 74.6 — the return contract does not change shape. Callers read by_kind by
-- key (the season wizard renders the breakdown from it), so PEW keeps its key
-- and reports zero rather than disappearing.
SELECT is(
  ((SELECT by_kind FROM _init74) ->> 'PEW'),
  '0',
  '74.6 — by_kind still carries the PEW key, reporting 0 (callers read by key)'
);

-- 74.7 — the rule restated at the level that actually matters: no skeleton is
-- provisioned for an organiser whose events arrive by scrape.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
     JOIN tbl_organizer o USING (id_organizer)
    WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
      AND o.txt_code = 'EVF'),
  0,
  '74.7 — no EVF-organised skeleton is provisioned at all'
);

-- 74.8 — ADR-077 §3's childless doctrine still holds for what remains.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')),
  0,
  '74.8 — the kept skeletons stay childless (ADR-077 §3)'
);

ROLLBACK TO SAVEPOINT s_init;

-- ---------------------------------------------------------------------------
-- 74.9 — the migration also clears the skeletons already provisioned, so the
-- environments do not carry a generation of unmatchable rows forward. Scoped
-- deliberately: only a CREATED, dateless, childless EVF row is removable.
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
     JOIN tbl_organizer o USING (id_organizer)
    WHERE e.enum_status = 'CREATED'
      AND e.dt_start IS NULL
      AND o.txt_code = 'EVF'),
  0,
  '74.9 — no dateless CREATED EVF skeleton is left anywhere after the migration'
);

SELECT * FROM finish();

ROLLBACK;
