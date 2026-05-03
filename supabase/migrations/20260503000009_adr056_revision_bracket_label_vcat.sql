-- ---------------------------------------------------------------------------
-- ADR-056 revision (2026-05-03): bracket-label V-cat overrides BY derivation.
--
-- Pre-revision: fn_assert_result_vcat unconditionally compared
-- tournament.enum_age_category against fn_age_category(BY, season_end_year).
-- This blocked legitimate placements where the source bracket label says
-- one V-cat but BY+season_end_year canonical math says another (e.g. fencer
-- BY=1974 in season 2023-2024 ending 2024 → age 50 → canonical V2, but
-- physically competed in V1 bracket on 2023-01-14).
--
-- Post-revision: when NEW.enum_source_age_category is set on the result row
-- (single-V-cat bracket label captured by stage 7), the trigger trusts the
-- bracket label and skips the BY-derived check. The organizer's bracket
-- placement is the source of truth for past tournaments. Joint-pool source
-- brackets emit category_hint=None → enum_source_age_category=NULL → BY-
-- derived check fires (existing behaviour preserved).
--
-- Plan-test-IDs:
--   5.19.4 (pgTAP, file 41) — bracket-label V-cat wins when source set
--   5.19.5 (pgTAP, file 41) — NULL source → BY-derived check fires
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
    -- ADR-056 revision: bracket-label wins. When the result row carries
    -- a non-NULL enum_source_age_category, the splitter has already routed
    -- the row to its tournament based on the source bracket V-cat. The
    -- BY-derived check would retroactively conflict with that placement
    -- across season boundaries, which is exactly what the revision rejects.
    -- We trust the splitter; nothing to assert. (Joint-pool path falls
    -- through to the BY-derived check below.)
    IF NEW.enum_source_age_category IS NOT NULL THEN
        RETURN NEW;
    END IF;

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
  'V-cat invariant guard for tbl_result. ADR-056 revision (2026-05-03): '
  'when NEW.enum_source_age_category is set, trust the bracket-label '
  'placement and skip BY-derived check. NULL source falls back to '
  'BY-derived assertion (joint-pool path).';

COMMENT ON TRIGGER trg_assert_result_vcat ON tbl_result IS
  'V-cat invariant. ADR-056 revision: bracket-label V-cat (from '
  'enum_source_age_category) wins when set; BY-derived check fires only '
  'on joint-pool rows (NULL source).';
