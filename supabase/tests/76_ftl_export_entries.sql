-- =============================================================================
-- pgTAP — fn_ftl_export_entries, the seed projection the download page reads
-- =============================================================================
-- Verifies migration 20260912000004_ftl_export_entries.sql.
--
-- WHY A FUNCTION AND NOT A VIEW. The FTL export page is public (plan §1:
-- "public WordPress page, /znajdz-zawody/ shape"), so the browser holds only
-- the anon key. tbl_registration has RLS enabled with a single policy —
-- `auth.role() = 'authenticated'` — so anon reads ZERO rows from it, which is
-- exactly right: that table carries the declared birth year and the
-- uuid_edit_token that authorises an edit. vw_registration_entry_list already
-- publishes the safe half (names, gender, weapons, age category) but it cannot
-- serve the exporter, because seeding needs the RANKING ORDER and the view has
-- no way to express it.
--
-- So this is a SECURITY DEFINER projection: it publishes the entry list's
-- columns plus one integer — the fencer's position inside their own
-- sub-ranking — and nothing else. No birth year, no id_fencer, no
-- id_registration, no edit token, no e-mail hash. 76.4 asserts that from the
-- function's own signature rather than by inspection, because a later widening
-- would otherwise be silent.
--
-- WHY THE ORDER IS COMPUTED HERE. Ordering needs fn_ranking_ppw for every
-- weapon × gender × category present — 22 of the 30 sub-rankings at PPW1. Doing
-- that from the browser means 22 round trips and 22 chances to render a
-- half-ordered file; doing it here is one call, and it keeps id_fencer (the
-- join key) server-side where it belongs.
--
-- ROLLING. fn_ftl_export_use_rolling is the SQL twin of the frontend's
-- shouldUseRolling (frontend/src/lib/rolling.ts, ADR-018/021): the live or
-- upcoming season ranks on carry-over, a finished season on its own results.
-- It matters here more than anywhere. PPW1-2026-2027 is the FIRST event of
-- SPWS-2026-2027, so the season has no results of its own: without rolling,
-- fn_ranking_ppw returns nothing, every registrant is "unranked", and the
-- mix-all file seeds the whole field in the order people happened to fill in
-- the form. Measured on LOCAL (PROD mirror, 2026-09-12): EPEE/M/V2 returns
-- 0 rows non-rolling and 22 rolling.
--
-- Plan-test-ID 76 (this file).
-- =============================================================================

BEGIN;

SELECT plan(32);

DO $setup$
DECLARE
  v_season INT;
  v_org    INT;
  v_ev     INT;
  v_t      INT;
  v_f      INT;
  v_fseason INT;
  v_fev    INT;
