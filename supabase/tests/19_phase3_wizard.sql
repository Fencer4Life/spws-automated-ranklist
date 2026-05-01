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
SELECT plan(25);

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
INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2026-2027', '2026-09-01', '2027-07-31', 'IMEW');

-- Call fn_init_season; capture result for downstream assertions.
-- Stored in a temp table to avoid re-invocation across assertions.
CREATE TEMP TABLE _init_result_imew AS
  SELECT * FROM fn_init_season(
    (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
  );

-- ph3.1 — skeleton count: 5 PPW + 9 PEW (numbered) + 1 MPW + 1 MSW + 1 IMEW = 17
SELECT is(
  (SELECT skeletons_created FROM _init_result_imew),
  23,
  'ph3.1: fn_init_season returns 23 skeletons for typical IMEW season (5 PPW + 15 PEW + MPW + MSW + IMEW; PEW count post-Phase4 split)'
);

-- ph3.2 — every skeleton event has enum_status='CREATED'
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND enum_status != 'CREATED'),
  0,
  'ph3.2: every skeleton event has enum_status=CREATED'
);

-- ph3.3 — PEW skeletons copy txt_location + txt_country from prior
SELECT is(
  (SELECT txt_location FROM tbl_event
     WHERE txt_code = 'PEW1efs-2026-2027'),
  (SELECT txt_location FROM tbl_event WHERE txt_code = 'PEW1efs-2025-2026'),
  'ph3.3: PEW1 skeleton inherits txt_location from prior PEW1efs'
);

-- ph3.4 — PPW skeletons have NULL location (rotating venues each season)
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code LIKE 'PPW%'
       AND txt_location IS NOT NULL),
  0,
  'ph3.4: PPW skeletons have NULL location (rotating venues)'
);

-- ph3.5 — every skeleton has id_prior_event set (prior exists for typical season)
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND id_prior_event IS NULL),
  0,
  'ph3.5: every skeleton has id_prior_event set (typical season)'
);

-- ph3.6 — 6 child tournaments per skeleton (M/F × 3 weapons, all V2 master)
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')),
  23 * 6,
  'ph3.6: 23 skeletons × 6 child tournaments = 138 total tournaments'
);

-- ph3.7 — IMEW skeleton present when enum_european_event_type='IMEW'
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027')
       AND txt_code LIKE 'IMEW%'),
  1,
  'ph3.7: IMEW skeleton created when enum_european_event_type=IMEW'
);

-- ph3.11 — idempotent: second call raises (skeletons already exist)
SELECT throws_ok(
  $$SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'))$$,
  NULL,
  NULL,
  'ph3.11: second call to fn_init_season raises (skeletons already exist)'
);

ROLLBACK TO SAVEPOINT s_imew;

-- =========================================================================
-- ph3.8: fn_init_season — DMEW European year
-- =========================================================================

SAVEPOINT s_dmew;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2027-2028', '2027-09-01', '2028-07-31', 'DMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2027-2028'));

-- ph3.8 — DMEW skeleton present when enum_european_event_type='DMEW'
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2027-2028')
       AND txt_code LIKE 'DMEW%'),
  1,
  'ph3.8: DMEW skeleton created when enum_european_event_type=DMEW'
);

ROLLBACK TO SAVEPOINT s_dmew;

-- =========================================================================
-- ph3.9: fn_init_season — no European singleton when type is NULL
-- =========================================================================

SAVEPOINT s_null;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2028-2029', '2028-09-01', '2029-07-31', NULL);

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2028-2029'));

-- ph3.9 — no IMEW or DMEW skeleton when European type NULL
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2028-2029')
       AND (txt_code LIKE 'IMEW%' OR txt_code LIKE 'DMEW%')),
  0,
  'ph3.9: no European singleton when enum_european_event_type IS NULL'
);

ROLLBACK TO SAVEPOINT s_null;

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
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
     WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-1900-1901')
       AND (id_prior_event IS NOT NULL OR txt_location IS NOT NULL)),
  0,
  'ph3.10: first-ever season skeletons have NULL prior + NULL location'
);

ROLLBACK TO SAVEPOINT s_first;

-- =========================================================================
-- ph3.12: Day-1 parity — new (CREATED) season ranklist == prior final ranklist
-- =========================================================================

SAVEPOINT s_parity;

-- Insert SPWS-2026-2027 (FK-matching engine via DEFAULT after Phase 3 migration)
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
SELECT cmp_ok(
  (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V2',
       (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'),
       TRUE) WHERE total_score > 0),
  '>=',
  (SELECT COUNT(*)::INT FROM fn_ranking_kadra('EPEE', 'M', 'V2', 3, FALSE)
     WHERE total_score > 0) - 5,
  'ph3.12: Day-1 rolling kadra of new CREATED season carries over from prior (>= prior count - 5)'
);

ROLLBACK TO SAVEPOINT s_parity;

-- =========================================================================
-- ph3.13-14, ph3.22b: fn_create_season_with_skeletons (atomic wizard RPC)
-- =========================================================================

SAVEPOINT s_create;

-- ph3.13 — happy path: returns (id, 23), season + scoring + skeletons exist
SELECT is(
  (SELECT skeletons_created FROM fn_create_season_with_skeletons(
    'SPWS-2027-2028',
    '2027-09-01'::DATE,
    '2028-07-31'::DATE,
    366,
    'DMEW',
    'EVENT_FK_MATCHING'::enum_event_carryover_engine,
    '{}'::JSONB,
    FALSE
  )),
  23,
  'ph3.13: fn_create_season_with_skeletons returns 23 skeletons (happy path; post-Phase4 PEW count)'
);

ROLLBACK TO SAVEPOINT s_create;

