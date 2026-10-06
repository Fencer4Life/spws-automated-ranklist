-- =============================================================================
-- pgTAP — the CERT→PROD calendar promotion carries id_pzsz_event
-- =============================================================================
-- Verifies migration 20261006000003_prod_mirror_pzsz_identity.sql
-- (doc/plans/pzsz-results-plugin-2026-10-06.html §6 F2; ADR-087 amendment).
--
-- The mirror carried id_evf_event, id_evf_calendar_event and txt_evf_slug but
-- not id_pzsz_event: on 6 October 2026 PPS1s-2026-2027 held 4588 on CERT and
-- NULL on PROD. Q5 A (decided 6 October): the same rule as id_evf_event —
-- CERT's id wins when it sends one, PROD keeps its own when CERT sends none.
-- =============================================================================

BEGIN;

SELECT plan(14);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-6500-6501', '6500-08-01', '6501-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('PZSz', 'Polski Związek Szermierczy') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'PZSz';

  -- PROD rows promoted before this migration: no PZSz identity.
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, dt_end)
  VALUES
    ('PPS1s-6500-6501', 'I PP seniorów', v_season, v_org, 'PLANNED', '6500-10-03', '6500-10-03'),
    ('PPS2s-6500-6501', 'II PP seniorów', v_season, v_org, 'PLANNED', '6500-11-07', '6500-11-07'),
    ('PPS3s-6500-6501', 'III PP seniorów', v_season, v_org, 'PLANNED', '6500-12-05', '6500-12-05');
  UPDATE tbl_event SET id_pzsz_event = 7002 WHERE txt_code = 'PPS2s-6500-6501';
  UPDATE tbl_event SET id_pzsz_event = 7003 WHERE txt_code = 'PPS3s-6500-6501';

  -- Two rows whose PZSz ids a re-key on CERT swaps (108.5).
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, dt_end, id_pzsz_event)
  VALUES
    ('PPS4s-6500-6501', 'IV PP seniorów', v_season, v_org, 'PLANNED', '6501-01-09', '6501-01-09', 7004),
    ('PPS5s-6500-6501', 'V PP seniorów', v_season, v_org, 'PLANNED', '6501-02-06', '6501-02-06', 7005);
END;
$setup$;

-- 108.1 — a created event carries CERT's PZSz id
SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'MPS-6500-6501',
      'txt_name', 'Mistrzostwa Polski Seniorów',
      'id_season', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501'),
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz'),
      'dt_start', '6501-05-08',
      'dt_end', '6501-05-09',
      'id_pzsz_event', 7100
    )),
    '[]'::JSONB, '[]'::JSONB)
  $mir$,
  '108.1a — the mirror accepts a create carrying id_pzsz_event'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'MPS-6500-6501'),
  7100,
  '108.1 — a created event carries CERT''s id_pzsz_event'
);

-- 108.2-108.4 — one update batch: fill an empty id, CERT's id wins over a
-- different one (Q5 A), and a payload without the key keeps PROD's id.
SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
        'id_pzsz_event', 4588),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS2s-6500-6501'),
        'id_pzsz_event', 7202),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS3s-6500-6501'),
        'txt_name', 'III PP seniorów')
    ),
    '[]'::JSONB)
  $mir$,
  '108.2a — the mirror accepts updates carrying id_pzsz_event'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS1s-6500-6501'),
  4588,
  '108.2 — an update fills PROD''s empty id_pzsz_event'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS2s-6500-6501'),
  7202,
  '108.3 — CERT''s id wins over a different PROD id (Q5 A, as id_evf_event)'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS3s-6500-6501'),
  7003,
  '108.4 — an update without id_pzsz_event keeps PROD''s'
);

-- 108.5 — a re-key that swaps two ids in one batch does not trip the unique
-- index idx_tbl_event_pzsz_season (the id_prior_event swap's lesson).
SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    '[]'::JSONB,
    jsonb_build_array(
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS4s-6500-6501'),
        'id_pzsz_event', 7005),
      jsonb_build_object(
        'id_event', (SELECT id_event FROM tbl_event WHERE txt_code = 'PPS5s-6500-6501'),
        'id_pzsz_event', 7004)
    ),
    '[]'::JSONB)
  $mir$,
  '108.5a — a batch swapping two PZSz ids lives'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS4s-6500-6501'),
  7005,
  '108.5 — the first row takes the second row''s id'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS5s-6500-6501'),
  7004,
  '108.5b — the second row takes the first row''s id'
);

-- 108.6 — a new event claiming an id another PROD row holds takes it (CERT wins).
SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'MPS2-6500-6501',
      'txt_name', 'II Mistrzostwa Polski Seniorów',
      'id_season', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501'),
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz'),
      'dt_start', '6501-06-05',
      'dt_end', '6501-06-06',
      'id_pzsz_event', 7003
    )),
    '[]'::JSONB, '[]'::JSONB)
  $mir$,
  '108.6a — a create claiming a held id lives'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'MPS2-6500-6501'),
  7003,
  '108.6 — the created event takes the id'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS3s-6500-6501'),
  NULL::INT,
  '108.6b — the former holder lets go of it'
);

-- 108.7 — a create of a code PROD already holds is skipped, so it releases nothing.
SELECT lives_ok(
  $mir$
  SELECT fn_mirror_events_to_prod(
    jsonb_build_array(jsonb_build_object(
      'txt_code', 'PPS4s-6500-6501',
      'txt_name', 'IV PP seniorów',
      'id_season', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501'),
      'id_organizer', (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'PZSz'),
      'dt_start', '6501-01-09',
      'dt_end', '6501-01-09',
      'id_pzsz_event', 7004
    )),
    '[]'::JSONB, '[]'::JSONB)
  $mir$,
  '108.7a — a skipped create lives'
);
SELECT is(
  (SELECT id_pzsz_event FROM tbl_event WHERE txt_code = 'PPS5s-6500-6501'),
  7004,
  '108.7 — a skipped create does not take an id from another row'
);

SELECT * FROM finish();
ROLLBACK;
