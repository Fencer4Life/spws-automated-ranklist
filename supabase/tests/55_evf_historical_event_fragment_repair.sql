-- =============================================================================
-- Historical EVF result fragments must be consolidated onto their physical
-- 2025-2026 events without reflowing the season or assigning a Guildford link.
-- =============================================================================

BEGIN;
SELECT plan(25);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW62efs-2025-2026'
      AND txt_name = 'EVF Circuit – Guildford (GBR)'
      AND txt_location = 'Guildford'
      AND txt_country = 'Great Britain'
      AND dt_start = DATE '2026-01-10'
      AND dt_end = DATE '2026-01-11'
      AND arr_weapons = ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]
      AND url_event = 'https://www.veteransfencing.eu/event/evf-circuit-guildford-gbr/'
      AND txt_evf_slug = 'evf-circuit-guildford-gbr'),
  1,
  '55.1: PEW62efs is the canonical Guildford event with official identity'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code IN (
      'PEW63e-2025-2026', 'PEW64s-2025-2026',
      'PEW66f-2025-2026', 'PEW67f-2025-2026'
    )),
  0,
  '55.2: all four Guildford donor events are deleted after consolidation'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT, COUNT(r.id_result)::INT
       FROM tbl_tournament t
       LEFT JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW62efs-2025-2026') $$,
  $$ VALUES (16, 52) $$,
  '55.3: Guildford has 16 canonical tournament slots and 52 unique results'
);

SELECT is(
  (WITH slots AS (
     SELECT t.enum_weapon, t.enum_gender, t.enum_age_category, r.id_fencer, COUNT(*) AS n
       FROM tbl_event e
       JOIN tbl_tournament t ON t.id_event = e.id_event
       JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE e.txt_code = 'PEW62efs-2025-2026'
      GROUP BY 1,2,3,4
   ) SELECT COUNT(*)::INT FROM slots WHERE n > 1),
  0,
  '55.4: Guildford has at most one result per fencer and sporting slot'
);

SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
    WHERE e.txt_code = 'PEW62efs-2025-2026'
      AND (t.txt_code !~ '^PEW62efs-' OR t.dt_tournament NOT BETWEEN e.dt_start AND e.dt_end)),
  0,
  '55.5: every Guildford child code and date belongs to the survivor'
);

SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
    WHERE e.txt_code = 'PEW62efs-2025-2026'
      AND t.url_results IS DISTINCT FROM
          'https://www.fencingtimelive.com/tournaments/eventSchedule/E2A7B077F2824DD8A7F2E413B4211296#today'),
  0,
  '55.6: Guildford results retain the original Fencing Time Live URL'
);

SELECT results_eq(
  $$ SELECT r.int_place, t.int_participant_count
       FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
       JOIN tbl_result r ON r.id_tournament = t.id_tournament
      JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      WHERE e.txt_code = 'PEW62efs-2025-2026'
        AND f.txt_surname = 'ALCSER' AND f.txt_first_name = 'Norbert' AND f.int_birth_year = 1985
        AND t.enum_weapon = 'FOIL' AND t.enum_gender = 'M' AND t.enum_age_category = 'V1' $$,
  $$ VALUES (5, 13) $$,
  '55.7: Guildford keeps the richer full-field result when a partial scrape conflicts'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW3fs-2025-2026'
      AND txt_name = 'EVF Circuit Memoriam Max Geuter – Munich (GER)'
      AND txt_location = 'Munich' AND txt_country = 'Germany'
      AND dt_start = DATE '2025-12-06' AND dt_end = DATE '2025-12-07'
      AND arr_weapons = ARRAY['FOIL','SABRE']::enum_weapon_type[]
      AND url_event = 'https://www.veteransfencing.eu/event/evf-circuit-munich/'
      AND txt_evf_slug = 'evf-circuit-munich'),
  1,
  '55.8: PEW3fs is the canonical Munich foil-and-sabre event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW21fs-2025-2026'),
  0,
  '55.9: the emptied PEW21fs Munich donor is deleted'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT, COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW3fs-2025-2026') $$,
  $$ VALUES (8, 7) $$,
  '55.10: Munich has 8 canonical tournament slots and 7 source-verified results'
);

