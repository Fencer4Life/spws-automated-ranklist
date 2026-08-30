-- ============================================================================
-- Add CISZEWSKA Barbara (BY 1974) and SZUMIELEWICZ Paweł (BY 1986) to tbl_fencer
-- ============================================================================
-- Source: supplied by the association administrator on 2026-07-29 while
-- reconciling three names against LOCAL, CERT and PROD.
--
-- BIRTH YEAR STATUS: both rows are inserted with
-- bool_birth_year_estimated = FALSE, i.e. CONFIRMED. That is the same
-- representation fn_update_fencer_birth_year (20260412000004, ADR-035) writes
-- when an admin saves a birth year with p_estimated => FALSE, and the same
-- treatment 20260719000001 (KOSZYK Agnieszka) and the 2026-07 master-list batch
-- (20260714000003) gave administrator-supplied years. Only the year is stored;
-- the schema has no birth-date column.
--
-- WHY THEY ARE MISSING AT ALL: neither surname exists in tbl_fencer on LOCAL,
-- CERT or PROD, and neither has rows in tbl_result. Checked before writing this
-- file with prefix matches on 'CISZEW%' and 'SZUMIEL%' against all three
-- environments -- these are new entrants, not mis-spellings of existing rows.
--
-- V-CAT CROSS-CHECK for the 2025/2026 season (season_end_year = 2026), recorded
-- here only as a check; the category is derived by fn_age_category and is
-- deliberately not stored on the row:
--   CISZEWSKA    2026 - 1974 = 52 -> V2
--   SZUMIELEWICZ 2026 - 1986 = 40 -> V1 (youngest qualifying V1 year)
--
-- GENDER: from the given names (Barbara -> 'F', Paweł -> 'M'). Neither has a
-- competition record to cross-check against yet, so this is the sole basis;
-- enum_gender is nullable and correctable via fn_update_fencer_gender (ADR-033).
--
-- IDENTITY CAUTION, recorded rather than acted on: PILARSKA Barbara (BY 1974)
-- already exists on all three environments -- same given name, same birth year.
-- If CISZEWSKA turns out to be the same person under a maiden or married name,
-- the correct remedy is an alias or fn_merge_fencers (20260626000001), NOT a
-- second row. The administrator named CISZEWSKA Barbara 1974 explicitly as a
-- distinct entry, so she is inserted as such; this note exists so a future
-- session finds the coincidence already noticed instead of rediscovering it.
--
-- RANKING IMPACT: none. Brand-new fencers have no rows in tbl_result, so no
-- result can move between rankings and nothing needs recomputing.
-- trg_fencer_change_enqueue is AFTER UPDATE only and does not fire for an
-- INSERT -- the same reasoning recorded in 20260714000003 and 20260719000001.
--
-- IDEMPOTENT: each insert is guarded by NOT EXISTS on
-- (txt_surname, txt_first_name, int_birth_year), because a from-scratch
-- bootstrap runs migrations BEFORE [db.seed] sql_paths loads
-- (supabase/config.toml), so this file must execute correctly against both an
-- empty and an already-populated tbl_fencer. It is also applied directly to
-- CERT and PROD ahead of the next release run, so re-application by the release
-- workflow must be a no-op.
--
-- DISAMBIGUATION: both surnames resolve uniquely today, unlike the
-- KRAWCZYK Paweł and MŁYNEK Janusz pairs. The guards are nonetheless
-- birth-year qualified so a future same-name arrival is handled correctly.
--
-- trg_trim_fencer_names normalises whitespace on insert; trg_audit_fencer
-- records subsequent changes.
-- ============================================================================

INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year,
    bool_birth_year_estimated, enum_gender, txt_nationality
)
SELECT 'CISZEWSKA', 'Barbara', 1974, FALSE, 'F', 'PL'
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer
     WHERE upper(txt_surname)    = 'CISZEWSKA'
       AND upper(txt_first_name) = 'BARBARA'
       AND int_birth_year        = 1974
);

INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year,
    bool_birth_year_estimated, enum_gender, txt_nationality
)
SELECT 'SZUMIELEWICZ', 'Paweł', 1986, FALSE, 'M', 'PL'
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer
     WHERE upper(txt_surname)    = 'SZUMIELEWICZ'
       AND upper(txt_first_name) = 'PAWEŁ'
       AND int_birth_year        = 1986
);

DO $$
DECLARE
  r          RECORD;
  v_expected TEXT;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('CISZEWSKA',    'BARBARA', 1974, 'F', 'V2'),
      ('SZUMIELEWICZ', 'PAWEŁ',   1986, 'M', 'V1')
    ) AS t(surname, first_name, birth_year, gender, vcat)
  LOOP
    PERFORM 1
       FROM tbl_fencer f
      WHERE upper(f.txt_surname)    = r.surname
        AND upper(f.txt_first_name) = r.first_name
        AND f.int_birth_year        = r.birth_year
        AND f.bool_birth_year_estimated = FALSE
        AND f.enum_gender::text     = r.gender;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        '% (BY %) missing, or birth year not marked confirmed, after insert',
        r.surname, r.birth_year;
    END IF;

    v_expected := fn_age_category(r.birth_year, 2026)::text;
    IF v_expected IS DISTINCT FROM r.vcat THEN
      RAISE EXCEPTION '% (BY %) resolves to %, expected %',
        r.surname, r.birth_year, v_expected, r.vcat;
    END IF;

    RAISE NOTICE '% (BY %) present, birth year confirmed, % for season 2025/2026',
      r.surname, r.birth_year, r.vcat;
  END LOOP;
END $$;
