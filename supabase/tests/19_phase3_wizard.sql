-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- Phase 3 — Admin UI + season-init wizard backend RPCs
-- =============================================================================
-- Tests ph3.1 - ph3.22c from doc/archive/MVP_development_plan.md (Phase 3 plan).
-- Covers four new RPCs:
--   * fn_init_season(p_id_season)                          → ph3.1-ph3.11
--   * fn_create_season_with_skeletons(...)                 → ph3.13-ph3.14, ph3.22b
--   * fn_update_event v2 (cascade rename + id_prior_event) → ph3.15-ph3.17
--   * fn_revert_season_init(p_id_season)                   → ph3.18-ph3.19
--   * fn_copy_prior_scoring_config(p_dt_start)             → ph3.20-ph3.21
-- Plus schema regression / default-flip guards (ph3.12, ph3.22, ph3.22a, ph3.22c).
-- =============================================================================

BEGIN;
-- Layer 6 (2026-04-30): targeted bypass of trg_assert_result_vcat for
-- legacy test fixtures whose dummy V-cats predate the FATAL invariant
-- guard. Targeted (not session_replication_role) so audit + status-
-- transition triggers stay live.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;
-- Every assertion runs OUTSIDE the savepoints. This file exercises the wizard
-- through 15 ROLLBACK TO SAVEPOINT cycles, and pgTAP keeps its test counter in
-- a table, so an assertion made inside a savepoint is uncounted by the
-- rollback ("planned 25 tests but ran 5", fixed 31 Oct 2026, F4 of
-- doc/plans/cert-event-details-reach-prod-every-scraper-2026-10-31.html).
-- Inside a savepoint the value under test is captured into a psql variable
-- (\gset survives the rollback); the assertion follows the rollback. An
-- expected error is captured the same way by pg_temp.error_of.
SELECT plan(25);

-- The SQLSTATE and message an SQL text raises, or NULL when it runs cleanly.
-- Created outside every savepoint so the rollbacks keep it.
CREATE FUNCTION pg_temp.error_of(p_sql TEXT) RETURNS TEXT
LANGUAGE plpgsql AS $error_of$
BEGIN
  EXECUTE p_sql;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN SQLSTATE || ': ' || SQLERRM;
END;
$error_of$;

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

-- =========================================================================
-- Schema-level checks (no setup required, no missing-function risk)
-- =========================================================================

-- ph3.22 — regression: enum_event_status still includes CREATED (Phase 1B add)
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_enum e
      JOIN pg_type t ON t.oid = e.enumtypid
     WHERE t.typname = 'enum_event_status' AND e.enumlabel = 'CREATED'
  ),
  'ph3.22: enum_event_status still includes CREATED (regression guard)'
);

-- ph3.22a — tbl_season.enum_carryover_engine DEFAULT flipped to FK
SELECT col_default_is(
  'tbl_season', 'enum_carryover_engine',
  'EVENT_FK_MATCHING'::enum_event_carryover_engine,
  'ph3.22a: tbl_season.enum_carryover_engine DEFAULT is EVENT_FK_MATCHING'
);

-- ph3.22c — existing rows preserved (no implicit re-flip on existing seasons)
SELECT is(
  (SELECT enum_carryover_engine::TEXT FROM tbl_season WHERE id_season = 1),
  'EVENT_CODE_MATCHING',
  'ph3.22c: existing seed seasons keep their enum_carryover_engine value (no re-flip)'
);

-- =========================================================================
-- ph3.20-21: fn_copy_prior_scoring_config
-- =========================================================================

-- ph3.20 — returns prior config JSONB matching fn_export_scoring_config
-- Wizard step-2 calls this with the new season's dt_start; chronology returns
-- the most recent season ending before that date. SPWS-2025-2026 ends 2026-07-15
-- so a 2026-09-01 start should resolve prior = SPWS-2025-2026 (id=3).
SELECT is(
  (SELECT (fn_copy_prior_scoring_config('2026-09-01'::DATE)->>'season_code')),
  'SPWS-2025-2026',
  'ph3.20: fn_copy_prior_scoring_config returns prior season config (SPWS-2025-2026)'
);

