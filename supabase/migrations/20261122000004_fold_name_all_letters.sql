-- =============================================================================
-- I27 · Name folding: every accented letter folds to its base letter
-- Plan doc/plans/registration-name-list-under-surname-2026-11-22.html, rev 1,
-- Part A (signed 22 Nov 2026). Repairs fn_fold_name of migration
-- 20260925000001 (ADR-093; FR-165 folds names the same way on the page).
--
-- The letter table of that migration lost three letters in one place (a
-- damaged character stands where e-ogonek, S-acute and s-acute should be), so
-- its two strings are 70 and 72 letters long and every letter after E-ogonek
-- was folded to the wrong one: e-ogonek not at all, o-acute to N, s-acute to O,
-- a-acute to Z. Both sides of a comparison were damaged alike, so a name typed
-- with its accents still matched; typed without them, it did not.
--
-- 1. fn_fold_name folds the way frontend/src/lib/foldName.ts and the Python
--    matcher do: the letters that are not a base letter plus a mark (L-stroke,
--    O-stroke, D-stroke) by hand, then NFD, then the marks dropped. Spaces,
--    hyphens and capitals as before.
-- 2. tbl_common_given_name.txt_name_key is stored from fn_fold_name, so its
--    rows are written again; two names that now fold alike keep the older row.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

CREATE OR REPLACE FUNCTION fn_fold_name(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT upper(
    regexp_replace(
      normalize(
        translate(
          -- 2. 'A - B' and 'A -B' both become 'A-B', after 1. whitespace collapse.
          regexp_replace(
            regexp_replace(btrim(COALESCE(p_name, '')), '\s+', ' ', 'g'),
            '\s*-\s*', '-', 'g'
          ),
          -- 3. Letters NFD does not split into a base letter and a mark.
          'ŁłØøĐđ',
          'LlOoDd'
        ),
        NFD
      ),
      -- 4. The marks NFD split off.
      '[̀-ͯ]', '', 'g'
    )
  );
$$;

COMMENT ON FUNCTION fn_fold_name(TEXT) IS
  'Name normalisation shared by the registration identity lookup, the name check and the '
  'ingestion matcher: collapse whitespace, close hyphen spacing (A - B -> A-B), fold every '
  'accented letter to its base letter (L-stroke, O-stroke and D-stroke by hand, the rest by '
  'NFD), upper-case. IMMUTABLE so it can back a stored key. Repaired 2026-11-22 (I27).';

GRANT EXECUTE ON FUNCTION fn_fold_name(TEXT) TO anon, authenticated, service_role;

-- The stored keys, written again with the repaired folding, in one statement:
-- every row is taken out (txt_name_key is the primary key, never NULL, so the
-- WHERE keeps them all) and put back once per new key, the older row first.
WITH taken AS (
  DELETE FROM tbl_common_given_name
   WHERE txt_name_key IS NOT NULL
  RETURNING txt_name, txt_source, ts_created
)
INSERT INTO tbl_common_given_name (txt_name, txt_source, ts_created)
SELECT DISTINCT ON (fn_fold_name(o.txt_name)) o.txt_name, o.txt_source, o.ts_created
  FROM taken o
 ORDER BY fn_fold_name(o.txt_name), o.ts_created, o.txt_name;

COMMIT;
