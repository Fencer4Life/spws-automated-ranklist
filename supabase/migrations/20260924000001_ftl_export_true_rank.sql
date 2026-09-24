-- =============================================================================
-- fn_ftl_export_entries — seed on the TRUE rank, categorise on the
-- authoritative birth year, and stop publishing the club.
-- =============================================================================
--
-- Found on 2026-09-24 importing the PPW1 files into Fencing Time. SZKLAR
-- Bożena is 4th on the EPEE FV0 ranklist and came out seed 1, ahead of every
-- genuine category winner. Two independent causes, which compound.
--
-- 1. THE RANK WAS COMPACTED AWAY. The projection returned
--
--      ROW_NUMBER() OVER (PARTITION BY weapon, gender, vcat
--                         ORDER BY rk.position NULLS LAST, created, …)
--
--    a dense 1..N over the fencers who entered. EPEE FV0's entrants held true
--    ranks 4, 5 and 7 — ranks 1-3 stayed at home — and were renumbered 1, 2, 3.
--    interleave_mixall lays down every bucket's "1" in its first pass, so a
--    true 4th was seeded as a category winner. The rule is that ranks 1-3 are
--    omitted FOR THAT CATEGORY: the true number 1 leads, and a true 4th is laid
--    down with the other 4th places. So the true rank is published, NULL when
--    the fencer holds no points at all, and int_order survives only to order
--    the unranked tail deterministically without publishing ts_created.
--
-- 2. THE CATEGORY CAME FROM THE DECLARED YEAR, THE RANKING FROM THE MASTER ONE.
--    fn_ranking_ppw resolves a fencer's category live from tbl_fencer:
--    COALESCE(fn_age_category(f.int_birth_year, season_end), t.enum_age_category)
--    (ADR-010). This function used the DECLARED year instead, so whenever the
--    two disagreed the fencer was looked up in a sub-ranking they are not in,
--    lost their rank entirely, and sank to the tail. Live on PPW1: PĘCZEK
--    Sandra, true FV0 #1, declared a year putting her in FV1 where she is
--    unranked — she fell to seed 32 and FV0's top went to SZKLAR. Category now
--    resolves from tbl_fencer for a matched registration, falling back to the
--    declared year only when there is no fencer row to consult. ADR-093 makes
--    the declaration authoritative by writing it THROUGH to tbl_fencer, so the
--    two agree by construction; this removes the remaining way to disagree.
--
-- 3. THE CLUB IS WITHDRAWN. Added 2026-09-13 by 20260913000001 (ADR-080
--    amendment (f)); 41 of 90 PPW1 registrations supplied one and the free text
--    was already unusable — one Poznań club arrived under three spellings, plus
--    a "Wawrszawa" typo and diacritics dropped. It is removed from the public
--    projection here so the seed files stop carrying it. tbl_registration
--    .txt_club and fn_create_registration's parameter are deliberately LEFT
--    ALONE by this migration: they are collection, not publication, and the
--    consent text (CONSENT_VERSION v1.1) names the club, so retiring them is a
--    consent change to make after the event rather than two days before it.
--
-- vw_registration_entry_list never published the club and is untouched
-- (pgTAP 49.16).
-- =============================================================================

DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT, UUID);

CREATE FUNCTION fn_ftl_export_entries(p_id_event INT, p_token UUID)
RETURNS TABLE (
  txt_surname       TEXT,
  txt_first_name    TEXT,
  enum_gender       enum_gender_type,
  enum_age_category enum_age_category,
  enum_weapon       enum_weapon_type,
  int_order         INT,
  int_rank          INT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_season INT;
  v_end_year  INT;
  v_rolling   BOOLEAN;
BEGIN
  -- No token, no data. Returning empty rather than raising is deliberate: a
  -- stale link should look empty, not broken, and an error would confirm to a
  -- prober that they had found a real endpoint.
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  SELECT e.id_season, EXTRACT(YEAR FROM s.dt_end)::INT
    INTO v_id_season, v_end_year
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;

  -- An unknown event is an empty entry list, not an error: the page resolves
  -- an event from a URL parameter, and a stale link must not show a stack trace.
  IF v_id_season IS NULL THEN
    RETURN;
  END IF;

  v_rolling := COALESCE(fn_ftl_export_use_rolling(p_id_event), FALSE);

  RETURN QUERY
  WITH entries AS (
    -- One row per declared weapon. A registration for épée and foil is two
    -- entries in two competitions, and they can be seeded differently.
    --
    -- The category comes from tbl_fencer when the registration is matched,
    -- because that is the year fn_ranking_ppw ranks on. COALESCE falls back to
    -- the declared year for an unmatched row, which has no fencer to consult.
    SELECT r.id_fencer       AS fid,
           r.txt_surname     AS surname,
           r.txt_first_name  AS first_name,
           r.enum_gender     AS gender,
           fn_age_category(
             COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year
           )                 AS vcat,
           w.weapon          AS weapon,
           r.ts_created      AS created
      FROM tbl_registration r
      LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  ),
  live AS (
    -- A birth year below the veteran floor has no sub-ranking, so it has no
    -- seed position and no file to go in. Same rule as the exporter's
    -- registration_subranking_key.
    SELECT * FROM entries WHERE vcat IS NOT NULL
  ),
  groups AS (
    SELECT DISTINCT weapon, gender, vcat FROM live
  ),
  ranked AS (
    -- One fn_ranking_ppw call per sub-ranking that actually has entrants,
    -- rather than all thirty.
    SELECT g.weapon, g.gender, g.vcat, rk.id_fencer AS fid, rk.rank AS position
      FROM groups g
      CROSS JOIN LATERAL fn_ranking_ppw(
        g.weapon, g.gender, g.vcat, v_id_season, v_rolling
      ) rk
  )
  SELECT l.surname,
         l.first_name,
         l.gender,
         l.vcat,
         l.weapon,
         ROW_NUMBER() OVER (
           PARTITION BY l.weapon, l.gender, l.vcat
           -- Ranked registrants in ranking order; everyone else after them, in
           -- the order they entered. Name is the final tiebreak so that two
           -- registrations written in the same transaction still order
           -- deterministically — a seed file that changes between two downloads
           -- of the same entry list would be impossible to reconcile. This is
           -- no longer the seed position: it orders the UNRANKED tail, and
           -- exists so that tail is stable without publishing ts_created.
           ORDER BY rk.position NULLS LAST, l.created, l.surname, l.first_name
         )::INT,
         -- The seed tier. NULL means no ranking points at all, which is not
         -- rank 0 and not "last in the bucket": it is what sends the entry to
         -- the tail after every ranked fencer in every bucket.
         rk.position::INT
    FROM live l
    LEFT JOIN ranked rk
      ON  rk.weapon = l.weapon
      AND rk.gender = l.gender
      AND rk.vcat   = l.vcat
      AND rk.fid    = l.fid
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$$;

REVOKE ALL ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;

COMMENT ON FUNCTION fn_ftl_export_entries(INT, UUID) IS
  'Public seed projection for the FTL export page: one row per registration x '
  'declared weapon, carrying the canonical-name inputs, the sub-ranking key, '
  'the fencer''s TRUE rank in that sub-ranking (NULL when unranked) and a dense '
  'int_order used only to keep the unranked tail deterministic. Categorises on '
  'tbl_fencer''s birth year when the registration is matched, which is what '
  'fn_ranking_ppw ranks on. Publishes no birth year, fencer id, registration '
  'id, edit token or club.';