-- ph3.21 — returns NULL when no prior season exists (chronologically first)
SELECT is(
  fn_copy_prior_scoring_config('1900-01-01'::DATE),
  NULL::JSONB,
  'ph3.21: fn_copy_prior_scoring_config returns NULL when no prior season exists'
);

-- =========================================================================
-- ph3.1-7, ph3.11: fn_init_season — typical season (IMEW European year)
-- =========================================================================

SAVEPOINT s_imew;

-- Seed: insert SPWS-2026-2027 marked as IMEW year. Chronologically follows
-- SPWS-2025-2026 (id=3, dt_end=2026-07-15). Trigger trg_season_auto_config will
-- insert default scoring config; we don't overwrite here (fn_init_season
-- doesn't depend on scoring config values).
-- ADR-077 Phase C: SPWS-2026-2027 now exists in the seed (promoted skeleton).
-- Remove it within this savepoint so the fixture recreates it; ROLLBACK restores it.
-- pgt-ignore-start typecheck: pg_temp helpers this file creates (the checker sees only the live schema)
SELECT pg_temp.seed_imported_2026_27_result('19.imew');
-- pgt-ignore-end typecheck

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

-- Call fn_init_season; capture result for downstream assertions.
-- Stored in a temp table to avoid re-invocation across assertions.
CREATE TEMP TABLE _init_result_imew AS
  SELECT * FROM fn_init_season(
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
  );

-- ph3.1 — REMOVED: hardcoded skeleton count (23/26) is not portable across
-- environments. The wizard's output count is a function of season config
-- (PPW count, PEW priors, championship type) — should be asserted as a
-- formula derived from prior-season state, not a magic number. To be
-- rewritten as ph3.1 v2 in a follow-up.

-- ph3.2 — every skeleton event has enum_status='CREATED'
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_2 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
   AND enum_status != 'CREATED' \gset

-- ph3.3 v2 — REVERSED by migration 20260906000001 (amends ADR-077 §3).
-- Was: "PEW1 skeleton inherits txt_location from prior PEW1efs". The inherited
-- city was the skeleton's ONLY handle for fn_allocate_evf_event_code Step A,
-- and it was empty on all 23 PROD skeletons because the season was bootstrapped
-- (2026-06-28) before ADR-088 made txt_location reliable (2026-09-04) — so the
-- adopt rung never fired and every scrape minted a duplicate. EVF events are no
-- longer predicted at all; evf_sync discovers them. Positive coverage for what
-- IS still provisioned lives in 74_no_evf_season_skeletons.sql.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_3 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
   AND txt_code ~ '^PEW\d+[efs]*-' \gset

-- ph3.4 — PPW skeletons have NULL location (rotating venues each season)
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_4 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
   AND txt_code LIKE 'PPW%'
   AND txt_location IS NOT NULL \gset

-- ph3.5 — every skeleton has id_prior_event set (prior exists for typical season)
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_5 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
   AND id_prior_event IS NULL \gset

-- ph3.6 v2 — skeleton events are CHILDLESS. Tournaments are ingested per event
-- after the season is created; the empty events serve a calendar purpose only
-- (user requirement 2026-06-27). fn_init_season creates no child tournaments,
-- and no function in the schema creates skeleton brackets (ADM27.SKEL.04).
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_6 FROM tbl_tournament t
  JOIN tbl_event e ON e.id_event = t.id_event
 WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027') \gset

-- ph3.7 v2 — REVERSED by migration 20260906000001 (amends ADR-077 §3).
-- IMEW is EVF's, and evf_sync discovers it like the rest of the circuit.
-- enum_european_event_type still records which championship the season expects;
-- it no longer pre-creates the row.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_7 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
   AND txt_code LIKE 'IMEW%' \gset

