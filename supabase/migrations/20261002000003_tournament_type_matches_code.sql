-- =============================================================================
-- A tournament's type agrees with its code family (TT.CODE)
-- =============================================================================
-- The ranking and the drilldown file a result under domestic or EVF+ by its
-- tournament's enum_type. On 2 Oct 2026 the Phase 5 draft builder typed every
-- re-ingested tournament PPW, so on LOCAL Manama (IMSW) and Guildford
-- (PEW62efs) were listed under domestic tournaments and counted in the
-- domestic ranking; the ADR-105 guards keyed on an international type did not
-- see them either.
--
-- fn_tournament_type_for_code mirrors the ingest's
-- derive_tourn_type_from_event_code (python/pipeline/db_connector.py) on the
-- code's first segment. A family it does not know (GP of 2023/24, test codes)
-- is not checked. The trigger refuses a disagreeing insert or update on every
-- write path, the draft commit included. It runs as its owner, so a writer
-- needs no EXECUTE on the mapping, which stays off the anon allowlist (52.7).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_tournament_type_for_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN f ~ '^PPW[0-9]+$' THEN 'PPW'
    WHEN f = 'MPW' THEN 'MPW'
    WHEN f = 'PSW' THEN 'PSW'
    WHEN f ~* '^PEW[0-9]+[efs]*$' THEN 'PEW'
    WHEN f IN ('MEW', 'IMEW') THEN 'MEW'
    -- DMEW, the team European championship, is never scraped for the ranking
    -- (ADR-021): it holds no tournament and its type is left unclaimed.
    WHEN f IN ('MSW', 'IMSW') THEN 'MSW'
    WHEN f ~ '^PPS[0-9]+[WM]?[efsEFS]*$' THEN 'PPS'
    WHEN f ~ '^MPS[WM]?[efsEFS]*$' THEN 'MPS'
  END
  FROM (SELECT split_part(p_code, '-', 1) AS f) s
$$;

CREATE OR REPLACE FUNCTION fn_guard_tournament_type_matches_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expected TEXT := fn_tournament_type_for_code(NEW.txt_code);
BEGIN
  IF v_expected IS NOT NULL AND v_expected <> NEW.enum_type::TEXT THEN
    RAISE EXCEPTION 'tournament coded % but typed %: its code family is %',
      NEW.txt_code, NEW.enum_type, v_expected
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tournament_type_matches_code ON tbl_tournament;
CREATE TRIGGER trg_tournament_type_matches_code
  BEFORE INSERT OR UPDATE OF txt_code, enum_type ON tbl_tournament
  FOR EACH ROW EXECUTE FUNCTION fn_guard_tournament_type_matches_code();

REVOKE ALL ON FUNCTION fn_tournament_type_for_code(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_tournament_type_for_code(TEXT) TO service_role;
REVOKE ALL ON FUNCTION fn_guard_tournament_type_matches_code() FROM PUBLIC, anon, authenticated;
