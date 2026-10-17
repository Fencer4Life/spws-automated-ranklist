-- =============================================================================
-- ROUTE.APPLY — promote fills a blank result slot on PROD (ADR-113)
-- =============================================================================
-- An international CERT run records every result slot it read (url_event …
-- url_event_5). Promote's plan reads exactly those on PROD, and the apply
-- writes slot 2-5 under ADR-086's fill-blank tier, as it writes url_event: a
-- blank slot takes the run's URL, an equal one stays, a different one
-- refuses, and only the five result slots are accepted. Everything rolls back.
-- =============================================================================

BEGIN;

SELECT plan(5);

INSERT INTO tbl_season (txt_code, dt_start, dt_end) VALUES ('SPWS-2093-2094', DATE '2093-09-01', DATE '2094-06-30');

INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, dt_start, dt_end, enum_status, url_event_2)
SELECT c, 'ROUTE.APPLY fixture', (SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2093-2094'),
       (SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), DATE '2093-10-10', DATE '2093-10-11',
       'PLANNED', u
  FROM (VALUES ('PPW7-2093-2094', NULL), ('PPW6-2093-2094', 'https://other.example/x')) v(c, u);

SELECT id_event AS ev7 FROM tbl_event WHERE txt_code = 'PPW7-2093-2094' \gset
SELECT id_event AS ev6 FROM tbl_event WHERE txt_code = 'PPW6-2093-2094' \gset
SELECT (fn_event_input_fingerprint('PPW7-2093-2094')->'parts')::TEXT AS inputs7 \gset
SELECT (fn_event_input_fingerprint('PPW6-2093-2094')->'parts')::TEXT AS inputs6 \gset

-- What each event holds once url_event is written (the slots are not part of
-- the result fingerprint; url_event is).
SAVEPOINT live;
UPDATE tbl_event SET url_event = 'https://a.example/s' WHERE id_event IN (:ev7, :ev6);
SELECT fn_event_result_fingerprint('PPW7-2093-2094') AS fp7 \gset
SELECT fn_event_result_fingerprint('PPW6-2093-2094') AS fp6 \gset
ROLLBACK TO SAVEPOINT live;

CREATE TEMP TABLE p (label TEXT PRIMARY KEY, j JSONB);
INSERT INTO p VALUES
  ('fill', jsonb_build_object('event_code', 'PPW7-2093-2094', 'ops', jsonb_build_array(
     jsonb_build_object('op', 'set_event_url_event', 'id_event', :ev7, 'url_event', 'https://a.example/s'),
     jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev7, 'slot', 'url_event_2',
                        'url_event', 'https://b.example/e')))),
  ('differs', jsonb_build_object('event_code', 'PPW6-2093-2094', 'ops', jsonb_build_array(
     jsonb_build_object('op', 'set_event_url_event', 'id_event', :ev6, 'url_event', 'https://a.example/s'),
     jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev6, 'slot', 'url_event_2',
                        'url_event', 'https://b.example/e')))),
  ('slot', jsonb_build_object('event_code', 'PPW6-2093-2094', 'ops', jsonb_build_array(
     jsonb_build_object('op', 'set_event_url_event', 'id_event', :ev6, 'url_event', 'https://a.example/s'),
     jsonb_build_object('op', 'set_event_source_url', 'id_event', :ev6, 'slot', 'txt_name',
                        'url_event', 'https://b.example/e'))));

SELECT lives_ok(format($$SELECT fn_promote_event_apply('PPW7-2093-2094', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', FALSE)$$,
                       (SELECT j FROM p WHERE label = 'fill'), :'fp7', :'inputs7'),
  'ROUTE.APPLY.01 a plan that fills a result slot applies');

SELECT is((SELECT url_event_2 FROM tbl_event WHERE id_event = :ev7), 'https://b.example/e',
  'ROUTE.APPLY.02 a blank slot takes the CERT run''s URL');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW6-2093-2094', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'differs'), :'fp6', :'inputs6'),
  'PROMOTE_URL_DIFFERS%url_event_2%',
  'ROUTE.APPLY.03 a different slot refuses, and nothing is written');

SELECT is((SELECT url_event FROM tbl_event WHERE id_event = :ev6), NULL,
  'ROUTE.APPLY.04 the refused apply left url_event as it was');

SELECT throws_like(format($$SELECT fn_promote_event_apply('PPW6-2093-2094', %L::JSONB, %L, %L::JSONB, NULL, 'IN_PROGRESS', FALSE)$$,
                          (SELECT j FROM p WHERE label = 'slot'), :'fp6', :'inputs6'),
  'PROMOTE_PLAN_SLOT%',
  'ROUTE.APPLY.05 only the five result slots are written');

SELECT * FROM finish();
ROLLBACK;
