-- =============================================================================
-- EVF id/slug dedup key (ADR-039 rev 3 / ADR-028 amendment)
-- =============================================================================
-- Tests 50.1–50.7: fn_sync_evf_event_fields diff-and-sync semantics,
-- idx_tbl_event_evf_slug / idx_tbl_event_evf uniqueness, and the migration's
-- backfill tie-break (lowest id_event per duplicate url_event group becomes
-- canonical). Root-cause context: "EVF Circuit - Samorin (SVK)" was
-- duplicated 7x because country+location were blank on both scrape and CERT
-- row, so the pre-existing date+country+location ladder never matched.
-- =============================================================================

BEGIN;
SELECT plan(8);

-- ===== SETUP =====
DO $setup$
DECLARE
  v_season INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_season := fn_create_season('EVFSLUG-TEST', '2034-09-01', '2035-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('EVF', 'European Veterans Fencing')
  ON CONFLICT (txt_code) DO NOTHING;
END;
$setup$;


-- =========================================================================
-- 50.1 — fn_sync_evf_event_fields overwrites dt_start/dt_end when the
--        payload's dates differ (reschedule propagation).
-- =========================================================================
DO $t501$
DECLARE
  v_season  INT;
  v_org     INT;
  v_id      INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id := fn_create_event(
    'EVFSLUG-EV-50-1', 'Reschedule test 50.1', v_season, v_org,
    'OldCity', '2034-10-01'::DATE, '2034-10-01'::DATE
  );
  v_payload := jsonb_build_array(jsonb_build_object(
    'id_event', v_id, 'dt_start', '2034-11-15', 'dt_end', '2034-11-16'
  ));
  PERFORM fn_sync_evf_event_fields(v_payload);
END;
$t501$;

SELECT results_eq(
  $$SELECT dt_start::TEXT, dt_end::TEXT FROM tbl_event
     WHERE txt_code = 'EVFSLUG-EV-50-1'$$,
  $$VALUES ('2034-11-15'::TEXT, '2034-11-16'::TEXT)$$,
  '50.1: fn_sync_evf_event_fields overwrites dt_start/dt_end on reschedule'
);


-- =========================================================================
-- 50.2 — fills txt_location/txt_country from NULL when venue becomes known.
-- =========================================================================
DO $t502$
DECLARE
  v_season  INT;
  v_org     INT;
  v_id      INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id := fn_create_event(
    'EVFSLUG-EV-50-2', 'Venue-fill test 50.2', v_season, v_org,
    NULL, '2034-10-02'::DATE, '2034-10-02'::DATE
  );
  v_payload := jsonb_build_array(jsonb_build_object(
    'id_event', v_id, 'location', 'Samorin', 'country', 'Slovakia'
  ));
  PERFORM fn_sync_evf_event_fields(v_payload);
END;
$t502$;

SELECT results_eq(
  $$SELECT txt_location, txt_country FROM tbl_event
     WHERE txt_code = 'EVFSLUG-EV-50-2'$$,
  $$VALUES ('Samorin'::TEXT, 'Slovakia'::TEXT)$$,
  '50.2: fn_sync_evf_event_fields fills txt_location/txt_country from NULL'
);


-- =========================================================================
-- 50.3 — does NOT null out an already-populated txt_location/txt_country
--        when the payload sends blank for it (transient scrape gap guard).
-- =========================================================================
DO $t503$
DECLARE
  v_season  INT;
  v_org     INT;
  v_id      INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id := fn_create_event(
    'EVFSLUG-EV-50-3', 'Blank-guard test 50.3', v_season, v_org,
    'Dublin', '2034-10-03'::DATE, '2034-10-03'::DATE, NULL, 'Ireland'
  );
  -- Payload omits location/country entirely (blank scrape) -- must not wipe.
  v_payload := jsonb_build_array(jsonb_build_object(
    'id_event', v_id, 'name', 'Dublin (unchanged)'
  ));
  PERFORM fn_sync_evf_event_fields(v_payload);
END;
$t503$;

SELECT results_eq(
  $$SELECT txt_location, txt_country FROM tbl_event
     WHERE txt_code = 'EVFSLUG-EV-50-3'$$,
  $$VALUES ('Dublin'::TEXT, 'Ireland'::TEXT)$$,
  '50.3: fn_sync_evf_event_fields does not null out populated location/country on blank payload'
);


-- =========================================================================
-- 50.4 — fill-only for id_evf_event/txt_evf_slug: an existing non-NULL
--        value is never overwritten by a different incoming value.
-- =========================================================================
DO $t504$
DECLARE
  v_season  INT;
  v_org     INT;
  v_id      INT;
  v_payload JSONB;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id := fn_create_event(
    'EVFSLUG-EV-50-4', 'Fill-only test 50.4', v_season, v_org,
    'Munich', '2034-10-04'::DATE, '2034-10-04'::DATE
  );
  UPDATE tbl_event SET id_evf_event = 5150104, txt_evf_slug = 'original-slug-50-4'
   WHERE id_event = v_id;
  -- Incoming payload tries to overwrite both with different values.
  v_payload := jsonb_build_array(jsonb_build_object(
    'id_event', v_id, 'evf_id', 9990104, 'evf_slug', 'different-slug-50-4'
  ));
  PERFORM fn_sync_evf_event_fields(v_payload);
END;
$t504$;

SELECT results_eq(
  $$SELECT id_evf_event, txt_evf_slug FROM tbl_event
     WHERE txt_code = 'EVFSLUG-EV-50-4'$$,
  $$VALUES (5150104, 'original-slug-50-4'::TEXT)$$,
  '50.4: fn_sync_evf_event_fields is fill-only for id_evf_event/txt_evf_slug'
);


-- =========================================================================
-- 50.5 — idx_tbl_event_evf_slug rejects a duplicate txt_evf_slug on two
--        distinct id_event rows.
-- =========================================================================
DO $t505_setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_id_a   INT;
  v_id_b   INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id_a := fn_create_event(
    'EVFSLUG-EV-50-5A', 'Slug uniqueness A', v_season, v_org,
    'Faches', '2034-10-05'::DATE, '2034-10-05'::DATE
  );
  v_id_b := fn_create_event(
    'EVFSLUG-EV-50-5B', 'Slug uniqueness B', v_season, v_org,
    'Faches', '2034-10-06'::DATE, '2034-10-06'::DATE
  );
  UPDATE tbl_event SET txt_evf_slug = 'evf-circuit-faches-505' WHERE id_event = v_id_a;
END;
$t505_setup$;

SELECT throws_ok(
  $$UPDATE tbl_event SET txt_evf_slug = 'evf-circuit-faches-505'
     WHERE txt_code = 'EVFSLUG-EV-50-5B'$$,
  NULL,
  NULL,
  '50.5: idx_tbl_event_evf_slug rejects a duplicate txt_evf_slug on a distinct row'
);


-- =========================================================================
-- 50.6 — idx_tbl_event_evf (now unique) rejects a duplicate id_evf_event
--        on two distinct id_event rows.
-- =========================================================================
DO $t506_setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_id_a   INT;
  v_id_b   INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  v_id_a := fn_create_event(
    'EVFSLUG-EV-50-6A', 'Id uniqueness A', v_season, v_org,
    'Stockholm', '2034-10-07'::DATE, '2034-10-07'::DATE
  );
  v_id_b := fn_create_event(
    'EVFSLUG-EV-50-6B', 'Id uniqueness B', v_season, v_org,
    'Stockholm', '2034-10-08'::DATE, '2034-10-08'::DATE
  );
  UPDATE tbl_event SET id_evf_event = 7770506 WHERE id_event = v_id_a;
END;
$t506_setup$;

SELECT throws_ok(
  $$UPDATE tbl_event SET id_evf_event = 7770506
     WHERE txt_code = 'EVFSLUG-EV-50-6B'$$,
  NULL,
  NULL,
  '50.6: idx_tbl_event_evf (unique) rejects a duplicate id_evf_event on a distinct row'
);


-- =========================================================================
-- 50.7 — backfill tie-break: among rows sharing one url_event, only the
--        LOWEST id_event gets txt_evf_slug populated; the rest stay NULL.
--        Re-executes the exact backfill statement from the migration
--        (20260710000001_evf_slug_dedup.sql) against a fresh 7-row group,
--        mirroring the real Samorin duplicate scenario (id_event ascending
--        = insertion order, all rows sharing one URL, no venue known yet).
-- =========================================================================
DO $t507_setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_url    TEXT := 'https://www.veteransfencing.eu/event/evf-circuit-test-50-7/';
  v_i      INT;
BEGIN
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'EVFSLUG-TEST';
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';
  FOR v_i IN 1..7 LOOP
    PERFORM fn_create_event(
      'EVFSLUG-EV-50-7-' || v_i, 'Duplicate group 50.7 #' || v_i, v_season, v_org,
      NULL, '2034-12-12'::DATE, '2034-12-12'::DATE, v_url
    );
  END LOOP;
END;
$t507_setup$;

-- Same statement shape as the migration's backfill (scoped implicitly to
-- this group since it's the only EVF row set sharing this url_event and
-- currently NULL txt_evf_slug; already-slugged rows from earlier tests are
-- untouched because their WHERE evf_slug IS NOT NULL rn=1 winner is stable).
WITH slug_extract AS (
  SELECT
    e.id_event,
    NULLIF(regexp_replace(TRIM(TRAILING '/' FROM e.url_event), '^.*/', ''), '') AS evf_slug
  FROM tbl_event e
  JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
  WHERE o.txt_code = 'EVF'
    AND e.url_event IS NOT NULL
    AND e.url_event <> ''
    AND e.txt_evf_slug IS NULL
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

SELECT results_eq(
  $$SELECT txt_code, (txt_evf_slug IS NOT NULL) AS has_slug
      FROM tbl_event
     WHERE txt_code LIKE 'EVFSLUG-EV-50-7-%'
     ORDER BY id_event ASC$$,
  $$VALUES
      ('EVFSLUG-EV-50-7-1'::TEXT, TRUE),
      ('EVFSLUG-EV-50-7-2'::TEXT, FALSE),
      ('EVFSLUG-EV-50-7-3'::TEXT, FALSE),
      ('EVFSLUG-EV-50-7-4'::TEXT, FALSE),
      ('EVFSLUG-EV-50-7-5'::TEXT, FALSE),
      ('EVFSLUG-EV-50-7-6'::TEXT, FALSE),
      ('EVFSLUG-EV-50-7-7'::TEXT, FALSE)$$,
  '50.7: backfill tie-break — only the lowest id_event per url_event group gets txt_evf_slug'
);


-- =========================================================================
-- 50.8 — idx_tbl_event_evf_slug allows the SAME txt_evf_slug to recur on a
--        row in a DIFFERENT season (live bug, 2026-07-14): EVF reuses one
--        detail-page slug ("evf-circuit-munich") for every yearly edition
--        of a recurring circuit stop. A prior-season COMPLETED row already
--        carries that slug; the next season's calendar scrape must be able
--        to create/claim its own row with the same slug without violating
--        uniqueness. Only same-season collisions (50.5) must stay rejected.
-- =========================================================================
DO $t508_setup$
DECLARE
  v_season_a INT;
  v_season_b INT;
  v_org      INT;
  v_id_a     INT;
BEGIN
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  UPDATE tbl_season SET bool_active = FALSE;
  v_season_a := fn_create_season('EVFSLUG-TEST-A', '2036-09-01', '2037-06-30');
  v_season_b := fn_create_season('EVFSLUG-TEST-B', '2037-09-01', '2038-06-30');
  UPDATE tbl_season SET bool_active = TRUE WHERE id_season = v_season_b;

  v_id_a := fn_create_event(
    'EVFSLUG-EV-50-8A', 'Cross-season slug A', v_season_a, v_org,
    'Munich', '2036-11-28'::DATE, '2036-11-28'::DATE
  );
  UPDATE tbl_event SET txt_evf_slug = 'evf-circuit-munich-508'
   WHERE id_event = v_id_a;

  PERFORM fn_create_event(
    'EVFSLUG-EV-50-8B', 'Cross-season slug B', v_season_b, v_org,
    'Munich', '2037-11-28'::DATE, '2037-11-28'::DATE
  );
END;
$t508_setup$;

SELECT lives_ok(
  $$UPDATE tbl_event SET txt_evf_slug = 'evf-circuit-munich-508'
     WHERE txt_code = 'EVFSLUG-EV-50-8B'$$,
  '50.8: idx_tbl_event_evf_slug allows the same slug to recur in a different season'
);


SELECT * FROM finish();
ROLLBACK;
