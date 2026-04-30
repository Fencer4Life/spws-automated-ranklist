-- ---------------------------------------------------------------------------
-- Layer 2 (combined-pool ingestion fix, 2026-04-29):
-- fn_assert_result_vcat — verify V-cat invariant on every tbl_result write.
--
-- Invariant: a result row R inserted into tournament T must satisfy
--   T.enum_age_category = fn_age_category(F.int_birth_year, season_end_year)
-- where F = R's fencer and season_end_year derives from T's parent event's
-- season. Violations indicate combined-pool corruption (e.g. V1 fencer
-- placed in a V0 tournament because the FTL/Engarde path was missing the
-- splitter).
--
-- This migration installs the trigger in NOTICE-ONLY mode — RAISE NOTICE,
-- not RAISE EXCEPTION — so existing data and live ingest aren't blocked.
-- After Layer 6 (replay of 162 corrupted groups), a follow-up migration
-- flips the trigger to RAISE EXCEPTION.
--
-- A row with NULL int_birth_year is skipped silently: V-cat is unknowable,
-- and the admin's identity queue is the right surface for that signal.
-- ---------------------------------------------------------------------------

-- Pure expression-only checker: returns the violation message (or NULL when
-- clean). Lifts the V-cat-mismatch logic out of the trigger so pgTAP can
-- exercise every branch without depending on RAISE NOTICE capture, and so
-- Layer 5 admin tooling can re-use the same predicate.
CREATE OR REPLACE FUNCTION fn_vcat_violation_msg(
    p_birth_year       INT,
    p_tour_vcat        enum_age_category,
    p_season_end_year  INT,
    p_fencer_name      TEXT,
    p_tour_code        TEXT
)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_birth_year IS NULL THEN NULL
        WHEN fn_age_category(p_birth_year, p_season_end_year) IS NULL THEN NULL
        WHEN fn_age_category(p_birth_year, p_season_end_year) = p_tour_vcat THEN NULL
        ELSE format(
            'fn_assert_result_vcat: %s (BY=%s) placed in %s but expected %s (tournament %s)',
            p_fencer_name,
            p_birth_year,
            p_tour_vcat,
            fn_age_category(p_birth_year, p_season_end_year),
            p_tour_code
        )
    END;
$$;

COMMENT ON FUNCTION fn_vcat_violation_msg(INT, enum_age_category, INT, TEXT, TEXT) IS
  'Returns the V-cat invariant violation message for a result row, or NULL '
  'when the row is consistent. Pure helper used by trg_assert_result_vcat '
  'and by Layer 5 admin tooling.';


CREATE OR REPLACE FUNCTION fn_assert_result_vcat()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_birth_year   SMALLINT;
    v_fencer_name  TEXT;
    v_tour_vcat    enum_age_category;
    v_tour_code    TEXT;
    v_season_end   INT;
    v_msg          TEXT;
BEGIN
    SELECT f.int_birth_year, f.txt_surname || ' ' || f.txt_first_name
      INTO v_birth_year, v_fencer_name
      FROM tbl_fencer f
     WHERE f.id_fencer = NEW.id_fencer;

    SELECT t.enum_age_category, t.txt_code,
           EXTRACT(YEAR FROM s.dt_end)::INT
      INTO v_tour_vcat, v_tour_code, v_season_end
      FROM tbl_tournament t
      JOIN tbl_event e   ON e.id_event  = t.id_event
      JOIN tbl_season s  ON s.id_season = e.id_season
     WHERE t.id_tournament = NEW.id_tournament;

    v_msg := fn_vcat_violation_msg(
        v_birth_year::INT, v_tour_vcat, v_season_end, v_fencer_name, v_tour_code
    );

    IF v_msg IS NOT NULL THEN
        RAISE NOTICE '%', v_msg;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_assert_result_vcat() IS
  'NOTICE-only V-cat invariant guard for tbl_result. Layer 2 of the '
  'combined-pool ingestion fix (2026-04-29). Flipped to RAISE EXCEPTION '
  'after Layer 6 replay clears the 162 corrupted groups.';

DROP TRIGGER IF EXISTS trg_assert_result_vcat ON tbl_result;
CREATE TRIGGER trg_assert_result_vcat
    BEFORE INSERT OR UPDATE OF id_fencer, id_tournament
    ON tbl_result
    FOR EACH ROW
    EXECUTE FUNCTION fn_assert_result_vcat();

COMMENT ON TRIGGER trg_assert_result_vcat ON tbl_result IS
  'V-cat invariant: tournament.enum_age_category must equal '
  'fn_age_category(fencer.int_birth_year, season_end_year). '
  'NOTICE-only until Layer 6 replay; FATAL after.';
