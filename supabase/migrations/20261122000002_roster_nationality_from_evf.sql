-- =============================================================================
-- FR-172 · The roster nationality: one spelling, kept to the EVF ranking
-- Plan doc/plans/roster-nationality-from-evf-2026-11-22.html, rev 3 (N1–N9 signed
-- 22 Nov 2026). Amends ADR-106 and ADR-072.
--
-- 1. A nationality change queues no recompute (N8): nothing that scores, places
--    or ranks reads tbl_fencer.txt_nationality, and a recompute rescores closed
--    seasons with the current engine. A birth-year change still queues.
-- 2. 25 fencers take the code decided on 22 Nov (N1, N4): 20 take the EVF
--    ranking country, four POL, one USA. Each row names the fencer id and the
--    value it holds now (PL); a fencer holding anything else is left alone, so on
--    a fresh database (migrations before the seed) nothing matches.
-- 3. For fencer 140, the 2024/25 and 2025/26 nationality is an administrator entry, POL (N3,
--    N7), which the results trigger keeps as entered.
-- 4. PL becomes POL everywhere (N2): the rows, the alias split, and the EVF
--    parity check, which counted PL only (I26).
-- 5. The column defaults to POL and takes three capital letters only (N2, N9).
-- =============================================================================

SET lock_timeout = '2s';

-- 1 · The recompute trigger: birth year only -----------------------------------

CREATE OR REPLACE FUNCTION fn_fencer_change_enqueue()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Only a birth-year change relocates results between categories. Name, alias
    -- and nationality edits move no point (FK is durable, ADR-003; nationality is
    -- read by the matcher, promote and the EVF parity check only — FR-172).
    IF NEW.int_birth_year IS DISTINCT FROM OLD.int_birth_year THEN
        PERFORM fn_enqueue_affected_events(NEW.id_fencer);
    END IF;
    RETURN NEW;
END;
$$;

-- 2 · The 25 fencers decided on 22 Nov -----------------------------------------

UPDATE tbl_fencer f
   SET txt_nationality = v.code
  FROM (VALUES
    (5, 'HUN'),
    (8, 'SWE'),
    (34, 'ITA'),
    (60, 'HUN'),
    (80, 'SVK'),
    (81, 'ISR'),
    (133, 'SVK'),
    (137, 'IRL'),
    (138, 'POL'),
    (143, 'POL'),
    (162, 'IRL'),
    (167, 'GBR'),
    (186, 'IRL'),
    (201, 'IRL'),
    (236, 'UKR'),
    (241, 'BEL'),
    (272, 'CZE'),
    (273, 'NED'),
    (284, 'SVK'),
    (304, 'UKR'),
    (311, 'NED'),
    (320, 'USA'),
    (349, 'GER'),
    (354, 'POL'),
    (356, 'POL')
  ) AS v(id, code)
 WHERE f.id_fencer = v.id
   AND f.txt_nationality = 'PL';

-- 3 · Fencer 140: an administrator's POL for 2024/25 and 2025/26 ----------------

INSERT INTO tbl_fencer_nationality (id_fencer, id_season, txt_country, id_result_first, enum_source)
SELECT 140, s.id_season, 'POL', NULL, 'ADMIN'
  FROM tbl_season s
 WHERE s.txt_code IN ('SPWS-2024-2025', 'SPWS-2025-2026')
   AND EXISTS (SELECT 1 FROM tbl_fencer WHERE id_fencer = 140 AND int_birth_year = 1981 AND enum_gender = 'M')
ON CONFLICT (id_fencer, id_season) DO UPDATE
   SET txt_country = 'POL', id_result_first = NULL, enum_source = 'ADMIN', ts_updated = NOW();

-- 4 · One spelling --------------------------------------------------------------

UPDATE tbl_fencer SET txt_nationality = 'POL' WHERE txt_nationality = 'PL';

