-- =============================================================================
-- fn_split_pew_by_weapon collision resilience (ADR-046 amendment, 2026-06-25)
-- =============================================================================
-- The idempotent LOCAL/CERT reconciliation splitter renames each PEW event to a
-- weapon-letter-suffixed code derived from its children's weapons. A malformed
-- EVF placeholder export can make two events resolve to the SAME target code.
-- Pre-amendment that aborted the whole seed load on idx_event_code. The splitter
-- now (1) PRUNES empty placeholder child slots whose weapon contradicts the
-- event's explicit code suffix, and (2) RESOLVES a genuine code collision by
-- provenance: an empty (0-result) duplicate is merged away so the result-bearing
-- event takes the code; a collision between two result-bearing events is skipped
-- (WARNING) for operator review. No result row is ever deleted.
--   C.1 — splitter completes without aborting on collisions
--   C.2 — empty mismatched child slot is pruned
--   C.3 — matching child slot is kept
--   C.4 — empty duplicate event is merged (deleted) on collision
--   C.5 — the result-bearing event takes the freed code
--   C.6 — a result-bearing-vs-result-bearing collision is skipped (both kept)
-- =============================================================================

BEGIN;
SELECT plan(6);

-- Legacy-style fixture V-cats predate the FATAL vcat invariant; bypass it.
ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;

-- Far-future test season so the fixture never overlaps real seed events.
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_fencer INT;
  v_id     INT;
BEGIN
  v_season := fn_create_season('SPLITCOLL', '2099-09-01', '2100-06-30');
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_fencer    INTO v_fencer FROM tbl_fencer LIMIT 1;

  -- PRUNE: sabre-coded event with an empty SABRE slot + an empty (mismatched)
  -- EPEE slot. The EPEE slot must be pruned; the SABRE slot kept; code unchanged.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_country)
  VALUES ('PEW90s-2099-2100', 'prune', v_season, v_org, 'PLANNED', '2099-10-01', 'T') RETURNING id_event INTO v_id;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status) VALUES
    (v_id, 'P90-S', 's', 'PEW', 'SABRE', 'M', 'V2', '2099-10-01', 5, 'PLANNED'),
    (v_id, 'P90-E', 'e', 'PEW', 'EPEE',  'M', 'V2', '2099-10-01', 5, 'PLANNED');

  -- MERGE: an EMPTY PEW91efs duplicate + a RESULT-BEARING event whose efs
  -- children resolve to PEW91efs. The empty one must be deleted; the
  -- result-bearing one renamed onto PEW91efs.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_country)
  VALUES ('PEW91efs-2099-2100', 'empty dup', v_season, v_org, 'PLANNED', '2099-11-01', 'T') RETURNING id_event INTO v_id;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status) VALUES
    (v_id, 'X91-E', 'e', 'PEW', 'EPEE',  'M', 'V2', '2099-11-01', 5, 'PLANNED'),
    (v_id, 'X91-F', 'f', 'PEW', 'FOIL',  'M', 'V2', '2099-11-01', 5, 'PLANNED'),
    (v_id, 'X91-S', 's', 'PEW', 'SABRE', 'M', 'V2', '2099-11-01', 5, 'PLANNED');

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_country)
  VALUES ('PEW91e-2099-2100', 'result dup', v_season, v_org, 'COMPLETED', '2099-11-01', 'T') RETURNING id_event INTO v_id;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status) VALUES
    (v_id, 'Y91-E', 'e', 'PEW', 'EPEE',  'M', 'V2', '2099-11-01', 5, 'SCORED'),
    (v_id, 'Y91-F', 'f', 'PEW', 'FOIL',  'M', 'V2', '2099-11-01', 5, 'SCORED'),
    (v_id, 'Y91-S', 's', 'PEW', 'SABRE', 'M', 'V2', '2099-11-01', 5, 'SCORED');
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
    SELECT v_fencer, id_tournament, 1, 'res' FROM tbl_tournament WHERE id_event = v_id;

  -- SKIP: two RESULT-BEARING events resolving to the same code. The second must
  -- be skipped (kept under its own code); neither loses data.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_country)
  VALUES ('PEW92efs-2099-2100', 'target', v_season, v_org, 'COMPLETED', '2099-12-01', 'T') RETURNING id_event INTO v_id;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status) VALUES
    (v_id, 'PR92-E', 'e', 'PEW', 'EPEE',  'M', 'V2', '2099-12-01', 5, 'SCORED'),
    (v_id, 'PR92-F', 'f', 'PEW', 'FOIL',  'M', 'V2', '2099-12-01', 5, 'SCORED'),
    (v_id, 'PR92-S', 's', 'PEW', 'SABRE', 'M', 'V2', '2099-12-01', 5, 'SCORED');
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
    SELECT v_fencer, id_tournament, 1, 'res' FROM tbl_tournament WHERE id_event = v_id;

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, txt_country)
  VALUES ('PEW92e-2099-2100', 'loser', v_season, v_org, 'COMPLETED', '2099-12-01', 'T') RETURNING id_event INTO v_id;
  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament, int_participant_count, enum_import_status) VALUES
    (v_id, 'QR92-E', 'e', 'PEW', 'EPEE',  'M', 'V2', '2099-12-01', 5, 'SCORED'),
    (v_id, 'QR92-F', 'f', 'PEW', 'FOIL',  'M', 'V2', '2099-12-01', 5, 'SCORED'),
    (v_id, 'QR92-S', 's', 'PEW', 'SABRE', 'M', 'V2', '2099-12-01', 5, 'SCORED');
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place, txt_scraped_name)
    SELECT v_fencer, id_tournament, 1, 'res' FROM tbl_tournament WHERE id_event = v_id;
END;
$setup$;

SELECT lives_ok(
  $$ SELECT fn_split_pew_by_weapon() $$,
  'C.1: fn_split_pew_by_weapon completes without aborting on code collisions'
);

SELECT is(
  (SELECT count(*)::INT FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'PEW90s-2099-2100' AND t.enum_weapon = 'EPEE'),
  0,
  'C.2: empty mismatched EPEE slot pruned from sabre-coded PEW90s'
);

SELECT is(
  (SELECT count(*)::INT FROM tbl_tournament t JOIN tbl_event e ON e.id_event = t.id_event
    WHERE e.txt_code = 'PEW90s-2099-2100' AND t.enum_weapon = 'SABRE'),
  1,
  'C.3: matching SABRE slot kept under PEW90s'
);

SELECT is(
  (SELECT count(*)::INT FROM tbl_event WHERE txt_name = 'empty dup'),
  0,
  'C.4: empty duplicate event merged (deleted) on collision'
);

SELECT is(
  (SELECT txt_code FROM tbl_event WHERE txt_name = 'result dup'),
  'PEW91efs-2099-2100',
  'C.5: result-bearing event renamed onto the freed PEW91efs code'
);

SELECT is(
  (SELECT txt_code FROM tbl_event WHERE txt_name = 'loser'),
  'PEW92e-2099-2100',
  'C.6: result-bearing collision skipped — loser keeps its code, both preserved'
);

SELECT * FROM finish();
ROLLBACK;
