-- pgt-ignore-all lint/safety: pgTAP runs this file in one rolled-back transaction on LOCAL/CI, never on CERT/PROD
-- =============================================================================
-- FR-172 (plan roster-nationality-from-evf-2026-11-22, rev 3, N1–N9 signed):
-- the roster's nationality is one spelling (POL, never PL), kept to the EVF
-- ranking, and a nationality change rescores nothing.
--
--   RNAT.01  tbl_fencer.txt_nationality defaults to POL
--   RNAT.02  the column refuses anything but three capital letters (PL, Poland)
--   RNAT.03  no roster fencer holds PL or any other non-code
--   RNAT.04  fn_event_results_for_parity returns a POL fencer's result
--   RNAT.05  a fencer split from an alias without a nationality is POL
--   RNAT.06  the 25 fencers decided on 22 Nov hold their codes
--   RNAT.07  fencer 140's 2024/25 and 2025/26 nationality is an administrator's POL,
--            and a refresh from results keeps it
--   (RNAT.08 is test 44.8, amended: a nationality change queues no recompute.)
-- =============================================================================

BEGIN;
SELECT plan(9);

-- RNAT.01
SELECT col_default_is('public', 'tbl_fencer', 'txt_nationality', 'POL'::TEXT,
  'RNAT.01: a new fencer is POL unless a source says otherwise');

-- RNAT.02
SELECT throws_ok(
  $$INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality) VALUES ('RNAT', 'Two', 'PL')$$,
  '23514', NULL, 'RNAT.02: PL is refused');
SELECT throws_ok(
  $$INSERT INTO tbl_fencer (txt_surname, txt_first_name, txt_nationality) VALUES ('RNAT', 'Word', 'Poland')$$,
  '23514', NULL, 'RNAT.02: a word is refused');

-- RNAT.03
SELECT is(
  (SELECT count(*)::INT FROM tbl_fencer WHERE txt_nationality IS NULL OR txt_nationality !~ '^[A-Z]{3}$'),
  0, 'RNAT.03: every roster nationality is a three-letter code');

-- RNAT.04
DO $fix$
DECLARE
  v_event INT;
  v_tournament INT;
  v_fencer INT;
BEGIN
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end)
  VALUES ('RNAT-EVF', 'RNAT parity', (SELECT min(id_season) FROM tbl_season),
          (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'EVF'), '2026-06-15', '2026-06-15')
  RETURNING id_event INTO v_event;
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, txt_nationality)
  VALUES ('RNATPOL', 'Adam', 1980, 'M', 'POL') RETURNING id_fencer INTO v_fencer;
  INSERT INTO tbl_tournament (txt_code, id_event, enum_type, enum_weapon, enum_gender, enum_age_category, dt_tournament)
  VALUES ('RNAT-EVF-V1-M-EPEE', v_event, 'PEW', 'EPEE', 'M', 'V1', '2026-06-15')
  RETURNING id_tournament INTO v_tournament;
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place) VALUES (v_fencer, v_tournament, 3);
END;
$fix$;
SELECT is(
  (SELECT count(*)::INT FROM fn_event_results_for_parity((SELECT id_event FROM tbl_event WHERE txt_code = 'RNAT-EVF'))
    WHERE fencer_name = 'Adam RNATPOL'),
  1, 'RNAT.04: the EVF parity check counts a POL fencer (I26)');

-- RNAT.05
INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year, enum_gender, json_name_aliases)
VALUES ('RNATSRC', 'Jan', 1970, 'M', '["RNATSPLIT Piotr"]'::JSONB);
SELECT fn_split_fencer_from_alias(
  (SELECT id_fencer FROM tbl_fencer WHERE txt_surname = 'RNATSRC'),
  'RNATSPLIT Piotr',
  '{"txt_surname":"RNATSPLIT","txt_first_name":"Piotr","int_birth_year":1971,"enum_gender":"M"}'::JSONB);
SELECT is(
  (SELECT txt_nationality FROM tbl_fencer WHERE txt_surname = 'RNATSPLIT'),
  'POL', 'RNAT.05: a fencer split from an alias without a nationality is POL');

-- RNAT.06
SELECT set_eq(
  $$SELECT id_fencer, txt_nationality FROM tbl_fencer WHERE id_fencer IN
      (5, 8, 34, 60, 80, 81, 133, 137, 138, 143, 162, 167, 186, 201, 236, 241, 272, 273, 284, 304, 311, 320, 349, 354, 356)$$,
  $$VALUES (5, 'HUN'), (8, 'SWE'), (34, 'ITA'), (60, 'HUN'), (80, 'SVK'), (81, 'ISR'), (133, 'SVK'),
           (137, 'IRL'), (138, 'POL'), (143, 'POL'), (162, 'IRL'), (167, 'GBR'), (186, 'IRL'), (201, 'IRL'),
           (236, 'UKR'), (241, 'BEL'), (272, 'CZE'), (273, 'NED'), (284, 'SVK'), (304, 'UKR'), (311, 'NED'),
           (320, 'USA'), (349, 'GER'), (354, 'POL'), (356, 'POL')$$,
  'RNAT.06: the 25 fencers decided on 22 Nov hold their codes');

-- RNAT.07
SELECT set_eq(
  $$SELECT s.txt_code, n.txt_country, n.enum_source::TEXT FROM tbl_fencer_nationality n
      JOIN tbl_season s USING (id_season)
     WHERE n.id_fencer = 140 AND s.txt_code IN ('SPWS-2024-2025', 'SPWS-2025-2026')$$,
  $$VALUES ('SPWS-2024-2025', 'POL', 'ADMIN'), ('SPWS-2025-2026', 'POL', 'ADMIN')$$,
  'RNAT.07: fencer 140 is an administrator''s POL in 2024/25 and 2025/26');
SELECT fn_refresh_fencer_season_nationality(140, (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'));
SELECT is(
  (SELECT txt_country FROM tbl_fencer_nationality n JOIN tbl_season s USING (id_season)
    WHERE n.id_fencer = 140 AND s.txt_code = 'SPWS-2025-2026'),
  'POL', 'RNAT.07: a refresh from the season''s results keeps the administrator''s POL');

SELECT * FROM finish();
ROLLBACK;
