-- =============================================================================
-- pgTAP — Phase 5.5: alias RPCs return id_tournaments[] + tournament_labels[]
-- =============================================================================
-- Plan-test-ID 5.11 (per /Users/aleks/.claude/plans/tingly-strolling-stearns.md)
-- Verifies migration 20260503000002_phase5_alias_rpcs_return_tournaments.sql:
--   * fn_transfer_fencer_alias returns id_tournaments INT[] + tournament_labels TEXT[]
--   * fn_discard_fencer_alias_and_results returns id_tournaments INT[] + tournament_labels TEXT[]
--   * fn_split_fencer_from_alias passes through transfer_result with the new keys
--   * For an alias spanning 2 tournaments across 2 events, returned arrays
--     have length 2 with shape "<event_code> / <vcat> / <weapon> / <gender>"
--
-- Cross-event scenario: same (id_fencer, txt_scraped_name) appears in two
-- tournaments under two different events — the cascade discovers both and
-- recomputes scoring for both.
-- =============================================================================

BEGIN;

SELECT plan(8);

-- Fixture: 2 events, 2 tournaments (one per event), 2 result rows for the
-- same (fencer #97001, alias "MULTI Marek").
DO $fix$
DECLARE
  v_org INT;
  v_season INT;
  v_event1 INT;
  v_event2 INT;
  v_t1 INT;
  v_t2 INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer ORDER BY id_organizer LIMIT 1;
  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;

  INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender,
                          json_name_aliases)
  VALUES
    (97001, 'PGTAP36_SRC', 'Source', 1970, 'M', '["MULTI Marek"]'::jsonb),
    (97002, 'PGTAP36_DST', 'Dest',   1970, 'M', '[]'::jsonb);

  INSERT INTO tbl_event (txt_code, dt_start, dt_end, txt_name, enum_status,
                         id_season, id_organizer)
  VALUES ('PGTAP36-EV-A', '2024-04-01', '2024-04-01', 'pgTAP 36 event A', 'COMPLETED',
          v_season, v_org)
  RETURNING id_event INTO v_event1;

  INSERT INTO tbl_event (txt_code, dt_start, dt_end, txt_name, enum_status,
                         id_season, id_organizer)
  VALUES ('PGTAP36-EV-B', '2024-05-01', '2024-05-01', 'pgTAP 36 event B', 'COMPLETED',
          v_season, v_org)
  RETURNING id_event INTO v_event2;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, num_multiplier,
                              dt_tournament, enum_weapon, enum_gender, enum_age_category,
                              int_participant_count)
  VALUES (v_event1, 'PGTAP36-T-A-V2-M-EPEE', 'pgTAP 36 t A V2 M EPEE', 'PPW', 1.0,
          '2024-04-01', 'EPEE', 'M', 'V2', 1)
  RETURNING id_tournament INTO v_t1;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, num_multiplier,
                              dt_tournament, enum_weapon, enum_gender, enum_age_category,
                              int_participant_count)
  VALUES (v_event2, 'PGTAP36-T-B-V2-M-EPEE', 'pgTAP 36 t B V2 M EPEE', 'PPW', 1.0,
          '2024-05-01', 'EPEE', 'M', 'V2', 1)
  RETURNING id_tournament INTO v_t2;

  INSERT INTO tbl_result (id_tournament, id_fencer, txt_scraped_name, int_place,
                          num_match_confidence, enum_match_method)
  VALUES
    (v_t1, 97001, 'MULTI Marek', 5, 0.9, 'AUTO_MATCH'),
    (v_t2, 97001, 'MULTI Marek', 7, 0.9, 'AUTO_MATCH');
END
$fix$;

-- ============================================================================
-- 5.11.1-3 — fn_transfer_fencer_alias returns id_tournaments + labels
-- ============================================================================
DO $$
DECLARE
  v_result JSONB;
  v_ids JSONB;
  v_labels JSONB;
BEGIN
  v_result := fn_transfer_fencer_alias(97001, 97002, 'MULTI Marek');
  -- Stash for the SELECT-based assertions below using a temp table
  CREATE TEMP TABLE _spws_36_transfer (result JSONB);
  INSERT INTO _spws_36_transfer VALUES (v_result);
END
$$;

-- 5.11.1 — id_tournaments key present, length 2
SELECT is(
  (SELECT jsonb_array_length(result -> 'id_tournaments')
     FROM _spws_36_transfer),
  2,
  '5.11.1 — fn_transfer_fencer_alias.id_tournaments has length 2 (cross-event cascade)'
);

-- 5.11.2 — tournament_labels key present, length 2
SELECT is(
  (SELECT jsonb_array_length(result -> 'tournament_labels')
     FROM _spws_36_transfer),
  2,
  '5.11.2 — fn_transfer_fencer_alias.tournament_labels has length 2'
);

