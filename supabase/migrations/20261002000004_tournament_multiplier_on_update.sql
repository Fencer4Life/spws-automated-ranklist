-- =============================================================================
-- The cached tournament multiplier follows a change of type (TT.MULT)
-- =============================================================================
-- tbl_tournament.num_multiplier is a display cache of the season's type
-- multiplier (20260919000004): scoring resolves its own and never reads it,
-- the drilldown prints it through vw_score. fn_auto_populate_multiplier set it
-- on INSERT only. On 2 Oct 2026 the re-ingested Plovdiv and Manama tournaments,
-- inserted as PPW (1.0) and re-typed MEW and MSW by an UPDATE, kept 1.0 while
-- their points used 1.2. The trigger now also fires when the type, the event
-- (and so the season) or the cached value itself changes. Its function is
-- unchanged.
-- =============================================================================

DROP TRIGGER IF EXISTS trg_tournament_auto_multiplier ON tbl_tournament;
CREATE TRIGGER trg_tournament_auto_multiplier
  BEFORE INSERT OR UPDATE OF enum_type, id_event, num_multiplier ON tbl_tournament
  FOR EACH ROW EXECUTE FUNCTION fn_auto_populate_multiplier();
