-- =============================================================================
-- EVF calendar identity + season-count bound + scrape ledger
--
-- Amends ADR-028, ADR-039, ADR-042 and ADR-043.
-- =============================================================================

SET lock_timeout = '5s';

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS id_evf_calendar_event BIGINT;

COMMENT ON COLUMN tbl_event.id_evf_calendar_event IS
  'Public EVF WordPress calendar post id. Separate from id_evf_event, which '
  'belongs to the secondary EVF results database.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_tbl_event_evf_calendar_season
  ON tbl_event (id_season, id_evf_calendar_event)
  WHERE id_evf_calendar_event IS NOT NULL;


CREATE TABLE IF NOT EXISTS tbl_evf_calendar_scrape_run (
  id_run                 UUID PRIMARY KEY,
  id_season              INT NOT NULL REFERENCES tbl_season(id_season),
  ts_started             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ts_finished            TIMESTAMPTZ,
  int_calendar_count     INT NOT NULL CHECK (int_calendar_count >= 0),
  int_cancelled_count    INT NOT NULL DEFAULT 0 CHECK (int_cancelled_count >= 0),
  txt_status             TEXT NOT NULL CHECK (txt_status IN ('STARTED','SUCCEEDED','FAILED')),
  json_details           JSONB NOT NULL DEFAULT '{}'::JSONB
);

COMMENT ON TABLE tbl_evf_calendar_scrape_run IS
  'One durable row per EVF calendar scrape attempt, including failed attempts. '
  'int_calendar_count counts retained competitions wholly contained in the '
  'season, including cancellations but excluding whole-word CAMP entries.';

ALTER TABLE tbl_evf_calendar_scrape_run ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_evf_calendar_scrape_run FROM anon, authenticated, PUBLIC;


