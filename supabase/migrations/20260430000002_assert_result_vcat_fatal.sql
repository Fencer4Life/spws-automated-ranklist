-- ---------------------------------------------------------------------------
-- Layer 6 (combined-pool ingestion fix, 2026-04-30):
-- flip fn_assert_result_vcat from NOTICE-only to RAISE EXCEPTION.
--
-- Pre-condition: Layer 6 replay has cleared the data corruption (200 of 209
-- violator rows resolved by in-DB redo; 9 orphans waiting on admin to
-- create missing sibling tournaments). With the corruption gone, the
-- trigger can now block any future write that would re-introduce a V-cat
-- mismatch — the protection promised since Layer 2 finally turns on.
--
-- The 9 orphan rows still violate the invariant. They live in tournaments
-- whose expected V-cat sibling does not exist; admin must either create
-- the missing tournament + move the row, or delete the row. Until that's
-- done, this trigger will RAISE EXCEPTION on any UPDATE OF id_fencer or
-- id_tournament on those specific rows. INSERTs on other rows are
-- unaffected. (See the orphan list captured by Layer 6 dry-run.)
-- ---------------------------------------------------------------------------

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
        RAISE EXCEPTION '%', v_msg;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_assert_result_vcat() IS
  'V-cat invariant guard for tbl_result — RAISE EXCEPTION mode (Layer 6, '
  '2026-04-30). Was NOTICE-only between Layer 2 and Layer 6 while the '
  'historical 209 violator rows were cleaned up.';

COMMENT ON TRIGGER trg_assert_result_vcat ON tbl_result IS
  'V-cat invariant: tournament.enum_age_category must equal '
  'fn_age_category(fencer.int_birth_year, season_end_year). '
  'RAISE EXCEPTION since Layer 6.';
