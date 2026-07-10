-- =============================================================================
-- EVF id/slug dedup key (ADR-039 rev 3 / ADR-028 amendment)
-- =============================================================================
-- Root cause: "EVF Circuit - Samorin (SVK)" (dt_start 2026-09-12) was
-- duplicated 7x (PEW68..PEW74, id_event 111-117) because country+location
-- were blank on both scrape and CERT row, so the date+country+location
-- fuzzy ladder in _find_existing_match (python/scrapers/evf_calendar.py)
-- could never match. This adds a slug-based fallback key (ranked between
-- id_evf_event, primary but structurally unavailable for freshly-listed
-- future events, and the fuzzy ladder, now demoted to backup/last-resort).
-- =============================================================================

ALTER TABLE tbl_event
  ADD COLUMN IF NOT EXISTS txt_evf_slug TEXT;

COMMENT ON COLUMN tbl_event.txt_evf_slug IS
  'Last path segment of the EVF calendar detail-page URL (veteransfencing.eu/event/<slug>/). '
  'NULL for non-EVF events and legacy EVF rows imported before this column existed. '
  'Fallback dedup key: ranked below id_evf_event, above the date+country+location ladder.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_tbl_event_evf_slug
  ON tbl_event (txt_evf_slug)
  WHERE txt_evf_slug IS NOT NULL;

-- Strengthen id_evf_event to UNIQUE too (defense in depth -- it's the
-- PRIMARY dedup key, so two rows sharing one EVF id should be impossible;
-- the pre-existing idx_tbl_event_evf, from 20260429000002, is only a plain
-- index. Safe to convert: live-verified 2026-07-10, all 87 EVF rows on
-- CERT currently have id_evf_event = NULL, so there is no existing
-- duplicate to conflict).
DROP INDEX IF EXISTS idx_tbl_event_evf;
CREATE UNIQUE INDEX idx_tbl_event_evf
  ON tbl_event (id_evf_event)
  WHERE id_evf_event IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Backfill: derive txt_evf_slug from url_event for existing EVF rows.
-- Tie-break (locked decision): when multiple rows share the same url_event
-- (the 7 Samorin duplicates), only the LOWEST id_event in the group gets
-- txt_evf_slug populated -- it becomes canonical. The others are left NULL
-- and are NOT deleted here (manual cleanup happens after verification, see
-- the plan doc -- out of scope for this migration).
-- -----------------------------------------------------------------------------
WITH slug_extract AS (
  SELECT
    e.id_event,
    NULLIF(regexp_replace(TRIM(TRAILING '/' FROM e.url_event), '^.*/', ''), '') AS evf_slug
  FROM tbl_event e
  JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
  WHERE o.txt_code = 'EVF'
    AND e.url_event IS NOT NULL
    AND e.url_event <> ''
),
ranked AS (
  SELECT id_event, evf_slug,
         ROW_NUMBER() OVER (PARTITION BY evf_slug ORDER BY id_event ASC) AS rn
  FROM slug_extract
  WHERE evf_slug IS NOT NULL
)
UPDATE tbl_event e
SET txt_evf_slug = r.evf_slug
FROM ranked r
WHERE e.id_event = r.id_event
  AND r.rn = 1;

-- -----------------------------------------------------------------------------
-- Rebuild vw_calendar to expose txt_evf_slug (feedback_view_rebuild_on_
-- tbl_event memory). Based on the CURRENT definition in
-- 20260704000001_event_registration_schema.sql (id_prior_event,
-- json_ingest_sources, json_source_overrides, url_entry_list,
-- txt_organizer_email, ts_ftl_sent, num_entry_fee_2w/3w,
-- bool_use_spws_registration) -- NOT the older 20260429000002 version --
-- just append e.txt_evf_slug to the existing column list.
-- -----------------------------------------------------------------------------
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
  e.id_evf_event,
  e.txt_evf_slug,
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

GRANT SELECT ON vw_calendar TO anon;
GRANT SELECT ON vw_calendar TO authenticated;


