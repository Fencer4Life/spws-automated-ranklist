-- =============================================================================
-- pgTAP — PZSz start lists are stored inputs (ADR-112)
-- =============================================================================
-- Verifies migration 20261007000001_pzsz_start_list.sql: the store is
-- service_role only and insert-only; a version is appended only when it
-- differs from the newest one for the same event, weapon and gender; the
-- checks refuse what is not a start list; retention deletes the lists of
-- events outside the active season.
-- =============================================================================

BEGIN;

SELECT plan(20);

-- 109.1 — the store is service_role only (ADR-083)
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'tbl_pzsz_start_list'),
  '109.1a — RLS is on'
);
SELECT ok(
  NOT has_table_privilege('anon', 'tbl_pzsz_start_list', 'SELECT'),
  '109.1b — anon cannot read a start list'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'tbl_pzsz_start_list', 'SELECT'),
  '109.1c — authenticated cannot read a start list'
);

-- 109.2 — rows are insert-only
SELECT ok(
  NOT has_table_privilege('service_role', 'tbl_pzsz_start_list', 'UPDATE'),
  '109.2a — service_role cannot update a stored version'
);
SELECT ok(
  has_table_privilege('service_role', 'tbl_pzsz_start_list', 'INSERT')
  AND has_table_privilege('service_role', 'tbl_pzsz_start_list', 'DELETE'),
  '109.2b — service_role inserts, and deletes for retention'
);

-- 109.3 — append only when the list differs from the newest version
SELECT is(
  (fn_pzsz_start_list_store(jsonb_build_object(
    'id_pzsz_event', 970001, 'id_pzsz_tournament', 980001,
    'enum_weapon', 'SABRE', 'enum_gender', 'M',
    'txt_sha256', repeat('a', 64),
    'jsonb_starters', '[["Testowy Jan", 1971]]'::JSONB,
    'txt_source', 'pzszerm.pl')) ->> 'stored')::BOOLEAN,
  TRUE,
  '109.3a — the first version A is stored'
);
SELECT is(
  (fn_pzsz_start_list_store(jsonb_build_object(
    'id_pzsz_event', 970001, 'id_pzsz_tournament', 980001,
    'enum_weapon', 'SABRE', 'enum_gender', 'M',
    'txt_sha256', repeat('a', 64),
    'jsonb_starters', '[["Testowy Jan", 1971]]'::JSONB,
    'txt_source', 'pzszerm.pl')) ->> 'stored')::BOOLEAN,
  FALSE,
  '109.3b — A again stores nothing'
);
SELECT is(
  (fn_pzsz_start_list_store(jsonb_build_object(
    'id_pzsz_event', 970001, 'id_pzsz_tournament', 980001,
    'enum_weapon', 'SABRE', 'enum_gender', 'M',
    'txt_sha256', repeat('b', 64),
    'jsonb_starters', '[["Testowy Jan", 1971], ["Wzorcowa Anna", 2009]]'::JSONB,
    'txt_source', 'pzszerm.pl')) ->> 'stored')::BOOLEAN,
  TRUE,
  '109.3c — a changed list B is stored'
);
SELECT is(
  (fn_pzsz_start_list_store(jsonb_build_object(
    'id_pzsz_event', 970001, 'id_pzsz_tournament', 980001,
    'enum_weapon', 'SABRE', 'enum_gender', 'M',
    'txt_sha256', repeat('a', 64),
    'jsonb_starters', '[["Testowy Jan", 1971]]'::JSONB,
    'txt_source', 'saved page')) ->> 'stored')::BOOLEAN,
  TRUE,
  '109.3d — A after B is stored again'
);
SELECT is(
  (SELECT count(*)::INT FROM tbl_pzsz_start_list WHERE id_pzsz_event = 970001),
  3,
  '109.3e — A, A, B, A leaves three versions'
);
SELECT is(
  (SELECT txt_sha256 FROM tbl_pzsz_start_list
    WHERE id_pzsz_event = 970001 AND enum_weapon = 'SABRE' AND enum_gender = 'M'
    ORDER BY id_pzsz_start_list DESC LIMIT 1),
  repeat('a', 64),
  '109.3f — the newest version is A'
);

