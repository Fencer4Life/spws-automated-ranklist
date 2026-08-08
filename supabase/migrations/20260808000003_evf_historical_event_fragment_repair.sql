-- =============================================================================
-- Reviewed historical repair: fragmented 2025-2026 EVF physical events.
--
-- Approved scope:
--   * preserve PEW62 as Guildford; never reflow the complete season;
--   * consolidate source-verified physical-event fragments;
--   * delete only the named donors after all children have moved;
--   * assign or transfer no Guildford id_prior_event.
--
-- Original scoring-provider facts are authoritative. FencingWorldwide remains
-- public for Munich. Fencing Time Live is currently login-walled and the EVF
-- results API has no 2026 Guildford row, so the user explicitly approved the
-- stored full-field fragments as fallback evidence for Guildford, Faches and
-- the misplaced March 2025 result. Their exact input counts are pinned below.
-- =============================================================================

CREATE FUNCTION pg_temp.merge_evf_fragment_slots(
  p_survivor_code TEXT,
  p_member_codes TEXT[],
  p_result_url TEXT,
  p_delete_empty_members BOOLEAN DEFAULT TRUE
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_survivor_id INT;
  v_member_count INT;
  v_slot RECORD;
  v_winner_id INT;
  v_loser RECORD;
  v_desired_code TEXT;
  v_candidate_count_before INT;
  v_candidate_count_after INT;
  v_candidate_duplicates INT := 0;
  v_deleted_candidates INT;
  v_base TEXT := regexp_replace(p_survivor_code, '-[0-9]{4}-[0-9]{4}$', '');
  v_season TEXT := substring(p_survivor_code FROM '([0-9]{4}-[0-9]{4})$');
BEGIN
  SELECT COUNT(*)::INT INTO v_member_count
    FROM tbl_event WHERE txt_code = ANY(p_member_codes);

  -- LOCAL reset applies migrations before loading the already-corrected seed.
  IF v_member_count = 0 THEN RETURN; END IF;
  IF v_member_count <> cardinality(p_member_codes) THEN
    RAISE EXCEPTION 'EVF repair % expected % members, found %',
      p_survivor_code, cardinality(p_member_codes), v_member_count;
  END IF;

  SELECT id_event INTO STRICT v_survivor_id
    FROM tbl_event WHERE txt_code = p_survivor_code;

  IF EXISTS (
    SELECT 1 FROM tbl_registration reg JOIN tbl_event e ON e.id_event=reg.id_event
     WHERE e.txt_code=ANY(p_member_codes)
  ) THEN
    RAISE EXCEPTION 'EVF repair refuses registrations in %', p_member_codes;
  END IF;

  SELECT COUNT(*)::INT INTO v_candidate_count_before
    FROM tbl_match_candidate mc
    JOIN tbl_result r ON r.id_result=mc.id_result
    JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
    JOIN tbl_event e ON e.id_event=t.id_event
   WHERE e.txt_code=ANY(p_member_codes);

  FOR v_slot IN
    SELECT DISTINCT t.enum_weapon,t.enum_gender,t.enum_age_category
      FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
     WHERE e.txt_code=ANY(p_member_codes)
     ORDER BY 1,2,3
  LOOP
    -- Within the exact reviewed baseline, the largest field is the approved
    -- full-source/fallback scrape. Ties keep the selected survivor.
    SELECT t.id_tournament INTO STRICT v_winner_id
      FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
     WHERE e.txt_code=ANY(p_member_codes)
       AND t.enum_weapon=v_slot.enum_weapon
       AND t.enum_gender=v_slot.enum_gender
       AND t.enum_age_category=v_slot.enum_age_category
     ORDER BY COALESCE(t.int_participant_count,-1) DESC,
              (e.id_event=v_survivor_id) DESC,
              t.id_tournament
     LIMIT 1;

    FOR v_loser IN
      SELECT t.id_tournament,t.int_participant_count
        FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
       WHERE e.txt_code=ANY(p_member_codes)
         AND t.enum_weapon=v_slot.enum_weapon
         AND t.enum_gender=v_slot.enum_gender
         AND t.enum_age_category=v_slot.enum_age_category
         AND t.id_tournament<>v_winner_id
       ORDER BY t.id_tournament
    LOOP
      IF EXISTS (
        SELECT 1 FROM tbl_result losing
        JOIN tbl_result winning ON winning.id_tournament=v_winner_id
                               AND winning.id_fencer=losing.id_fencer
        JOIN tbl_tournament winner_t ON winner_t.id_tournament=v_winner_id
        WHERE losing.id_tournament=v_loser.id_tournament
          AND COALESCE(winner_t.int_participant_count,-1)=COALESCE(v_loser.int_participant_count,-1)
          AND winning.int_place IS DISTINCT FROM losing.int_place
      ) THEN
        RAISE EXCEPTION 'unapproved equal-field conflict in %/%/%',
          v_slot.enum_weapon,v_slot.enum_gender,v_slot.enum_age_category;
      END IF;

      -- A legacy AUTO_MATCHED candidate is provenance for its result. The
      -- schema permits only one (result,scraped-name) pair, so an identical
      -- pair on both duplicate results must collapse before re-pointing. Any
      -- semantic disagreement is unreviewed and aborts the whole repair.
      IF EXISTS (
        SELECT 1
          FROM tbl_result losing
          JOIN tbl_match_candidate losing_mc ON losing_mc.id_result=losing.id_result
          JOIN tbl_result winning ON winning.id_tournament=v_winner_id
                                 AND winning.id_fencer=losing.id_fencer
          JOIN tbl_match_candidate winning_mc ON winning_mc.id_result=winning.id_result
                                             AND winning_mc.txt_scraped_name=losing_mc.txt_scraped_name
         WHERE losing.id_tournament=v_loser.id_tournament
           AND (winning_mc.id_fencer IS DISTINCT FROM losing_mc.id_fencer
             OR winning_mc.num_confidence IS DISTINCT FROM losing_mc.num_confidence
             OR winning_mc.enum_status IS DISTINCT FROM losing_mc.enum_status
             OR winning_mc.txt_admin_note IS DISTINCT FROM losing_mc.txt_admin_note)
      ) THEN
        RAISE EXCEPTION 'unapproved match-candidate conflict in %/%/%',
          v_slot.enum_weapon,v_slot.enum_gender,v_slot.enum_age_category;
      END IF;

      DELETE FROM tbl_match_candidate losing_mc
        USING tbl_result losing,tbl_result winning,tbl_match_candidate winning_mc
       WHERE losing.id_tournament=v_loser.id_tournament
         AND winning.id_tournament=v_winner_id
         AND winning.id_fencer=losing.id_fencer
         AND losing_mc.id_result=losing.id_result
         AND winning_mc.id_result=winning.id_result
         AND winning_mc.txt_scraped_name=losing_mc.txt_scraped_name;
      GET DIAGNOSTICS v_deleted_candidates = ROW_COUNT;
      v_candidate_duplicates := v_candidate_duplicates+v_deleted_candidates;

      UPDATE tbl_match_candidate mc SET id_result=winning.id_result,ts_updated=NOW()
        FROM tbl_result losing,tbl_result winning
       WHERE losing.id_tournament=v_loser.id_tournament
         AND winning.id_tournament=v_winner_id
         AND winning.id_fencer=losing.id_fencer
         AND mc.id_result=losing.id_result;

      DELETE FROM tbl_result losing USING tbl_result winning
       WHERE losing.id_tournament=v_loser.id_tournament
         AND winning.id_tournament=v_winner_id
         AND winning.id_fencer=losing.id_fencer;

      UPDATE tbl_result SET id_tournament=v_winner_id,ts_updated=NOW()
       WHERE id_tournament=v_loser.id_tournament;
      DELETE FROM tbl_tournament WHERE id_tournament=v_loser.id_tournament;
    END LOOP;

    v_desired_code := format('%s-%s-%s-%s-%s',v_base,
      v_slot.enum_age_category::TEXT,v_slot.enum_gender::TEXT,
      v_slot.enum_weapon::TEXT,v_season);
    IF EXISTS (SELECT 1 FROM tbl_tournament
                WHERE txt_code=v_desired_code AND id_tournament<>v_winner_id) THEN
      RAISE EXCEPTION 'EVF repair child-code collision: %',v_desired_code;
    END IF;

    UPDATE tbl_tournament SET id_event=v_survivor_id,txt_code=v_desired_code,
      url_results=COALESCE(p_result_url,url_results),ts_updated=NOW()
     WHERE id_tournament=v_winner_id;
  END LOOP;

  IF p_delete_empty_members THEN
    IF EXISTS (
      SELECT 1 FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
       WHERE e.txt_code=ANY(p_member_codes) AND e.id_event<>v_survivor_id
    ) THEN
      RAISE EXCEPTION 'EVF repair left donor children in %',p_member_codes;
    END IF;
    DELETE FROM tbl_event WHERE txt_code=ANY(p_member_codes) AND id_event<>v_survivor_id;
  END IF;

  SELECT COUNT(*)::INT INTO v_candidate_count_after
    FROM tbl_match_candidate mc
    JOIN tbl_result r ON r.id_result=mc.id_result
    JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
   WHERE t.id_event=v_survivor_id;
  IF v_candidate_count_after<>v_candidate_count_before-v_candidate_duplicates THEN
    RAISE EXCEPTION 'EVF repair candidate conservation failed for %: expected % minus % exact duplicates, found %',
      p_survivor_code,v_candidate_count_before,v_candidate_duplicates,v_candidate_count_after;
  END IF;
END;
$$;

DO $repair$
DECLARE
  v_present INT;
  v_expected_ok INT;
  v_tid INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('SPWS EVF historical fragment repair 2025-2026'));

  SELECT COUNT(*)::INT INTO v_present FROM tbl_event
   WHERE txt_code=ANY(ARRAY[
     'PEW3s-2025-2026','PEW21fs-2025-2026','PEW31fs-2025-2026',
     'PEW5s-2025-2026','PEW65ef-2025-2026','PEW62efs-2025-2026',
     'PEW63e-2025-2026','PEW64s-2025-2026','PEW66f-2025-2026',
     'PEW67f-2025-2026','PEW8f-2025-2026','PEW8f-2024-2025'
   ]);
  IF v_present=0 THEN RETURN; END IF;

  WITH expected(txt_code,tournaments,results) AS (VALUES
    ('PEW3s-2025-2026',3,6),('PEW21fs-2025-2026',8,7),
    ('PEW31fs-2025-2026',5,1),('PEW5s-2025-2026',1,1),
    ('PEW65ef-2025-2026',5,10),('PEW62efs-2025-2026',9,24),
    ('PEW63e-2025-2026',1,2),('PEW64s-2025-2026',2,10),
    ('PEW66f-2025-2026',3,4),('PEW67f-2025-2026',4,17),
    ('PEW8f-2025-2026',1,1),('PEW8f-2024-2025',7,20)
  ), actual AS (
    SELECT e.txt_code,COUNT(DISTINCT t.id_tournament)::INT tournaments,
           COUNT(r.id_result)::INT results
      FROM tbl_event e LEFT JOIN tbl_tournament t ON t.id_event=e.id_event
      LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
     WHERE e.txt_code IN (SELECT txt_code FROM expected)
     GROUP BY e.txt_code
  )
  SELECT COUNT(*)::INT INTO v_expected_ok FROM expected x JOIN actual a USING(txt_code)
   WHERE x.tournaments=a.tournaments AND x.results=a.results;
  IF v_expected_ok<>12 THEN
    RAISE EXCEPTION 'EVF repair baseline mismatch: expected 12 exact rows, found %',v_expected_ok;
  END IF;

  -- Guildford: retain PEW62 and absorb PEW63/64/66/67. The approved fallback
  -- chooses the full-field tournament for overlapping slots.
  PERFORM pg_temp.merge_evf_fragment_slots(
    'PEW62efs-2025-2026',
    ARRAY['PEW62efs-2025-2026','PEW63e-2025-2026','PEW64s-2025-2026',
          'PEW66f-2025-2026','PEW67f-2025-2026'],
    'https://www.fencingtimelive.com/tournaments/eventSchedule/E2A7B077F2824DD8A7F2E413B4211296#today',TRUE
  );
  UPDATE tbl_tournament SET dt_tournament=CASE enum_weapon
    WHEN 'EPEE'::enum_weapon_type THEN DATE '2026-01-10'
    ELSE DATE '2026-01-11' END
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW62efs-2025-2026');
  UPDATE tbl_event SET
    txt_name='EVF Circuit – Guildford (GBR)',txt_location='Guildford',
    txt_country='Great Britain',dt_start=DATE '2026-01-10',dt_end=DATE '2026-01-11',
    arr_weapons=ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[],
    url_event='https://www.veteransfencing.eu/event/evf-circuit-guildford-gbr/',
    txt_evf_slug='evf-circuit-guildford-gbr',
    txt_venue_address='Parkway, Guildford, United Kingdom',
    url_invitation='https://www.veteransfencing.eu/wp-content/uploads/2025/10/EVf-Guildford-2026-invitation-letter.pdf',
    ts_updated=NOW()
   WHERE txt_code='PEW62efs-2025-2026';

  -- Munich: merge first, then replace every retained result with the public
  -- FencingWorldwide classification and field size. KOŃCZYŁO is absent from
  -- the original category and is therefore not retained.
  PERFORM pg_temp.merge_evf_fragment_slots(
    'PEW3s-2025-2026',ARRAY['PEW3s-2025-2026','PEW21fs-2025-2026'],NULL,TRUE
  );
  DELETE FROM tbl_result r USING tbl_tournament t,tbl_fencer f
   WHERE r.id_tournament=t.id_tournament AND r.id_fencer=f.id_fencer
     AND t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW3s-2025-2026')
     AND f.txt_surname='KOŃCZYŁO' AND f.txt_first_name='Tomasz';

  WITH official(surname,first_name,weapon,gender,age_category,place,field_size,competition_id,held_on) AS (VALUES
    ('GINZERY','Tomas','FOIL'::enum_weapon_type,'M'::enum_gender_type,'V1'::enum_age_category,5,17,'903539',DATE '2025-12-07'),
    ('ZYLKA','Henryk','FOIL','M','V4',1,12,'903542',DATE '2025-12-06'),
    ('GANSZCZYK','Marcin','SABRE','M','V2',6,25,'912306',DATE '2025-12-06'),
    ('NOWICKI','Robert','SABRE','M','V2',9,25,'912306',DATE '2025-12-06'),
    ('CHIAROMONTE','Francesco','SABRE','M','V2',8,25,'912306',DATE '2025-12-06'),
    ('GAJDA','Leszek','SABRE','M','V3',7,22,'912307',DATE '2025-12-07'),
    ('FUHRMANN','Ulrike','SABRE','F','V3',5,11,'912303',DATE '2025-12-06')
  )
  UPDATE tbl_result r SET int_place=o.place,ts_updated=NOW()
   FROM tbl_tournament t,tbl_fencer f,official o
   WHERE r.id_tournament=t.id_tournament AND r.id_fencer=f.id_fencer
     AND t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW3s-2025-2026')
     AND f.txt_surname=o.surname AND f.txt_first_name=o.first_name
     AND t.enum_weapon=o.weapon AND t.enum_gender=o.gender AND t.enum_age_category=o.age_category;

  WITH slots(weapon,gender,age_category,field_size,competition_id,held_on) AS (VALUES
    ('FOIL'::enum_weapon_type,'M'::enum_gender_type,'V1'::enum_age_category,17,'903539',DATE '2025-12-07'),
    ('FOIL','M','V2',0,'903540',DATE '2025-12-07'),
    ('FOIL','M','V4',12,'903542',DATE '2025-12-06'),
    ('FOIL','F','V2',0,'903536',DATE '2025-12-06'),
    ('SABRE','M','V2',25,'912306',DATE '2025-12-06'),
    ('SABRE','M','V3',22,'912307',DATE '2025-12-07'),
    ('SABRE','F','V2',0,'912301',DATE '2025-12-07'),
    ('SABRE','F','V3',11,'912303',DATE '2025-12-06')
  )
  UPDATE tbl_tournament t SET int_participant_count=s.field_size,
    dt_tournament=s.held_on,
    url_results=format('https://www.fencingworldwide.com/en/%s-2025/results/',s.competition_id),
    ts_updated=NOW()
   FROM slots s WHERE t.id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW3s-2025-2026')
    AND t.enum_weapon=s.weapon AND t.enum_gender=s.gender AND t.enum_age_category=s.age_category;

  UPDATE tbl_event SET txt_code='PEW3fs-2025-2026',
    txt_name='EVF Circuit Memoriam Max Geuter – Munich (GER)',txt_location='Munich',
    txt_country='Germany',dt_start=DATE '2025-12-06',dt_end=DATE '2025-12-07',
    arr_weapons=ARRAY['FOIL','SABRE']::enum_weapon_type[],
    url_event='https://www.veteransfencing.eu/event/evf-circuit-munich/',
    txt_evf_slug='evf-circuit-munich',txt_venue_address='Riesstrasse 40, Munich, Germany',
    url_invitation='https://www.veteransfencing.eu/wp-content/uploads/2025/10/Ausschreibung-englisch-5.8.25.pdf',
    ts_updated=NOW() WHERE txt_code='PEW3s-2025-2026';
  UPDATE tbl_tournament SET txt_code=regexp_replace(txt_code,'^PEW3s-','PEW3fs-')
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW3fs-2025-2026');

  -- Faches: the PEW5 tournament is the approved full-field fallback. Move it
  -- into PEW31 but keep the now-empty PEW5 event identity for Stockholm.
  PERFORM pg_temp.merge_evf_fragment_slots(
    'PEW31fs-2025-2026',ARRAY['PEW31fs-2025-2026','PEW5s-2025-2026'],NULL,FALSE
  );
  UPDATE tbl_tournament SET dt_tournament=CASE enum_weapon
    WHEN 'FOIL'::enum_weapon_type THEN DATE '2026-02-07'
    ELSE DATE '2026-02-08' END
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW31fs-2025-2026');
  UPDATE tbl_event SET dt_start=DATE '2026-02-07',dt_end=DATE '2026-02-08',
    arr_weapons=ARRAY['FOIL','SABRE']::enum_weapon_type[],ts_updated=NOW()
   WHERE txt_code='PEW31fs-2025-2026';

  -- Stockholm: reuse the emptied PEW5 row and absorb the PEW65 fragment.
  PERFORM pg_temp.merge_evf_fragment_slots(
    'PEW5s-2025-2026',ARRAY['PEW5s-2025-2026','PEW65ef-2025-2026'],
    'https://engarde-service.com/tournament/sthlm/vet2026',TRUE
  );
  UPDATE tbl_tournament SET dt_tournament=DATE '2026-03-14'
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW5s-2025-2026');
  UPDATE tbl_event SET txt_code='PEW5ef-2025-2026',
    txt_name='EVF Circuit – Stockholm (SWE)',txt_location='Stockholm',txt_country='Sweden',
    dt_start=DATE '2026-03-14',dt_end=DATE '2026-03-14',
    arr_weapons=ARRAY['EPEE','FOIL']::enum_weapon_type[],
    url_event='https://www.veteransfencing.eu/event/evf-circuit-stockholm-swe/',
    txt_evf_slug='evf-circuit-stockholm-swe',ts_updated=NOW()
   WHERE txt_code='PEW5s-2025-2026';
  UPDATE tbl_tournament SET txt_code=regexp_replace(txt_code,'^PEW5s-','PEW5ef-')
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW5ef-2025-2026');

  -- The Chania row contains one result from March 2025. Merge it into the
  -- existing prior-season foil slot using the approved full-field fallback,
  -- but retain and correct the now-empty Chania calendar row.
  PERFORM pg_temp.merge_evf_fragment_slots(
    'PEW8f-2024-2025',ARRAY['PEW8f-2024-2025','PEW8f-2025-2026'],NULL,FALSE
  );
  UPDATE tbl_tournament SET dt_tournament=DATE '2025-03-30'
   WHERE id_event=(SELECT id_event FROM tbl_event WHERE txt_code='PEW8f-2024-2025')
     AND enum_weapon='FOIL' AND enum_gender='F' AND enum_age_category='V1';
  UPDATE tbl_event SET txt_code='PEW8es-2025-2026',
    txt_name='EVF Circuit – Chania (GRE)',txt_location='Chania',txt_country='Greece',
    dt_start=DATE '2026-05-02',dt_end=DATE '2026-05-03',
    arr_weapons=ARRAY['EPEE','SABRE']::enum_weapon_type[],
    url_event='https://www.veteransfencing.eu/event/evf-circuit-athens-gre/',
    txt_evf_slug='evf-circuit-athens-gre',ts_updated=NOW()
   WHERE txt_code='PEW8f-2025-2026';

  -- Recompute only the affected scored tournaments after official/fallback
  -- places and full field sizes have been finalized.
  FOR v_tid IN
    SELECT DISTINCT t.id_tournament FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
     WHERE e.txt_code IN ('PEW62efs-2025-2026','PEW3fs-2025-2026',
                          'PEW31fs-2025-2026','PEW5ef-2025-2026','PEW8f-2024-2025')
       AND COALESCE(t.int_participant_count,0)>0
       AND EXISTS(SELECT 1 FROM tbl_result r WHERE r.id_tournament=t.id_tournament)
  LOOP
    PERFORM fn_calc_tournament_scores(v_tid);
  END LOOP;

  IF (SELECT COUNT(*) FROM tbl_event WHERE txt_code IN (
    'PEW21fs-2025-2026','PEW63e-2025-2026','PEW64s-2025-2026',
    'PEW65ef-2025-2026','PEW66f-2025-2026','PEW67f-2025-2026'))<>0 THEN
    RAISE EXCEPTION 'EVF repair left donor events behind';
  END IF;
  IF (SELECT COUNT(*) FROM tbl_tournament t JOIN tbl_event e ON e.id_event=t.id_event
       WHERE e.txt_code='PEW62efs-2025-2026')<>16
     OR (SELECT COUNT(*) FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
         JOIN tbl_event e ON e.id_event=t.id_event WHERE e.txt_code='PEW62efs-2025-2026')<>52 THEN
    RAISE EXCEPTION 'EVF repair Guildford conservation check failed';
  END IF;
  IF (SELECT COUNT(*) FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
       JOIN tbl_event e ON e.id_event=t.id_event WHERE e.txt_code='PEW3fs-2025-2026')<>7 THEN
    RAISE EXCEPTION 'EVF repair Munich source-verification check failed';
  END IF;
END;
$repair$;
