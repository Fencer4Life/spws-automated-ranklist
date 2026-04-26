-- =============================================================================
-- Phase 2: EVF event code allocator + classifier (ADR-043)
-- =============================================================================
-- Three helpers used by fn_import_evf_events_v2 (next migration):
--   fn_normalize_city_key(text, text)  → (loc_key, country_key)
--   fn_classify_evf_event(text, bool)  → 'PEW' | 'IMEW' | 'DMEW'
--   fn_allocate_evf_event_code(int, text, text, text)
--                                      → (txt_code, id_prior_event, alloc_path)
--
-- The allocator's three-step ladder for PEW (city-matched):
--   A. CURRENT_SLOT_REUSE  — admin pre-created CREATED PEWn slot matches city
--   B. PRIOR_SEASON_MATCH  — prior-season PEWn with same city → reuse number
--   C. NEXT_FREE_ALLOC     — MAX(N)+1 in current season, FK NULL, alert admin
--
-- For IMEW / DMEW (singletons): same ladder but without city — the season
-- has at most one IMEW and at most one DMEW (biennial alternation per ADR-021).
-- =============================================================================


-- =============================================================================
-- fn_normalize_city_key — diacritic-fold + lowercase + alias-resolved country
-- =============================================================================
-- Mirrors python.scrapers.evf_calendar._normalize_country + _diacritic_fold so
-- the allocator's city match agrees with the scraper's dedup matcher.
CREATE OR REPLACE FUNCTION fn_normalize_city_key(
  p_location TEXT,
  p_country  TEXT
)
RETURNS TABLE(loc_key TEXT, country_key TEXT)
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  -- Diacritic source/target — manual NFKD-equivalent for European scripts
  -- (no unaccent extension installed). Keep paired char-by-char.
  v_dia_src CONSTANT TEXT :=
    'ąćčęłńňóòôõöøőśšźžżäãàáâåăæçďěèéêëîíìïșțťñřůűùúûüýÿß';
  v_dia_tgt CONSTANT TEXT :=
    'accelnnooooooosszzzaaaaaaaacdeeeeeiiiisttnnruuuuuuyys';
  v_loc_lower  TEXT;
  v_ctry_lower TEXT;