-- =============================================================================
-- fn_import_evf_events_v2 -- extend to read/write evf_slug (same signature)
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_import_evf_events_v2(
  p_events    JSONB,
  p_id_season INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_evt          JSONB;
  v_evf_org      INT;
  v_alloc        RECORD;
  v_event_id     INT;
  v_kind         TEXT;
  v_weapon       TEXT;
  v_created      INT := 0;
  v_slot_reused  INT := 0;
  v_prior_match  INT := 0;
  v_alerts       JSONB := '[]'::JSONB;
BEGIN
  LOCK TABLE tbl_event IN SHARE ROW EXCLUSIVE MODE;

  SELECT id_organizer INTO v_evf_org FROM tbl_organizer WHERE txt_code = 'EVF';
  IF v_evf_org IS NULL THEN
    RAISE EXCEPTION 'fn_import_evf_events_v2: EVF organizer not found in tbl_organizer';
  END IF;

  FOR v_evt IN SELECT * FROM jsonb_array_elements(p_events)
  LOOP
    DECLARE
      v_name      TEXT    := v_evt ->> 'name';
      v_dt_start  DATE    := (v_evt ->> 'dt_start')::DATE;
      v_dt_end    DATE    := COALESCE((v_evt ->> 'dt_end')::DATE, (v_evt ->> 'dt_start')::DATE);
      v_location  TEXT    := COALESCE(v_evt ->> 'location', '');
      v_country   TEXT    := COALESCE(v_evt ->> 'country', '');
      v_weapons   JSONB   := COALESCE(v_evt -> 'weapons', '[]'::JSONB);
      v_is_team   BOOLEAN := COALESCE((v_evt ->> 'is_team')::BOOLEAN, FALSE);
      v_url_event TEXT    := COALESCE(v_evt ->> 'url_event', '');
      v_url_inv   TEXT    := COALESCE(v_evt ->> 'url_invitation', '');
      v_url_reg   TEXT    := COALESCE(v_evt ->> 'url_registration', '');
      v_addr      TEXT    := COALESCE(v_evt ->> 'address', '');
      v_evf_id    INT     := NULLIF(v_evt ->> 'evf_id', '')::INT;
      v_evf_slug  TEXT    := NULLIF(v_evt ->> 'evf_slug', '');
    BEGIN
      v_kind := fn_classify_evf_event(v_name, v_is_team);

      SELECT * INTO v_alloc
        FROM fn_allocate_evf_event_code(p_id_season, v_kind, v_location, v_country);

      IF v_alloc.alloc_path = 'CURRENT_SLOT_REUSE' THEN
        UPDATE tbl_event SET
          txt_name      = v_name,
          dt_start      = v_dt_start,
          dt_end        = v_dt_end,
          txt_location  = NULLIF(v_location, ''),
          txt_country   = NULLIF(v_country, ''),
          txt_venue_address = COALESCE(NULLIF(v_addr, ''), txt_venue_address),
          url_event     = COALESCE(NULLIF(v_url_event, ''), url_event),
          url_invitation = COALESCE(NULLIF(v_url_inv, ''), url_invitation),
          id_evf_event  = COALESCE(v_evf_id, id_evf_event),
          txt_evf_slug  = COALESCE(v_evf_slug, txt_evf_slug),
          enum_status   = 'PLANNED'
        WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season
        RETURNING id_event INTO v_event_id;
        v_slot_reused := v_slot_reused + 1;
      ELSE
        IF EXISTS (SELECT 1 FROM tbl_event
                    WHERE txt_code = v_alloc.txt_code AND id_season = p_id_season) THEN
          CONTINUE;
        END IF;

        INSERT INTO tbl_event (
          txt_code, txt_name, id_season, id_organizer,
          dt_start, dt_end, txt_location, txt_country,
          txt_venue_address, url_event, url_invitation,
          enum_status, id_prior_event, id_evf_event, txt_evf_slug
        ) VALUES (
          v_alloc.txt_code, v_name, p_id_season, v_evf_org,
          v_dt_start, v_dt_end,
          NULLIF(v_location, ''), NULLIF(v_country, ''),
          NULLIF(v_addr, ''), NULLIF(v_url_event, ''), NULLIF(v_url_inv, ''),
          'PLANNED', v_alloc.id_prior_event, v_evf_id, v_evf_slug
        ) RETURNING id_event INTO v_event_id;

        IF v_alloc.alloc_path = 'PRIOR_SEASON_MATCH' THEN
          v_prior_match := v_prior_match + 1;
        ELSE
          v_created := v_created + 1;
          v_alerts := v_alerts || jsonb_build_object(
            'code',     v_alloc.txt_code,
            'location', v_location,
            'country',  v_country
          );
        END IF;
      END IF;

      FOR v_weapon IN SELECT jsonb_array_elements_text(v_weapons)
      LOOP
        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-M-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'M', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-M-' || v_weapon
        );

        INSERT INTO tbl_tournament (
          id_event, txt_code, txt_name, enum_type,
          enum_weapon, enum_gender, enum_age_category,
          dt_tournament, int_participant_count, enum_import_status
        )
        SELECT
          v_event_id,
          v_alloc.txt_code || '-F-' || v_weapon,
          v_name,
          v_kind::enum_tournament_type,
          v_weapon::enum_weapon_type, 'F', 'V2',
          v_dt_start, 0, 'PLANNED'
        WHERE NOT EXISTS (
          SELECT 1 FROM tbl_tournament
          WHERE txt_code = v_alloc.txt_code || '-F-' || v_weapon
        );
      END LOOP;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'created',       v_created,
    'slot_reused',   v_slot_reused,
    'prior_matched', v_prior_match,
    'alerts',        v_alerts
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_import_evf_events_v2(JSONB, INT) TO authenticated;


