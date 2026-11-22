-- =============================================================================
-- FR-174 · An event seed files follow its organiser ranking, and the EVF
-- ranking places are kept (plan doc/plans/seeding-by-organiser-ranking-2026-11-22.html,
-- rev 1, release 1; amends ADR-079 and ADR-080)
-- =============================================================================
-- 1. tbl_evf_ranking_place: each ranked fencer place and points on the EVF list
--    of one weapon, gender and category, as last read by evf-ranking-sync.yml.
-- 2. fn_replace_evf_ranking_places: the read replaces every place at once, and
--    only with all 24 lists; anything less changes nothing.
-- 3. fn_evf_ranking_read_due: whether a read day has come since the last
--    successful read (seven days after an EVF event, the day before an EVF
--    event with our registration, or 31 days after the last read).
-- 4. fn_event_seed_ranks: the one rule both readers use. EVF organises: the
--    place of the one ranked fencer of the entry name on the list of its
--    weapon, gender and category. Anyone else: our ranking, as before.
-- 5. fn_ftl_export_entries reads its place and points from that rule and names
--    the ranking and when it was read. For our events nothing else changes.
-- Tests: supabase/tests/139_evf_seed_ranks.sql (EVFSEED.01-16); the export
-- earlier tests (76) pass unedited.
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- ---------------------------------------------------------------------------
-- 1. The places.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tbl_evf_ranking_place (
  id_evf       UUID NOT NULL REFERENCES tbl_evf_ranking_fencer (id_evf) ON DELETE CASCADE,
  enum_weapon  enum_weapon_type NOT NULL,
  enum_gender  enum_gender_type NOT NULL,
  int_category SMALLINT NOT NULL CHECK (int_category BETWEEN 1 AND 4),
  int_place    INT NOT NULL CHECK (int_place >= 1),
  num_points   NUMERIC NOT NULL,
  ts_read      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id_evf, enum_weapon)
);

COMMENT ON TABLE tbl_evf_ranking_place IS
  'FR-174: each ranked fencer place and points on the EVF list of one weapon, gender and category, as last '
  'read by evf-ranking-sync.yml. Replaced in full by every read (fn_replace_evf_ranking_places). Seeds the '
  'entries of an event EVF organises (fn_event_seed_ranks). No grant to a visitor or a signed-in user.';

ALTER TABLE tbl_evf_ranking_place ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_evf_ranking_place FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON tbl_evf_ranking_place TO service_role;

-- ---------------------------------------------------------------------------
-- 2. The full replacement, all or nothing.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_replace_evf_ranking_places(p_rows JSONB)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lists INT;
  v_n     INT;
BEGIN
  SELECT count(DISTINCT (x ->> 'weapon') || '/' || (x ->> 'gender') || '/' || (x ->> 'category'))
    INTO v_lists
    FROM jsonb_array_elements(COALESCE(p_rows, '[]'::JSONB)) x;
  IF v_lists <> 24 THEN
    RAISE EXCEPTION 'EVF_PLACES_INCOMPLETE: % of 24 lists', v_lists;
  END IF;

  -- Every row is taken out: id_evf is part of the primary key, never NULL, so
  -- the WHERE keeps them all (as 20261122000004 does).
  DELETE FROM tbl_evf_ranking_place WHERE id_evf IS NOT NULL;

  INSERT INTO tbl_evf_ranking_place (id_evf, enum_weapon, enum_gender, int_category, int_place, num_points)
  SELECT (x ->> 'id')::UUID, (x ->> 'weapon')::enum_weapon_type, (x ->> 'gender')::enum_gender_type,
         (x ->> 'category')::SMALLINT, (x ->> 'place')::INT, (x ->> 'points')::NUMERIC
    FROM jsonb_array_elements(p_rows) x;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

COMMENT ON FUNCTION fn_replace_evf_ranking_places(JSONB) IS
  'FR-174: replaces every stored EVF place with the rows of one complete read (24 lists), or refuses '
  'EVF_PLACES_INCOMPLETE and changes nothing. Called by python/tools/extract_evf_given_names.py.';

