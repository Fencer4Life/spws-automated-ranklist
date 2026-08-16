-- =============================================================================
-- Reviewed predecessor-season EVF repair: six physical events fragmented by
-- weapon across thirteen rows. Preserve the lowest established PEW number,
-- move all children losslessly, delete only seven named empty donors, and do
-- not reflow either historical season or infer any prior-event relationship.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_merge_predecessor_evf_event(
  p_survivor_code TEXT,
  p_member_codes TEXT[],
  p_final_code TEXT,
  p_name TEXT,
  p_location TEXT,
  p_country TEXT,
  p_start DATE,
  p_end DATE,
  p_weapons enum_weapon_type[],
  p_expected_tournaments INT,
  p_expected_results INT
) RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_survivor_id INT;
  v_member_count INT;
  v_tournaments INT;
  v_results INT;
  v_candidates INT;
  v_candidates_after INT;
  v_final_base TEXT := regexp_replace(p_final_code,'-[0-9]{4}-[0-9]{4}$','');
BEGIN
  SELECT COUNT(*)::INT INTO v_member_count
    FROM tbl_event WHERE txt_code=ANY(p_member_codes);
  IF v_member_count<>cardinality(p_member_codes) THEN
    RAISE EXCEPTION 'predecessor EVF repair % expected % members, found %',
      p_final_code,cardinality(p_member_codes),v_member_count;
  END IF;

  SELECT id_event INTO STRICT v_survivor_id
    FROM tbl_event WHERE txt_code=p_survivor_code;

  IF EXISTS (
    SELECT 1 FROM tbl_registration reg JOIN tbl_event e ON e.id_event=reg.id_event
     WHERE e.txt_code=ANY(p_member_codes)
  ) THEN
    RAISE EXCEPTION 'predecessor EVF repair refuses registrations in %',p_member_codes;
  END IF;

  SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT,
         COUNT(DISTINCT mc.id_match)::INT
    INTO v_tournaments,v_results,v_candidates
    FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
    LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
    LEFT JOIN tbl_match_candidate mc ON mc.id_result=r.id_result
   WHERE e.txt_code=ANY(p_member_codes);
  IF v_tournaments<>p_expected_tournaments OR v_results<>p_expected_results THEN
    RAISE EXCEPTION 'predecessor EVF repair baseline mismatch for %: tournaments %, results %, candidates %',
      p_final_code,v_tournaments,v_results,v_candidates;
  END IF;

  IF EXISTS (
    SELECT 1 FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
     WHERE e.txt_code=ANY(p_member_codes)
     GROUP BY t.enum_weapon,t.enum_gender,t.enum_age_category HAVING COUNT(*)>1
  ) THEN
    RAISE EXCEPTION 'predecessor EVF repair overlapping sporting slot in %',p_member_codes;
  END IF;

  IF EXISTS (
    SELECT 1 FROM tbl_event e JOIN tbl_tournament t ON t.id_event=e.id_event
     WHERE e.txt_code=ANY(p_member_codes)
       AND EXISTS (SELECT 1 FROM tbl_tournament collision
         WHERE collision.txt_code=regexp_replace(t.txt_code,'^[^-]+-',v_final_base||'-')
           AND collision.id_tournament<>t.id_tournament)
  ) THEN
    RAISE EXCEPTION 'predecessor EVF repair child-code collision for %',p_final_code;
  END IF;

  UPDATE tbl_tournament t SET
    id_event=v_survivor_id,
    txt_code=regexp_replace(t.txt_code,'^[^-]+-',v_final_base||'-'),
    ts_updated=NOW()
   FROM tbl_event e
   WHERE t.id_event=e.id_event AND e.txt_code=ANY(p_member_codes);

  DELETE FROM tbl_event
   WHERE txt_code=ANY(p_member_codes) AND id_event<>v_survivor_id;

  UPDATE tbl_event SET
    txt_code=p_final_code,
    txt_name=p_name,
    txt_location=p_location,
    txt_country=p_country,
    dt_start=p_start,
    dt_end=p_end,
    arr_weapons=p_weapons,
    ts_updated=NOW()
   WHERE id_event=v_survivor_id;

  SELECT COUNT(DISTINCT t.id_tournament)::INT,COUNT(r.id_result)::INT,
         COUNT(DISTINCT mc.id_match)::INT
    INTO v_tournaments,v_results,v_candidates_after
    FROM tbl_tournament t LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
    LEFT JOIN tbl_match_candidate mc ON mc.id_result=r.id_result
   WHERE t.id_event=v_survivor_id;
  IF v_tournaments<>p_expected_tournaments OR v_results<>p_expected_results
     OR v_candidates_after<>v_candidates THEN
    RAISE EXCEPTION 'predecessor EVF repair conservation failure for %: tournaments %, results %, candidates % -> %',
      p_final_code,v_tournaments,v_results,v_candidates,v_candidates_after;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fn_repair_evf_predecessor_fragments()
