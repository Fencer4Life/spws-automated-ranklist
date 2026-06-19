-- =============================================================================
-- N14 — populate tbl_tournament.url_results during ingestion (ADR-073 amendment)
-- =============================================================================
-- The Commit plugin (python/pipeline/plugins/ingest.py) now persists each
-- committed tournament's results-page URL from the parsed WEB source
-- (FTL/ENGARDE/FOURFENCE/DARTAGNAN/OPHARDT_HTML). It flows through this RPC via
-- the new trailing arg `p_url_results`:
--   * non-NULL  → set/overwrite url_results (re-ingest refreshes to the page
--                 actually ingested — the established populate_tournament_urls.py
--                 behaviour, now inline);
--   * NULL      → preserve the existing value (XML / EVF-API / file paths and
--                 admin-entered URLs are never wiped).
-- `url_event` stays admin-managed; EVF-API URLs are never written (gated on
-- domestic/web SourceKind in the Commit plugin). No vw_score change — it already
-- selects t.url_results for the fencer Drilldown.
--
-- Recreated from the current definition (20260429000003_evf_fk_ingestion.sql,
-- which added p_id_evf_competition); only the new arg + the url_results writes
-- are additive. Relates to: ADR-073, ADR-076 (source_decisions map), ADR-068
-- (populate_tournament_urls behaviour).

-- Adding a parameter changes the function's argument signature, so CREATE OR
-- REPLACE would leave an extra overload (the 7-arg version) and make 6-arg calls
-- ambiguous. Drop the prior signature first (same pattern as 20260429000003,
-- which dropped its 6-arg predecessor before adding p_id_evf_competition).
DROP FUNCTION IF EXISTS fn_find_or_create_tournament(
  INT, enum_weapon_type, enum_gender_type, enum_age_category, DATE,
  enum_tournament_type, INT);

CREATE OR REPLACE FUNCTION fn_find_or_create_tournament(
  p_event_id           INT,
  p_weapon             enum_weapon_type,
  p_gender             enum_gender_type,
  p_age_category       enum_age_category,
  p_date               DATE,
  p_type               enum_tournament_type,
  p_id_evf_competition INT DEFAULT NULL,
  p_url_results        TEXT DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tourn_id    INT;
  v_event_code  TEXT;
  v_season_code TEXT;
  v_tourn_code  TEXT;
BEGIN
  SELECT t.id_tournament INTO v_tourn_id
  FROM tbl_tournament t
  WHERE t.id_event = p_event_id
    AND t.enum_weapon = p_weapon
    AND t.enum_gender = p_gender
    AND t.enum_age_category = p_age_category;

  IF v_tourn_id IS NOT NULL THEN
    -- Backfill id_evf_competition when supplied and currently NULL.
    IF p_id_evf_competition IS NOT NULL THEN
      UPDATE tbl_tournament
         SET id_evf_competition = p_id_evf_competition
       WHERE id_tournament = v_tourn_id AND id_evf_competition IS NULL;
    END IF;
    -- Refresh url_results when a web source URL is supplied; NULL preserves the
    -- existing value (never wipes admin / non-web URLs).
    IF p_url_results IS NOT NULL THEN
      UPDATE tbl_tournament
         SET url_results = p_url_results
       WHERE id_tournament = v_tourn_id;
    END IF;
    RETURN v_tourn_id;
  END IF;

  SELECT e.txt_code, s.txt_code
    INTO v_event_code, v_season_code
  FROM tbl_event e
  JOIN tbl_season s ON s.id_season = e.id_season
  WHERE e.id_event = p_event_id;

  IF v_event_code IS NULL THEN
    RAISE EXCEPTION 'Event % does not exist', p_event_id;
  END IF;

  v_event_code := regexp_replace(v_event_code, '-\d{4}-\d{4}$', '');
  v_tourn_code := v_event_code || '-' || p_age_category || '-' || p_gender || '-' || p_weapon || '-' || v_season_code;
  v_tourn_code := regexp_replace(v_tourn_code, '-SPWS-(\d{4}-\d{4})$', '-\1');

  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type,
    enum_weapon, enum_gender, enum_age_category,
    dt_tournament, int_participant_count, enum_import_status,
    id_evf_competition, url_results
  ) VALUES (
    p_event_id, v_tourn_code,
    p_age_category || ' ' || p_gender || ' ' || p_weapon,
    p_type, p_weapon, p_gender, p_age_category,
    p_date, 0, 'PLANNED', p_id_evf_competition, p_url_results
  )
  RETURNING id_tournament INTO v_tourn_id;

  RETURN v_tourn_id;
END;
$$;