-- =============================================================================
-- fn_sync_evf_event_fields -- NEW: diff-and-sync identity fields (ADR-039
-- rev 3). Called only from sync_calendar()'s "already imported" branch, in
-- ADDITION to (not instead of) the existing fn_refresh_evf_event_urls call.
-- Owns the fields that function never touches (txt_name/dt_start/dt_end/
-- txt_location/txt_country), plus fill-only maintenance of id_evf_event/
-- txt_evf_slug. Deliberately NOT merged into fn_refresh_evf_event_urls --
-- that function is shared with python/pipeline/promote.py (CERT->PROD
-- promotion, "fill NULLs only, never overwrites admin edits") and locked by
-- pgTAP test 15.6; changing its semantics would silently alter promotion
-- behavior for an unrelated concern.
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_sync_evf_event_fields(
  p_updates JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_upd     JSONB;
  v_touched INT := 0;
  v_changed INT := 0;
  v_row_cnt INT;
BEGIN
  FOR v_upd IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    DECLARE
      v_id        INT  := (v_upd ->> 'id_event')::INT;
      v_name      TEXT := NULLIF(v_upd ->> 'name', '');
      v_dt_start  DATE := NULLIF(v_upd ->> 'dt_start', '')::DATE;
      v_dt_end    DATE := NULLIF(v_upd ->> 'dt_end', '')::DATE;
      v_location  TEXT := NULLIF(v_upd ->> 'location', '');
      v_country   TEXT := NULLIF(v_upd ->> 'country', '');
      v_evf_id    INT  := NULLIF(v_upd ->> 'evf_id', '')::INT;
      v_evf_slug  TEXT := NULLIF(v_upd ->> 'evf_slug', '');
    BEGIN
      IF v_id IS NULL THEN
        CONTINUE;
      END IF;
      v_touched := v_touched + 1;

      -- Diff-and-overwrite for source-owned identity/schedule fields: only
      -- overwrite when the scraped value is present (never null out a
      -- populated field because of a transient blank scrape). Dates always
      -- propagate a fresh non-null value -- this is how a reschedule
      -- reaches CERT. id_evf_event / txt_evf_slug stay fill-only (an
      -- established id/slug is immutable once set).
      UPDATE tbl_event SET
        txt_name     = COALESCE(v_name, txt_name),
        dt_start     = COALESCE(v_dt_start, dt_start),
        dt_end       = COALESCE(v_dt_end, dt_end),
        txt_location = COALESCE(v_location, txt_location),
        txt_country  = COALESCE(v_country, txt_country),
        id_evf_event = COALESCE(id_evf_event, v_evf_id),
        txt_evf_slug = COALESCE(txt_evf_slug, v_evf_slug),
        ts_updated   = NOW()
      WHERE id_event = v_id
        AND (
          txt_name     IS DISTINCT FROM COALESCE(v_name, txt_name)
          OR dt_start     IS DISTINCT FROM COALESCE(v_dt_start, dt_start)
          OR dt_end       IS DISTINCT FROM COALESCE(v_dt_end, dt_end)
          OR txt_location IS DISTINCT FROM COALESCE(v_location, txt_location)
          OR txt_country  IS DISTINCT FROM COALESCE(v_country, txt_country)
          OR id_evf_event IS DISTINCT FROM COALESCE(id_evf_event, v_evf_id)
          OR txt_evf_slug IS DISTINCT FROM COALESCE(txt_evf_slug, v_evf_slug)
        );

      GET DIAGNOSTICS v_row_cnt = ROW_COUNT;
      IF v_row_cnt > 0 THEN
        v_changed := v_changed + 1;
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object('touched', v_touched, 'changed', v_changed);
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_sync_evf_event_fields(JSONB) FROM anon, PUBLIC;
GRANT  EXECUTE ON FUNCTION fn_sync_evf_event_fields(JSONB) TO authenticated;