CREATE OR REPLACE FUNCTION public.fn_split_fencer_from_alias(p_from_fencer integer, p_alias text, p_new_fencer_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_new_id INT;
  v_surname     TEXT := p_new_fencer_data ->> 'txt_surname';
  v_first_name  TEXT := p_new_fencer_data ->> 'txt_first_name';
  v_birth_year  INT  := (p_new_fencer_data ->> 'int_birth_year')::INT;
  v_gender      enum_gender_type := (p_new_fencer_data ->> 'enum_gender')::enum_gender_type;
  v_country     TEXT := p_new_fencer_data ->> 'txt_nationality';
  v_club        TEXT := p_new_fencer_data ->> 'txt_club';
  v_transfer_result JSONB;
BEGIN
  -- FR-172: one spelling; the roster's default is POL.
  v_country := NULLIF(upper(btrim(v_country)), '');
  IF v_country = 'PL' THEN
    v_country := 'POL';
  END IF;

  IF v_surname IS NULL OR v_first_name IS NULL OR v_birth_year IS NULL OR v_gender IS NULL THEN
    RAISE EXCEPTION 'fn_split_fencer_from_alias: required fields missing (txt_surname, txt_first_name, int_birth_year, enum_gender)';
  END IF;

  INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year, enum_gender,
    txt_nationality, txt_club, json_name_aliases
  )
  VALUES (
    v_surname, v_first_name, v_birth_year, v_gender,
    COALESCE(v_country, 'POL'), v_club, '[]'::jsonb
  )
  RETURNING id_fencer INTO v_new_id;

  -- Audit log for fencer creation
  INSERT INTO tbl_audit_log (txt_table_name, id_row, txt_action, jsonb_new_values)
  VALUES ('tbl_fencer', v_new_id, 'create_from_alias_split',
          jsonb_build_object(
            'split_from_fencer', p_from_fencer,
            'alias', p_alias,
            'new_fencer_data', p_new_fencer_data
          ));

  -- Reuse transfer logic for the alias + result reassignment
  SELECT fn_transfer_fencer_alias(p_from_fencer, v_new_id, p_alias) INTO v_transfer_result;

  RETURN jsonb_build_object(
    'new_fencer_id',   v_new_id,
    'transfer_result', v_transfer_result
  );
END;
$function$;

CREATE OR REPLACE FUNCTION fn_event_results_for_parity(p_id_event INT)
RETURNS TABLE (
  fencer_name      TEXT,
  int_place        INT,
  num_final_score  NUMERIC,
  id_fencer        INT,
  id_result        INT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    (f.txt_first_name || ' ' || f.txt_surname) AS fencer_name,
    r.int_place,
    r.num_final_score,
    f.id_fencer,
    r.id_result
  FROM tbl_result r
  JOIN tbl_tournament t ON t.id_tournament = r.id_tournament
  JOIN tbl_fencer f     ON f.id_fencer = r.id_fencer
  WHERE t.id_event = p_id_event
    AND f.txt_nationality = 'POL'
  -- 2 is r.int_place (positional: postgrestools mis-reads the qualified name in this file)
  ORDER BY 2, f.txt_surname, f.txt_first_name;
$$;

-- 5 · The default and three capital letters only (one statement, last) -------

COMMENT ON COLUMN tbl_fencer.txt_nationality IS
  'FR-172: the fencer''s federation as a three-letter code (POL for Poland, never PL); kept to the EVF ranking monthly by evf-ranking-sync.yml (python/tools/unify_roster_nationality.py). The per-season record is tbl_fencer_nationality (ADR-106).';

ALTER TABLE tbl_fencer
  ALTER COLUMN txt_nationality SET DEFAULT 'POL',
  DROP CONSTRAINT IF EXISTS ck_fencer_nationality_code,
  ADD CONSTRAINT ck_fencer_nationality_code CHECK (txt_nationality ~ '^[A-Z]{3}$');