BEGIN
  -- A FINISHED season, so the ordering assertions below read the season's own
  -- results and do not depend on carry-over. Season end year 2020 → V2 is
  -- birth years 1961-1970, V0 is 1981-1990, and 1995 is not a veteran at all.
  v_season := fn_create_season('FTLX76', '2019-09-01', '2020-06-30');

  -- fn_create_season defaults new seasons to EVENT_FK_MATCHING, whose
  -- carry-over resolution runs through vw_eligible_event and needs event
  -- linkage this synthetic fixture has no reason to build. EVENT_CODE_MATCHING
  -- is an equally live configuration (SPWS-2023-2024 through SPWS-2025-2026 all
  -- use it) and the ordering rule under test is the same either way.
  UPDATE tbl_season SET enum_carryover_engine = 'EVENT_CODE_MATCHING'
   WHERE id_season = v_season;

  INSERT INTO tbl_organizer (txt_code, txt_name)
    VALUES ('FTLXORG76', 'FTL export org 76') RETURNING id_organizer INTO v_org;
  v_ev := fn_create_event('FTLX76EVT', 'FTL export 76', v_season, v_org,
                          NULL, '2019-10-05', '2019-10-05');

  -- The one registrant who already has a ranking position.
  INSERT INTO tbl_fencer (txt_surname, txt_first_name, int_birth_year,
                          enum_gender, bool_birth_year_estimated)
    VALUES ('PGTAP76RANK', 'Robert', 1965, 'M', FALSE) RETURNING id_fencer INTO v_f;

  INSERT INTO tbl_tournament (id_event, txt_code, txt_name, enum_type,
                              enum_weapon, enum_gender, enum_age_category,
                              enum_import_status, num_multiplier, int_participant_count)
    VALUES (v_ev, 'FTLX76T', 'FTL export 76 tournament', 'PPW',
            'EPEE', 'M', 'V2', 'SCORED', 1.0, 8) RETURNING id_tournament INTO v_t;

  -- enum_source_age_category is set for the same reason as in test 75: it is
  -- the splitter's own path, so fn_assert_result_vcat returns early instead of
  -- demanding a BY-derived V-cat from a synthetic fixture.
  INSERT INTO tbl_result (id_fencer, id_tournament, int_place,
                          enum_fencer_age_category, enum_source_age_category,
                          num_final_score)
    VALUES (v_f, v_t, 1, 'V2', 'V2', 100.0);

  -- The entry list. ts_created is set explicitly: it is the tiebreak among
  -- unranked registrants, and a fixture that relied on insertion order would
  -- prove nothing about the ORDER BY.
  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name,
                                enum_gender, int_birth_year, arr_weapons, ts_created, txt_club)
  VALUES
    -- ranked, and entered LAST — so a result that merely preserved arrival
    -- order would put him third. Also the club fixture (76.4b/76.4c).
    (v_ev, v_f, 'PGTAP76RANK', 'Robert', 'M', 1965,
     ARRAY['EPEE', 'FOIL']::enum_weapon_type[], '2019-10-03T00:00:00Z', 'Klub Testowy 76'),
    -- unranked, entered second, no declared club
    (v_ev, NULL, 'PGTAP76LATE', 'Bogdan', 'M', 1965,
     ARRAY['EPEE']::enum_weapon_type[], '2019-10-02T00:00:00Z', NULL),
    -- unranked, entered first
    (v_ev, NULL, 'PGTAP76EARLY', 'Cezary', 'M', 1966,
     ARRAY['EPEE']::enum_weapon_type[], '2019-10-01T00:00:00Z', NULL),
    -- 25 years old in the 2019/20 season — not a veteran, no sub-ranking
    (v_ev, NULL, 'PGTAP76YOUNG', 'Damian', 'M', 1995,
     ARRAY['EPEE']::enum_weapon_type[], '2019-10-01T00:00:00Z', NULL),
    -- same weapon and category, different gender — a separate competition
    (v_ev, NULL, 'PGTAP76WOMAN', 'Ewa', 'F', 1965,
     ARRAY['EPEE']::enum_weapon_type[], '2019-10-01T00:00:00Z', NULL);

  -- The picker's own fixtures. FTLX76EVT above is in the PAST (2019), which is
  -- exactly the case 76.23 needs; the picker itself needs events that have not
  -- happened yet, so they get their own far-future season.
  v_fseason := fn_create_season('FTLX76F', '2098-09-01', '2099-06-30');
  v_fev := fn_create_event('FTLX76FEVT', 'FTL export 76 future', v_fseason, v_org,
                           NULL, '2099-01-15', '2099-01-15');
  PERFORM fn_create_event('FTLX76EMPTY', 'FTL export 76 empty', v_fseason, v_org,
                          NULL, '2099-02-15', '2099-02-15');

  INSERT INTO tbl_registration (id_event, id_fencer, txt_surname, txt_first_name,
                                enum_gender, int_birth_year, arr_weapons)
  VALUES
    (v_fev, NULL, 'PGTAP76FUT', 'Filip', 'M', 2045, ARRAY['EPEE']::enum_weapon_type[]),
    (v_fev, NULL, 'PGTAP76FUT2', 'Grzegorz', 'M', 2045, ARRAY['EPEE']::enum_weapon_type[]);

  INSERT INTO tbl_ftl_export_token (uuid_token, txt_label)
    VALUES ('76000000-0000-4000-8000-000000000001', 'pgTAP 76 live'),
           ('76000000-0000-4000-8000-000000000002', 'pgTAP 76 revoked');
  UPDATE tbl_ftl_export_token SET ts_revoked = now()
   WHERE uuid_token = '76000000-0000-4000-8000-000000000002';
END $setup$;

