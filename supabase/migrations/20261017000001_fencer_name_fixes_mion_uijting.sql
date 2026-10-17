-- ============================================================================
-- Correct two roster names so the FIE World Championships identity finds them
-- (ADR-106 amendment of 2026-10-17, decision D4 A and the UIJTING typo)
-- ============================================================================
-- Found by the Tbilisi 2026 completeness check (doc/plans/
-- adr-106-amendment-fie-worlds-and-tbilisi-ingest-2026-10-17.html): both are
-- SPWS starters whose FTL rows were rejected only because our row is wrong.
--
--   ANNA-LISE Mion (1975, F) -> MION Annalise. Surname and first name were
--     stored swapped; FIE prints "MION Annalise" (IRL). The old form is kept
--     as an alias, so a domestic listing printed that way still matches.
--   UIJTING Henh (1954, M) -> UIJTING Henk. A one-letter typo; FIE prints
--     "UIJTING Henk" (NED), already the row's alias. "UIJTING Henh" is kept as
--     an alias for the same reason.
--
-- KEYED BY NAME AND BIRTH YEAR, never by id: fencer ids differ between LOCAL,
-- CERT and PROD. Each UPDATE matches the old name exactly, so re-applying it
-- (the release workflow, CERT, PROD) is a no-op.
--
-- FRESH BOOTSTRAP: migrations run BEFORE the seed dump loads (ADR-036
-- amendment), so on an empty tbl_fencer both UPDATEs touch nothing and the
-- check below passes; the seed then brings PROD's rows, corrected once this
-- migration has run on PROD and the seed is re-exported.
--
-- RANKING IMPACT: none. A name change moves no result; trg_audit_fencer
-- records it.
-- ============================================================================

UPDATE tbl_fencer
   SET txt_surname       = 'MION',
       txt_first_name    = 'Annalise',
       json_name_aliases = COALESCE(json_name_aliases, '[]'::jsonb) || '["ANNA-LISE Mion"]'::jsonb
 WHERE txt_surname = 'ANNA-LISE'
   AND txt_first_name = 'Mion'
   AND int_birth_year = 1975;

UPDATE tbl_fencer
   SET txt_first_name    = 'Henk',
       json_name_aliases = COALESCE(json_name_aliases, '[]'::jsonb) || '["UIJTING Henh"]'::jsonb
 WHERE txt_surname = 'UIJTING'
   AND txt_first_name = 'Henh'
   AND int_birth_year = 1954;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM tbl_fencer
              WHERE (txt_surname = 'ANNA-LISE' AND txt_first_name = 'Mion')
                 OR (txt_surname = 'UIJTING' AND txt_first_name = 'Henh')) THEN
    RAISE EXCEPTION 'a swapped or misspelt roster name is still present after the fix';
  END IF;
  IF EXISTS (SELECT 1 FROM tbl_fencer
              WHERE txt_surname = 'MION' AND txt_first_name = 'Annalise'
                AND NOT (json_name_aliases ? 'ANNA-LISE Mion')) THEN
    RAISE EXCEPTION 'MION Annalise lost the alias of her old row';
  END IF;
  IF EXISTS (SELECT 1 FROM tbl_fencer
              WHERE txt_surname = 'UIJTING' AND txt_first_name = 'Henk'
                AND NOT (json_name_aliases ? 'UIJTING Henh')) THEN
    RAISE EXCEPTION 'UIJTING Henk lost the alias of his old row';
  END IF;
  RAISE NOTICE 'roster names corrected: MION Annalise, UIJTING Henk';
END $$;