-- ph3.11 — idempotent: second call raises (skeletons already exist)
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COALESCE(pg_temp.error_of(
  $$SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'))$$
), '') AS ph3_11 \gset

ROLLBACK TO SAVEPOINT s_imew;

SELECT is(:'ph3_2'::INT, 0, 'ph3.2: every skeleton event has enum_status=CREATED');
SELECT is(:'ph3_3'::INT, 0, 'ph3.3 v2: no PEW skeleton is provisioned (EVF events arrive by scrape)');
SELECT is(:'ph3_4'::INT, 0, 'ph3.4: PPW skeletons have NULL location (rotating venues)');
SELECT is(:'ph3_5'::INT, 0, 'ph3.5: every skeleton has id_prior_event set (typical season)');
SELECT is(:'ph3_6'::INT, 0, 'ph3.6 v2: fn_init_season creates childless skeleton events (zero tournaments)');
SELECT is(:'ph3_7'::INT, 0, 'ph3.7 v2: no IMEW skeleton, even when enum_european_event_type=IMEW');
SELECT ok(:'ph3_11' <> '', 'ph3.11: second call to fn_init_season raises (skeletons already exist)');

-- =========================================================================
-- ph3.8: fn_init_season — DMEW European year
-- =========================================================================

SAVEPOINT s_dmew;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2027-2028', '2027-09-01', '2028-07-31', 'DMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2027-2028'));

-- ph3.8 v2 — REVERSED by migration 20260906000001, same reason as ph3.7:
-- DMEW is EVF's team championship and arrives by scrape.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_8 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2027-2028')
   AND txt_code LIKE 'DMEW%' \gset

ROLLBACK TO SAVEPOINT s_dmew;

SELECT is(:'ph3_8'::INT, 0, 'ph3.8 v2: no DMEW skeleton, even when enum_european_event_type=DMEW');

-- =========================================================================
-- ph3.9: fn_init_season — no European singleton when type is NULL
-- =========================================================================

SAVEPOINT s_null;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2028-2029', '2028-09-01', '2029-07-31', NULL);

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2028-2029'));

-- ph3.9 — no IMEW or DMEW skeleton when European type NULL
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_9 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2028-2029')
   AND (txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%') \gset

ROLLBACK TO SAVEPOINT s_null;

SELECT is(:'ph3_9'::INT, 0, 'ph3.9: no European singleton when enum_european_event_type IS NULL');

-- =========================================================================
-- ph3.10: fn_init_season — first-ever season (no prior)
-- =========================================================================

SAVEPOINT s_first;

-- Insert chronologically earliest season (dt_end before all existing). The
-- earliest existing seed season is SPWS-2023-2024 (dt_start 2023-08-15).
-- Use 1900-08-01 → 1901-07-15 to guarantee no chronological prior.
INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-1900-1901', '1900-08-01', '1901-07-15', NULL);

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-1900-1901'));

-- ph3.10 — first-ever: skeletons have id_prior_event=NULL and no city info
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_10 FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-1900-1901')
   AND (id_prior_event IS NOT NULL OR txt_location IS NOT NULL) \gset

ROLLBACK TO SAVEPOINT s_first;

SELECT is(:'ph3_10'::INT, 0, 'ph3.10: first-ever season skeletons have NULL prior + NULL location');

-- =========================================================================
-- ph3.12: Day-1 parity — new (CREATED) season ranklist == prior final ranklist
-- =========================================================================

SAVEPOINT s_parity;

-- Insert SPWS-2026-2027 (FK-matching engine via DEFAULT after Phase 3 migration)
-- ADR-077 Phase C: clear the seeded SPWS-2026-2027 first (savepoint-local; restored on ROLLBACK).
-- pgt-ignore-start typecheck: pg_temp helpers this file creates (the checker sees only the live schema)
SELECT pg_temp.seed_imported_2026_27_result('19.parity');
-- pgt-ignore-end typecheck

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

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));