-- ---------------------------------------------------------------------------
-- Shape and posture
-- ---------------------------------------------------------------------------
SELECT has_function('fn_ftl_export_entries', ARRAY['integer', 'uuid'],
  '76.1 fn_ftl_export_entries(INT, UUID) exists');

SELECT is(
  (SELECT p.prosecdef FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_ftl_export_entries'),
  TRUE,
  '76.2 it is SECURITY DEFINER — the only way anon sees past tbl_registration RLS');

SELECT is(
  (SELECT p.provolatile FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_ftl_export_entries'),
  's'::"char",
  '76.3 it is STABLE — a read, and never a write');

SELECT ok(
  pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) NOT LIKE '%birth_year%'
  AND pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) NOT LIKE '%id_fencer%'
  AND pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) NOT LIKE '%id_registration%'
  AND pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) NOT LIKE '%uuid_edit_token%'
  AND pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) NOT LIKE '%email%',
  '76.4 the projection publishes no birth year, fencer id, registration id, edit token or e-mail hash');

-- 76.4b/76.4c — the declared club (2026-09-13, ADR-080 amendment (f)) IS part
-- of this projection, given or not.
SELECT ok(
  pg_get_function_result('fn_ftl_export_entries(integer,uuid)'::regprocedure) LIKE '%txt_club%',
  '76.4b the projection DOES publish txt_club — the organizer-only surface that widens for it');

SELECT is(
  (SELECT txt_club FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
   -- PGTAP76RANK declared two weapons (EPEE+FOIL), so scope to one row.
   WHERE txt_surname = 'PGTAP76RANK' AND enum_weapon = 'EPEE'),
  'Klub Testowy 76',
  '76.4c a declared club is returned verbatim');

SELECT is(
  (SELECT txt_club FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
   WHERE txt_surname = 'PGTAP76LATE'),
  NULL,
  '76.4d a registration with no declared club returns NULL, not an empty string');

SELECT ok(
  has_function_privilege('anon', 'fn_ftl_export_entries(integer,uuid)', 'EXECUTE'),
  '76.5 anon can call it — the download page is public and holds only the anon key');

SELECT ok(
  NOT has_function_privilege('anon', 'fn_ftl_export_use_rolling(integer)', 'EXECUTE'),
  '76.6 the rolling helper is NOT part of the public surface; it is reached only through the projection');

-- ---------------------------------------------------------------------------
-- Population
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)),
  5,
  '76.7 one row per declared weapon: 4 veterans on épée + Robert''s second weapon');

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE txt_surname = 'PGTAP76RANK'),
  2,
  '76.8 a registrant who declared two weapons appears once per weapon');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_entries(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
     WHERE txt_surname = 'PGTAP76YOUNG'$$,
  '76.9 a registrant below the veteran floor has no sub-ranking and is omitted');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_entries(-1, '76000000-0000-4000-8000-000000000001'::UUID)$$,
  '76.10 an unknown event yields no rows rather than an error');