RETURNS VOID
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old_present INT;
  v_final_present INT;
  v_expected_ok INT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('SPWS EVF predecessor fragment repair'));

  SELECT COUNT(*)::INT INTO v_old_present FROM tbl_event WHERE txt_code=ANY(ARRAY[
    'PEW5fs-2023-2024','PEW21e-2023-2024','PEW8fs-2023-2024','PEW24e-2023-2024',
    'PEW9e-2023-2024','PEW11f-2023-2024','PEW4f-2024-2025','PEW11e-2024-2025',
    'PEW6fs-2024-2025','PEW12e-2024-2025','PEW7s-2024-2025',
    'PEW14e-2024-2025']);
  SELECT COUNT(*)::INT INTO v_final_present FROM tbl_event WHERE txt_code=ANY(ARRAY[
    'PEW5efs-2023-2024','PEW8efs-2023-2024','PEW9ef-2023-2024',
    'PEW4ef-2024-2025','PEW6efs-2024-2025','PEW7es-2024-2025']);

  -- Migrations run before the canonical seed on LOCAL reset. A fully repaired
  -- seed also reaches this branch on repeat application.
  IF v_old_present=0 THEN
    IF v_final_present IN (0,6) THEN RETURN; END IF;
    RAISE EXCEPTION 'predecessor EVF repair found partial repaired state: % final rows',v_final_present;
  END IF;
  IF v_old_present<>12 OR v_final_present<>0 THEN
    RAISE EXCEPTION 'predecessor EVF repair requires exact unrepaired state: old %, final %',
      v_old_present,v_final_present;
  END IF;

  WITH expected(txt_code,tournaments,results) AS (VALUES
    ('PEW5fs-2023-2024',7,11),('PEW21e-2023-2024',5,15),
    ('PEW8fs-2023-2024',2,4),('PEW24e-2023-2024',5,7),
    ('PEW9e-2023-2024',4,8),('PEW11f-2023-2024',2,2),
    ('PEW4f-2024-2025',1,1),('PEW11e-2024-2025',4,8),
    ('PEW6fs-2024-2025',3,5),('PEW12e-2024-2025',4,7),
    ('PEW7s-2024-2025',7,31),('PEW14e-2024-2025',8,58)
  ), actual AS (
    SELECT e.txt_code,COUNT(DISTINCT t.id_tournament)::INT tournaments,
           COUNT(r.id_result)::INT results
      FROM tbl_event e LEFT JOIN tbl_tournament t ON t.id_event=e.id_event
      LEFT JOIN tbl_result r ON r.id_tournament=t.id_tournament
     WHERE e.txt_code IN (SELECT txt_code FROM expected) GROUP BY e.txt_code
  )
  SELECT COUNT(*)::INT INTO v_expected_ok FROM expected x JOIN actual a USING(txt_code)
   WHERE x.tournaments=a.tournaments AND x.results=a.results;
  IF v_expected_ok<>12 THEN
    RAISE EXCEPTION 'predecessor EVF repair expected 12 exact baseline rows, found %',v_expected_ok;
  END IF;

  CREATE TEMP TABLE tmp_predecessor_score_snapshot ON COMMIT DROP AS
    SELECT r.id_result,r.num_place_pts,r.num_de_bonus,r.num_podium_bonus,r.num_final_score
      FROM tbl_result r JOIN tbl_tournament t ON t.id_tournament=r.id_tournament
      JOIN tbl_event e ON e.id_event=t.id_event
     WHERE e.txt_code=ANY(ARRAY[
       'PEW5fs-2023-2024','PEW21e-2023-2024','PEW8fs-2023-2024','PEW24e-2023-2024',
       'PEW9e-2023-2024','PEW11f-2023-2024','PEW4f-2024-2025','PEW11e-2024-2025',
       'PEW6fs-2024-2025','PEW12e-2024-2025','PEW7s-2024-2025',
       'PEW14e-2024-2025']);
  IF (SELECT COUNT(*) FROM tmp_predecessor_score_snapshot)<>157 THEN
    RAISE EXCEPTION 'predecessor EVF repair score snapshot expected 157 rows';
  END IF;

  -- Clear only the three explicitly reviewed wrong relationships before the
  -- Chania's reviewed link to the distinct prior Guildford foil event is
  -- cleared. No replacement link is inferred.
  UPDATE tbl_event SET id_prior_event=NULL,ts_updated=NOW()
   WHERE txt_code IN ('PEW4f-2024-2025','PEW7s-2024-2025','PEW8es-2025-2026');

  PERFORM fn_merge_predecessor_evf_event(
    'PEW5fs-2023-2024',ARRAY['PEW5fs-2023-2024','PEW21e-2023-2024'],
    'PEW5efs-2023-2024','EVF Circuit – Budapest (HUN)','Budapest','Hungary',
    DATE '2023-09-16',DATE '2023-09-16',ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[],12,26);
  PERFORM fn_merge_predecessor_evf_event(
    'PEW8fs-2023-2024',ARRAY['PEW8fs-2023-2024','PEW24e-2023-2024'],
    'PEW8efs-2023-2024','EVF Circuit – Terni (ITA)','Terni','Italy',
    DATE '2023-12-16',DATE '2023-12-16',ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[],7,11);
  PERFORM fn_merge_predecessor_evf_event(
    'PEW9e-2023-2024',ARRAY['PEW9e-2023-2024','PEW11f-2023-2024'],
    'PEW9ef-2023-2024','EVF Circuit – Stockholm (SWE)','Stockholm','Sweden',
    DATE '2024-02-24',DATE '2024-02-24',ARRAY['EPEE','FOIL']::enum_weapon_type[],6,10);
  PERFORM fn_merge_predecessor_evf_event(
    'PEW4f-2024-2025',ARRAY['PEW4f-2024-2025','PEW11e-2024-2025'],
    'PEW4ef-2024-2025','EVF Circuit – Guildford (GBR)','Guildford','Great Britain',
    DATE '2025-01-04',DATE '2025-01-05',ARRAY['EPEE','FOIL']::enum_weapon_type[],5,9);
  PERFORM fn_merge_predecessor_evf_event(
    'PEW6fs-2024-2025',ARRAY['PEW6fs-2024-2025','PEW12e-2024-2025'],
    'PEW6efs-2024-2025','EVF Circuit – Terni (ITA)','Terni','Italy',
    DATE '2025-02-01',DATE '2025-02-02',ARRAY['EPEE','FOIL','SABRE']::enum_weapon_type[],7,12);
  PERFORM fn_merge_predecessor_evf_event(
    'PEW7s-2024-2025',ARRAY['PEW7s-2024-2025','PEW14e-2024-2025'],
    'PEW7es-2024-2025','European Veterans Circuit – Jabłonna (POL)','Jabłonna','Poland',
    DATE '2025-03-29',DATE '2025-03-29',ARRAY['EPEE','SABRE']::enum_weapon_type[],15,89);

  IF EXISTS (
    SELECT 1 FROM tmp_predecessor_score_snapshot before
    JOIN tbl_result after USING(id_result)
    WHERE before.num_place_pts IS DISTINCT FROM after.num_place_pts
       OR before.num_de_bonus IS DISTINCT FROM after.num_de_bonus
       OR before.num_podium_bonus IS DISTINCT FROM after.num_podium_bonus
       OR before.num_final_score IS DISTINCT FROM after.num_final_score
  ) OR (SELECT COUNT(*) FROM tmp_predecessor_score_snapshot)<>(
    SELECT COUNT(*) FROM tmp_predecessor_score_snapshot before JOIN tbl_result after USING(id_result)
  ) THEN
    RAISE EXCEPTION 'predecessor EVF repair changed stored result points';
  END IF;

  IF EXISTS (SELECT 1 FROM tbl_event WHERE txt_code=ANY(ARRAY[
    'PEW21e-2023-2024','PEW24e-2023-2024','PEW11f-2023-2024',
    'PEW11e-2024-2025','PEW12e-2024-2025','PEW14e-2024-2025'])) THEN
    RAISE EXCEPTION 'predecessor EVF repair left named donor events';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION fn_merge_predecessor_evf_event(
  TEXT,TEXT[],TEXT,TEXT,TEXT,TEXT,DATE,DATE,enum_weapon_type[],INT,INT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION fn_repair_evf_predecessor_fragments()
  FROM PUBLIC, anon, authenticated;

SELECT fn_repair_evf_predecessor_fragments();
