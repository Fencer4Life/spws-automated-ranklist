-- ===========================================================================
-- Phase 4 follow-up — repair scalar json_name_aliases + harden view
-- ===========================================================================
-- Symptom (2026-05-02): the alias UI showed "0 fencers / 0 aliases" plus
-- the error
--     fn_list_fencer_aliases: cannot get array length of a scalar
-- Root cause: seed_local_2026-04-30.sql stores nine fencers with
-- json_name_aliases set to a JSON-STRING SCALAR like '"{\"FRAŚ Felix\"}"'
-- instead of a JSON-ARRAY '["FRAŚ Felix"]'. Postgres parses the value as a
-- JSONB string scalar, and `vw_fencer_aliases` calls
-- `jsonb_array_length(json_name_aliases)` on every row — the scalar makes
-- the entire query abort, returning the error to the UI before any rows
-- come back.
--
-- Fix is two-pronged:
--   1. Repair the data: convert each affected row's scalar string (which
--      embeds a Postgres array-literal like `{"X","Y"}`) into a real JSONB
--      array `["X","Y"]`. Idempotent — only operates on rows whose value
--      is currently a JSONB string.
--   2. Harden the view: gate jsonb_array_length on jsonb_typeof = 'array'
--      so future stray scalars never crash the entire list query again.
--
-- The phase4_alias_management trigger blocks writes of non-array values,
-- so this regression cannot recur via normal write paths — only via raw
-- seed inserts. A pgTAP test covers both behaviours (35_alias_view_robustness).
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Repair scalar rows
-- ---------------------------------------------------------------------------
-- The scalar form embeds the Postgres array-literal text (`{"X","Y"}`) inside
-- a JSON string. Cast that text via ::text[] to parse the array literal, then
-- to_jsonb() to land back in JSONB-array shape.
UPDATE tbl_fencer
   SET json_name_aliases = to_jsonb(
         (json_name_aliases #>> '{}')::text[]
       )
 WHERE json_name_aliases IS NOT NULL
   AND jsonb_typeof(json_name_aliases) = 'string';

-- ---------------------------------------------------------------------------
-- 2. Harden vw_fencer_aliases against any future stray scalar
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_fencer_aliases AS
SELECT
  f.id_fencer,
  f.txt_first_name,
  f.txt_surname,
  CASE
    WHEN jsonb_typeof(f.json_name_aliases) = 'array'
      THEN f.json_name_aliases
    ELSE '[]'::jsonb
  END                                              AS json_name_aliases,
  CASE
    WHEN jsonb_typeof(f.json_revoked_aliases) = 'array'
      THEN f.json_revoked_aliases
    ELSE '[]'::jsonb
  END                                              AS json_revoked_aliases,
  CASE
    WHEN jsonb_typeof(f.json_name_aliases) = 'array'
      THEN jsonb_array_length(f.json_name_aliases)
    ELSE 0
  END                                              AS alias_count,
  f.ts_updated                                     AS ts_last_alias_added
FROM tbl_fencer f;

COMMENT ON VIEW vw_fencer_aliases IS
  'List view for FencerAliasManager.svelte. Defensive against scalar / NULL '
  'json_name_aliases — only treats jsonb_typeof=array as real aliases. '
  'Defensive layer is belt-and-braces: phase4_alias_management trigger '
  'rejects non-array writes, so only seed-time corruption can land scalars.';

COMMIT;
