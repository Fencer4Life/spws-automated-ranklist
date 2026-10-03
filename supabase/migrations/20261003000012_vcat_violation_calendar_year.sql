-- =============================================================================
-- ADR-047 amendment (2026-10-03): the category check accepts the calendar year
-- a labelled result was fenced in.
-- =============================================================================
-- Since the ADR-056 revision (20260503000009), trg_assert_result_vcat trusts a
-- result that carries its source's category label (enum_source_age_category)
-- and skips the comparison. This view was written four days before that and
-- kept comparing every result with the birth-year category for the season's
-- end year, so it listed labelled results the guard had deliberately accepted.
--
-- The case that matters: the World Championships of 12-16 November 2025 placed
-- KORONA Przemyslaw and KROCHMALSKI Jakub, born 1976, in V1 (49 in 2025),
-- while SPWS counts them V2 for 2025/26 (50 in 2026). Both are right. ADR-106
-- already accepts this one-year shift when it identifies international rows.
--
-- A labelled result now passes when its label is the tournament's category and
-- that category is the birth-year category for the calendar year the
-- tournament was fenced in (its own date, else its event's start). Everything
-- else is checked by the season's end year, as before; a labelled result that
-- fits neither year is still listed. Columns, order and grants are unchanged.
--
-- Plan-test-IDs: pgTAP 24.5-24.8.
-- =============================================================================

CREATE OR REPLACE VIEW vw_vcat_violation AS
SELECT
    r.id_result,
    r.id_fencer,
    r.id_tournament,
    f.txt_surname,
    f.txt_first_name,
    f.int_birth_year,
    t.txt_code              AS tournament_code,
    t.enum_age_category     AS tournament_vcat,
    fn_age_category(
        f.int_birth_year::INT,
        EXTRACT(YEAR FROM s.dt_end)::INT
    )                       AS expected_vcat,
    EXTRACT(YEAR FROM s.dt_end)::INT AS season_end_year,
    e.txt_code              AS event_code,
    s.txt_code              AS season_code,
    fn_vcat_violation_msg(
        f.int_birth_year::INT,
        t.enum_age_category,
        EXTRACT(YEAR FROM s.dt_end)::INT,
        f.txt_surname || ' ' || f.txt_first_name,
        t.txt_code
    )                       AS violation_msg
  FROM tbl_result    r
  JOIN tbl_fencer    f ON f.id_fencer    = r.id_fencer
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_event     e ON e.id_event     = t.id_event
  JOIN tbl_season    s ON s.id_season    = e.id_season
 WHERE f.int_birth_year IS NOT NULL
   AND fn_age_category(f.int_birth_year::INT, EXTRACT(YEAR FROM s.dt_end)::INT) IS NOT NULL
   AND fn_age_category(f.int_birth_year::INT, EXTRACT(YEAR FROM s.dt_end)::INT)
       <> t.enum_age_category
   AND NOT (
         r.enum_source_age_category IS NOT NULL
     AND r.enum_source_age_category = t.enum_age_category
     AND fn_age_category(
           f.int_birth_year::INT,
           EXTRACT(YEAR FROM COALESCE(t.dt_tournament, e.dt_start))::INT
         ) IS NOT DISTINCT FROM t.enum_age_category
   );

COMMENT ON VIEW vw_vcat_violation IS
  'Results whose tournament category differs from the fencer''s birth-year '
  'category for the season''s end year (ADR-047). A result carrying its '
  'source''s label passes when that label is the category for the calendar '
  'year the tournament was fenced in (ADR-047 amendment 2026-10-03, the '
  'one-year shift ADR-106 accepts). Output: the trigger''s message text plus '
  'the row coordinates needed to fix it.';

GRANT SELECT ON vw_vcat_violation TO authenticated;
