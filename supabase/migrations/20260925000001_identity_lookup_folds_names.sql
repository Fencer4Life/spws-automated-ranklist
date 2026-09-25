-- =============================================================================
-- The registration identity lookup normalises names the way the matcher does
-- =============================================================================
-- MACIEJ Spława - Neyman entered PPW1-2026-2027 with the two name fields
-- exchanged. #276 SPŁAWA-NEYMAN Maciej has been on the roster for fourteen
-- results, so ADR-093 rung 3 — "the two name fields were typed into each
-- other's boxes" — is exactly the case this subsystem was built to catch.
--
-- It never fired. fn_registration_identity_candidates compared with
-- upper(btrim(...)) and nothing else, and the SWAPPED branch was asking:
--
--   typed first name  'SPLAWA - NEYMAN'   plain L, spaces around the hyphen
--   fencer surname    'SPŁAWA-NEYMAN'     Ł, no spaces
--
-- Two independent differences, either one fatal. The function returned ZERO
-- candidates, so the form fell through every rung to rung 6 and echoed the
-- canonical form back as a brand-new person — which, for a name typed in the
-- wrong order, reads as perfectly correct to whoever is looking at it. The
-- entrant is now unmatched, will be minted a second time at ingestion, and
-- fourteen results' worth of history splits in two.
--
-- THE ASYMMETRY IS THE BUG. python/matcher/fuzzy_match.py has handled both of
-- these for years, on the ingestion side:
--
--   fold_diacritics()          special-cases ł/Ł *specifically because* NFD
--                              does not decompose them — the very character
--                              that broke this match.
--   canonicalize_scraped_name() step 3 collapses 'A - B' to 'A-B', added for
--                              "SAMECKA -NACZYŃSKA", the same defect in the
--                              same shape.
--
-- So the system already knew. The registration half simply never got the same
-- normalisation, and two halves that compare names differently will disagree
-- about who somebody is. fn_fold_name below is that normalisation expressed
-- once in SQL, and the lookup now applies it to BOTH sides of every
-- comparison.
--
-- WHY NOT unaccent. The extension is available but not installed, and it would
-- not have helped on its own: unaccent strips combining marks, and Ł is a
-- distinct letter rather than L plus a mark, so it survives untouched — the
-- same reason the Python helper special-cases it. A translate() pair is
-- explicit, needs no extension, and stays IMMUTABLE so it can be indexed later.
--
-- WIDER CANDIDATE SETS ARE THE POINT, AND THEY ARE SAFE. Folding finds more
-- near misses, which is the objective, and it can only ever ADD rows to a set
-- that "DECIDES NOTHING" (20260912000001). More candidates means more prompts
-- and fewer silent writes: rung 4 fires only when the name reaches exactly one
-- fencer, so a newly-visible namesake now suppresses a silent write rather
-- than causing one. Guard 2 in fn_confirm_registration_identity recomputes the
-- same set server-side, so both move together and cannot drift apart.
--
-- fn_match_registration_fencer is NOT touched. It stays an exact-tuple matcher
-- that can never merge two people (20260912000001's opening comment), and this
-- change does not loosen it — it only lets the near-miss lookup SEE what the
-- exact matcher structurally cannot.
--
-- Plan-test-ID 75.17-75.19 (supabase/tests/75_registration_identity_candidates.sql).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- ---------------------------------------------------------------------------
-- The shared normalisation. Mirrors python/matcher/fuzzy_match.py in order:
-- collapse whitespace, normalise hyphen spacing, fold diacritics, case-fold.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_fold_name(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT upper(
    translate(
      -- 2. 'A - B' and 'A -B' both become 'A-B', after 1. whitespace collapse.
      regexp_replace(
        regexp_replace(btrim(COALESCE(p_name, '')), '\s+', ' ', 'g'),
        '\s*-\s*', '-', 'g'
      ),
      -- 3. Diacritics. Ł/ł lead deliberately: they are separate letters, not
      --    a base plus a mark, which is why NFD-based folding misses them.
      'ŁłĄąĆćĘꌜŃńÓóŚśŹźŻżÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÝýÇçÑñ',
      'LlAaCcEeEeNnOoSsZzZzAAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuYyCcNn'
    )
  );
$$;

COMMENT ON FUNCTION fn_fold_name(TEXT) IS
  'Name normalisation shared by the registration identity lookup and the '
  'ingestion matcher: collapse whitespace, close hyphen spacing (A - B -> A-B), '
  'fold diacritics (L-stroke included, which NFD does not decompose), upper-case. '
  'IMMUTABLE so it can back an index. Added 2026-09-25 after a swapped name '
  'missed its own roster entry on both counts at once.';

GRANT EXECUTE ON FUNCTION fn_fold_name(TEXT) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The lookup, unchanged in shape and classification — only the comparison is
-- normalised. It still returns EVERY candidate and still decides nothing.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registration_identity_candidates(
  p_surname    TEXT,
  p_first_name TEXT,
  p_birth_year SMALLINT
)
RETURNS TABLE (
  id_fencer                 INT,
  txt_surname               TEXT,
  txt_first_name            TEXT,
  int_birth_year            SMALLINT,
  bool_birth_year_estimated BOOLEAN,
  enum_kind                 TEXT
)
LANGUAGE sql
STABLE
AS $$
  -- Candidates in the order the fencer typed them.
  SELECT
    f.id_fencer,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    f.bool_birth_year_estimated,
    CASE
      WHEN f.int_birth_year IS NULL        THEN 'BY_NULL'
      WHEN f.int_birth_year = p_birth_year THEN 'EXACT'
      ELSE                                      'BY_DIFFERS'
    END AS enum_kind
  FROM tbl_fencer f
  WHERE fn_fold_name(f.txt_surname)    = fn_fold_name(p_surname)
    AND fn_fold_name(f.txt_first_name) = fn_fold_name(p_first_name)

  UNION ALL

  -- The same lookup with the two name fields exchanged. A hit here is
  -- near-certain proof that they were typed into the wrong boxes — it is how
  -- KRZYSZTOF Łęcki reaches ŁĘCKI Krzysztof #168, and how SPLAWA - NEYMAN
  -- reaches SPŁAWA-NEYMAN #276 now that neither the stroke nor the spacing
  -- hides him. The birth year is NOT required to agree: the prompt shows the
  -- candidate's year and lets the person judge. Rows already reported in the
  -- typed order are excluded so a palindromic name cannot be classified twice.
  SELECT
    f.id_fencer,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    f.bool_birth_year_estimated,
    'SWAPPED' AS enum_kind
  FROM tbl_fencer f
  WHERE fn_fold_name(f.txt_surname)    = fn_fold_name(p_first_name)
    AND fn_fold_name(f.txt_first_name) = fn_fold_name(p_surname)
    AND NOT (fn_fold_name(f.txt_surname)    = fn_fold_name(p_surname)
         AND fn_fold_name(f.txt_first_name) = fn_fold_name(p_first_name))
$$;

COMMENT ON FUNCTION fn_registration_identity_candidates IS
  'Near-miss identity lookup for the registration form (plan 2026-09-12 §7). '
  'Scans by NAME, not by tuple, so unlike fn_match_registration_fencer it can '
  'see fencers whose birth year is NULL. Comparison goes through fn_fold_name '
  '(2026-09-25) so a stroked letter or a spaced hyphen can no longer hide a '
  'roster entry from its own registrant. Classifies every candidate as '
  'EXACT | SWAPPED | BY_NULL | BY_DIFFERS and DECIDES NOTHING — returning all '
  'of them is what keeps the same-name case (MŁYNEK Janusz 1951 vs 1984) safe. '
  'The caller applies the six-rung resolution order. Does not replace or relax '
  'fn_match_registration_fencer, which keeps serving the exact-match fast path.';

GRANT EXECUTE ON FUNCTION fn_registration_identity_candidates(TEXT, TEXT, SMALLINT) TO anon;
GRANT EXECUTE ON FUNCTION fn_registration_identity_candidates(TEXT, TEXT, SMALLINT) TO authenticated;

COMMIT;
