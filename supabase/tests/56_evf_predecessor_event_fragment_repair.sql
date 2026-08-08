-- =============================================================================
-- Six predecessor-season EVF physical events must own all of their weapon
-- results without renumbering either historical season or inferring links.
-- =============================================================================

BEGIN;
SELECT plan(26);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW5efs-2023-2024'
    AND dt_start=DATE '2023-09-16' AND dt_end=DATE '2023-09-16'
    AND arr_weapons=ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]),
  1, '56.1: Budapest 2023 is one PEW5efs physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW8efs-2023-2024'
    AND dt_start=DATE '2023-12-16' AND dt_end=DATE '2023-12-16'
    AND arr_weapons=ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]),
  1, '56.2: Terni 2023 is one PEW8efs physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW9ef-2023-2024'
    AND dt_start=DATE '2024-02-24' AND dt_end=DATE '2024-02-24'
    AND arr_weapons=ARRAY['EPEE','FOIL']::enum_weapon_type[]),
  1, '56.3: Stockholm 2024 is one PEW9ef physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW4ef-2024-2025'
    AND dt_start=DATE '2025-01-04' AND dt_end=DATE '2025-01-05'
    AND arr_weapons=ARRAY['EPEE','FOIL']::enum_weapon_type[]),
  1, '56.4: Guildford 2025 is one PEW4ef physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW6efs-2024-2025'
    AND dt_start=DATE '2025-02-01' AND dt_end=DATE '2025-02-02'
    AND arr_weapons=ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[]),
  1, '56.5: Terni 2025 is one PEW6efs physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW7es-2024-2025'
    AND dt_start=DATE '2025-03-29' AND dt_end=DATE '2025-03-29'
    AND arr_weapons=ARRAY['EPEE','SABRE']::enum_weapon_type[]),
  1, '56.6: Warsaw-Jablonna 2025 is one PEW7es physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code IN (
    'PEW21e-2023-2024','PEW24e-2023-2024','PEW11f-2023-2024',
    'PEW11e-2024-2025','PEW12e-2024-2025','PEW14e-2024-2025')),
  0, '56.7: all six named fragment donors are deleted'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW5efs-2023-2024') $$,
  $$ VALUES (12,26) $$, '56.8: Budapest conserves 12 slots and 26 results'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW8efs-2023-2024') $$,
  $$ VALUES (7,11) $$, '56.9: Terni 2023 conserves 7 slots and 11 results'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW9ef-2023-2024') $$,
  $$ VALUES (6,10) $$, '56.10: Stockholm conserves 6 slots and 10 results'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW4ef-2024-2025') $$,
  $$ VALUES (5,9) $$, '56.11: Guildford conserves 5 slots and 9 results'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW6efs-2024-2025') $$,
  $$ VALUES (7,12) $$, '56.12: Terni 2025 conserves 7 slots and 12 results'
);

SELECT results_eq(
  $$ SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT
       FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
      WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW7es-2024-2025') $$,
  $$ VALUES (15,89) $$, '56.13: Warsaw-Jablonna conserves 15 slots and 89 results'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
    WHERE e.txt_code IN ('PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
      'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025')
      AND t.txt_code !~ ('^'||regexp_replace(e.txt_code,'-[0-9]{4}-[0-9]{4}$','')||'-')),
  0, '56.14: every retained child code uses its survivor base'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
    WHERE e.txt_code IN ('PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
      'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025')
      AND t.dt_tournament NOT BETWEEN e.dt_start AND e.dt_end),
  0, '56.15: every retained tournament date belongs to its physical event'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_registration reg JOIN tbl_event e ON e.id_event=reg.id_event
    WHERE e.txt_code IN ('PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
      'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025')),
  0, '56.16: no repaired predecessor event has registrations'
);

SELECT ok(
  pg_get_functiondef('fn_merge_predecessor_evf_event(text,text[],text,text,text,text,date,date,enum_weapon_type[],integer,integer)'::regprocedure)
    LIKE '%v_candidates_after<>v_candidates%',
  '56.17: existing match-candidate provenance is conserved rather than rejected'
);

SELECT is(
  (WITH duplicates AS (
    SELECT e.id_event,t.enum_weapon,t.enum_gender,t.enum_age_category,r.id_fencer,COUNT(*) n
      FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
      JOIN tbl_result r ON r.id_tournament=t.id_tournament
     WHERE e.txt_code IN ('PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
       'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025')
     GROUP BY 1,2,3,4,5 HAVING COUNT(*)>1)
   SELECT COUNT(*)::INT FROM duplicates),
  0, '56.18: no fencer is duplicated in a repaired sporting slot'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event current_event JOIN tbl_event donor
    ON donor.id_event=current_event.id_prior_event WHERE donor.txt_code IN (
      'PEW21e-2023-2024','PEW24e-2023-2024','PEW11f-2023-2024',
      'PEW11e-2024-2025','PEW12e-2024-2025','PEW14e-2024-2025')),
  0, '56.19: no event retains a deleted donor as prior-event target'
);

SELECT is((SELECT id_prior_event FROM tbl_event WHERE txt_code='PEW4ef-2024-2025'),
  NULL::INT, '56.20: Guildford survivor has no guessed prior link');
SELECT is((SELECT id_prior_event FROM tbl_event WHERE txt_code='PEW7es-2024-2025'),
  NULL::INT, '56.21: Warsaw-Jablonna survivor has no unrelated prior link');
SELECT is((SELECT id_prior_event FROM tbl_event WHERE txt_code='PEW8es-2025-2026'),
  NULL::INT, '56.22: Chania no longer points to the distinct prior Guildford foil event');

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event WHERE txt_code='PEW15f-2024-2025'
    AND dt_start=DATE '2025-05-15' AND dt_end=DATE '2025-05-15'),
  1, '56.23: unresolved PEW15f remains untouched'
);

SELECT results_eq(
  $$ SELECT txt_code,dt_start,dt_end FROM tbl_season
      WHERE txt_code IN ('SPWS-2023-2024','SPWS-2024-2025') ORDER BY txt_code $$,
  $$ VALUES ('SPWS-2023-2024',DATE '2023-01-01',DATE '2024-07-15'),
            ('SPWS-2024-2025',DATE '2024-08-15',DATE '2025-07-15') ORDER BY column1 $$,
  '56.24: historical season boundaries remain exactly unchanged'
);

SELECT results_eq(
  $$ SELECT s.txt_code,COUNT(*)::INT FROM tbl_event e JOIN tbl_season s ON s.id_season=e.id_season
      WHERE s.txt_code IN ('SPWS-2023-2024','SPWS-2024-2025') AND e.txt_code LIKE 'PEW%'
      GROUP BY s.txt_code ORDER BY s.txt_code $$,
  $$ VALUES ('SPWS-2023-2024',22),('SPWS-2024-2025',12) ORDER BY column1 $$,
  '56.25: only the seven approved donor rows reduce predecessor PEW counts'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
    JOIN tbl_event e ON e.id_event=t.id_event WHERE e.txt_code IN (
      'PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
      'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025')),
  157, '56.26: all 157 reviewed predecessor results are conserved'
);

SELECT * FROM finish();
ROLLBACK;