-- Day-1 rolling for the new season (all-CREATED skeletons) must surface
-- carry-over scores from the prior season — i.e. the FK engine successfully
-- traces id_prior_event linkages from the freshly-created skeletons back to
-- prior events with results. We assert that the new season's rolling ranklist
-- has at least the same number of ranked fencers as the prior's final
-- ranklist for the most populated category (M EPEE V2). Exact total parity is
-- not asserted because the rolling engine includes the carry-chain (prior +
-- prior-of-prior within the 366-day cap), while the prior's final excludes
-- its own incoming chain.
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V2',
          (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
          TRUE) WHERE total_score > 0) AS ph3_12_new,
       (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V2', 3, FALSE)
          WHERE total_score > 0) AS ph3_12_prior \gset

ROLLBACK TO SAVEPOINT s_parity;

SELECT cmp_ok(
  :'ph3_12_new'::INT,
  '>=',
  :'ph3_12_prior'::INT - 5,
  'ph3.12: Day-1 rolling kadra of new CREATED season carries over from prior (>= prior count - 5)'
);

-- =========================================================================
-- ph3.13-14, ph3.22b: fn_create_season_with_skeletons (atomic wizard RPC)
-- =========================================================================

SAVEPOINT s_create;

-- ph3.13 — REMOVED: hardcoded skeleton count is not portable (same reason as
-- ph3.1). The atomic-wizard happy-path assertion needs to compare against a
-- computed expected count derived from prior-season config. To be rewritten
-- alongside ph3.1 v2. Side-effect coverage (season + scoring + skeletons
-- exist) is preserved by ph3.13b below.

-- ph3.13b — happy path: side-effects (no count assertion). Verifies the
-- atomic RPC creates the season row + scoring config + at least one skeleton
-- without asserting the exact count.
SAVEPOINT s_create_b;
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT skeletons_created AS ph3_13b FROM fn_create_season_with_skeletons(
  'SPWS-2027-2028',
  '2027-09-01'::DATE,
  '2028-07-31'::DATE,
  366,
  'DMEW',
  'EVENT_FK_MATCHING'::enum_event_carryover_engine,
  '{}'::JSONB,
  FALSE
) \gset
ROLLBACK TO SAVEPOINT s_create_b;

ROLLBACK TO SAVEPOINT s_create;

SELECT cmp_ok(
  :'ph3_13b'::INT,
  '>',
  0,
  'ph3.13b: fn_create_season_with_skeletons happy path creates >0 skeletons'
);

-- ph3.14 — rolls back on duplicate code (no partial state)
SAVEPOINT s_dup;
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COALESCE(pg_temp.error_of(
  $$SELECT fn_create_season_with_skeletons(
      'SPWS-2025-2026',
      '2099-09-01'::DATE,
      '2100-07-31'::DATE,
      366,
      'IMEW',
      'EVENT_FK_MATCHING'::enum_event_carryover_engine,
      '{}'::JSONB,
      FALSE
    )$$
), '') AS ph3_14 \gset
ROLLBACK TO SAVEPOINT s_dup;

SELECT ok(:'ph3_14' <> '', 'ph3.14: fn_create_season_with_skeletons rolls back on duplicate code');

-- ph3.22b — honors p_carryover_engine param (writes CODE when CODE passed)
SAVEPOINT s_engine;
SELECT fn_create_season_with_skeletons(
  'SPWS-2099-2100',
  '2099-09-01'::DATE,
  '2100-07-31'::DATE,
  366,
  'IMEW',
  'EVENT_CODE_MATCHING'::enum_event_carryover_engine,
  '{}'::JSONB,
  FALSE
);
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT (SELECT enum_carryover_engine::TEXT FROM tbl_season WHERE txt_code = 'SPWS-2099-2100') AS ph3_22b \gset
ROLLBACK TO SAVEPOINT s_engine;

SELECT is(
  :'ph3_22b'::TEXT,
  'EVENT_CODE_MATCHING'::TEXT,
  'ph3.22b: fn_create_season_with_skeletons honors p_carryover_engine (CODE)'
);