SELECT results_eq(
  $$ SELECT f.txt_surname, f.txt_first_name, t.enum_weapon::TEXT,
            t.enum_gender::TEXT, t.enum_age_category::TEXT,
            r.int_place, t.int_participant_count
       FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
       JOIN tbl_result r ON r.id_tournament = t.id_tournament
       JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      WHERE e.txt_code = 'PEW3fs-2025-2026'
      ORDER BY t.enum_weapon::TEXT, t.enum_gender::TEXT,
               t.enum_age_category::TEXT, f.txt_surname $$,
  $$ VALUES
      ('GINZERY','Tomas','FOIL','M','V1',5,17),
      ('ZYLKA','Henryk','FOIL','M','V4',1,12),
      ('GANSZCZYK','Marcin','SABRE','M','V2',6,25),
      ('NOWICKI','Robert','SABRE','M','V2',9,25),
      ('CHIAROMONTE','Francesco','SABRE','M','V2',8,25),
      ('GAJDA','Leszek','SABRE','M','V3',7,22),
      ('FUHRMANN','Ulrike','SABRE','F','V3',5,11)
    ORDER BY column3, column4, column5, column1 $$,
  '55.10a: Munich places and full fields match the original FencingWorldwide pages'
);

SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
     LEFT JOIN (VALUES
       ('FOIL'::enum_weapon_type,'M'::enum_gender_type,'V1'::enum_age_category,'903539','2025-12-07'::DATE),
       ('FOIL','M','V2','903540','2025-12-07'::DATE),
       ('FOIL','M','V4','903542','2025-12-06'::DATE),
       ('FOIL','F','V2','903536','2025-12-06'::DATE),
       ('SABRE','M','V2','912306','2025-12-06'::DATE),
       ('SABRE','M','V3','912307','2025-12-07'::DATE),
       ('SABRE','F','V2','912301','2025-12-07'::DATE),
       ('SABRE','F','V3','912303','2025-12-06'::DATE)
     ) expected(weapon,gender,age_category,competition_id,held_on)
       ON expected.weapon=t.enum_weapon AND expected.gender=t.enum_gender
      AND expected.age_category=t.enum_age_category
    WHERE e.txt_code = 'PEW3fs-2025-2026' AND (
      t.txt_code !~ '^PEW3fs-'
      OR expected.competition_id IS NULL
      OR t.dt_tournament IS DISTINCT FROM expected.held_on
      OR t.url_results IS DISTINCT FROM format(
        'https://www.fencingworldwide.com/en/%s-2025/results/', expected.competition_id
      )
    )),
  0,
  '55.11: Munich children use PEW3fs and retain their scoring-site URL'
);

SELECT results_eq(
  $$ SELECT COUNT(*)::INT, COUNT(r.id_result)::INT, MAX(t.int_participant_count)::INT,
            MAX(r.int_place)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW31fs-2025-2026')
        AND t.enum_weapon = 'SABRE' AND t.enum_gender = 'M' AND t.enum_age_category = 'V1' $$,
  $$ VALUES (1, 1, 20, 3) $$,
  '55.12: Faches keeps the richer sabre field and one Robert Teclaw result'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW31fs-2025-2026'
      AND dt_start = DATE '2026-02-07' AND dt_end = DATE '2026-02-08'
      AND arr_weapons = ARRAY['FOIL','SABRE']::enum_weapon_type[]),
  1,
  '55.13: Faches metadata spans the official foil-and-sabre weekend'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW5ef-2025-2026'
      AND txt_name = 'EVF Circuit – Stockholm (SWE)'
      AND txt_location = 'Stockholm' AND txt_country = 'Sweden'
      AND dt_start = DATE '2026-03-14' AND dt_end = DATE '2026-03-14'
      AND arr_weapons = ARRAY['EPEE','FOIL']::enum_weapon_type[]
      AND url_event = 'https://www.veteransfencing.eu/event/evf-circuit-stockholm-swe/'
      AND txt_evf_slug = 'evf-circuit-stockholm-swe'),
  1,
  '55.14: PEW5ef is the canonical Stockholm epee-and-foil event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW65ef-2025-2026'),
  0,
  '55.15: the emptied PEW65 Stockholm donor is deleted'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT, COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW5ef-2025-2026') $$,
  $$ VALUES (5, 10) $$,
  '55.16: Stockholm has its 5 tournament slots and all 10 unique results'
);

