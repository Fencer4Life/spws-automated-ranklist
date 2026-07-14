-- ============================================================================
-- Fencer birth-year master-list reconciliation (2026-07 batch)
-- ============================================================================
-- Source: organizer-supplied master list, 216 names, matched against
-- tbl_fencer by (txt_surname, txt_first_name) + json_name_aliases.
-- 188 names matched; 178 already carried the correct confirmed birth year
-- (no-op, intentionally not touched here, per the ADR-056 precedent of
-- skipping true no-ops). These 10 are the genuine corrections. All become
-- bool_birth_year_estimated = FALSE ("confirmed") via the existing
-- fn_update_fencer_birth_year RPC (ADR-035). Resolved by name, not id_fencer,
-- so this file is portable across LOCAL/CERT/PROD.
--
-- MŁYNEK Janusz (id_fencer 197): the DB's one SABRE-only MŁYNEK Janusz row
-- is the "szabla" master-list entry (BY 1951) per full tournament-history
-- review, not the unqualified BY 1984 entry (a second, unregistered person,
-- inserted separately below -- two MŁYNEK Janusz rows now exist, BY-only
-- disambiguated).
-- WOJTAS Bogusław: matched via existing json_name_aliases = ['WOJTAS Bogdan'].
--
-- SAMECKA-NACZYŃSKA Martyna: genuinely re-brackets SPWS-2024-2025 (V0->V1) --
-- see doc/audits/prod-recompute-drain-gap-2026-07-14.html. This is why
-- ADR-072 was amended (2026-07-14) to also drain PROD's recompute queue
-- (recompute-drain-prod.yml) before this migration ships to PROD.
--
-- Every change is preserved in tbl_audit_log via trg_audit_fencer.
--
-- Guarded lookup, not a bare fn_update_fencer_birth_year(subquery, ...) call:
-- that RPC RAISE EXCEPTIONs when the id resolves to NULL (ADR-035, correct
-- for its normal admin-UI caller). On LOCAL/CERT/PROD -- long-running,
-- already-seeded databases -- every name below resolves and the guard is a
-- no-op. A from-scratch bootstrap (CI's `supabase start`) runs migrations
-- BEFORE `[db.seed] sql_paths` loads (supabase/config.toml), so tbl_fencer is
-- still empty when this file runs there; skip-with-NOTICE instead of
-- crashing the whole migration sequence over an ordering artifact that
-- doesn't apply to any real deployed environment.
-- ============================================================================

DO $$
DECLARE
  v_id  INT;
  v_row RECORD;
BEGIN
  FOR v_row IN
    SELECT * FROM (VALUES
      ('BOBUSIA',            'Dariusz',  1984),
      ('FRYDRYCKI',          'Mariusz',  1980),
      ('FUHRMANN',           'Ulrike',   1963),
      ('GAJDA',              'Krzysztof',1993),
      ('KULKA',               'Dawid',   1979),
      ('MŁYNEK',              'Janusz',  1951),
      ('NOWICKI',            'Robert',   1970),
      ('SAMECKA-NACZYŃSKA',  'Martyna',  1985),
      ('WOJTAS',             'Bogusław', 1969),
      ('WYLĘGAŁA',           'Jerzy',    1949)
    ) AS t(surname, first_name, new_by)
  LOOP
    SELECT id_fencer INTO v_id FROM tbl_fencer
     WHERE txt_surname = v_row.surname AND txt_first_name = v_row.first_name;

    IF v_id IS NOT NULL THEN
      PERFORM fn_update_fencer_birth_year(v_id, v_row.new_by, FALSE);
    ELSE
      RAISE NOTICE 'fencer_birth_year_master_list_reconcile: % % not found -- skipped (expected pre-seed in a from-scratch bootstrap)',
        v_row.surname, v_row.first_name;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- New fencer roster entries — 15 master-list names with no existing
-- tbl_fencer row. No tournament result to attach in this batch, so
-- fn_create_fencer_from_match (which requires one) does not apply — plain
-- INSERTs, confirmed birth year, same organizer master list.
--
-- Gender is INFERRED from the Polish given name (not supplied by the
-- source) -- 13 male, 2 female (Diana Dąbrowska-Mandrela, Beata Pelińska).
-- Nationality defaults to 'PL' (schema default; all 15 names read as Polish).
-- Neither is organizer-confirmed the way the birth year is.
--
-- Confirmed 2026-07-14: "Krawczyk (GLIWICE) Paweł" -- Gliwice is his home
-- town, not a club; dropped rather than stored in txt_club. Inserted as
-- plain KRAWCZYK Paweł.
--
-- Two same-name pairs are, per the organizer, different people -- nothing
-- here disambiguates them beyond birth year:
--   KRAWCZYK Paweł   -- BY 1989 (this batch) and BY 1954 (this batch)
--   MŁYNEK Janusz    -- BY 1984 (this row) vs the EXISTING id_fencer 197,
--                        BY 1951, SABRE-only, updated above
-- A future scraped result for either name will need human review to pick
-- the right candidate -- expected, not a defect.
--
-- No trg_fencer_change_enqueue firing here: that trigger is AFTER UPDATE
-- only, and a brand-new fencer has no existing results to recompute.
-- ============================================================================

INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, enum_gender, txt_nationality) VALUES
  ('BURLIKOWSKI', 'Bartosz', 1972, FALSE, 'M', 'PL'),
  ('DĄBROWSKA-MANDRELA', 'Diana', 1982, FALSE, 'F', 'PL'),
  ('GOLA', 'Maciej', 1981, FALSE, 'M', 'PL'),
  ('KOLER', 'Jarosław', 1989, FALSE, 'M', 'PL'),
  ('KRAWCZYK', 'Paweł', 1989, FALSE, 'M', 'PL'),
  ('KRAWCZYK', 'Paweł', 1954, FALSE, 'M', 'PL'),
  ('MŁYNEK', 'Janusz', 1984, FALSE, 'M', 'PL'),
  ('MROCZYK', 'Ireneusz', 1957, FALSE, 'M', 'PL'),
  ('PELIŃSKA', 'Beata', 1979, FALSE, 'F', 'PL'),
  ('PIGUŁA', 'Dariusz', 1977, FALSE, 'M', 'PL'),
  ('RUDZIŃSKI', 'Piotr', 1975, FALSE, 'M', 'PL'),
  ('SERAFIN', 'Marek', 1967, FALSE, 'M', 'PL'),
  ('SZTUBA', 'Mariusz', 1968, FALSE, 'M', 'PL'),
  ('TUSZYŃSKI', 'Piotr', 1986, FALSE, 'M', 'PL'),
  ('WĘCŁAWSKI', 'Mirosław', 1970, FALSE, 'M', 'PL');
