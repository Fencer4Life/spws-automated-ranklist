-- =============================================================================
-- A season is bootstrapped only with skeletons nobody discovers for us
-- =============================================================================
-- ADR-077 §3 provisions a season as a set of childless CREATED events — PPW1-n,
-- the PEW circuit, MPW, MSW, optional IMEW/DMEW. The EVF members of that set
-- are the problem: SPWS does not schedule the European circuit. EVF publishes
-- it and `evf_calendar.py` / `evf_sync.py` discover it within the same season,
-- so a PEW skeleton is a PREDICTION of a row that is going to arrive anyway.
--
-- WHY THE PREDICTION DUPLICATES
-- -----------------------------
-- A skeleton carries none of the four identities the ADR-039 dedup ladder can
-- use: no date, no EVF calendar id, no EVF results id, no slug. Its only handle
-- is the prior season's city, copied at bootstrap, which is what
-- `fn_allocate_evf_event_code` Step A (20260429000001_phase4_pew_split.sql:55)
-- matches on to adopt a skeleton instead of minting a code.
--
-- Measured on PROD 2026-09-05: all 23 skeletons had an EMPTY txt_location, so
-- fn_normalize_city_key returned '' for every one of them and Step A could
-- never fire. The season was bootstrapped on 2026-06-28; ADR-088 — the work
-- that made txt_location reliably hold a city — was accepted on 2026-09-04,
-- more than two months later, so there were no cities to inherit. The allocator
-- fell through to Step C (next-free PEW{N+1}) and minted a fresh row beside the
-- skeleton on every scrape: 8 duplicate pairs, with 15 more due as EVF
-- published the rest of the season.
--
-- Fixing only the empty cities would not settle it. Step A needs an EXACT city
-- match and EVF moves its circuit between seasons; every event that moves is a
-- skeleton that cannot be adopted, and a duplicate.
--
-- THE RULE
-- --------
-- Not "keep skeletons for SPWS events" but "keep skeletons for events nobody
-- will discover for us". MSW is the case that separates the two: FIE organises
-- it, but no FIE scraper exists in python/scrapers/, so its skeleton is the
-- only thing holding that slot and it cannot be duplicated.
--
--   PPW1-n  SPWS  no scraper           -> kept
--   MPW     SPWS  no scraper           -> kept
--   MSW     FIE   no scraper           -> kept
--   PEW1-n  EVF   evf_calendar/evf_sync -> dropped
--   IMEW    EVF   evf_calendar/evf_sync -> dropped
--   DMEW    EVF   evf_calendar/evf_sync -> dropped
--
-- Step A is deliberately LEFT ALONE. It is correct for what remains — an
-- administrator who creates a skeleton and types a city should have it adopted
-- rather than duplicated — and nothing reaches it with a guessed city any more.
--
-- Amends ADR-077 §3. Verified by supabase/tests/74_no_evf_season_skeletons.sql.
-- =============================================================================

