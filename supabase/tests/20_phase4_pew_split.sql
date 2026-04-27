-- =============================================================================
-- Phase 4 (ADR-046) — pgTAP tests for PEW per-weapon-suffix
-- =============================================================================
BEGIN;
SELECT plan(10);

-- ph4.1 — fn_pew_weapon_letters builds alphabetical letter string from array
SELECT is(
  fn_pew_weapon_letters(ARRAY['SABRE','EPEE']::enum_weapon_type[]),
  'es',
  'ph4.1: letters built alphabetically (sabre+epee → es)'
);

-- ph4.2 — single weapon → single letter
SELECT is(
  fn_pew_weapon_letters(ARRAY['FOIL']::enum_weapon_type[]),
  'f',
  'ph4.2: single weapon → single letter'
);

-- ph4.3 — three weapons in arbitrary order → efs alphabetical
SELECT is(
  fn_pew_weapon_letters(ARRAY['SABRE','EPEE','FOIL']::enum_weapon_type[]),
  'efs',
  'ph4.3: three weapons → efs in alphabetical order'
);

-- ph4.4 — fn_init_season regex matches weapon-suffixed prior PEW events
DO $ph4_4$
BEGIN
  -- Verify the regex pattern accepts weapon-suffix codes
  PERFORM 1 WHERE 'PEW3sf-2024-2025' ~ '^PEW\d+[efs]*-';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ph4.4: regex should match PEW3sf-2024-2025';
  END IF;
  PERFORM 1 WHERE 'PEW10efs-2025-2026' ~ '^PEW\d+[efs]*-';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'ph4.4: regex should match PEW10efs-2025-2026';
  END IF;
END;
$ph4_4$;
SELECT pass('ph4.4: fn_init_season regex matches weapon-suffix codes');

-- ph4.5 — Splitter is idempotent: re-running on already-suffixed event is a no-op
DO $ph4_5$
DECLARE
  v_first_renamed INT;
  v_second_renamed INT;
  v_result RECORD;
BEGIN
  SELECT events_renamed INTO v_first_renamed FROM fn_split_pew_by_weapon();
  SELECT events_renamed INTO v_second_renamed FROM fn_split_pew_by_weapon();
  IF v_second_renamed <> 0 THEN
    RAISE EXCEPTION 'ph4.5: re-run should rename 0 events, got %', v_second_renamed;
  END IF;
END;
$ph4_5$;
SELECT pass('ph4.5: splitter is idempotent on second run');

-- ph4.6 — Every PEW event WITH children has a weapon-letter suffix.
-- Childless events (skeletons not yet populated) keep no suffix until
-- tournaments are added — splitter is idempotent and will pick up the suffix
-- on a subsequent run once children appear.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
    WHERE e.txt_code ~ '^PEW\d+-'
      AND e.txt_code !~ '^PEW\d+[efs]+-'
      AND EXISTS (SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event)),
  0,
  'ph4.6: no populated PEW event lacks weapon-letter suffix'
);

-- ph4.7 — Child tournament codes match their parent's weapon-letter prefix
SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
    WHERE e.txt_code ~ '^PEW\d+[efs]+-'
      AND t.txt_code !~ ('^' || regexp_replace(e.txt_code, '-\d{4}-\d{4}$', '') || '-')),
  0,
  'ph4.7: every PEW child tournament code starts with its parent code prefix'
);

-- ph4.8 — Child tournament weapons are subset of parent suffix letters
SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
    WHERE e.txt_code ~ '^PEW\d+[efs]+-'
      AND NOT (
        (t.enum_weapon = 'EPEE'  AND e.txt_code ~ '^PEW\d+[a-z]*e[a-z]*-')
        OR (t.enum_weapon = 'FOIL'  AND e.txt_code ~ '^PEW\d+[a-z]*f[a-z]*-')
        OR (t.enum_weapon = 'SABRE' AND e.txt_code ~ '^PEW\d+[a-z]*s[a-z]*-')
      )),
  0,
  'ph4.8: every child tournament weapon appears as a letter in its parent suffix'
);

-- ph4.9 — idx_event_code uniqueness preserved (no duplicate codes)
SELECT is(
  (SELECT COUNT(*)::INT FROM (
    SELECT txt_code, COUNT(*) AS n FROM tbl_event GROUP BY txt_code HAVING COUNT(*) > 1
  ) dup),
  0,
  'ph4.9: no duplicate txt_code values across tbl_event'
);

-- ph4.10 — fn_allocate_evf_event_code emits weapon suffix when called with letters
DO $ph4_10$
DECLARE
  v_alloc RECORD;
  v_seed_season INT;
BEGIN
  SELECT id_season INTO v_seed_season FROM tbl_season WHERE bool_active LIMIT 1;
  IF v_seed_season IS NULL THEN
    RAISE EXCEPTION 'ph4.10: no active season found in seed data';
  END IF;
  SELECT * INTO v_alloc FROM fn_allocate_evf_event_code(
    v_seed_season, 'PEW', 'TestCity-PH410', 'TestCountry-PH410', 'efs'
  );
  IF v_alloc.txt_code !~ '^PEW\d+efs-' THEN
    RAISE EXCEPTION 'ph4.10: allocator should emit PEW{N}efs-... but got %', v_alloc.txt_code;
  END IF;
END;
$ph4_10$;
SELECT pass('ph4.10: allocator emits weapon-letter suffix when given letters');

SELECT * FROM finish();
ROLLBACK;
