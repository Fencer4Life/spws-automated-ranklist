-- =============================================================================
-- EVF chronological renumbering must move rolling links by event series,
-- never by the current-season numeric slot being occupied.
-- =============================================================================

BEGIN;
SELECT plan(5);

DO $setup$
DECLARE
  v_org INT;
  v_prior_season INT;
  v_current_season INT;
  v_wrong_prior INT;
  v_guildford_prior INT;
  v_chania_prior INT;
BEGIN
  UPDATE tbl_season SET bool_active = FALSE;
  v_prior_season := fn_create_season('EVFPRIOR-PRIOR', '2037-08-01', '2038-07-15');
  v_current_season := fn_create_season('EVFPRIOR-CURR', '2038-08-01', '2039-07-15');
  SELECT id_organizer INTO v_org FROM tbl_organizer WHERE txt_code = 'EVF';

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status
  ) VALUES (
    v_prior_season, v_org, 'PEW1e-EVFPRIOR-PRIOR', 'EVF Circuit Wrong City',
    '2038-01-01', '2038-01-02', 'Wrong City', 'France', 'COMPLETED'
  ) RETURNING id_event INTO v_wrong_prior;

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status
  ) VALUES (
    v_prior_season, v_org, 'PEW9efs-EVFPRIOR-PRIOR', 'EVF Circuit Guildford',
    '2038-02-01', '2038-02-02', 'Guildford', 'Great Britain', 'COMPLETED'
  ) RETURNING id_event INTO v_guildford_prior;

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status
  ) VALUES (
    v_prior_season, v_org, 'PEW2es-EVFPRIOR-PRIOR', 'EVF Circuit Chania',
    '2038-03-01', '2038-03-02', 'Chania', 'Greece', 'COMPLETED'
  ) RETURNING id_event INTO v_chania_prior;

  -- The desired chronological slot points to the wrong prior event. A second
  -- inherited skeleton carries Guildford's real rolling link.
  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, txt_location, txt_country,
    enum_status, id_prior_event
  ) VALUES
    (v_current_season, v_org, 'PEW1e-EVFPRIOR-CURR', 'Wrong numbered skeleton',
     'Wrong City', 'France', 'CREATED', v_wrong_prior),
    (v_current_season, v_org, 'PEW8f-EVFPRIOR-CURR', 'Chania link carrier',
     'Chania', 'Greece', 'CREATED', v_chania_prior),
    (v_current_season, v_org, 'PEW2es-EVFPRIOR-CURR', 'Athens numbered skeleton',
     'Athens', 'Greece', 'CREATED', NULL),
    (v_current_season, v_org, 'PEW9efs-EVFPRIOR-CURR', 'Guildford link carrier',
     'Guildford', 'Great Britain', 'CREATED', v_guildford_prior);

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status, txt_evf_slug
  ) VALUES (
    v_current_season, v_org, 'PEW70e-EVFPRIOR-CURR', 'EVF Circuit – Guildford (GBR)',
    '2039-01-09', '2039-01-10', 'Guildford Spectrum', 'Great Britain',
    'PLANNED', 'guildford-prior-link-regression'
  );

  INSERT INTO tbl_event (
    id_season, id_organizer, txt_code, txt_name, dt_start, dt_end,
    txt_location, txt_country, enum_status, txt_evf_slug
  ) VALUES (
    v_current_season, v_org, 'PEW71es-EVFPRIOR-CURR', 'EVF Circuit – Athens (GRE)',
    '2039-05-22', '2039-05-23', 'Athens', 'Greece',
    'PLANNED', 'athens-new-target-regression'
  );
END;
$setup$;

SELECT lives_ok(
  $$ SELECT fn_ingest_evf_calendar(
       '[{"name":"EVF Circuit – Guildford (GBR)","dt_start":"2039-01-09","dt_end":"2039-01-10","location":"Guildford Spectrum","country":"Great Britain","weapons":["EPEE"],"evf_calendar_id":2113,"evf_slug":"guildford-prior-link-regression","desired_code":"PEW1e-EVFPRIOR-CURR","existing_id_event":null},{"name":"EVF Circuit – Athens (GRE)","dt_start":"2039-05-22","dt_end":"2039-05-23","location":"Athens","country":"Greece","weapons":["EPEE","SABRE"],"evf_calendar_id":3438,"evf_slug":"athens-new-target-regression","desired_code":"PEW2es-EVFPRIOR-CURR","existing_id_event":null}]'::JSONB,
       (SELECT id_season FROM tbl_season WHERE txt_code = 'EVFPRIOR-CURR'), 2
     ) $$,
  '54.1: chronological renumber survives a wrong prior link on the desired slot'
);

SELECT is(
  (SELECT prior.txt_name FROM tbl_event current_event
    JOIN tbl_event prior ON prior.id_event = current_event.id_prior_event
    WHERE current_event.id_evf_calendar_event = 2113),
  'EVF Circuit Guildford',
  '54.2: Guildford receives the Guildford prior-season rolling link'
);

SELECT is(
  (SELECT COUNT(*)::INT FROM tbl_event current_event
    JOIN tbl_event prior ON prior.id_event = current_event.id_prior_event
    WHERE current_event.id_season = (
      SELECT id_season FROM tbl_season WHERE txt_code = 'EVFPRIOR-CURR'
    ) AND prior.txt_name = 'EVF Circuit Wrong City'),
  0,
  '54.3: chronological slot number never transfers the wrong geographic link'
);

SELECT is(
  (SELECT id_prior_event FROM tbl_event WHERE txt_code = 'PEW9efs-EVFPRIOR-CURR'),
  NULL::INT,
  '54.4: the inherited Guildford carrier relinquishes its link to the real event'
);

SELECT is(
  (SELECT prior.txt_name FROM tbl_event current_event
    JOIN tbl_event prior ON prior.id_event = current_event.id_prior_event
    WHERE current_event.id_evf_calendar_event = 3438),
  'EVF Circuit Chania',
  '54.5: Athens receives Chania after its unrelated-number carrier relinquishes the link'
);

SELECT * FROM finish();
ROLLBACK;