CREATE OR REPLACE FUNCTION fn_record_evf_calendar_scrape(
  p_run_id           UUID,
  p_id_season        INT,
  p_calendar_count   INT,
  p_cancelled_count  INT,
  p_status           TEXT,
  p_details          JSONB DEFAULT '{}'::JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_status NOT IN ('STARTED','SUCCEEDED','FAILED') THEN
    RAISE EXCEPTION 'fn_record_evf_calendar_scrape: invalid status %', p_status;
  END IF;
  IF p_calendar_count < 0 OR p_cancelled_count < 0 OR p_cancelled_count > p_calendar_count THEN
    RAISE EXCEPTION 'fn_record_evf_calendar_scrape: invalid counts total=% cancelled=%',
      p_calendar_count, p_cancelled_count;
  END IF;

  INSERT INTO tbl_evf_calendar_scrape_run (
    id_run, id_season, int_calendar_count, int_cancelled_count,
    txt_status, ts_finished, json_details
  ) VALUES (
    p_run_id, p_id_season, p_calendar_count, p_cancelled_count,
    p_status, CASE WHEN p_status = 'STARTED' THEN NULL ELSE NOW() END,
    COALESCE(p_details, '{}'::JSONB)
  )
  ON CONFLICT (id_run) DO UPDATE SET
    int_calendar_count  = EXCLUDED.int_calendar_count,
    int_cancelled_count = EXCLUDED.int_cancelled_count,
    txt_status          = EXCLUDED.txt_status,
    ts_finished         = EXCLUDED.ts_finished,
    json_details        = EXCLUDED.json_details;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_record_evf_calendar_scrape(UUID, INT, INT, INT, TEXT, JSONB)
  FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_record_evf_calendar_scrape(UUID, INT, INT, INT, TEXT, JSONB)
  TO authenticated;


-- Complete-snapshot wrapper around the established two-argument ingestion RPC.
-- It validates chronology and pre-claims exact durable identities/codes before
-- delegating child tournament materialisation.
CREATE OR REPLACE FUNCTION fn_ingest_evf_calendar(
  p_events              JSONB,
  p_id_season           INT,
  p_season_event_count  INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_evt          JSONB;
  v_alloc        RECORD;
  v_org          INT;
  v_existing_id  INT;
  v_calendar_id  BIGINT;
  v_slug         TEXT;
  v_kind         TEXT;
  v_result       JSONB;
  v_delegate     JSONB := '[]'::JSONB;
  v_existing_status TEXT;
  v_desired_code TEXT;
  v_expected_code TEXT;
  v_season_suffix TEXT;
  v_weapons_arr enum_weapon_type[];
  v_letters TEXT;
  v_w TEXT;
  v_positive_n INT := 0;
  v_prior_n INT;
  v_cancelled BOOLEAN;
  v_occupant_id INT;
  v_old_code TEXT;
BEGIN
  IF p_season_event_count < 0
     OR jsonb_typeof(p_events) <> 'array'
     OR jsonb_array_length(p_events) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: retained count must equal payload length';
  END IF;

  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_org IS NULL THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: EVF organizer not found';
  END IF;

  SELECT regexp_replace(txt_code, '^SPWS-', '') INTO v_season_suffix
    FROM tbl_season WHERE id_season = p_id_season;
  IF v_season_suffix IS NULL THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: unknown season %', p_id_season;
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_events) e
     WHERE COALESCE(e ->> 'name', '') ~* '\mCAMP\M'
  ) THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: CAMP entries are forbidden';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(p_events) e
     WHERE NULLIF(e ->> 'evf_calendar_id', '') IS NULL
  ) OR (
    SELECT COUNT(DISTINCT (e ->> 'evf_calendar_id')::BIGINT)
      FROM jsonb_array_elements(p_events) e
  ) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: calendar ids must be present and unique';
  END IF;
  IF (
    SELECT COUNT(DISTINCT e ->> 'desired_code')
      FROM jsonb_array_elements(p_events) e
  ) <> p_season_event_count THEN
    RAISE EXCEPTION 'fn_ingest_evf_calendar: desired codes must be present and unique';
  END IF;

  FOR v_evt IN
    SELECT value FROM jsonb_array_elements(p_events)
    ORDER BY value ->> 'dt_start', (value ->> 'evf_calendar_id')::BIGINT
  LOOP
    v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
    IF v_calendar_id IS NULL THEN
      RAISE EXCEPTION 'fn_ingest_evf_calendar: evf_calendar_id is required for %',
        COALESCE(v_evt ->> 'name', '<unnamed>');
    END IF;
    v_slug := NULLIF(v_evt ->> 'evf_slug', '');
    v_existing_id := NULLIF(v_evt ->> 'existing_id_event', '')::INT;
    v_existing_status := NULL;

    IF v_existing_id IS NOT NULL THEN
      SELECT e.enum_status::TEXT INTO v_existing_status
        FROM tbl_event e
       WHERE e.id_event = v_existing_id AND e.id_season = p_id_season
         AND (e.id_evf_calendar_event IS NULL OR e.id_evf_calendar_event = v_calendar_id);
      IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: invalid legacy match % for calendar id %',
          v_existing_id, v_calendar_id;
      END IF;
    ELSE
      SELECT e.id_event, e.enum_status::TEXT INTO v_existing_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.id_evf_calendar_event = v_calendar_id;
    END IF;

    IF v_existing_id IS NULL AND v_slug IS NOT NULL THEN
      SELECT e.id_event, e.enum_status::TEXT INTO v_existing_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.txt_evf_slug = v_slug;
    END IF;

    v_weapons_arr := ARRAY[]::enum_weapon_type[];
    FOR v_w IN SELECT jsonb_array_elements_text(COALESCE(v_evt -> 'weapons', '[]'::JSONB))
    LOOP
      v_weapons_arr := v_weapons_arr || v_w::enum_weapon_type;
    END LOOP;
    v_letters := fn_pew_weapon_letters(v_weapons_arr);
    IF v_letters = '' THEN
      RAISE EXCEPTION 'fn_ingest_evf_calendar: weapons are required for calendar id %',
        v_calendar_id;
    END IF;

    v_cancelled := COALESCE((v_evt ->> 'is_cancelled')::BOOLEAN, FALSE);
    v_prior_n := NULL;
    IF v_existing_id IS NOT NULL THEN
      SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = v_existing_id;
      IF v_old_code ~ '^PEW\d+[efs]*-' THEN
        v_prior_n := ((regexp_match(v_old_code, '^PEW(\d+)'))[1])::INT;
      END IF;
    END IF;

    IF v_cancelled AND (
      COALESCE(v_prior_n, 0) = 0 OR v_calendar_id = 5074
    ) THEN
      v_expected_code := 'PEW0' || v_letters || '-' || v_season_suffix;
    ELSE
      v_positive_n := v_positive_n + 1;
      IF v_cancelled AND v_prior_n IS DISTINCT FROM v_positive_n THEN
        RAISE EXCEPTION
          'fn_ingest_evf_calendar: later cancellation % cannot move PEW% to PEW%',
          v_calendar_id, v_prior_n, v_positive_n;
      END IF;
      v_expected_code := 'PEW' || v_positive_n::TEXT || v_letters || '-' || v_season_suffix;
    END IF;
    v_desired_code := NULLIF(v_evt ->> 'desired_code', '');
    IF v_desired_code IS DISTINCT FROM v_expected_code THEN
      RAISE EXCEPTION
        'fn_ingest_evf_calendar: code plan mismatch for %: got %, expected %',
        v_calendar_id, v_desired_code, v_expected_code;
    END IF;

    -- An inherited empty skeleton already occupying the desired chronological
    -- code is the canonical row. Attach the durable identity to it instead of
    -- creating another occurrence.
    IF v_existing_id IS NULL THEN
      SELECT e.id_event, e.enum_status::TEXT INTO v_occupant_id, v_existing_status
        FROM tbl_event e
       WHERE e.id_season = p_id_season AND e.txt_code = v_desired_code
         AND e.id_evf_calendar_event IS NULL;
      IF v_occupant_id IS NOT NULL THEN
        v_existing_id := v_occupant_id;
      END IF;
    END IF;

    IF v_existing_id IS NOT NULL THEN
      SELECT id_event INTO v_occupant_id FROM tbl_event
       WHERE id_season = p_id_season AND txt_code = v_desired_code
         AND id_event <> v_existing_id;
      IF v_occupant_id IS NOT NULL THEN
        IF EXISTS (
          SELECT 1 FROM tbl_tournament t JOIN tbl_result r USING (id_tournament)
           WHERE t.id_event IN (v_existing_id, v_occupant_id)
        ) OR EXISTS (
          SELECT 1 FROM tbl_event WHERE id_event = v_occupant_id
            AND id_evf_calendar_event IS NOT NULL
        ) THEN
          RAISE EXCEPTION 'fn_ingest_evf_calendar: unsafe occupied code %', v_desired_code;
        END IF;
        UPDATE tbl_event target
           SET id_prior_event = COALESCE(target.id_prior_event, occupied.id_prior_event)
          FROM tbl_event occupied
         WHERE target.id_event = v_existing_id AND occupied.id_event = v_occupant_id;
        UPDATE tbl_tournament
           SET txt_code = 'EVFLEGACY' || v_occupant_id::TEXT || '-' || id_tournament::TEXT
         WHERE id_event = v_occupant_id;
        UPDATE tbl_event
           SET txt_code = 'EVFLEGACY' || v_occupant_id::TEXT || '-' || v_season_suffix
         WHERE id_event = v_occupant_id;
      END IF;

      SELECT txt_code INTO v_old_code FROM tbl_event WHERE id_event = v_existing_id;
      IF v_old_code <> v_desired_code AND EXISTS (
        SELECT 1 FROM tbl_tournament t JOIN tbl_result r USING (id_tournament)
         WHERE t.id_event = v_existing_id
      ) THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: refusing to renumber scored event %',
          v_existing_id;
      END IF;
      IF v_old_code <> v_desired_code THEN
        UPDATE tbl_tournament SET txt_code = '__evfcal_' || id_tournament::TEXT
         WHERE id_event = v_existing_id;
        UPDATE tbl_event SET txt_code = v_desired_code WHERE id_event = v_existing_id;
        UPDATE tbl_tournament SET
          txt_code = v_desired_code || '-' || enum_age_category::TEXT || '-' ||
                     enum_gender::TEXT || '-' || enum_weapon::TEXT
         WHERE id_event = v_existing_id;
      END IF;

      UPDATE tbl_event
         SET txt_name = COALESCE(v_evt ->> 'name', txt_name),
             dt_start = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
             dt_end = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
             txt_location = COALESCE(NULLIF(v_evt ->> 'location', ''), txt_location),
             txt_country = COALESCE(NULLIF(v_evt ->> 'country', ''), txt_country),
             txt_code = v_desired_code,
             id_evf_calendar_event = v_calendar_id,
             txt_evf_slug = COALESCE(txt_evf_slug, v_slug)
       WHERE id_event = v_existing_id;
    ELSE
      v_kind := fn_classify_evf_event(
        v_evt ->> 'name', COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE)
      );
      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(
          p_id_season, v_kind,
          COALESCE(v_evt ->> 'location', ''),
          COALESCE(v_evt ->> 'country', ''), v_letters
        );

      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        txt_location, txt_country, enum_status, id_prior_event,
        id_evf_calendar_event, txt_evf_slug
      ) VALUES (
        v_desired_code, COALESCE(v_evt ->> 'name', v_desired_code),
        p_id_season, v_org,
        NULLIF(v_evt ->> 'location', ''), NULLIF(v_evt ->> 'country', ''),
        'CREATED', v_alloc.id_prior_event, v_calendar_id, v_slug
      ) RETURNING id_event INTO v_existing_id;
    END IF;

    -- Approved geographic-series exception: the Athens occurrence continues
    -- Chania for rolling-score purposes; current-season digits remain purely
    -- chronological and do not participate in this link.
    IF v_calendar_id = 3438 THEN
      UPDATE tbl_event current_event SET id_prior_event = prior_event.id_event
        FROM LATERAL (
          SELECT e.id_event FROM tbl_event e
          JOIN tbl_season s ON s.id_season = e.id_season
          WHERE e.id_season <> p_id_season
            AND (e.txt_name ILIKE '%Chania%' OR e.txt_location ILIKE '%Chania%')
          ORDER BY s.dt_end DESC, e.id_event DESC
          LIMIT 1
        ) prior_event
       WHERE current_event.id_event = v_existing_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_ingest_evf_calendar: Athens requires a prior Chania event';
      END IF;
    END IF;

    -- The established two-argument implementation always writes PLANNED.
    -- Delegate new/pre-terminal rows only; terminal lifecycle state is never
    -- demoted by a calendar refresh.
    IF v_existing_status IS NULL OR v_existing_status IN (
      'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS'
    ) THEN
      v_delegate := v_delegate || jsonb_build_array(v_evt);
    END IF;
  END LOOP;

  IF jsonb_array_length(v_delegate) > 0 THEN
    v_result := fn_ingest_evf_calendar(v_delegate, p_id_season);
  ELSE
    v_result := jsonb_build_object(
      'created', 0, 'slot_reused', 0, 'prior_matched', 0, 'alerts', '[]'::JSONB
    );
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    IF COALESCE((v_evt ->> 'is_cancelled')::BOOLEAN, FALSE) THEN
      v_calendar_id := NULLIF(v_evt ->> 'evf_calendar_id', '')::BIGINT;
      SELECT e.id_event INTO v_existing_id
        FROM tbl_event e
       WHERE e.id_season = p_id_season
         AND e.id_evf_calendar_event = v_calendar_id;

      IF EXISTS (
        SELECT 1 FROM tbl_tournament t
        JOIN tbl_result r ON r.id_tournament = t.id_tournament
        WHERE t.id_event = v_existing_id
      ) THEN
        RAISE EXCEPTION 'refusing to cancel EVF calendar event % because results exist',
          v_calendar_id;
      END IF;

      UPDATE tbl_event
         SET enum_status = 'CANCELLED'
       WHERE id_event = v_existing_id
         AND enum_status IN (
           'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
         );

      IF NOT FOUND THEN
        RAISE EXCEPTION 'refusing to cancel EVF calendar event % from advanced status',
          v_calendar_id;
      END IF;
    END IF;
  END LOOP;

  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ingest_evf_calendar(JSONB, INT, INT) TO authenticated;


