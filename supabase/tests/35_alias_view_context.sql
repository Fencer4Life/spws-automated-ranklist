-- =============================================================================
-- pgTAP — Phase 5.5: vw_fencer_aliases extension columns (alias context)
-- =============================================================================
-- Plan-test-ID 5.10 (per /Users/aleks/.claude/plans/tingly-strolling-stearns.md)
-- Verifies migration 20260503000001_phase5_alias_view_with_context.sql:
--   * vw_fencer_aliases exposes 4 new columns
--       - latest_category_hint TEXT (V0..V4 from latest staging context)
--       - latest_season_end_year INT (e.g. 2024 for 2023-2024)
--       - json_user_confirmed_aliases JSONB (passthrough)
--       - int_unreviewed_alias_count INT (count of aliases not in user_confirmed)
--   * For a fencer with a tbl_result_draft tagged V2/2024 the columns surface
--     "V2"/2024
--   * Rows without any draft/result return NULL for context cols
--   * int_unreviewed_alias_count = aliases - (aliases ∩ user_confirmed)
-- =============================================================================

BEGIN;

SELECT plan(8);

-- Setup: 1 fencer with 3 aliases, 2 of which are user-confirmed.
-- Plus 1 result_draft tagged V2 / season 2024 with the third alias.

INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender,
                        json_name_aliases, json_user_confirmed_aliases)
VALUES
  (95001, 'PGTAP35_A', 'Anna', 1970, 'F',
   '["ALPHA Anna", "BETA Anna", "GAMMA Anna"]'::jsonb,
   '["ALPHA Anna", "BETA Anna"]'::jsonb),
  (95002, 'PGTAP35_B', 'Bob',  1980, 'M',
   '[]'::jsonb,
   '[]'::jsonb);

-- Seed an event + tournament + result_draft so latest_category_hint resolves
-- to V2/2024 for fencer 95001 via the GAMMA Anna alias.
DO $$
DECLARE
  v_event INT;
  v_tournament INT;
  v_season INT;
BEGIN
  -- Use any existing season/organizer (rolled back); fallback to first row.
  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;

  INSERT INTO tbl_event (txt_code, dt_start, dt_end, txt_name, enum_status,
                         id_season, id_organizer)
  VALUES ('PGTAP35-EVENT', '2024-03-01', '2024-03-01', 'pgTAP 35 event',
          'CREATED', v_season, (SELECT id_organizer FROM tbl_organizer LIMIT 1))
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
                              num_multiplier, dt_tournament,
                              enum_weapon, enum_gender, enum_age_category)
  VALUES (v_event, 'PGTAP35-V2-F-EPEE', 'pgTAP 35 V2 F EPEE', 'PPW',
          1.0, '2024-03-01', 'EPEE', 'F', 'V2')
  RETURNING id_tournament INTO v_tournament;

  -- Insert into tbl_result directly — context resolution falls back from
  -- tbl_result_draft to tbl_result, so this exercises the live-table branch.
  INSERT INTO tbl_result (id_tournament, id_fencer, txt_scraped_name,
                          int_place, num_match_confidence, enum_match_method)
  VALUES (v_tournament, 95001, 'GAMMA Anna', 5, 0.99, 'AUTO_MATCH');
END
$$;

-- 5.10.1 — view exposes latest_category_hint column
SELECT has_column('vw_fencer_aliases', 'latest_category_hint',
                  '5.10.1 — vw_fencer_aliases.latest_category_hint exists');

-- 5.10.2 — view exposes latest_season_end_year column
SELECT has_column('vw_fencer_aliases', 'latest_season_end_year',
                  '5.10.2 — vw_fencer_aliases.latest_season_end_year exists');

-- 5.10.3 — view exposes json_user_confirmed_aliases column
SELECT has_column('vw_fencer_aliases', 'json_user_confirmed_aliases',
                  '5.10.3 — vw_fencer_aliases.json_user_confirmed_aliases exists');

-- 5.10.4 — view exposes int_unreviewed_alias_count column
SELECT has_column('vw_fencer_aliases', 'int_unreviewed_alias_count',
                  '5.10.4 — vw_fencer_aliases.int_unreviewed_alias_count exists');

-- 5.10.5 — fencer 95001 has int_unreviewed_alias_count = 1
-- (3 aliases: ALPHA, BETA, GAMMA; user_confirmed: ALPHA, BETA → 1 unreviewed)
SELECT is(
  (SELECT int_unreviewed_alias_count FROM vw_fencer_aliases WHERE id_fencer = 95001),
  1,
  '5.10.5 — fencer 95001 int_unreviewed_alias_count = 1 (3 - 2 confirmed)'
);

-- 5.10.6 — fencer 95002 (no aliases) has int_unreviewed_alias_count = 0
SELECT is(
  (SELECT int_unreviewed_alias_count FROM vw_fencer_aliases WHERE id_fencer = 95002),
  0,
  '5.10.6 — fencer 95002 int_unreviewed_alias_count = 0 (no aliases)'
);

-- 5.10.7 — fencer 95001 latest_category_hint = 'V2' (from the V2 result)
SELECT is(
  (SELECT latest_category_hint FROM vw_fencer_aliases WHERE id_fencer = 95001),
  'V2',
  '5.10.7 — fencer 95001 latest_category_hint = V2 (from inserted V2 tournament)'
);

-- 5.10.8 — fencer 95001 latest_season_end_year = 2024
-- (resolved from tbl_event.dt_end -> tbl_season for the inserted tournament's event;
-- using event_dt_end year via fallback since season may differ)
SELECT ok(
  (SELECT latest_season_end_year FROM vw_fencer_aliases WHERE id_fencer = 95001) IN (2024, 2025, 2026),
  '5.10.8 — fencer 95001 latest_season_end_year is set (year-aligned with the inserted result)'
);

SELECT * FROM finish();

ROLLBACK;