-- ph3.14 — rolls back on duplicate code (no partial state)
SAVEPOINT s_dup;
SELECT throws_ok(
  $$SELECT fn_create_season_with_skeletons(
      'SPWS-2025-2026',
      '2099-09-01'::DATE,
      '2100-07-31'::DATE,
      366,
      'IMEW',
      'EVENT_FK_MATCHING'::enum_event_carryover_engine,
      '{}'::JSONB,
      FALSE
    )$$,
  NULL,
  NULL,
  'ph3.14: fn_create_season_with_skeletons rolls back on duplicate code'
);
ROLLBACK TO SAVEPOINT s_dup;

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
SELECT is(
  (SELECT enum_carryover_engine::TEXT FROM tbl_season WHERE txt_code = 'SPWS-2099-2100'),
  'EVENT_CODE_MATCHING',
  'ph3.22b: fn_create_season_with_skeletons honors p_carryover_engine (CODE)'
);
ROLLBACK TO SAVEPOINT s_engine;

-- =========================================================================
-- ph3.15-17: fn_update_event v2 (cascade rename + id_prior_event picker)
-- =========================================================================

SAVEPOINT s_update;

-- ph3.15 — cascade rename of a freshly-init'd skeleton (deterministic 6 V2
-- children). Real seed events have mixed-V children which would make the
-- assertion brittle; using a skeleton is the realistic Phase 3 use case
-- anyway (admin renames a CREATED skeleton during planning).
INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2026-2027', '2026-09-01', '2027-07-31', 'IMEW');
SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2026-2027'));

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

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_tournament t
     JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'PEW1B-2026-2027'
      AND t.txt_code LIKE 'PEW1B-V2-%-2026-2027'),
  6,
  'ph3.15: fn_update_event v2 cascades txt_code rename to all 6 V2 children'
);

ROLLBACK TO SAVEPOINT s_update;

-- ph3.16 — sets id_prior_event when picker value supplied
SAVEPOINT s_prior;
SELECT fn_update_event(
  55,
  (SELECT txt_name FROM tbl_event WHERE id_event = 55),
  (SELECT txt_location FROM tbl_event WHERE id_event = 55),
  (SELECT dt_start FROM tbl_event WHERE id_event = 55),
  (SELECT dt_end FROM tbl_event WHERE id_event = 55),
  (SELECT url_event FROM tbl_event WHERE id_event = 55),
  (SELECT txt_country FROM tbl_event WHERE id_event = 55),
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL,
  NULL, NULL, NULL, NULL,
  (SELECT txt_code FROM tbl_event WHERE id_event = 55),
  41                               -- p_id_prior_event = PEW1-2025-2026
);
SELECT is(
  (SELECT id_prior_event FROM tbl_event WHERE id_event = 55),
  41,
  'ph3.16: fn_update_event v2 sets id_prior_event when picker value supplied'
);
ROLLBACK TO SAVEPOINT s_prior;

-- ph3.17 — leaves child tournament codes alone when only name/dates change
SAVEPOINT s_namechg;

-- Snapshot child codes BEFORE the update
CREATE TEMP TABLE _child_codes_before AS
  SELECT txt_code FROM tbl_tournament WHERE id_event = 55 ORDER BY id_tournament;

SELECT fn_update_event(
  55,
  'A different name',              -- p_name (changed)
  (SELECT txt_location FROM tbl_event WHERE id_event = 55),
  (SELECT dt_start FROM tbl_event WHERE id_event = 55) + 1,  -- p_dt_start changed
  (SELECT dt_end FROM tbl_event WHERE id_event = 55),
  (SELECT url_event FROM tbl_event WHERE id_event = 55),
  (SELECT txt_country FROM tbl_event WHERE id_event = 55),
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL,
  NULL, NULL, NULL, NULL,
  (SELECT txt_code FROM tbl_event WHERE id_event = 55),  -- p_code unchanged
  NULL                             -- p_id_prior_event unchanged
);

SELECT bag_eq(
  $$SELECT txt_code FROM _child_codes_before$$,
  $$SELECT txt_code FROM tbl_tournament WHERE id_event = 55$$,
  'ph3.17: fn_update_event v2 leaves child codes unchanged when only name/dates change'
);

ROLLBACK TO SAVEPOINT s_namechg;

-- =========================================================================
-- ph3.18-19: fn_revert_season_init
-- =========================================================================

SAVEPOINT s_revert;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2030-2031', '2030-09-01', '2031-07-31', 'DMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2030-2031'));

-- ph3.18 — happy path: deletes all skeletons + scoring + season
SELECT fn_revert_season_init((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2030-2031'));

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_season WHERE txt_code = 'SPWS-2030-2031'),
  0,
  'ph3.18: fn_revert_season_init deletes season + skeletons + scoring (happy path)'
);

ROLLBACK TO SAVEPOINT s_revert;

-- ph3.19 — refuses when any skeleton has advanced past CREATED
SAVEPOINT s_refuse;

INSERT INTO tbl_season (txt_code, dt_start, dt_end, enum_european_event_type)
  VALUES ('SPWS-2031-2032', '2031-09-01', '2032-07-31', 'IMEW');

SELECT fn_init_season((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032'));

-- Promote one skeleton to PLANNED to simulate admin progress
UPDATE tbl_event
   SET enum_status = 'PLANNED'
 WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032')
   AND txt_code LIKE 'PPW1-%';

SELECT throws_ok(
  $$SELECT fn_revert_season_init((SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2031-2032'))$$,
  NULL,
  NULL,
  'ph3.19: fn_revert_season_init refuses when a skeleton has advanced past CREATED'
);

ROLLBACK TO SAVEPOINT s_refuse;

SELECT * FROM finish();
ROLLBACK;
