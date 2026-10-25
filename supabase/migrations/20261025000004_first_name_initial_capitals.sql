-- =============================================================================
-- A first name written in capitals is stored with initial capitals (D5 A)
-- =============================================================================
-- Three fencers carry a first name in capitals on LOCAL, CERT and PROD alike:
-- #117 KALECKA EMILIA, #276 SPŁAWA-NEYMAN MACIEJ, #348 ŻYCZKOWSKI KAROL, from a
-- source that printed the whole name in capitals (in every seed since May
-- 2026). The fix is at the writer every path passes: fn_trim_fencer_names,
-- the BEFORE INSERT OR UPDATE trigger on tbl_fencer that already trims the
-- names, so the ingest, Admin, promote's replay and the seed load all store
-- 'Emilia'. The rule has one owner, fn_first_name_initial_capitals: a first
-- name of two letters or more that is entirely in capitals gets initial
-- capitals (initcap: Polish letters, two names and a hyphen included); a
-- mixed-case name, a one-letter initial and the surname are never changed.
--
-- The seed load takes the roster's first names through the same rule before
-- it pairs and aligns. A fresh bootstrap runs this migration before the seed,
-- and a seed exported while a name was in capitals would otherwise fail
-- fn_align_fencers_to's check that the roster equals the one given
-- (ALIGN_ROSTER_MISMATCH), the trigger having changed what it was given.
--
-- The three rows are then corrected, each guarded by its id, surname and
-- capitalised first name, so a row that differs is left alone.
-- doc/plans/pzsz-results-url-rca-2026-10-25.html (issue #10). pgTAP
-- NAMECASE.01–04 (38_fencer_trim_trigger.sql), SEED.09 (99_seed_load_fencers.sql).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_first_name_initial_capitals(p_first_name TEXT)
 RETURNS TEXT
 LANGUAGE sql
 IMMUTABLE
 SET search_path = public
AS $function$
  SELECT CASE
           WHEN p_first_name = upper(p_first_name)
            AND length(regexp_replace(p_first_name, '[^[:alpha:]]', '', 'g')) >= 2
             THEN initcap(p_first_name)
           ELSE p_first_name
         END;
$function$;

COMMENT ON FUNCTION public.fn_first_name_initial_capitals(TEXT) IS
  'D5 A: a first name of two letters or more written wholly in capitals gets '
  'initial capitals; any other value is returned as given. The one owner of the '
  'rule fn_trim_fencer_names and fn_seed_load_fencers apply.';

CREATE OR REPLACE FUNCTION public.fn_trim_fencer_names()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.txt_surname IS NOT NULL THEN
    NEW.txt_surname := btrim(NEW.txt_surname);
  END IF;
  IF NEW.txt_first_name IS NOT NULL THEN
    NEW.txt_first_name := fn_first_name_initial_capitals(btrim(NEW.txt_first_name));
  END IF;
  RETURN NEW;
END;
$function$;

-- pgt-ignore-start plpgsql_check: _seed_match is a temp table the body creates itself, which the checker cannot see
CREATE OR REPLACE FUNCTION fn_seed_load_fencers(
  p_roster   JSONB,
  p_sequence BIGINT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_missing   TEXT;
  v_ambiguous TEXT;
  v_pairs     JSONB;
BEGIN
  IF p_roster IS NULL OR jsonb_typeof(p_roster) <> 'array' THEN
    RAISE EXCEPTION 'SEED_ROSTER_INVALID: the roster must be a JSON array of fencer rows';
  END IF;

  -- The roster's first names take the writer's rule, so the roster is what
  -- the trigger will store and the alignment's equality check holds.
  SELECT COALESCE(jsonb_agg(
           CASE WHEN jsonb_typeof(r.j->'txt_first_name') = 'string'
                THEN jsonb_set(r.j, '{txt_first_name}',
                               to_jsonb(fn_first_name_initial_capitals(btrim(r.j->>'txt_first_name'))))
                ELSE r.j END
           ORDER BY r.n), '[]'::jsonb)
    INTO p_roster
    FROM jsonb_array_elements(p_roster) WITH ORDINALITY AS r(j, n);

  CREATE TEMP TABLE _seed_match ON COMMIT DROP AS
  SELECT f.id_fencer,
         f.txt_surname || ' ' || f.txt_first_name || ' (' || COALESCE(f.int_birth_year::TEXT, '?') || ')' AS label,
         count(r.j) AS n,
         min((r.j->>'id_fencer')::INT) AS prod_id
    FROM tbl_fencer f
    LEFT JOIN jsonb_array_elements(p_roster) AS r(j)
      ON upper(btrim(r.j->>'txt_surname'))    = upper(btrim(f.txt_surname))
     AND upper(btrim(r.j->>'txt_first_name')) = upper(btrim(f.txt_first_name))
     AND (r.j->>'int_birth_year')::INT IS NOT DISTINCT FROM f.int_birth_year::INT
   GROUP BY f.id_fencer, f.txt_surname, f.txt_first_name, f.int_birth_year;

  SELECT string_agg(label, ', ' ORDER BY label) INTO v_missing FROM _seed_match WHERE n = 0;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'SEED_FENCER_NOT_IN_ROSTER: % exist here but not in the roster', v_missing;
  END IF;

  SELECT string_agg(label, ', ' ORDER BY label) INTO v_ambiguous FROM _seed_match WHERE n > 1;
  IF v_ambiguous IS NOT NULL THEN
    RAISE EXCEPTION 'SEED_FENCER_AMBIGUOUS: % match more than one roster row', v_ambiguous;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('cert_id', id_fencer, 'prod_id', prod_id)), '[]'::jsonb)
    INTO v_pairs FROM _seed_match;
  DROP TABLE _seed_match;

  RETURN fn_align_fencers_to(v_pairs, p_roster, '[]'::jsonb, p_sequence, FALSE);
END;
$$;
-- pgt-ignore-end plpgsql_check

COMMENT ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) IS
  'ADR-036 §1: the seed''s fencer load. Takes the roster''s first names through '
  'fn_first_name_initial_capitals, pairs every present fencer (those data '
  'migrations created on a fresh bootstrap) with one roster row by name and birth '
  'year, then fn_align_fencers_to gives everyone PROD''s id and values, creates '
  'the rest and checks the roster equals the one given. Refuses by name.';

-- The trigger runs as whoever writes the row, so an administrator's direct
-- write (authenticated) needs the rule too; anon writes no table (52.3–52.6).
REVOKE ALL ON FUNCTION fn_first_name_initial_capitals(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fn_first_name_initial_capitals(TEXT) TO authenticated, service_role;
REVOKE ALL ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) TO service_role;

DO $fix$
DECLARE
  v_fixed INT;
BEGIN
  UPDATE tbl_fencer f
     SET txt_first_name = initcap(f.txt_first_name)
   WHERE (f.id_fencer, f.txt_surname, f.txt_first_name) IN (
           (117, 'KALECKA', 'EMILIA'),
           (276, 'SPŁAWA-NEYMAN', 'MACIEJ'),
           (348, 'ŻYCZKOWSKI', 'KAROL'));
  GET DIAGNOSTICS v_fixed = ROW_COUNT;
  RAISE NOTICE 'first names given initial capitals: %', v_fixed;
END;
$fix$;
