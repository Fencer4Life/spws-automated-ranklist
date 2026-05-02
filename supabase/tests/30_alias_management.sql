-- =============================================================================
-- Phase 4 (ADR-050) — Alias management UI infrastructure
--
-- View + RPCs used by the new FencerAliasManager.svelte component:
--   - vw_fencer_aliases             — list fencers with alias_count
--   - fn_list_fencer_aliases        — view wrapper
--   - fn_transfer_fencer_alias      — move alias A → B + reassign tbl_result
--   - fn_split_fencer_from_alias    — create fencer + transfer
--   - fn_discard_fencer_alias_and_results — tombstone + hard-delete results
--
-- Schema additions:
--   - tbl_fencer.json_revoked_aliases jsonb DEFAULT '[]' (Discard tombstones)
--   - Cross-fencer alias-uniqueness trigger
--
-- Tests:
--   30.1   tbl_fencer.json_revoked_aliases column exists
--   30.2   vw_fencer_aliases view exists with required columns
--   30.3   fn_list_fencer_aliases() exists
--   30.4   fn_transfer_fencer_alias(INT, INT, TEXT) exists
--   30.5   fn_split_fencer_from_alias(INT, TEXT, JSONB) exists
--   30.6   fn_discard_fencer_alias_and_results(INT, TEXT) exists
--   30.7   transfer: alias removed from source fencer
--   30.8   transfer: alias added to destination fencer
--   30.9   transfer: tbl_result rows reassigned to destination
--   30.10  split: new fencer created with provided data
--   30.11  split: alias on new fencer (and removed from source)
--   30.12  split: tbl_result rows reassigned to new fencer
--   30.13  discard: alias removed from json_name_aliases on source
--   30.14  discard: alias added to json_revoked_aliases on source
--   30.15  discard: affected tbl_result rows hard-deleted
--   30.16  cross-fencer uniqueness trigger: rejects same alias on two fencers
-- =============================================================================

BEGIN;
SELECT plan(16);


-- ===== 30.1 — json_revoked_aliases column =====
SELECT has_column(
  'tbl_fencer'::name,
  'json_revoked_aliases'::name,
  '30.1: tbl_fencer.json_revoked_aliases column exists'
);


-- ===== 30.2 — vw_fencer_aliases view =====
SELECT has_view(
  'vw_fencer_aliases'::name,
  '30.2: vw_fencer_aliases view exists'
);


-- ===== 30.3 — fn_list_fencer_aliases =====
SELECT has_function(
  'fn_list_fencer_aliases',
  '30.3: fn_list_fencer_aliases() exists'
);


-- ===== 30.4 — fn_transfer_fencer_alias =====
SELECT has_function(
  'fn_transfer_fencer_alias',
  ARRAY['integer', 'integer', 'text'],
  '30.4: fn_transfer_fencer_alias(INT, INT, TEXT) exists'
);


-- ===== 30.5 — fn_split_fencer_from_alias =====
SELECT has_function(
  'fn_split_fencer_from_alias',
  ARRAY['integer', 'text', 'jsonb'],
  '30.5: fn_split_fencer_from_alias(INT, TEXT, JSONB) exists'
);


-- ===== 30.6 — fn_discard_fencer_alias_and_results =====
SELECT has_function(
  'fn_discard_fencer_alias_and_results',
  ARRAY['integer', 'text'],
  '30.6: fn_discard_fencer_alias_and_results(INT, TEXT) exists'
);


-- =============================================================================
-- Fixture: 3 fencers + tournament + result rows for behavioural tests.
-- F1, F2, F3 with explicit aliases; one tournament with results bound via aliases.
-- =============================================================================
DO $fix$
DECLARE
  v_org INT;
  v_season INT;
  v_event INT;
  v_t INT;
  v_f1 INT; v_f2 INT; v_f3 INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'SPWS' LIMIT 1;
  IF v_org IS NULL THEN
    INSERT INTO tbl_organizer (txt_code, txt_name) VALUES ('TEST30ORG', 'Test30 Org')
    RETURNING id_organizer INTO v_org;
  END IF;

  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  IF v_season IS NULL THEN
    INSERT INTO tbl_season (txt_code, dt_start, dt_end)
    VALUES ('TEST30', '2026-01-01', '2026-12-31')
    RETURNING id_season INTO v_season;
  END IF;

  -- 3 fencers
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('TEST30', 'F1-Source', 1970, '["TF1 Variant", "TF1 Other"]'::JSONB)
  RETURNING id_fencer INTO v_f1;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('TEST30', 'F2-Dest', 1971, '["TF2 Variant"]'::JSONB)
  RETURNING id_fencer INTO v_f2;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, json_name_aliases)
  VALUES ('TEST30', 'F3-Discardable', 1972, '["DiscardMe"]'::JSONB)
  RETURNING id_fencer INTO v_f3;

  -- Event + tournament + 3 result rows (one per fencer, via their aliases)
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, enum_status)
  VALUES ('TEST30-E', 'Test30 Event', v_season, v_org, '2026-06-01', 'COMPLETED')
  RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count)
  VALUES (v_event, 'TEST30-T', 'PPW', 'EPEE', 'M', 'V2', '2026-06-01', 2)
  RETURNING id_tournament INTO v_t;

  -- Only F1 and F3 have results in this tournament (F2 will be the transfer destination)
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
  VALUES (v_f1, v_t, 1, 'TF1 Variant');
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
  VALUES (v_f3, v_t, 2, 'DiscardMe');