-- Matched rows never enter fn_ingest_evf_calendar, so the identity-refresh
-- path must own the calendar post id and authoritative cancellation marker.
CREATE OR REPLACE FUNCTION fn_sync_evf_event_fields(p_updates JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_upd       JSONB;
  v_touched   INT := 0;
  v_changed   INT := 0;
  v_row_cnt   INT;
  v_id        INT;
  v_cancelled BOOLEAN;
BEGIN
  FOR v_upd IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := NULLIF(v_upd ->> 'id_event', '')::INT;
    IF v_id IS NULL THEN
      CONTINUE;
    END IF;
    v_touched := v_touched + 1;
    v_cancelled := COALESCE((v_upd ->> 'is_cancelled')::BOOLEAN, FALSE);

    IF v_cancelled AND EXISTS (
      SELECT 1 FROM tbl_event e
      WHERE e.id_event = v_id
        AND e.enum_status NOT IN (
          'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
        )
    ) THEN
      RAISE EXCEPTION 'refusing to cancel EVF event % from terminal status', v_id;
    END IF;

    IF v_cancelled AND EXISTS (
      SELECT 1 FROM tbl_tournament t
      JOIN tbl_result r ON r.id_tournament = t.id_tournament
      WHERE t.id_event = v_id
    ) THEN
      RAISE EXCEPTION 'refusing to cancel EVF event % because results exist', v_id;
    END IF;

    UPDATE tbl_event SET
      txt_name     = COALESCE(NULLIF(v_upd ->> 'name', ''), txt_name),
      dt_start     = COALESCE(NULLIF(v_upd ->> 'dt_start', '')::DATE, dt_start),
      dt_end       = COALESCE(NULLIF(v_upd ->> 'dt_end', '')::DATE, dt_end),
      txt_location = COALESCE(NULLIF(v_upd ->> 'location', ''), txt_location),
      txt_country  = COALESCE(NULLIF(v_upd ->> 'country', ''), txt_country),
      id_evf_event = COALESCE(id_evf_event, NULLIF(v_upd ->> 'evf_id', '')::INT),
      id_evf_calendar_event = COALESCE(
        id_evf_calendar_event, NULLIF(v_upd ->> 'evf_calendar_id', '')::BIGINT
      ),
      txt_evf_slug = COALESCE(txt_evf_slug, NULLIF(v_upd ->> 'evf_slug', '')),
      enum_status = CASE
        WHEN v_cancelled AND enum_status IN (
          'CREATED','PLANNED','SCHEDULED','CHANGED','IN_PROGRESS','CANCELLED'
        ) THEN 'CANCELLED'::enum_event_status
        ELSE enum_status
      END,
      ts_updated = NOW()
    WHERE id_event = v_id
      AND (
        txt_name IS DISTINCT FROM COALESCE(NULLIF(v_upd ->> 'name', ''), txt_name)
        OR dt_start IS DISTINCT FROM COALESCE(NULLIF(v_upd ->> 'dt_start', '')::DATE, dt_start)
        OR dt_end IS DISTINCT FROM COALESCE(NULLIF(v_upd ->> 'dt_end', '')::DATE, dt_end)
        OR txt_location IS DISTINCT FROM COALESCE(NULLIF(v_upd ->> 'location', ''), txt_location)
        OR txt_country IS DISTINCT FROM COALESCE(NULLIF(v_upd ->> 'country', ''), txt_country)
        OR id_evf_event IS DISTINCT FROM COALESCE(id_evf_event, NULLIF(v_upd ->> 'evf_id', '')::INT)
        OR id_evf_calendar_event IS DISTINCT FROM COALESCE(
          id_evf_calendar_event, NULLIF(v_upd ->> 'evf_calendar_id', '')::BIGINT
        )
        OR txt_evf_slug IS DISTINCT FROM COALESCE(txt_evf_slug, NULLIF(v_upd ->> 'evf_slug', ''))
        OR (v_cancelled AND enum_status <> 'CANCELLED')
      );

    GET DIAGNOSTICS v_row_cnt = ROW_COUNT;
    IF v_row_cnt > 0 THEN
      v_changed := v_changed + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'changed', v_changed);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_sync_evf_event_fields(JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_sync_evf_event_fields(JSONB) TO authenticated;


-- Public read model exposes the durable calendar identity for diagnostics.
DROP VIEW IF EXISTS vw_calendar;
CREATE VIEW vw_calendar AS
SELECT
  e.id_event, e.txt_code, e.txt_name, e.id_season,
  s.txt_code AS txt_season_code,
  e.id_organizer, o.txt_name AS txt_organizer_name,
  e.txt_location, e.txt_country, e.txt_venue_address,
  e.url_invitation, e.num_entry_fee, e.txt_entry_fee_currency,
  e.arr_weapons,
  e.dt_start, e.dt_end, e.url_event, e.enum_status,
  e.url_registration, e.dt_registration_deadline,
  e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5,
  e.id_evf_event, e.txt_evf_slug, e.id_evf_calendar_event,
  e.id_prior_event,
  COUNT(t.id_tournament)::INT AS num_tournaments,
  COALESCE(BOOL_OR(t.enum_type IN ('PEW','MEW','MSW','PSW')), FALSE) AS bool_has_international,
  e.json_ingest_sources, e.json_source_overrides,
  e.url_entry_list, e.txt_organizer_email, e.ts_ftl_sent,
  e.num_entry_fee_2w, e.num_entry_fee_3w, e.bool_use_spws_registration
FROM tbl_event e
JOIN tbl_season s ON s.id_season = e.id_season
LEFT JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
LEFT JOIN tbl_tournament t ON t.id_event = e.id_event
GROUP BY e.id_event, s.txt_code, o.txt_name
ORDER BY e.dt_start ASC;

GRANT SELECT ON vw_calendar TO anon, authenticated;


-- CERT -> PROD reconciliation carries the same durable calendar identity.
CREATE OR REPLACE FUNCTION fn_mirror_events_to_prod(
  p_creates JSONB DEFAULT '[]'::JSONB,
  p_updates JSONB DEFAULT '[]'::JSONB,
  p_deletes JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_evt            JSONB;
  v_created        INT := 0;
  v_updated        INT := 0;
  v_deleted        INT := 0;
  v_delete_skipped JSONB := '[]'::JSONB;
  v_id_org         INT;
  v_id_event       INT;
  v_arr_weapons    enum_weapon_type[];
BEGIN
  IF jsonb_array_length(p_creates) > 0 THEN
    FOR v_evt IN SELECT * FROM jsonb_array_elements(p_creates)
    LOOP
      IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code = v_evt ->> 'txt_code') THEN
        CONTINUE;
      END IF;

      v_id_org := (v_evt ->> 'id_organizer')::INT;
      IF v_id_org IS NULL OR NOT EXISTS (
        SELECT 1 FROM tbl_organizer WHERE id_organizer = v_id_org
      ) THEN
        RAISE EXCEPTION 'fn_mirror_events_to_prod: event % has unresolved id_organizer (%)',
          v_evt ->> 'txt_code', v_id_org;
      END IF;

      v_arr_weapons := NULL;
      IF v_evt ? 'arr_weapons' THEN
        SELECT ARRAY(
          SELECT (value #>> '{}')::enum_weapon_type
          FROM jsonb_array_elements(v_evt -> 'arr_weapons')
        ) INTO v_arr_weapons;
      END IF;

      INSERT INTO tbl_event (
        txt_code, txt_name, id_season, id_organizer,
        dt_start, dt_end, txt_location, txt_country, enum_status,
        url_event, url_event_2, url_event_3, url_event_4, url_event_5,
        url_invitation, url_registration, dt_registration_deadline,
        txt_venue_address, num_entry_fee, txt_entry_fee_currency,
        arr_weapons, id_prior_event, id_evf_event, txt_evf_slug,
        id_evf_calendar_event
      ) VALUES (
        v_evt ->> 'txt_code', v_evt ->> 'txt_name',
        (v_evt ->> 'id_season')::INT, v_id_org,
        NULLIF(v_evt ->> 'dt_start', '')::DATE, NULLIF(v_evt ->> 'dt_end', '')::DATE,
        NULLIF(v_evt ->> 'txt_location', ''), NULLIF(v_evt ->> 'txt_country', ''),
        COALESCE(v_evt ->> 'enum_status', 'PLANNED')::enum_event_status,
        NULLIF(v_evt ->> 'url_event', ''), NULLIF(v_evt ->> 'url_event_2', ''),
        NULLIF(v_evt ->> 'url_event_3', ''), NULLIF(v_evt ->> 'url_event_4', ''),
        NULLIF(v_evt ->> 'url_event_5', ''),
        NULLIF(v_evt ->> 'url_invitation', ''), NULLIF(v_evt ->> 'url_registration', ''),
        NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE,
        NULLIF(v_evt ->> 'txt_venue_address', ''),
        NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC,
        NULLIF(v_evt ->> 'txt_entry_fee_currency', ''),
        v_arr_weapons, (v_evt ->> 'id_prior_event')::INT,
        (v_evt ->> 'id_evf_event')::INT, NULLIF(v_evt ->> 'txt_evf_slug', ''),
        (v_evt ->> 'id_evf_calendar_event')::BIGINT
      );
      v_created := v_created + 1;
    END LOOP;
  END IF;

  IF jsonb_array_length(p_updates) > 0 THEN
    FOR v_evt IN SELECT * FROM jsonb_array_elements(p_updates)
    LOOP
      v_id_event := (v_evt ->> 'id_event')::INT;
      v_arr_weapons := NULL;
      IF v_evt ? 'arr_weapons' THEN
        SELECT ARRAY(
          SELECT (value #>> '{}')::enum_weapon_type
          FROM jsonb_array_elements(v_evt -> 'arr_weapons')
        ) INTO v_arr_weapons;
      END IF;

      UPDATE tbl_event SET
        txt_name = COALESCE(NULLIF(v_evt ->> 'txt_name', ''), txt_name),
        dt_start = COALESCE(NULLIF(v_evt ->> 'dt_start', '')::DATE, dt_start),
        dt_end = COALESCE(NULLIF(v_evt ->> 'dt_end', '')::DATE, dt_end),
        txt_location = COALESCE(NULLIF(v_evt ->> 'txt_location', ''), txt_location),
        txt_country = COALESCE(NULLIF(v_evt ->> 'txt_country', ''), txt_country),
        id_organizer = COALESCE((v_evt ->> 'id_organizer')::INT, id_organizer),
        arr_weapons = COALESCE(v_arr_weapons, arr_weapons),
        id_evf_event = COALESCE((v_evt ->> 'id_evf_event')::INT, id_evf_event),
        id_evf_calendar_event = COALESCE(
          id_evf_calendar_event, (v_evt ->> 'id_evf_calendar_event')::BIGINT
        ),
        txt_evf_slug = COALESCE(NULLIF(v_evt ->> 'txt_evf_slug', ''), txt_evf_slug),
        url_event = COALESCE(url_event, NULLIF(v_evt ->> 'url_event', '')),
        url_event_2 = COALESCE(url_event_2, NULLIF(v_evt ->> 'url_event_2', '')),
        url_event_3 = COALESCE(url_event_3, NULLIF(v_evt ->> 'url_event_3', '')),
        url_event_4 = COALESCE(url_event_4, NULLIF(v_evt ->> 'url_event_4', '')),
        url_event_5 = COALESCE(url_event_5, NULLIF(v_evt ->> 'url_event_5', '')),
        url_invitation = COALESCE(url_invitation, NULLIF(v_evt ->> 'url_invitation', '')),
        url_registration = COALESCE(url_registration, NULLIF(v_evt ->> 'url_registration', '')),
        dt_registration_deadline = COALESCE(
          dt_registration_deadline,
          NULLIF(v_evt ->> 'dt_registration_deadline', '')::DATE
        ),
        num_entry_fee = COALESCE(
          num_entry_fee, NULLIF(v_evt ->> 'num_entry_fee', '')::NUMERIC
        ),
        txt_entry_fee_currency = COALESCE(
          txt_entry_fee_currency, NULLIF(v_evt ->> 'txt_entry_fee_currency', '')
        ),
        ts_updated = NOW()
      WHERE id_event = v_id_event;

      IF FOUND THEN v_updated := v_updated + 1; END IF;
    END LOOP;
  END IF;

  IF jsonb_array_length(p_deletes) > 0 THEN
    FOR v_id_event IN
      SELECT (value)::INT FROM jsonb_array_elements_text(p_deletes) AS value
    LOOP
      IF EXISTS (
        SELECT 1 FROM tbl_event e
        WHERE e.id_event = v_id_event
          AND e.enum_status = 'PLANNED'
          AND NOT EXISTS (
            SELECT 1 FROM tbl_tournament t
            JOIN tbl_result r ON r.id_tournament = t.id_tournament
            WHERE t.id_event = e.id_event
          )
      ) THEN
        DELETE FROM tbl_tournament WHERE id_event = v_id_event;
        DELETE FROM tbl_event WHERE id_event = v_id_event;
        v_deleted := v_deleted + 1;
      ELSE
        v_delete_skipped := v_delete_skipped || to_jsonb(v_id_event);
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'created', v_created,
    'updated', v_updated,
    'deleted', v_deleted,
    'delete_skipped', v_delete_skipped
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_mirror_events_to_prod(JSONB, JSONB, JSONB)
  FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION fn_mirror_events_to_prod(JSONB, JSONB, JSONB)
  TO authenticated;