-- 109.4 — only service_role runs the functions
SELECT ok(
  NOT has_function_privilege('anon', 'fn_pzsz_start_list_store(jsonb)', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_pzsz_start_list_store(jsonb)', 'EXECUTE'),
  '109.4a — anon and authenticated cannot store a start list'
);
SELECT ok(
  NOT has_function_privilege('anon', 'fn_pzsz_start_list_purge()', 'EXECUTE')
  AND NOT has_function_privilege('authenticated', 'fn_pzsz_start_list_purge()', 'EXECUTE'),
  '109.4b — anon and authenticated cannot purge'
);

-- 109.5 — what is not a start list is refused
SELECT throws_ok(
  $$ SELECT fn_pzsz_start_list_store(jsonb_build_object(
       'id_pzsz_event', 970001, 'id_pzsz_tournament', 980002,
       'enum_weapon', 'SABRE', 'enum_gender', 'F', 'txt_sha256', repeat('c', 64),
       'jsonb_starters', '[["Testowa Ewa", 1970]]'::JSONB, 'txt_source', 'elsewhere')) $$,
  '23514', NULL,
  '109.5a — an unknown source is refused'
);
SELECT throws_ok(
  $$ SELECT fn_pzsz_start_list_store(jsonb_build_object(
       'id_pzsz_event', 970001, 'id_pzsz_tournament', 980002,
       'enum_weapon', 'SABRE', 'enum_gender', 'F', 'txt_sha256', repeat('c', 64),
       'jsonb_starters', '[]'::JSONB, 'txt_source', 'pzszerm.pl')) $$,
  '23514', NULL,
  '109.5b — an empty list is refused'
);
SELECT throws_ok(
  $$ SELECT fn_pzsz_start_list_store(jsonb_build_object(
       'id_pzsz_event', 970001, 'id_pzsz_tournament', 980002,
       'enum_weapon', 'SABRE', 'enum_gender', 'F', 'txt_sha256', 'not-a-hash',
       'jsonb_starters', '[["Testowa Ewa", 1970]]'::JSONB, 'txt_source', 'pzszerm.pl')) $$,
  '23514', NULL,
  '109.5c — a malformed hash is refused'
);
SELECT throws_ok(
  $$ SELECT fn_pzsz_start_list_store(jsonb_build_object(
       'id_pzsz_event', 970001, 'id_pzsz_tournament', 980002,
       'enum_weapon', 'SPEAR', 'enum_gender', 'F', 'txt_sha256', repeat('c', 64),
       'jsonb_starters', '[["Testowa Ewa", 1970]]'::JSONB, 'txt_source', 'pzszerm.pl')) $$,
  '22P02', NULL,
  '109.5d — an unknown weapon is refused'
);

-- 109.6 — retention: lists of events outside the active season are deleted
DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
BEGIN
  PERFORM set_config('spws.today', '6500-09-01', true);
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES ('SPWS-6500-6501', '6500-08-01', '6501-07-31')
  ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_season INTO v_season FROM tbl_season WHERE txt_code = 'SPWS-6500-6501';
  INSERT INTO tbl_organizer (txt_code, txt_name)
  VALUES ('PZSz', 'Polski Związek Szermierczy') ON CONFLICT (txt_code) DO NOTHING;
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'PZSz';
  INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, enum_status, dt_start, dt_end, id_pzsz_event)
  VALUES ('PPS1s-6500-6501', 'I PP seniorów', v_season, v_org, 'PLANNED', '6500-10-03', '6500-10-04', 970001);

  -- A list whose PZSz event is on no event of the active season.
  PERFORM fn_pzsz_start_list_store(jsonb_build_object(
    'id_pzsz_event', 970002, 'id_pzsz_tournament', 980003,
    'enum_weapon', 'EPEE', 'enum_gender', 'M', 'txt_sha256', repeat('d', 64),
    'jsonb_starters', '[["Dawny Piotr", 1960]]'::JSONB, 'txt_source', 'pzszerm.pl'));
END;
$setup$;

SELECT ok(fn_pzsz_start_list_purge() >= 1, '109.6a — the purge reports what it deleted');
SELECT is(
  (SELECT count(*)::INT FROM tbl_pzsz_start_list WHERE id_pzsz_event = 970002),
  0,
  '109.6b — a list of an event outside the active season is deleted'
);
SELECT is(
  (SELECT count(*)::INT FROM tbl_pzsz_start_list WHERE id_pzsz_event = 970001),
  3,
  '109.6c — the active season''s lists stay'
);

SELECT * FROM finish();
ROLLBACK;