-- ---------------------------------------------------------------------------
-- Order — the reason this function exists
-- ---------------------------------------------------------------------------
SELECT is(
  (SELECT array_agg(txt_surname ORDER BY int_order)
     FROM fn_ftl_export_entries(
       (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE enum_weapon = 'EPEE' AND enum_gender = 'M'),
  ARRAY['PGTAP76RANK', 'PGTAP76EARLY', 'PGTAP76LATE'],
  '76.11 ranked first, then the unranked in registration order');

SELECT is(
  (SELECT array_agg(int_order ORDER BY int_order)
     FROM fn_ftl_export_entries(
       (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE enum_weapon = 'EPEE' AND enum_gender = 'M'),
  ARRAY[1, 2, 3],
  '76.12 int_order is dense and one-based inside a sub-ranking');

SELECT is(
  (SELECT int_order FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE enum_weapon = 'EPEE' AND enum_gender = 'F'),
  1,
  '76.13 genders are never merged: the single woman is first in her own sub-ranking');

SELECT is(
  (SELECT int_order FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE enum_weapon = 'FOIL'),
  1,
  '76.14 and so is the one foil entry, ranked épéeist though he is');

SELECT is(
  (SELECT enum_age_category FROM fn_ftl_export_entries(
     (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'), '76000000-0000-4000-8000-000000000001'::UUID)
    WHERE txt_surname = 'PGTAP76EARLY'),
  'V2'::enum_age_category,
  '76.15 the category comes from the DECLARED birth year and the season end year');

-- ---------------------------------------------------------------------------
-- The rolling rule, named and tested on its own
-- ---------------------------------------------------------------------------
SELECT is(
  fn_ftl_export_use_rolling(
    (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT')),
  FALSE,
  '76.16 a finished season ranks on its own results, never carry-over');

SELECT is(
  (SELECT fn_ftl_export_use_rolling(e.id_event)
     FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season
    WHERE s.bool_active
    LIMIT 1),
  TRUE,
  '76.17 the live season ranks on carry-over — without this PPW1 seeds in form-fill order');

-- ---------------------------------------------------------------------------
-- The capability token.
--
-- ADR-090 §3 settled that administration stays on GitHub Pages and that a
-- sign-in modal is not reachable from a public page on the association's site,
-- so this surface cannot be protected by a login. It is protected by a
-- capability instead, checked HERE rather than in the page — the bundle is
-- public, so a check in JavaScript is decoration.
--
-- What the token defends is worth stating precisely, because it is easy to
-- overrate: every name, gender, weapon and age category this page shows is
-- ALREADY public through vw_registration_entry_list. The token keeps an
-- organizer-only tool off four hundred fencers' screens and gives us something
-- to rotate when a link goes astray. It is not the reason birth years are safe;
-- that is 76.4.
--
-- An absent, unknown or revoked token returns NO ROWS rather than raising. A
-- stale link should look empty, not broken, and an error would confirm to a
-- prober that they had found a real endpoint.
-- ---------------------------------------------------------------------------
SELECT has_function('fn_ftl_export_events', ARRAY['uuid'],
  '76.18 fn_ftl_export_events(UUID) exists');

SELECT ok(
  has_function_privilege('anon', 'fn_ftl_export_events(uuid)', 'EXECUTE'),
  '76.19 anon can call the picker — the page is public and holds only the anon key');

SELECT is(
  (SELECT count(*)::INT FROM fn_ftl_export_events('76000000-0000-4000-8000-000000000001')
    WHERE txt_code = 'FTLX76FEVT'),
  1,
  '76.20 a live token lists an event that has entries and has not happened yet');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_events(NULL)$$,
  '76.21 no token lists nothing at all');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_events('76000000-0000-4000-8000-0000000000ff')$$,
  '76.22 an unknown token lists nothing, and does not raise');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_events('76000000-0000-4000-8000-000000000002')$$,
  '76.23 a revoked token lists nothing — revocation is one UPDATE');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_entries(
      (SELECT id_event FROM tbl_event WHERE txt_code = 'FTLX76EVT'),
      '76000000-0000-4000-8000-0000000000ff')$$,
  '76.24 the entries projection is gated by the same token, not only the picker');

-- ---------------------------------------------------------------------------
-- What the picker shows, and for how long
-- ---------------------------------------------------------------------------
SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_events('76000000-0000-4000-8000-000000000001')
     WHERE txt_code = 'FTLX76EVT'$$,
  '76.25 an event whose end date has passed drops off the list, with no grace period');

SELECT is_empty(
  $$SELECT 1 FROM fn_ftl_export_events('76000000-0000-4000-8000-000000000001')
     WHERE txt_code = 'FTLX76EMPTY'$$,
  '76.26 an event nobody has entered is not listed — there would be nothing to download');

SELECT is(
  (SELECT int_registrations FROM fn_ftl_export_events('76000000-0000-4000-8000-000000000001')
    WHERE txt_code = 'FTLX76FEVT'),
  2,
  '76.27 the count beside an event is its registration count');

-- ---------------------------------------------------------------------------
-- The token table itself
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT c.relrowsecurity FROM pg_class c
     JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'tbl_ftl_export_token'),
  '76.28 the token table has RLS enabled; anon reads no row of it');

SELECT ok(
  NOT has_function_privilege('anon', 'fn_ftl_export_token_valid(uuid)', 'EXECUTE'),
  '76.29 the validator is not itself part of the public surface');

SELECT * FROM finish();
ROLLBACK;
