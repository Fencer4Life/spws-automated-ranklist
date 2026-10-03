-- =============================================================================
-- ADR-036 §1 (amended by ADR-108): the seed loads PROD's roster at PROD's ids.
-- =============================================================================
-- The fencer id is the same on LOCAL, CERT and PROD. On a fresh bootstrap every
-- migration runs before the seed, and three data migrations create fencers by
-- hand (20260714000003's fifteen, KOSZYK, CISZEWSKA and SZUMIELEWICZ) under
-- whatever ids the sequence gives them on an empty table. The seed used to skip
-- them by name and insert everyone else under fresh ids, so LOCAL and CI never
-- held PROD's ids.
--
-- fn_seed_load_fencers(p_roster, p_sequence) is what the seed calls instead,
-- with PROD's whole roster (to_jsonb rows) and PROD's id sequence:
--
--   * every fencer already present is paired with exactly one roster row by
--     surname and first name (trimmed, case-insensitive) and birth year (an
--     unknown year with an unknown year). A present fencer the roster lacks,
--     or one that two roster rows describe, is refused by name: nothing is
--     guessed and nothing is written;
--   * the pairing goes through fn_align_fencers_to, which moves the present
--     fencers to PROD's ids with PROD's values, creates every other roster row
--     at its PROD id, sets the sequence, and refuses unless the roster then
--     equals the one given — the bootstrap's check against PROD.
--
-- Callable by the seed (run as the owner) and the service role only.
-- Plan-test-IDs: pgTAP SEED.01–08; pytest PROMO.SEED.01–05.
-- =============================================================================

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

COMMENT ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) IS
  'ADR-036 §1: the seed''s fencer load. Pairs every present fencer (those data '
  'migrations created on a fresh bootstrap) with one roster row by name and birth '
  'year, then fn_align_fencers_to gives everyone PROD''s id and values, creates '
  'the rest and checks the roster equals the one given. Refuses by name.';

REVOKE ALL ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_seed_load_fencers(JSONB, BIGINT) TO service_role;
