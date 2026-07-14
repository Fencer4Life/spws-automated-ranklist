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
-- ============================================================================

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'BOBUSIA' AND txt_first_name = 'Dariusz'),
  1984, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FRYDRYCKI' AND txt_first_name = 'Mariusz'),
  1980, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'FUHRMANN' AND txt_first_name = 'Ulrike'),
  1963, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'GAJDA' AND txt_first_name = 'Krzysztof'),
  1993, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'KULKA' AND txt_first_name = 'Dawid'),
  1979, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'MŁYNEK' AND txt_first_name = 'Janusz'),
  1951, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'NOWICKI' AND txt_first_name = 'Robert'),
  1970, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'SAMECKA-NACZYŃSKA' AND txt_first_name = 'Martyna'),
  1985, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WOJTAS' AND txt_first_name = 'Bogusław'),
  1969, FALSE);

SELECT fn_update_fencer_birth_year(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'WYLĘGAŁA' AND txt_first_name = 'Jerzy'),
  1949, FALSE);

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
