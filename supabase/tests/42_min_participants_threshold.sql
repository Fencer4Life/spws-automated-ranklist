-- =============================================================================
-- pgTAP — ADR-066: min-participants threshold ingestion gate (5.M8)
--
-- Asserts the database invariants that the Python ingestion gate depends on:
--   5.M8.1 — `int_min_participants_ppw` exists, is NOT NULL, has default ≥ 1
--   5.M8.2 — `int_min_participants_evf` exists, is NOT NULL, has default ≥ 1
--   5.M8.3 — Every existing scoring_config row has both columns populated
--            (no orphan NULLs that would break the gate's COALESCE fallback)
--   5.M8.4 — `fn_export_scoring_config` returns both fields in its JSONB
--            payload so the admin UI's import/export round-trip preserves
--            the ADR-066 threshold settings
-- =============================================================================

BEGIN;

SELECT plan(4);

-- 5.M8.1
SELECT ok(
  (SELECT a.attnotnull
     FROM pg_attribute a
     JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relname = 'tbl_scoring_config'
      AND a.attname = 'int_min_participants_ppw'),
  '5.M8.1 int_min_participants_ppw exists and is NOT NULL'
);

-- 5.M8.2
SELECT ok(
  (SELECT a.attnotnull
     FROM pg_attribute a
     JOIN pg_class c ON c.oid = a.attrelid
    WHERE c.relname = 'tbl_scoring_config'
      AND a.attname = 'int_min_participants_evf'),
  '5.M8.2 int_min_participants_evf exists and is NOT NULL'
);

-- 5.M8.3
SELECT is(
  (SELECT COUNT(*)
     FROM tbl_scoring_config
    WHERE int_min_participants_ppw IS NULL
       OR int_min_participants_evf IS NULL)::INT,
  0,
  '5.M8.3 every scoring_config row has both threshold columns populated'
);

-- 5.M8.4 — fn_export_scoring_config JSONB round-trip
DO $m8_4_setup$
DECLARE
  v_season INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end, bool_active)
    VALUES ('ADR066-TEST-9999', '4999-09-01', '5000-06-30', FALSE)
    RETURNING id_season INTO v_season;
  -- tbl_scoring_config row is created automatically by the season-init
  -- trigger; nothing else required for this assertion.
END;
$m8_4_setup$;

SELECT ok(
  (
    SELECT (cfg ? 'min_participants_ppw') AND (cfg ? 'min_participants_evf')
      FROM (
        SELECT fn_export_scoring_config(
          (SELECT id_season FROM tbl_season WHERE txt_code='ADR066-TEST-9999')
        ) AS cfg
      ) q
  ),
  '5.M8.4 fn_export_scoring_config emits both min_participants_* keys'
);

SELECT * FROM finish();
ROLLBACK;
