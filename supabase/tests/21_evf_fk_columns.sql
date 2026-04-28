-- =============================================================================
-- EVF FK columns (id_evf_event, id_evf_competition)
-- =============================================================================
-- Tests 21.1–21.5: schema + index + view exposure + nullability round-trip.
-- =============================================================================

BEGIN;
SELECT plan(5);


-- =========================================================================
-- 21.1 — tbl_event.id_evf_event is a nullable INTEGER column
-- =========================================================================
SELECT is(
  (SELECT data_type || '/' || is_nullable
     FROM information_schema.columns
    WHERE table_name = 'tbl_event' AND column_name = 'id_evf_event'),
  'integer/YES',
  '21.1: tbl_event.id_evf_event is a nullable INTEGER column'
);


-- =========================================================================
-- 21.2 — tbl_tournament.id_evf_competition is a nullable INTEGER column
-- =========================================================================
SELECT is(
  (SELECT data_type || '/' || is_nullable
     FROM information_schema.columns
    WHERE table_name = 'tbl_tournament' AND column_name = 'id_evf_competition'),
  'integer/YES',
  '21.2: tbl_tournament.id_evf_competition is a nullable INTEGER column'
);


-- =========================================================================
-- 21.3 — Partial indexes exist on both FK columns
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT
     FROM pg_indexes
    WHERE indexname IN ('idx_tbl_event_evf','idx_tbl_tournament_evf')),
  2,
  '21.3: partial indexes exist on both id_evf_event and id_evf_competition'
);


-- =========================================================================
-- 21.4 — vw_calendar exposes id_evf_event (form round-trip safety)
-- =========================================================================
SELECT is(
  (SELECT COUNT(*)::INT
     FROM information_schema.columns
    WHERE table_name = 'vw_calendar' AND column_name = 'id_evf_event'),
  1,
  '21.4: vw_calendar exposes id_evf_event'
);


-- =========================================================================
-- 21.5 — NULL is the default and is preserved (round-trip insert/update)
-- =========================================================================
DO $rt$
DECLARE
  v_season INT;
  v_org    INT;
  v_event  INT;
  v_tour   INT;
BEGIN
  -- Use any active or first season.
  SELECT id_season INTO v_season FROM tbl_season ORDER BY id_season LIMIT 1;
  -- Use any organizer or create one for the test.
  SELECT id_organizer INTO v_org FROM tbl_organizer ORDER BY id_organizer LIMIT 1;
  IF v_org IS NULL THEN
    INSERT INTO tbl_organizer (txt_code, txt_name)
      VALUES ('EVFFK-ORG','EVF FK Test Org')
      RETURNING id_organizer INTO v_org;
  END IF;

  INSERT INTO tbl_event (
    txt_code, txt_name, id_season, id_organizer,
    txt_location, dt_start, dt_end, enum_status
  ) VALUES (
    'EVFFK-EV-21-5','EVF FK round-trip 21.5',
    v_season, v_org, 'Test', '2031-09-01','2031-09-02','PLANNED'
  ) RETURNING id_event INTO v_event;

  INSERT INTO tbl_tournament (
    id_event, txt_code, txt_name, enum_type, enum_weapon, enum_gender,
    enum_age_category, dt_tournament, int_participant_count
  ) VALUES (
    v_event,'EVFFK-T-21-5','EVF FK Tournament','PEW','EPEE','M','V2',
    '2031-09-01', 0
  ) RETURNING id_tournament INTO v_tour;

  -- Round-trip: starts NULL, set, then unset.
  UPDATE tbl_event       SET id_evf_event       = 999 WHERE id_event = v_event;
  UPDATE tbl_tournament  SET id_evf_competition = 555 WHERE id_tournament = v_tour;
  UPDATE tbl_event       SET id_evf_event       = NULL WHERE id_event = v_event;
  UPDATE tbl_tournament  SET id_evf_competition = NULL WHERE id_tournament = v_tour;
END;
$rt$;

SELECT is(
  (SELECT id_evf_event IS NULL AND
          (SELECT id_evf_competition IS NULL FROM tbl_tournament WHERE txt_code = 'EVFFK-T-21-5')
     FROM tbl_event WHERE txt_code = 'EVFFK-EV-21-5'),
  TRUE,
  '21.5: id_evf_event / id_evf_competition round-trip NULL→value→NULL'
);


SELECT * FROM finish();
ROLLBACK;
