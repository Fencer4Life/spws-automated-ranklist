-- =============================================================================
-- Ranking publication boundary (design step 5)
-- =============================================================================
-- doc/plans/publication-boundary-2026-09-19.html §04/§05. Closes
-- SS26.PUBLISH.01-10. ADR-099.
--
-- WHAT THIS MIGRATION DOES.
--
-- Adds tbl_season.enum_ranking_publication (PPW_ONLY | FULL), NOT NULL
-- DEFAULT 'FULL'. Backfills the three spreadsheet-derived seasons
-- (SPWS-2023-2024 through SPWS-2025-2026) to PPW_ONLY; SPWS-2026-2027 keeps
-- its default, FULL. Every season created after this migration -- through
-- fn_create_season or fn_create_season_with_skeletons, neither of which
-- needs to change -- is FULL by construction, matching design §06's "later
-- seasons: FULL by season-creation policy."
--
-- A BEFORE UPDATE trigger then makes the column permanently immutable: no
-- role exemption (unlike the scoring lock's guards, which exist specifically
-- to let privileged/internal callers past an ordinarily-blocked write --
-- nothing should ever change this value, including a future migration
-- correcting a mistake, which would be an explicit, reviewed DROP
-- TRIGGER/ALTER/CREATE TRIGGER sequence in its own migration, not a bypass
-- built in ahead of time). ORDER MATTERS: the backfill UPDATE runs BEFORE
-- the trigger is created, or this migration's own backfill would trip its
-- own guard.
--
-- fn_ranking_full (design step 4, ADR-098) gains one check at the top of its
-- dispatcher: a PPW_ONLY season's call raises before any aggregation work
-- happens. Every other ranking function (fn_ranking_ppw, fn_ranking_kadra,
-- fn_fencer_scores_rolling) is untouched -- a PPW_ONLY season's plain PPW
-- ranking keeps working exactly as today; only the combined SPWS+EVF+ view
-- is refused.
-- =============================================================================

CREATE TYPE enum_ranking_publication AS ENUM (
  'PPW_ONLY',
  'FULL'
);

ALTER TABLE tbl_season
  ADD COLUMN enum_ranking_publication enum_ranking_publication
    NOT NULL DEFAULT 'FULL';

COMMENT ON COLUMN tbl_season.enum_ranking_publication IS
  'Immutable publication capability (design §06, ADR-099): PPW_ONLY or '
  'FULL. Migration/season-creation policy only -- never an Admin display '
  'toggle, never governed by the scoring-config lock. A BEFORE UPDATE '
  'trigger below rejects any later change to this column, for every role, '
  'permanently.';

-- Backfill BEFORE the trigger exists -- see header. The three
-- spreadsheet-derived seasons reproduce what the association's Excel
-- workbooks already published and never represented an official combined
-- ranking (design §06's "historical ranking publication boundary").
-- SPWS-2026-2027 keeps its column default (FULL) and needs no statement.
UPDATE tbl_season
   SET enum_ranking_publication = 'PPW_ONLY'
 WHERE txt_code IN ('SPWS-2023-2024', 'SPWS-2024-2025', 'SPWS-2025-2026');

-- -----------------------------------------------------------------------------
-- Immutability guard -- one column checked, every other tbl_season column
-- (dates, active flag, carry-over engine, scoring engine, lock timestamp)
-- passes through untouched. Same field-level-not-whole-row pattern as
-- fn_guard_scoring_config_write, applied to a stricter case: no bypass path
-- at all, because none is legitimate.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_guard_season_publication_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.enum_ranking_publication IS DISTINCT FROM OLD.enum_ranking_publication THEN
    RAISE EXCEPTION
      'Ranking publication capability for season % is immutable and cannot be changed after creation',
      OLD.txt_code;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_guard_season_publication_immutable() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_season_publication_immutable ON tbl_season;
CREATE TRIGGER trg_guard_season_publication_immutable
  BEFORE UPDATE ON tbl_season
  FOR EACH ROW EXECUTE FUNCTION fn_guard_season_publication_immutable();

-- -----------------------------------------------------------------------------
-- fn_ranking_full -- one check added at the top of the dispatcher, before
-- the season's carry-over engine is even read. Full redefinition (CREATE OR
-- REPLACE requires the complete body); the CASE dispatch below is otherwise
-- unchanged from 20260919000008.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_ranking_full(
  p_weapon   enum_weapon_type,
  p_gender   enum_gender_type,
  p_category enum_age_category,
  p_season   INT DEFAULT NULL,
  p_rolling  BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  rank               INT,
  id_fencer          INT,
  fencer_name        TEXT,
  spws_total         NUMERIC,
  evf_plus_total     NUMERIC,
  total_score        NUMERIC,
  bool_has_carryover BOOLEAN
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engine          enum_event_carryover_engine;
  v_publication     enum_ranking_publication;
  v_resolved_season INT;
BEGIN
  v_resolved_season := COALESCE(
    p_season,
    (SELECT s.id_season FROM tbl_season s WHERE s.bool_active LIMIT 1)
  );

  SELECT s.enum_carryover_engine, s.enum_ranking_publication INTO v_engine, v_publication
    FROM tbl_season s WHERE s.id_season = v_resolved_season;

  -- historical ranking publication boundary: a PPW_ONLY season never
  -- publishes the combined SPWS+EVF+ view. fn_ranking_ppw/fn_ranking_kadra
  -- remain the correct, unrestricted read paths for such a season.
  IF v_publication = 'PPW_ONLY' THEN
    RAISE EXCEPTION
      'Season % is PPW_ONLY and does not publish the full (SPWS+EVF+) ranking -- historical ranking publication boundary',
      v_resolved_season;
  END IF;

  CASE v_engine
    WHEN 'EVENT_CODE_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_full_event_code_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    WHEN 'EVENT_FK_MATCHING' THEN
      RETURN QUERY SELECT * FROM fn_ranking_full_event_fk_matching(
        p_weapon, p_gender, p_category, p_season, p_rolling
      );
    ELSE
      RAISE EXCEPTION 'Unknown carryover engine: % for season %', v_engine, v_resolved_season;
  END CASE;
END;
$$;

COMMENT ON FUNCTION fn_ranking_full(enum_weapon_type, enum_gender_type, enum_age_category, INT, BOOLEAN) IS
  'Design step 4/5: the generalized public ranking RPC. Returns spws_total, '
  'evf_plus_total and total_score, aggregating Season Scoring Rules (schema '
  'v1 or v2) into exactly two display groups. Raises for a PPW_ONLY season '
  '(ADR-099, historical ranking publication boundary) before any '
  'aggregation runs. Not yet called from any UI -- that wiring is design '
  'step 7, together with the SPWS-2026-2027 cutover to schema v2.';