SELECT is(
  (SELECT COUNT(*)::INT
     FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
    WHERE e.txt_code = 'PEW5ef-2025-2026'
      AND (t.txt_code !~ '^PEW5ef-' OR t.url_results IS DISTINCT FROM
        'https://engarde-service.com/tournament/sthlm/vet2026')),
  0,
  '55.17: Stockholm children use PEW5ef and retain the Engarde results URL'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW8es-2025-2026'
      AND txt_name = 'EVF Circuit – Chania (GRE)'
      AND txt_location = 'Chania' AND txt_country = 'Greece'
      AND dt_start = DATE '2026-05-02' AND dt_end = DATE '2026-05-03'
      AND arr_weapons = ARRAY['EPEE','SABRE']::enum_weapon_type[]
      AND url_event = 'https://www.veteransfencing.eu/event/evf-circuit-athens-gre/'
      AND txt_evf_slug = 'evf-circuit-athens-gre'),
  1,
  '55.18: PEW8es is the corrected Chania epee-and-sabre calendar event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code = 'PEW8f-2025-2026'),
  0,
  '55.19: the corrupted current-season PEW8f identity no longer exists'
);

SELECT results_eq(
  $$ SELECT t.int_participant_count, COUNT(r.id_result)::INT
       FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
       LEFT JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE e.txt_code = 'PEW8f-2024-2025'
        AND t.enum_weapon = 'FOIL' AND t.enum_gender = 'F' AND t.enum_age_category = 'V1'
      GROUP BY t.int_participant_count $$,
  $$ VALUES (4, 2) $$,
  '55.20: the prior Guildford foil slot keeps the richer field and two unique fencers'
);

SELECT results_eq(
  $$ SELECT r.int_place
       FROM tbl_event e JOIN tbl_tournament t ON t.id_event = e.id_event
       JOIN tbl_result r ON r.id_tournament = t.id_tournament
      JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      WHERE e.txt_code = 'PEW8f-2024-2025'
        AND f.txt_surname = 'LIPKOWSKA' AND f.txt_first_name = 'Dominika' AND f.int_birth_year = 1984
        AND t.enum_weapon = 'FOIL' AND t.enum_gender = 'F' AND t.enum_age_category = 'V1' $$,
  $$ VALUES (3) $$,
  '55.21: the richer prior Guildford placing replaces the partial duplicate'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event current_event
    JOIN tbl_event prior_event ON prior_event.id_event = current_event.id_prior_event
    WHERE current_event.txt_code IN (
      'PEW21fs-2026-2027','PEW63e-2026-2027','PEW64s-2026-2027',
      'PEW65ef-2026-2027','PEW66f-2026-2027','PEW67f-2026-2027'
    ) AND prior_event.txt_code IN (
      'PEW21fs-2025-2026','PEW63e-2025-2026','PEW64s-2025-2026',
      'PEW65ef-2025-2026','PEW66f-2025-2026','PEW67f-2025-2026'
    )),
  0,
  '55.22: deleted donors cannot remain prior-link targets'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code = 'PEW73-2026-2027' AND id_prior_event IS NOT NULL),
  0,
  '55.23: the repair does not assign a prior link to the real Guildford row'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code LIKE 'PEW%-2025-2026'),
  (SELECT COUNT(*)::INT FROM tbl_event
    WHERE txt_code LIKE 'PEW%-2025-2026'
      AND txt_code NOT IN (
        'PEW21fs-2025-2026','PEW63e-2025-2026','PEW64s-2025-2026',
        'PEW65ef-2025-2026','PEW66f-2025-2026','PEW67f-2025-2026'
      )),
  '55.24: no unapproved 2025-2026 PEW code is removed or reflowed'
);

SELECT * FROM finish();
ROLLBACK;