REVOKE EXECUTE ON FUNCTION fn_replace_evf_ranking_places(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_replace_evf_ranking_places(JSONB) TO service_role;

-- ---------------------------------------------------------------------------
-- 3. Is a read due? NULL: no. Otherwise the reason, which the job reports.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_evf_ranking_read_due(p_today DATE DEFAULT CURRENT_DATE)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH seen AS (
    SELECT max(p.ts_read)::DATE AS d FROM tbl_evf_ranking_place p
  ),
  evf AS (
    SELECT e.txt_code, e.dt_start, COALESCE(e.dt_end, e.dt_start) AS dt_last,
           e.bool_use_spws_registration AS reg
      FROM tbl_event e
      JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
     WHERE o.txt_code = 'EVF'
       AND e.enum_status <> 'CANCELLED'
       AND e.dt_start IS NOT NULL
  )
  SELECT CASE
    WHEN (SELECT d FROM seen) IS NULL THEN 'no places stored yet'
    ELSE COALESCE(
      -- The day before an EVF event we take entries for, until its last day.
      (SELECT 'the day before ' || v.txt_code
         FROM evf v, seen
        WHERE v.reg AND v.dt_start - 1 <= p_today AND p_today <= v.dt_last AND v.dt_start - 1 > seen.d
        ORDER BY v.dt_start LIMIT 1),
      -- Seven days after an EVF event, time for EVF to update its ranking.
      (SELECT '7 days after ' || v.txt_code
         FROM evf v, seen
        WHERE v.dt_last + 7 <= p_today AND v.dt_last + 7 > seen.d
        ORDER BY v.dt_last DESC, v.txt_code LIMIT 1),
      -- The safety line: never older than 31 days.
      (SELECT 'the last read is older than 31 days' FROM seen WHERE seen.d + 31 < p_today))
  END;
$$;

COMMENT ON FUNCTION fn_evf_ranking_read_due(DATE) IS
  'FR-174: NULL when no read of the EVF ranking is due on p_today; otherwise why one is (no places stored, '
  'the day before an EVF event with our registration, 7 days after an EVF event, or the last read older than 31 days).';

REVOKE EXECUTE ON FUNCTION fn_evf_ranking_read_due(DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_evf_ranking_read_due(DATE) TO service_role;

-- ---------------------------------------------------------------------------
-- 4. The one rule: each start with its place in the organiser ranking.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_event_seed_ranks(p_id_event INT)
RETURNS TABLE (
  id_registration   INT,
  enum_weapon       enum_weapon_type,
  enum_gender       enum_gender_type,
  enum_age_category enum_age_category,
  int_rank          INT,
  num_rank_points   NUMERIC,
  int_seed_order    INT,
  txt_ranking       TEXT,
  ts_ranking_read   TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_season INT;
  v_end_year  INT;
  v_org       TEXT;
  v_rolling   BOOLEAN;
  v_read      TIMESTAMPTZ;
BEGIN
  SELECT e.id_season, EXTRACT(YEAR FROM s.dt_end)::INT, o.txt_code
    INTO v_id_season, v_end_year, v_org
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
   WHERE e.id_event = p_id_event;
  IF v_id_season IS NULL THEN
    RETURN;
  END IF;

  IF v_org = 'EVF' THEN
    SELECT max(p.ts_read) INTO v_read FROM tbl_evf_ranking_place p;
    RETURN QUERY
    WITH live AS (
      SELECT r.id_registration AS rid, r.txt_surname AS surname, r.txt_first_name AS first_name,
             r.enum_gender AS gender, w.weapon AS weapon,
             fn_age_category(COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year) AS vcat
        FROM tbl_registration r
        LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
        CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
       WHERE r.id_event = p_id_event
    ),
    cand AS (
      SELECT l.rid, l.weapon, p.int_place AS place, p.num_points AS points,
             count(*) OVER (PARTITION BY l.rid, l.weapon) AS n
        FROM live l
        JOIN tbl_evf_ranking_place p
          ON p.enum_weapon = l.weapon
         AND p.enum_gender = l.gender
         AND ('V' || p.int_category::TEXT)::enum_age_category = l.vcat
        JOIN tbl_evf_ranking_fencer x ON x.id_evf = p.id_evf
       WHERE fn_fold_name(x.txt_surname)    = fn_fold_name(fn_name_without_title(l.surname))
         AND fn_fold_name(x.txt_first_name) = fn_fold_name(l.first_name)
    )
    SELECT l.rid, l.weapon, l.gender, l.vcat,
           c.place, c.points,
           CASE WHEN c.place IS NOT NULL THEN
             ROW_NUMBER() OVER (
               PARTITION BY l.weapon, l.gender, l.vcat
               ORDER BY c.place NULLS LAST, c.points DESC NULLS LAST,
                        fn_fold_name(fn_name_without_title(l.surname)), fn_fold_name(l.first_name), l.rid
             )::INT
           END,
           'EVF'::TEXT, v_read
      FROM live l
      LEFT JOIN cand c ON c.rid = l.rid AND c.weapon = l.weapon AND c.n = 1
     -- EVF ranks 40 and over: V0 has no EVF list, so it has no row here.
     WHERE l.vcat IN ('V1', 'V2', 'V3', 'V4');
    RETURN;
  END IF;

  v_rolling := COALESCE(fn_ftl_export_use_rolling(p_id_event), FALSE);
  RETURN QUERY
  WITH live AS (
    SELECT r.id_registration AS rid, r.id_fencer AS fid, r.enum_gender AS gender, w.weapon AS weapon,
           fn_age_category(COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year) AS vcat
      FROM tbl_registration r
      LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  ),
  groups AS (
    SELECT DISTINCT l.weapon, l.gender, l.vcat FROM live l WHERE l.vcat IS NOT NULL
  ),
  ranked AS (
    SELECT g.weapon, g.gender, g.vcat, rk.id_fencer AS fid, rk.rank AS position,
           rk.total_score AS points, rk.ordinality AS ord
      FROM groups g
      CROSS JOIN LATERAL fn_ranking_ppw(g.weapon, g.gender, g.vcat, v_id_season, v_rolling) WITH ORDINALITY rk
  )
  SELECT l.rid, l.weapon, l.gender, l.vcat,
         rk.position::INT, rk.points::NUMERIC,
         CASE WHEN rk.position IS NOT NULL THEN
           ROW_NUMBER() OVER (
             PARTITION BY l.weapon, l.gender, l.vcat
             -- ADR-115: fencers sharing a place keep the ranking own order.
             ORDER BY rk.position NULLS LAST, rk.ord NULLS LAST, l.rid
           )::INT
         END,
         'SPWS'::TEXT, NULL::TIMESTAMPTZ
    FROM live l
    LEFT JOIN ranked rk
      ON rk.weapon = l.weapon AND rk.gender = l.gender AND rk.vcat = l.vcat AND rk.fid = l.fid
   WHERE l.vcat IS NOT NULL;
END;
$$;

COMMENT ON FUNCTION fn_event_seed_ranks(INT) IS
  'FR-174: each start of an event (registration x weapon) with its place, points and seed order in the '
  'organiser ranking: the EVF list of its weapon, gender and category when EVF organises, ours otherwise.';

REVOKE EXECUTE ON FUNCTION fn_event_seed_ranks(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_event_seed_ranks(INT) TO service_role;

-- ---------------------------------------------------------------------------
-- 5. The export, on the one rule. DROP + CREATE: two columns are added.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_ftl_export_entries(INT, UUID);

CREATE OR REPLACE FUNCTION public.fn_ftl_export_entries(p_id_event integer, p_token uuid)
 RETURNS TABLE(txt_surname text, txt_first_name text, enum_gender enum_gender_type,
               enum_age_category enum_age_category, enum_weapon enum_weapon_type, int_order integer,
               int_rank integer, num_rank_points numeric, txt_country text,
               txt_ranking text, ts_ranking_read timestamptz)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_end_year INT;
  v_ranking  TEXT;
  v_read     TIMESTAMPTZ;
BEGIN
  -- No token, no data: a stale link looks empty, not broken.
  IF NOT COALESCE(fn_ftl_export_token_valid(p_token), FALSE) THEN
    RETURN;
  END IF;

  SELECT EXTRACT(YEAR FROM s.dt_end)::INT,
         CASE WHEN o.txt_code = 'EVF' THEN 'EVF' ELSE 'SPWS' END
    INTO v_end_year, v_ranking
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
    JOIN tbl_organizer o ON o.id_organizer = e.id_organizer
   WHERE e.id_event = p_id_event;
  IF v_end_year IS NULL THEN
    RETURN;
  END IF;
  IF v_ranking = 'EVF' THEN
    SELECT max(p.ts_read) INTO v_read FROM tbl_evf_ranking_place p;
  END IF;

  RETURN QUERY
  WITH live AS (
    -- One row per declared weapon. The category comes from tbl_fencer when the
    -- entry is linked (the year our ranking ranks on), else the declared year.
    SELECT r.id_registration AS rid, r.txt_surname AS surname, r.txt_first_name AS first_name,
           r.enum_gender AS gender, w.weapon AS weapon, r.ts_created AS created, r.txt_country AS country,
           fn_age_category(COALESCE(f.int_birth_year, r.int_birth_year)::INT, v_end_year) AS vcat
      FROM tbl_registration r
      LEFT JOIN tbl_fencer f ON f.id_fencer = r.id_fencer
      CROSS JOIN LATERAL unnest(r.arr_weapons) AS w(weapon)
     WHERE r.id_event = p_id_event
  )
  SELECT l.surname, l.first_name, l.gender, l.vcat, l.weapon,
         ROW_NUMBER() OVER (
           PARTITION BY l.weapon, l.gender, l.vcat
           -- Ranked entrants in the ranking order (place, then the ranking own
           -- order inside a shared place, ADR-115); everyone else after them in
           -- the order they entered; the name last, so two downloads agree.
           ORDER BY s.int_rank NULLS LAST, s.int_seed_order NULLS LAST, l.created, l.surname, l.first_name
         )::INT,
         s.int_rank, s.num_rank_points, l.country, v_ranking, v_read
    FROM live l
    LEFT JOIN fn_event_seed_ranks(p_id_event) s
      ON s.id_registration = l.rid AND s.enum_weapon = l.weapon
   -- A year below the veteran floor has no sub-ranking and no file.
   WHERE l.vcat IS NOT NULL
   ORDER BY l.weapon, l.gender, l.vcat, 6;
END;
$function$;

REVOKE EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_ftl_export_entries(INT, UUID) TO anon, authenticated, service_role;

COMMIT;