-- =========================================================================
-- ph3.15-17: fn_update_event v2 (cascade rename + id_prior_event picker)
-- =========================================================================

SAVEPOINT s_update;

-- ph3.15 — cascade rename of a freshly-init'd skeleton (deterministic 6 V2
-- children). Real seed events have mixed-V children which would make the
-- assertion brittle; using a skeleton is the realistic Phase 3 use case
-- anyway (admin renames a CREATED skeleton during planning).
-- ADR-077 Phase C: clear the seeded SPWS-2026-2027 first (savepoint-local; restored on ROLLBACK).
-- pgt-ignore-start typecheck: pg_temp helpers this file creates (the checker sees only the live schema)
SELECT pg_temp.seed_imported_2026_27_result('19.update');
-- pgt-ignore-end typecheck

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
SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));

-- The PEW skeleton this fixture renames used to come from fn_init_season. Since
-- migration 20260906000001 the bootstrap no longer provisions EVF events, so the
-- fixture builds its own — which it should have done anyway: the cascade-rename
-- behaviour under test has nothing to do with which kinds a season bootstraps.
INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status)
SELECT 'PEW1efs-2026-2027', 'PEW1efs-2026-2027',
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'),
       'CREATED';

-- fn_init_season creates CHILDLESS skeletons (ph3.6 v2), so build the 6 V2
-- children fixture explicitly to exercise fn_update_event's cascade rename.
INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category)
SELECT e.id_event, 'PEW1efs-V2-' || g || '-' || w || '-2026-2027', 'PEW',
       w::enum_weapon_type, g::enum_gender_type, 'V2'
  FROM tbl_event e,
       unnest(ARRAY['F', 'M']) AS g,
       unnest(ARRAY['EPEE', 'FOIL', 'SABRE']) AS w
 WHERE e.txt_code = 'PEW1efs-2026-2027';