-- 5.11.3 — labels include both event codes
SELECT ok(
  (SELECT EXISTS (
     SELECT 1 FROM jsonb_array_elements_text(result -> 'tournament_labels') l(label)
      WHERE l.label LIKE 'PGTAP36-EV-A%'
   ) AND EXISTS (
     SELECT 1 FROM jsonb_array_elements_text(result -> 'tournament_labels') l(label)
      WHERE l.label LIKE 'PGTAP36-EV-B%'
   ) FROM _spws_36_transfer),
  '5.11.3 — labels include both PGTAP36-EV-A and PGTAP36-EV-B'
);

-- 5.11.4 — tournaments_recomputed count matches array length
SELECT is(
  (SELECT (result ->> 'tournaments_recomputed')::INT FROM _spws_36_transfer),
  2,
  '5.11.4 — tournaments_recomputed = 2 matches array length'
);

-- ============================================================================
-- 5.11.5-6 — fn_discard_fencer_alias_and_results returns the same shape
-- ============================================================================
-- Reset fixture: re-add alias + result rows on fencer 97001 to discard
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender,
                        json_name_aliases)
VALUES (97003, 'PGTAP36_DISCARD', 'Discardable', 1970, 'M',
        '["TRASH Tomek"]'::jsonb);

INSERT INTO tbl_result (id_tournament, id_fencer, txt_scraped_name, int_place,
                        num_match_confidence, enum_match_method)
SELECT id_tournament, 97003, 'TRASH Tomek', 9, 0.5, 'AUTO_MATCH'
  FROM tbl_tournament WHERE txt_code IN ('PGTAP36-T-A-V2-M-EPEE', 'PGTAP36-T-B-V2-M-EPEE');

DO $$
DECLARE
  v_result JSONB;
BEGIN
  v_result := fn_discard_fencer_alias_and_results(97003, 'TRASH Tomek');
  CREATE TEMP TABLE _spws_36_discard (result JSONB);
  INSERT INTO _spws_36_discard VALUES (v_result);
END
$$;

-- 5.11.5 — discard.id_tournaments has length 2
SELECT is(
  (SELECT jsonb_array_length(result -> 'id_tournaments')
     FROM _spws_36_discard),
  2,
  '5.11.5 — fn_discard_fencer_alias_and_results.id_tournaments has length 2'
);

-- 5.11.6 — discard.tournament_labels has length 2
SELECT is(
  (SELECT jsonb_array_length(result -> 'tournament_labels')
     FROM _spws_36_discard),
  2,
  '5.11.6 — fn_discard_fencer_alias_and_results.tournament_labels has length 2'
);

-- ============================================================================
-- 5.11.7-8 — fn_split_fencer_from_alias passes through new keys via transfer_result
-- ============================================================================
INSERT INTO tbl_fencer (id_fencer, txt_surname, txt_first_name, int_birth_year, enum_gender,
                        json_name_aliases)
VALUES (97004, 'PGTAP36_SPLIT_SRC', 'SplitSrc', 1970, 'M',
        '["SPLIT Sara"]'::jsonb);

INSERT INTO tbl_result (id_tournament, id_fencer, txt_scraped_name, int_place,
                        num_match_confidence, enum_match_method)
SELECT id_tournament, 97004, 'SPLIT Sara', 3, 0.7, 'AUTO_MATCH'
  FROM tbl_tournament WHERE txt_code = 'PGTAP36-T-A-V2-M-EPEE';

DO $$
DECLARE
  v_result JSONB;
BEGIN
  v_result := fn_split_fencer_from_alias(97004, 'SPLIT Sara',
    jsonb_build_object(
      'txt_surname', 'SPLIT', 'txt_first_name', 'Sara',
      'int_birth_year', 1974, 'enum_gender', 'F'  -- BY=1974 → V2 for 2024 season
    ));
  CREATE TEMP TABLE _spws_36_split (result JSONB);
  INSERT INTO _spws_36_split VALUES (v_result);
END
$$;

-- 5.11.7 — split.transfer_result.id_tournaments has length 1 (single event)
SELECT is(
  (SELECT jsonb_array_length((result -> 'transfer_result') -> 'id_tournaments')
     FROM _spws_36_split),
  1,
  '5.11.7 — fn_split_fencer_from_alias.transfer_result.id_tournaments has length 1'
);

-- 5.11.8 — split.transfer_result.tournament_labels[0] starts with PGTAP36-EV-A
SELECT ok(
  (SELECT (((result -> 'transfer_result') -> 'tournament_labels') ->> 0) LIKE 'PGTAP36-EV-A%'
     FROM _spws_36_split),
  '5.11.8 — fn_split_fencer_from_alias label[0] starts with PGTAP36-EV-A'
);

SELECT * FROM finish();

ROLLBACK;