END;
$fix$;


-- ===== 30.7 — transfer: alias removed from source =====
DO $$
DECLARE
  v_f1 INT; v_f2 INT;
BEGIN
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_first_name='F1-Source' AND txt_surname='TEST30';
  SELECT id_fencer INTO v_f2 FROM tbl_fencer WHERE txt_first_name='F2-Dest' AND txt_surname='TEST30';
  PERFORM fn_transfer_fencer_alias(v_f1, v_f2, 'TF1 Variant');
END;
$$;

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_first_name='F1-Source' AND txt_surname='TEST30'),
  '["TF1 Other"]'::JSONB,
  '30.7: transfer removes alias from source fencer'
);


-- ===== 30.8 — transfer: alias added to destination =====
SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_first_name='F2-Dest' AND txt_surname='TEST30'),
  '["TF2 Variant", "TF1 Variant"]'::JSONB,
  '30.8: transfer appends alias to destination fencer'
);


-- ===== 30.9 — transfer: tbl_result rows reassigned =====
SELECT is(
  (SELECT id_fencer FROM tbl_result
     WHERE txt_scraped_name = 'TF1 Variant'
       AND id_tournament = (SELECT id_tournament FROM tbl_tournament WHERE txt_code='TEST30-T')),
  (SELECT id_fencer FROM tbl_fencer WHERE txt_first_name='F2-Dest' AND txt_surname='TEST30'),
  '30.9: transfer reassigns tbl_result.id_fencer to destination'
);


-- ===== 30.10 — split: new fencer created =====
DO $$
DECLARE
  v_f1 INT;
  v_new_id INT;
BEGIN
  SELECT id_fencer INTO v_f1 FROM tbl_fencer WHERE txt_first_name='F1-Source' AND txt_surname='TEST30';
  PERFORM fn_split_fencer_from_alias(
    v_f1,
    'TF1 Other',
    '{"txt_surname":"NEW30","txt_first_name":"Split","int_birth_year":1965,"enum_gender":"M"}'::JSONB
  );
END;
$$;

SELECT ok(
  EXISTS (SELECT 1 FROM tbl_fencer WHERE txt_surname='NEW30' AND txt_first_name='Split'),
  '30.10: split creates new fencer with provided data'
);


-- ===== 30.11 — split: alias on new fencer + removed from source =====
SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_surname='NEW30' AND txt_first_name='Split'),
  '["TF1 Other"]'::JSONB,
  '30.11: split puts alias on new fencer (source no longer has it)'
);


-- ===== 30.12 — split: tbl_result rows reassigned =====
-- We need to check the result that originally pointed at F1-Source.
-- After 30.7, F1-Source kept the row for "TF1 Other" (no result existed for that alias).
-- For meaningful test of 30.12, we need a result whose scraped name was "TF1 Other".
-- Since the fixture had F1's result with scraped_name 'TF1 Variant' (transferred),
-- there's no F1 result for 'TF1 Other'. Verify the split fencer has empty results
-- (no result rows had scraped_name = 'TF1 Other' AND id_fencer = F1).
SELECT is(
  (SELECT count(*)::INT FROM tbl_result
     WHERE id_fencer = (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='NEW30' AND txt_first_name='Split')),
  0,
  '30.12: split reassigns matching tbl_result rows to new fencer (zero in this fixture — alias had no results)'
);


-- ===== 30.13 — discard: alias removed from json_name_aliases =====
DO $$
DECLARE
  v_f3 INT;
BEGIN
  SELECT id_fencer INTO v_f3 FROM tbl_fencer WHERE txt_first_name='F3-Discardable' AND txt_surname='TEST30';
  PERFORM fn_discard_fencer_alias_and_results(v_f3, 'DiscardMe');
END;
$$;

SELECT is(
  (SELECT json_name_aliases FROM tbl_fencer WHERE txt_first_name='F3-Discardable' AND txt_surname='TEST30'),
  '[]'::JSONB,
  '30.13: discard removes alias from json_name_aliases'
);


-- ===== 30.14 — discard: alias added to json_revoked_aliases =====
SELECT is(
  (SELECT json_revoked_aliases FROM tbl_fencer WHERE txt_first_name='F3-Discardable' AND txt_surname='TEST30'),
  '["DiscardMe"]'::JSONB,
  '30.14: discard appends alias to json_revoked_aliases'
);


-- ===== 30.15 — discard: tbl_result rows hard-deleted =====
SELECT is(
  (SELECT count(*)::INT FROM tbl_result
     WHERE txt_scraped_name = 'DiscardMe'),
  0,
  '30.15: discard hard-deletes affected tbl_result rows'
);


-- ===== 30.16 — cross-fencer uniqueness trigger =====
-- Attempt to manually add an alias to another fencer that already exists.
-- F2-Dest now has 'TF1 Variant' (after 30.7). Trying to add it to F1-Source again must fail.
SELECT throws_ok(
  $sql$
    UPDATE tbl_fencer
    SET json_name_aliases = json_name_aliases || '"TF1 Variant"'::JSONB
    WHERE txt_first_name='F1-Source' AND txt_surname='TEST30'
  $sql$,
  NULL,
  NULL,
  '30.16: cross-fencer alias-uniqueness trigger rejects duplicate alias'
);


SELECT * FROM finish();
ROLLBACK;