-- 1. Stop predicting the EVF circuit.
--
-- Redefines fn_init_season (last authoritative version: 20260627000003) verbatim
-- EXCEPT that the PEW loop and the IMEW/DMEW singleton block are removed. The
-- v_pew / v_eu counters and the by_kind keys are RETAINED and report zero: the
-- season wizard renders its breakdown by reading those keys, so removing them
-- would break a caller for no gain.
CREATE OR REPLACE FUNCTION fn_init_season(p_id_season INT)
RETURNS TABLE(skeletons_created INT, by_kind JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season       tbl_season%ROWTYPE;
  v_prior_id     INT;
  v_suffix       TEXT;
  v_count        INT := 0;
  v_ppw          INT := 0;
  v_pew          INT := 0;  -- retained, always 0: EVF events arrive by scrape
  v_mpw          INT := 0;
  v_msw          INT := 0;
  v_eu           INT := 0;  -- retained, always 0: likewise
  v_spws_org     INT;
  v_fie_org      INT;
  v_default_org  INT;
  v_prior        RECORD;
  v_prior_mpw    INT;
  v_prior_msw    INT;
  v_new_id       INT;
  v_new_code     TEXT;
  v_european     TEXT;
BEGIN
  SELECT * INTO v_season FROM tbl_season WHERE id_season = p_id_season;
  IF v_season.id_season IS NULL THEN
    RAISE EXCEPTION 'fn_init_season: season % not found', p_id_season;
  END IF;

  IF EXISTS (SELECT 1 FROM tbl_event WHERE id_season = p_id_season) THEN
    RAISE EXCEPTION 'fn_init_season: season % already has events', p_id_season;
  END IF;

  v_european := v_season.enum_european_event_type;
  v_suffix := regexp_replace(v_season.txt_code, '^SPWS-', '');

  SELECT id_season INTO v_prior_id
    FROM tbl_season
   WHERE dt_end < v_season.dt_start
   ORDER BY dt_end DESC LIMIT 1;

  SELECT id_organizer INTO v_spws_org FROM tbl_organizer WHERE txt_code = 'SPWS';
  SELECT id_organizer INTO v_fie_org  FROM tbl_organizer WHERE txt_code = 'FIE';

  v_default_org := COALESCE(
    v_spws_org,
    (SELECT id_organizer FROM tbl_organizer ORDER BY id_organizer LIMIT 1)
  );

  IF v_default_org IS NULL THEN
    RAISE EXCEPTION 'fn_init_season: no organizers exist; cannot create skeleton events';
  END IF;

  IF v_prior_id IS NOT NULL THEN
    FOR v_prior IN
      SELECT id_event, txt_code FROM tbl_event
       WHERE id_season = v_prior_id AND txt_code ~ '^PPW\d+-'
       ORDER BY txt_code
    LOOP
      v_new_code := regexp_replace(v_prior.txt_code, '\d{4}-\d{4}$', v_suffix);
      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event
      ) VALUES (
        v_new_code, v_new_code, p_id_season, v_default_org,
        NULL, NULL, 'CREATED', v_prior.id_event
      ) RETURNING id_event INTO v_new_id;
      -- childless: tournaments are ingested per event later (ADR-077 §3)
      v_ppw := v_ppw + 1;
      v_count := v_count + 1;
    END LOOP;

    -- The PEW loop that stood here is gone. evf_sync discovers the circuit and
    -- fn_ingest_evf_calendar allocates each event exactly once.
  END IF;

  v_new_code := 'MPW-' || v_suffix;
  IF v_prior_id IS NOT NULL THEN
    SELECT id_event INTO v_prior_mpw FROM tbl_event
     WHERE id_season = v_prior_id AND txt_code ~ '^MPW-' LIMIT 1;
  END IF;
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, txt_country, enum_status, id_prior_event
  ) VALUES (
    v_new_code, v_new_code, p_id_season, v_default_org,
    NULL, NULL, 'CREATED', v_prior_mpw
  ) RETURNING id_event INTO v_new_id;
  v_mpw := 1;
  v_count := v_count + 1;

  -- MSW is kept although FIE organises it: nothing discovers it for us.
  v_new_code := 'MSW-' || v_suffix;
  IF v_prior_id IS NOT NULL THEN
    SELECT id_event INTO v_prior_msw FROM tbl_event
     WHERE id_season = v_prior_id AND txt_code ~ '^I?MSW-' LIMIT 1;
  END IF;
  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, txt_country, enum_status, id_prior_event
  ) VALUES (
    v_new_code, v_new_code, p_id_season, COALESCE(v_fie_org, v_default_org),
    NULL, NULL, 'CREATED', v_prior_msw
  ) RETURNING id_event INTO v_new_id;
  v_msw := 1;
  v_count := v_count + 1;

  -- The IMEW/DMEW singleton block that stood here is gone for the same reason
  -- as the PEW loop. enum_european_event_type still selects which European
  -- championship the season expects; it just no longer pre-creates the row.

  DECLARE
    v_by_kind JSONB;
  BEGIN
    v_by_kind := jsonb_build_object('PPW', v_ppw, 'PEW', v_pew,
                                    'MPW', v_mpw, 'MSW', v_msw);
    IF v_european IS NOT NULL THEN
      v_by_kind := v_by_kind || jsonb_build_object(v_european, v_eu);
    END IF;
    RETURN QUERY SELECT v_count, v_by_kind;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_init_season(INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_init_season(INT) TO authenticated;

COMMENT ON FUNCTION fn_init_season(INT) IS
  'Provision a season with childless CREATED skeletons for the events nobody '
  'discovers for us: PPW1-n and MPW (SPWS) and MSW (FIE, but unscraped). EVF '
  'events — PEW, IMEW, DMEW — are deliberately NOT provisioned: evf_sync '
  'discovers them, and a skeleton with no date, id or slug cannot be matched to '
  'the scraped row, which produced 8 duplicate pairs on PROD in 2026-2027. '
  'by_kind keeps the PEW and European keys, reporting 0. See migration '
  '20260906000001 and ADR-077 §3 as amended.';


-- 2. Clear the generation already provisioned, so the environments do not carry
--    unmatchable rows forward.
--
--    This is a FUNCTION rather than a bare DELETE because it has to run in two
--    places that cannot share a statement. On CERT and PROD the migration runs
--    against live data and the DELETE below does the work. On a fresh bootstrap
--    — CI and `scripts/reset-dev.sh` — migrations run BEFORE the seed dump, so
--    the same DELETE would match nothing and the dump would then reinstate all
--    18 skeletons; `supabase/seed_post_backfill.sql` calls this function after
--    the seed to close that path. Two copies of the predicate would drift.
--    (The ordering trap is the one governed by the ADR-036 amendment of
--    2026-07-14; it was reproduced here before this function existed.)
--
--    Scoped hard, and every clause earns its place: CREATED and dateless is the
--    definition of an unclaimed skeleton; EVF is the organiser whose events
--    arrive by scrape; no tournament children means nothing has ever been
--    ingested against it; and nothing may point at it as its prior event, or a
--    carry-over chain would lose a link. A row failing any one of these is a
--    real event and is left alone.
CREATE OR REPLACE FUNCTION fn_prune_unclaimed_evf_skeletons()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  WITH gone AS (
    DELETE FROM tbl_event e
    USING tbl_organizer o
    WHERE e.id_organizer = o.id_organizer
      AND o.txt_code = 'EVF'
      AND e.enum_status = 'CREATED'
      AND e.dt_start IS NULL
      AND NOT EXISTS (SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event)
      AND NOT EXISTS (SELECT 1 FROM tbl_event c WHERE c.id_prior_event = e.id_event)
    RETURNING 1
  )
  SELECT COUNT(*)::INTEGER INTO v_deleted FROM gone;
  RETURN v_deleted;
END;
$$;

COMMENT ON FUNCTION fn_prune_unclaimed_evf_skeletons() IS
  'Delete unclaimed EVF season skeletons: CREATED, dateless, childless, and not '
  'referenced as anyone''s id_prior_event. Idempotent. Called by migration '
  '20260906000001 for live environments and by seed_post_backfill.sql for fresh '
  'bootstraps, where migrations run before the seed dump. Returns the row count.';

-- ADR-083 deny-by-default: a new function is EXECUTEable by PUBLIC unless said
-- otherwise, and pgTAP 52.7 asserts the anon-EXECUTEable set exactly. This
-- deletes rows; it is nobody's public surface.
REVOKE ALL ON FUNCTION fn_prune_unclaimed_evf_skeletons() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_prune_unclaimed_evf_skeletons() FROM anon;
REVOKE ALL ON FUNCTION fn_prune_unclaimed_evf_skeletons() FROM authenticated;

SELECT fn_prune_unclaimed_evf_skeletons();
