-- =============================================================================
-- pgTAP — ADR-056 revision (2026-05-03):
-- fn_assert_result_vcat uses enum_source_age_category as authoritative V-cat
-- when set, falls back to BY-derived V-cat otherwise.
--
-- Plan-test-IDs:
--   5.19.4 — when NEW.enum_source_age_category is set on tbl_result, the
--            trigger trusts the bracket label and does NOT raise even if
--            BY-derived V-cat would mismatch (organizer placement wins).
--   5.19.5 — when NEW.enum_source_age_category is NULL (joint-pool path),
--            the trigger falls back to the BY-derived assertion (existing
--            behaviour preserved for joint pools).
-- =============================================================================

BEGIN;

SELECT plan(2);

-- Setup: isolated season + V1 tournament + a fencer whose BY makes them
-- canonically V2 (BY=1974, season ending 2024 → age 50 → V2).
-- Use far-future dates (matching test 23's pattern) to avoid season-range
-- conflicts with seed seasons.
DO $vcat_bracket_setup$
DECLARE
  v_season  INT;
  v_org     INT;
  v_event   INT;
  v_tour    INT;
  v_fencer  INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('VCATBRK-41', '2099-09-01', '2100-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
       VALUES ('VCATORG41', 'V-cat bracket-label org')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code='VCATORG41';

  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer,
                         txt_location, dt_start, dt_end, enum_status)
       VALUES ('VCAT41E', 'V-cat bracket event', v_season, v_org,
               'TestCity', '2100-03-15', '2100-03-15', 'COMPLETED')
    RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (id_event, txt_code, enum_type, enum_weapon,
                              enum_gender, enum_age_category, dt_tournament)
       VALUES (v_event, 'VCAT41E-V1-M-SABRE', 'PPW', 'SABRE', 'M', 'V1', '2100-03-15')
    RETURNING id_tournament INTO v_tour;

  -- BY=2050: canonically V2 (age 50 in 2100 → V2) but the bracket label says V1.
  -- Mirrors the GP1 ZAWROTNIAK situation (BY=1974 in 2024, age 50, canonical V2)
  -- without colliding with seed fencers.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year)
       VALUES ('BRACKET41', 'Sim', 2050)
    RETURNING id_fencer INTO v_fencer;
END;
$vcat_bracket_setup$;

-- ===== 5.19.4 — bracket-label V-cat wins =====
-- INSERT a V2-canonical fencer into a V1 tournament with
-- enum_source_age_category='V1' (the splitter set it from category_hint).
-- Pre-revision: trigger raises (BY-derived mismatch).
-- Post-revision: trigger trusts the bracket label, INSERT succeeds.
SELECT lives_ok(
  $$ INSERT INTO tbl_result (id_fencer, id_tournament, int_place,
                              enum_source_age_category)
       VALUES (
         (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='BRACKET41' AND txt_first_name='Sim'),
         (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VCAT41E-V1-M-SABRE'),
         3,
         'V1'::enum_age_category
       ) $$,
  '5.19.4: bracket-label V-cat (enum_source_age_category=V1) wins — '
  'V2-canonical fencer accepted into V1 tournament without exception'
);

-- ===== 5.19.5 — NULL source V-cat → BY-derived assertion fires =====
-- INSERT a second result for the same fencer, this time with
-- enum_source_age_category=NULL (joint-pool source). BY-derived V-cat is V2,
-- tournament is V1 → trigger MUST raise.
-- Use a DIFFERENT placement to avoid PK-like collisions.
SELECT throws_like(
  $$ INSERT INTO tbl_result (id_fencer, id_tournament, int_place,
                              enum_source_age_category)
       VALUES (
         (SELECT id_fencer FROM tbl_fencer WHERE txt_surname='BRACKET41' AND txt_first_name='Sim'),
         (SELECT id_tournament FROM tbl_tournament WHERE txt_code='VCAT41E-V1-M-SABRE'),
         99,
         NULL
       ) $$,
  '%placed in V1 but expected V2%',
  '5.19.5: NULL enum_source_age_category falls back to BY-derived assertion '
  '(V2-canonical fencer rejected from V1 tournament when source V-cat is unset)'
);

SELECT * FROM finish();

ROLLBACK;
