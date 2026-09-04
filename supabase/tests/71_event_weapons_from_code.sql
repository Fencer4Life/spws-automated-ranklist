-- =============================================================================
-- pgTAP — the event's weapons live on the event, and the guard that fills them
--         actually fires
-- =============================================================================
-- Verifies migration 20260904000001_event_weapons_from_code.sql.
--
-- THE BUG THIS PINS. fn_refresh_evf_event_urls filled arr_weapons behind
--
--     arr_weapons = CASE WHEN arr_weapons IS NULL
--                          THEN COALESCE(v_weapons, arr_weapons)
--                        ELSE arr_weapons END
--
-- while the column was declared DEFAULT '{EPEE,FOIL,SABRE}'. A column with a
-- non-null default is never NULL, so the branch never ran and the scraper's
-- resolved weapons never reached the row. Measured on CERT before the fix: 53 of
-- 69 events whose code carries a weapon suffix sat on the untouched default, and
-- 35 of them disagreed with their own code -- PEW10e (epee only) advertising
-- foil and sabre.
--
-- The class of bug is "a fill-blank guard written against NULL on a column that
-- carries a DEFAULT", so 71.3 pins the schema itself: no default, so NULL can
-- mean unset again and the guard is reachable.
--
-- The code suffix is the authoritative weapon record (ADR-046, ADR-086), so for
-- events whose code carries one it is also what arr_weapons must agree with --
-- 71.5 asserts that across the whole corpus, which is the assertion that would
-- have caught all 35 rows at once.
--
-- Plan-test-ID 71.
-- =============================================================================

BEGIN;

SELECT plan(9);

-- ----- 71.1-71.3 the schema ---------------------------------------------------
SELECT has_column('tbl_event', 'arr_weapons', '71.1 — tbl_event.arr_weapons exists');

SELECT col_type_is('tbl_event', 'arr_weapons', 'enum_weapon_type[]',
  '71.2 — arr_weapons is an enum_weapon_type array');

SELECT col_hasnt_default('tbl_event', 'arr_weapons',
  '71.3 — arr_weapons has NO column default, so NULL means unset and a '
  'NULL-guarded fill is reachable. Re-adding a default silently disables '
  'every such guard.');

-- ----- fixtures ---------------------------------------------------------------
DO $setup$
DECLARE
  v_season INT;
  v_evf    INT;
  v_spws   INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
  VALUES ('WPN71', '2126-07-01', '2127-06-30', FALSE)
  RETURNING id_season INTO v_season;

  SELECT id_organizer INTO v_evf  FROM tbl_organizer WHERE txt_code = 'EVF';
  SELECT id_organizer INTO v_spws FROM tbl_organizer WHERE txt_code = 'SPWS';

  -- Left unset on purpose: this is the row the old guard could never fill.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         dt_start, dt_end)
  VALUES ('WPN71UNSET', 'unset weapons', v_season, v_evf,
          '2126-10-03', '2126-10-03');

  -- A deliberate admin value that must survive a refresh untouched.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         dt_start, dt_end, arr_weapons)
  VALUES ('WPN71ADMIN', 'admin set weapons', v_season, v_spws,
          '2126-10-10', '2126-10-10', '{FOIL,SABRE}'::enum_weapon_type[]);
END $setup$;

-- ----- 71.4 a new row is genuinely unset, not silently all-three ---------------
SELECT is(
  (SELECT arr_weapons FROM tbl_event WHERE txt_code = 'WPN71UNSET'),
  NULL,
  '71.4 — an event created without weapons reads NULL, not the old '
  '{EPEE,FOIL,SABRE} default that masked "nobody set this"'
);

-- ----- 71.5 the corpus invariant ---------------------------------------------
-- Every event whose code carries a weapon suffix must agree with that suffix.
SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e
    WHERE split_part(e.txt_code, '-', 1) ~ '[efs]$'
      AND e.arr_weapons IS NOT NULL
      AND e.arr_weapons::TEXT[] <> ARRAY(
            SELECT w FROM (
              SELECT CASE c WHEN 'e' THEN 'EPEE' WHEN 'f' THEN 'FOIL'
                            WHEN 's' THEN 'SABRE' END AS w
              FROM regexp_split_to_table(
                     substring(split_part(e.txt_code, '-', 1) FROM '[efs]+$'),
                     ''
                   ) AS c
            ) x ORDER BY w
          )),
  0,
  '71.5 — no event disagrees with the weapon suffix in its own code'
);

-- ----- 71.6-71.7 the guard fires, and only where it should ---------------------
DO $refresh$
DECLARE
  v_id INT;
BEGIN
  SELECT id_event INTO v_id FROM tbl_event WHERE txt_code = 'WPN71UNSET';
  PERFORM fn_refresh_evf_event_urls(
    jsonb_build_array(jsonb_build_object(
      'id_event', v_id, 'weapons', jsonb_build_array('EPEE')
    ))
  );

  SELECT id_event INTO v_id FROM tbl_event WHERE txt_code = 'WPN71ADMIN';
  PERFORM fn_refresh_evf_event_urls(
    jsonb_build_array(jsonb_build_object(
      'id_event', v_id, 'weapons', jsonb_build_array('EPEE','FOIL','SABRE')
    ))
  );
END $refresh$;

SELECT is(
  (SELECT arr_weapons::TEXT FROM tbl_event WHERE txt_code = 'WPN71UNSET'),
  '{EPEE}',
  '71.6 — the fill fires on an unset row. This is the assertion the old '
  'NULL-guard-on-a-defaulted-column could never satisfy.'
);

SELECT is(
  (SELECT arr_weapons::TEXT FROM tbl_event WHERE txt_code = 'WPN71ADMIN'),
  '{FOIL,SABRE}',
  '71.7 — a deliberate admin value is NOT overwritten; the fix fills blanks, '
  'it does not seize the column'
);

-- ----- 71.8-71.9 the suffix-less family keeps all three ------------------------
-- PPW, MPW, DMEW, IMEW and MSW are always three-weapon events. Verified against
-- their own tournaments: all 25 such events that have any read exactly
-- EPEE,FOIL,SABRE.
SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
    WHERE e.txt_code LIKE 'PPW%' AND e.arr_weapons IS NOT NULL
      AND e.arr_weapons::TEXT <> '{EPEE,FOIL,SABRE}'),
  0,
  '71.8 — no PPW event carries anything but all three weapons'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e
    WHERE e.txt_code LIKE 'MPW%' AND e.arr_weapons IS NOT NULL
      AND e.arr_weapons::TEXT <> '{EPEE,FOIL,SABRE}'),
  0,
  '71.9 — nor any MPW event'
);

SELECT * FROM finish();

ROLLBACK;