BEGIN
  -- Location: lowercase → diacritic-fold → strip non-alphanumeric
  IF p_location IS NULL OR length(trim(p_location)) = 0 THEN
    loc_key := '';
  ELSE
    v_loc_lower := lower(trim(p_location));
    v_loc_lower := translate(v_loc_lower, v_dia_src, v_dia_tgt);
    loc_key := regexp_replace(v_loc_lower, '[^a-z0-9]', '', 'g');
  END IF;

  -- Country: lowercase → diacritic-fold → strip non-letter+space → alias-map
  IF p_country IS NULL OR length(trim(p_country)) = 0 THEN
    country_key := '';
  ELSE
    v_ctry_lower := lower(trim(p_country));
    v_ctry_lower := translate(v_ctry_lower, v_dia_src, v_dia_tgt);
    v_ctry_lower := regexp_replace(v_ctry_lower, '[^a-z ]', '', 'g');
    v_ctry_lower := trim(v_ctry_lower);

    country_key := CASE v_ctry_lower
      WHEN 'polska'          THEN 'poland'
      WHEN 'deutschland'     THEN 'germany'
      WHEN 'italia'          THEN 'italy'
      WHEN 'osterreich'      THEN 'austria'
      WHEN 'espana'          THEN 'spain'
      WHEN 'belgique'        THEN 'belgium'
      WHEN 'belgie'          THEN 'belgium'
      WHEN 'hellas'          THEN 'greece'
      WHEN 'ellada'          THEN 'greece'
      WHEN 'holland'         THEN 'netherlands'
      WHEN 'nederland'       THEN 'netherlands'
      WHEN 'magyarorszag'    THEN 'hungary'
      WHEN 'czech republic'  THEN 'czechia'
      WHEN 'ceska republika' THEN 'czechia'
      WHEN 'sverige'         THEN 'sweden'
      WHEN 'norge'           THEN 'norway'
      WHEN 'suomi'           THEN 'finland'
      WHEN 'danmark'         THEN 'denmark'
      WHEN 'schweiz'         THEN 'switzerland'
      WHEN 'suisse'          THEN 'switzerland'
      WHEN 'svizzera'        THEN 'switzerland'
      WHEN 'united kingdom'  THEN 'great britain'
      WHEN 'uk'              THEN 'great britain'
      WHEN 'england'         THEN 'great britain'
      WHEN 'britain'         THEN 'great britain'
      WHEN 'eire'            THEN 'ireland'
      ELSE v_ctry_lower
    END;
  END IF;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_normalize_city_key(TEXT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_normalize_city_key(TEXT, TEXT) TO authenticated;


-- =============================================================================
-- fn_classify_evf_event — pick PEW / IMEW / DMEW from scraped event signal
-- =============================================================================
-- Rule (ADR-043):
--   is_team = TRUE                                    → DMEW (team championship)
--   is_team = FALSE AND name LIKE '%championship%'    → IMEW (individual champ)
--   else                                              → PEW  (individual circuit)
-- 'MEW' is dead — never emitted.
CREATE OR REPLACE FUNCTION fn_classify_evf_event(
  p_name    TEXT,
  p_is_team BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  IF p_is_team THEN
    RETURN 'DMEW';
  END IF;
  IF lower(coalesce(p_name, '')) LIKE '%championship%' THEN
    RETURN 'IMEW';
  END IF;
  RETURN 'PEW';
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_classify_evf_event(TEXT, BOOLEAN) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_classify_evf_event(TEXT, BOOLEAN) TO authenticated;


-- =============================================================================
-- fn_allocate_evf_event_code — three-step ladder, returns alloc decision
-- =============================================================================
-- For PEW (numbered, city-matched):
--   A. CURRENT_SLOT_REUSE — admin pre-created an empty CREATED PEWn slot in
--      current season with matching txt_location + txt_country.
--   B. PRIOR_SEASON_MATCH — prior season has exactly one PEWn matching city;
--      reuse N → PEWn-{curr_year_suffix}, link FK to prior row.
--   C. NEXT_FREE_ALLOC    — MAX(N)+1 across current season's PEW\d+- events
--      (slug events with non-numeric suffix are skipped).
--
-- For IMEW / DMEW (singleton, no city):
--   A. CURRENT_SLOT_REUSE — already exists in current season → reuse.
--   B. PRIOR_SEASON_MATCH — prior season has same singleton → link FK.
--   C. NEXT_FREE_ALLOC    — singleton code with NULL FK; admin alert.
--
-- Multi-match in step A or B raises (ambiguity → admin must disambiguate).
CREATE OR REPLACE FUNCTION fn_allocate_evf_event_code(
  p_id_season INT,
  p_kind      TEXT,
  p_location  TEXT,
  p_country   TEXT
)
RETURNS TABLE(
  txt_code        TEXT,
  id_prior_event  INT,
  alloc_path      TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_season_suffix TEXT;
  v_prior_season  INT;
  v_loc_key       TEXT;
  v_ctry_key      TEXT;
  v_match_count   INT;
  v_match_id      INT;
  v_match_code    TEXT;
  v_match_prior   INT;
  v_n             INT;
  v_prior_n       INT;
  v_code          TEXT;
BEGIN
  -- Season suffix: 'SPWS-2025-2026' → '2025-2026'; 'EVFP2-CURR' → 'EVFP2-CURR'.
  -- We strip a leading 'SPWS-' if present, otherwise keep the whole code.
  SELECT regexp_replace(s.txt_code, '^SPWS-', '') INTO v_season_suffix
    FROM tbl_season s WHERE s.id_season = p_id_season;
  IF v_season_suffix IS NULL THEN
    RAISE EXCEPTION 'fn_allocate_evf_event_code: unknown id_season=%', p_id_season;
  END IF;

  -- Singleton kinds (IMEW / DMEW)
  IF p_kind IN ('IMEW', 'DMEW') THEN
    v_code := p_kind || '-' || v_season_suffix;

    -- Step A: existing row in current season?
    SELECT e.id_prior_event INTO v_match_prior
      FROM tbl_event e
     WHERE e.txt_code = v_code AND e.id_season = p_id_season;
    IF FOUND THEN
      txt_code       := v_code;
      id_prior_event := v_match_prior;
      alloc_path     := 'CURRENT_SLOT_REUSE';
      RETURN NEXT; RETURN;
    END IF;

    -- Step B: prior-season singleton?
    SELECT s.id_season INTO v_prior_season
      FROM tbl_season s WHERE s.id_season < p_id_season
      ORDER BY s.id_season DESC LIMIT 1;
    IF v_prior_season IS NOT NULL THEN
      SELECT e.id_event INTO v_match_id
        FROM tbl_event e
       WHERE e.id_season = v_prior_season
         AND e.txt_code LIKE p_kind || '-%';
      IF FOUND THEN
        txt_code       := v_code;
        id_prior_event := v_match_id;
        alloc_path     := 'PRIOR_SEASON_MATCH';
        RETURN NEXT; RETURN;
      END IF;
    END IF;

    -- Step C: NEXT_FREE_ALLOC (singleton, no number)
    txt_code       := v_code;
    id_prior_event := NULL;
    alloc_path     := 'NEXT_FREE_ALLOC';
    RETURN NEXT; RETURN;
  END IF;

  -- PEW (numbered, city-matched)
  IF p_kind <> 'PEW' THEN
    RAISE EXCEPTION 'fn_allocate_evf_event_code: unsupported p_kind=% (expected PEW/IMEW/DMEW)', p_kind;
  END IF;

  SELECT n.loc_key, n.country_key INTO v_loc_key, v_ctry_key
    FROM fn_normalize_city_key(p_location, p_country) n;

  -- Step A: current-season CREATED slot reuse
  IF v_loc_key <> '' THEN
    SELECT COUNT(*)::INT, MAX(e.txt_code), MAX(e.id_prior_event)
      INTO v_match_count, v_match_code, v_match_prior
      FROM tbl_event e,
           LATERAL fn_normalize_city_key(e.txt_location, e.txt_country) n
     WHERE e.id_season = p_id_season
       AND e.enum_status = 'CREATED'
       AND e.txt_code ~ '^PEW\d+-'
       AND n.loc_key    = v_loc_key
       AND n.country_key = v_ctry_key;

    IF v_match_count > 1 THEN
      RAISE EXCEPTION 'fn_allocate_evf_event_code: % CREATED PEW slots match (location=%, country=%) in season %',
        v_match_count, p_location, p_country, p_id_season;
    END IF;
    IF v_match_count = 1 THEN
      txt_code       := v_match_code;
      id_prior_event := v_match_prior;
      alloc_path     := 'CURRENT_SLOT_REUSE';
      RETURN NEXT; RETURN;
    END IF;
  END IF;

  -- Step B: prior-season city match
  SELECT s.id_season INTO v_prior_season
    FROM tbl_season s WHERE s.id_season < p_id_season
    ORDER BY s.id_season DESC LIMIT 1;

  IF v_prior_season IS NOT NULL AND v_loc_key <> '' THEN
    WITH cands AS (
      SELECT e.id_event,
             ((regexp_match(e.txt_code, '^PEW(\d+)-'))[1])::INT AS pew_n
        FROM tbl_event e,
             LATERAL fn_normalize_city_key(e.txt_location, e.txt_country) n
       WHERE e.id_season = v_prior_season
         AND e.txt_code ~ '^PEW\d+-'
         AND n.loc_key    = v_loc_key
         AND n.country_key = v_ctry_key
    )
    SELECT COUNT(*)::INT, MAX(id_event), MAX(pew_n)
      INTO v_match_count, v_match_id, v_prior_n
      FROM cands;

    IF v_match_count > 1 THEN
      RAISE EXCEPTION 'fn_allocate_evf_event_code: % prior PEW events match (location=%, country=%) in season %',
        v_match_count, p_location, p_country, v_prior_season;
    END IF;
    IF v_match_count = 1 THEN
      txt_code       := 'PEW' || v_prior_n::TEXT || '-' || v_season_suffix;
      id_prior_event := v_match_id;
      alloc_path     := 'PRIOR_SEASON_MATCH';
      RETURN NEXT; RETURN;
    END IF;
  END IF;

  -- Step C: next-free PEW{N+1} in current season (slug events skipped via regex)
  SELECT COALESCE(MAX(((regexp_match(e.txt_code, '^PEW(\d+)-'))[1])::INT), 0) + 1
    INTO v_n
    FROM tbl_event e
   WHERE e.id_season = p_id_season
     AND e.txt_code ~ '^PEW\d+-';

  txt_code       := 'PEW' || v_n::TEXT || '-' || v_season_suffix;
  id_prior_event := NULL;
  alloc_path     := 'NEXT_FREE_ALLOC';
  RETURN NEXT; RETURN;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_allocate_evf_event_code(INT, TEXT, TEXT, TEXT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_allocate_evf_event_code(INT, TEXT, TEXT, TEXT) TO authenticated;
