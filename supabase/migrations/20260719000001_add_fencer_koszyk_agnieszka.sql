-- ============================================================================
-- Add KOSZYK Agnieszka (BY 1980, confirmed) to tbl_fencer
-- ============================================================================
-- Source: self-reported by the fencer by e-mail, 2026-07-14, giving a full
-- birth date. Only the year (1980) is recorded — here and in tbl_fencer — so
-- bool_birth_year_estimated = FALSE ("confirmed"), consistent with how the
-- 2026-07 master-list batch treated organizer-supplied dates (20260714000003).
-- The correspondence itself is deliberately not reproduced: this repository is
-- public, and the full date is both unnecessary to the ranking and more
-- precise than anything the schema stores.
--
-- WHY SHE IS MISSING AT ALL: she is classified in the SPWS season workbook
-- SZABLA-K1-2025-2026.xlsx (szabla kobiet V1, position 4) and joined that
-- category this season, but appears nowhere in the ranking database --
-- not tbl_fencer, not tbl_result, and not seed_prod_2026-06-28.sql. The season
-- workbooks and the ranking database are separate artefacts; being in the
-- former never implied a row in the latter.
--
-- V-CAT CROSS-CHECK, deliberately not taken on trust from the e-mail: she
-- competed in "Vet-40 Women's Saber" at the 2025 Veteran World Championships
-- (13 Nov 2025, 15th of 30), recorded in the IMSW sheet of the same workbook.
-- Vet-40 entry is age-verified by the FIE, so BY <= 1985 independently. BY 1980
-- agrees. Her own message claimed "V0", which is wrong on two counts -- V0 does
-- not exist at the World Championships, and 1980 puts her in V1 (40-49) for the
-- 2026 season regardless. The stated date, not the stated category, is correct.
--
-- RANKING IMPACT: none. A brand-new fencer has no rows in tbl_result, so no
-- result can move between rankings and nothing needs recomputing.
-- trg_fencer_change_enqueue is AFTER UPDATE only and does not fire for an
-- INSERT -- the same reasoning recorded in 20260714000003 for the fifteen
-- fencers inserted there.
--
-- IDEMPOTENT: guarded by NOT EXISTS on (txt_surname, txt_first_name, BY).
-- 20260714000003 used a bare INSERT, which is safe for a one-shot run but not
-- for re-application; a from-scratch bootstrap runs migrations BEFORE
-- [db.seed] sql_paths loads (supabase/config.toml), so this file can legitimately
-- execute against both an empty and an already-populated tbl_fencer.
--
-- NOT disambiguated by name alone: no other KOSZYK exists in tbl_fencer today,
-- so unlike the KRAWCZYK Paweł and MŁYNEK Janusz pairs this name resolves
-- uniquely. A future same-name arrival would need birth-year qualification.
--
-- The audit trigger (trg_audit_fencer) records the insert.
-- ============================================================================

INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year,
    bool_birth_year_estimated, enum_gender, txt_nationality
)
SELECT 'KOSZYK', 'Agnieszka', 1980, FALSE, 'F', 'PL'
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer
     WHERE upper(txt_surname)    = 'KOSZYK'
       AND upper(txt_first_name) = 'AGNIESZKA'
       AND int_birth_year        = 1980
);

DO $$
DECLARE
  v_id INT;
BEGIN
  SELECT id_fencer INTO v_id
    FROM tbl_fencer
   WHERE upper(txt_surname) = 'KOSZYK'
     AND upper(txt_first_name) = 'AGNIESZKA'
     AND int_birth_year = 1980;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'KOSZYK Agnieszka (BY 1980) missing after insert';
  END IF;

  RAISE NOTICE 'KOSZYK Agnieszka present as id_fencer %, BY 1980 confirmed', v_id;
END $$;