SELECT fn_update_event(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  'PEW1B-2026-2027',               -- p_name (renamed too)
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  (SELECT dt_start FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  (SELECT dt_end FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  (SELECT txt_country FROM tbl_event WHERE txt_code = 'PEW1efs-2026-2027'),
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL,
  NULL, NULL, NULL, NULL,
  'PEW1B-2026-2027',               -- p_code: cascade rename
  NULL                             -- p_id_prior_event unchanged
);

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_15 FROM tbl_tournament t
  JOIN tbl_event e ON e.id_event = t.id_event
 WHERE e.txt_code = 'PEW1B-2026-2027'
   AND t.txt_code LIKE 'PEW1B-V2-%-2026-2027' \gset

ROLLBACK TO SAVEPOINT s_update;

SELECT is(:'ph3_15'::INT, 6, 'ph3.15: fn_update_event v2 cascades txt_code rename to all 6 V2 children');

-- ph3.16 — sets id_prior_event when picker value supplied
SAVEPOINT s_prior;
SELECT fn_update_event(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT txt_name FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT dt_start FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT dt_end FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT txt_country FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL,
  NULL, NULL, NULL, NULL,
  (SELECT txt_code FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT id_event FROM tbl_event WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025') AND txt_code ~ '^PEW1[efs]*-' ORDER BY id_event LIMIT 1)  -- p_id_prior_event
);
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT (SELECT id_prior_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026') AS ph3_16_got,
       (SELECT id_event FROM tbl_event WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2024-2025') AND txt_code ~ '^PEW1[efs]*-' ORDER BY id_event LIMIT 1) AS ph3_16_want \gset
ROLLBACK TO SAVEPOINT s_prior;

SELECT is(
  NULLIF(:'ph3_16_got', '')::INT,
  NULLIF(:'ph3_16_want', '')::INT,
  'ph3.16: fn_update_event v2 sets id_prior_event when picker value supplied'
);

-- ph3.17 — leaves child tournament codes alone when only name/dates change
SAVEPOINT s_namechg;

-- Snapshot child codes BEFORE the update
CREATE TEMP TABLE _child_codes_before AS
  SELECT txt_code FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026') ORDER BY id_tournament;

SELECT fn_update_event(
  (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  'A different name',              -- p_name (changed)
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT dt_start FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026') + 1,  -- p_dt_start changed
  (SELECT dt_end FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT url_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  (SELECT txt_country FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL,
  NULL, NULL, NULL, NULL,
  (SELECT txt_code FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),  -- p_code unchanged
  NULL                             -- p_id_prior_event unchanged
);

-- The two bags are equal when neither has a code the other lacks (EXCEPT ALL
-- both ways), which is what bag_eq compared.
-- pgt-ignore-start typecheck: temp tables/views this file creates (the checker sees only the live schema)
-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT NOT EXISTS (
  (SELECT txt_code FROM _child_codes_before
   EXCEPT ALL
   SELECT txt_code FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'))
  UNION ALL
  (SELECT txt_code FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026')
   EXCEPT ALL
   SELECT txt_code FROM _child_codes_before)
) AS ph3_17 \gset
-- pgt-ignore-end typecheck

ROLLBACK TO SAVEPOINT s_namechg;

SELECT ok(:'ph3_17'::BOOLEAN, 'ph3.17: fn_update_event v2 leaves child codes unchanged when only name/dates change');

-- =========================================================================
-- ph3.18-19: fn_revert_season_init
-- =========================================================================

SAVEPOINT s_revert;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2030-2031', '2030-09-01', '2031-07-31', 'DMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2030-2031'));

-- ph3.18 — happy path: deletes all skeletons + scoring + season
SELECT fn_revert_season_init((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2030-2031'));

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_18 FROM tbl_season WHERE txt_code = 'SPWS-2030-2031' \gset

ROLLBACK TO SAVEPOINT s_revert;

SELECT is(:'ph3_18'::INT, 0, 'ph3.18: fn_revert_season_init deletes season + skeletons + scoring (happy path)');

-- ph3.19 — ADR-077 §6: a CHILDLESS season is revertible even after its skeletons
-- advance past CREATED (e.g. an admin dates one to PLANNED). The widened guard is
-- on childlessness, not status — a childless PLANNED season carries no results.
SAVEPOINT s_revert_planned;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2031-2032', '2031-09-01', '2032-07-31', 'IMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032'));

-- Promote one skeleton to PLANNED to simulate admin progress (still childless).
UPDATE tbl_event
   SET enum_status = 'PLANNED'
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032')
   AND txt_code LIKE 'PPW1-%';

SELECT fn_revert_season_init((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032'));

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COUNT(*)::INT AS ph3_19 FROM tbl_season WHERE txt_code = 'SPWS-2031-2032' \gset

ROLLBACK TO SAVEPOINT s_revert_planned;

SELECT is(:'ph3_19'::INT, 0, 'ph3.19: fn_revert_season_init reverts a childless season even when a skeleton advanced to PLANNED');

-- ph3.19b — refuses once any event has a tbl_tournament child (results may exist).
SAVEPOINT s_refuse_children;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2032-2033', '2032-09-01', '2033-07-31', 'DMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2032-2033'));

-- Ingest a tournament child under one skeleton event → no longer childless.
INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category)
SELECT id_event, 'PPW1-V0-M-EPEE-2032-2033', 'PPW', 'EPEE', 'M', 'V0'
  FROM tbl_event
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2032-2033')
   AND txt_code LIKE 'PPW1-%'
 LIMIT 1;

-- pgt-ignore syntax: psql \gset meta-command; pg_prove runs this file through psql
SELECT COALESCE(pg_temp.error_of(
  $$SELECT fn_revert_season_init((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2032-2033'))$$
), '') AS ph3_19b \gset

ROLLBACK TO SAVEPOINT s_refuse_children;

SELECT ok(:'ph3_19b' <> '', 'ph3.19b: fn_revert_season_init refuses when an event has a tournament child');

SELECT * FROM finish();
ROLLBACK;
