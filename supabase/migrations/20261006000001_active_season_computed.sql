-- =============================================================================
-- The active season is computed on read (ADR-031 amendment 2026-10-06)
-- =============================================================================
-- "Active" is a pure function of the season dates and today. Today changes
-- without any write, so a stored tbl_season.bool_active needed a writer at
-- every boundary: fn_refresh_active_season(), called by a trigger on season
-- edits and by the browser on every page load. ADR-083 (23 Jul 2026) revoked
-- anon's EXECUTE on that writer, so every public page load logged a 401 and,
-- since then, nothing moved the flag when a season's dates passed.
--
-- This migration removes the stored flag. bool_active becomes a computed
-- field: the function bool_active(tbl_season). PostgreSQL resolves
-- s.bool_active (an alias in front) to bool_active(s) once no column of that
-- name exists, and PostgREST exposes the same function as a computed field,
-- so `select=…,bool_active` and `bool_active=eq.true` keep working. The rule
-- is unchanged: the season whose dates contain today, else the nearest future
-- season, else none.
--
-- Tests choose "today" with set_config('spws.today', <date>, true); fn_today()
-- reads it before CURRENT_DATE. Clients cannot set it: PostgREST runs no SQL
-- from a request and sets only request.* settings.
--
-- Plan: doc/plans/active-season-computed-on-read-2026-10-06.html (option V).
-- Tests: supabase/tests/106_active_season_computed.sql (106.1-106.13).
-- =============================================================================

BEGIN;

SET LOCAL lock_timeout = '2s';

-- 1. Today, overridable by tests
CREATE OR REPLACE FUNCTION fn_today()
RETURNS date
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(NULLIF(current_setting('spws.today', true), '')::date, CURRENT_DATE)
$$;

COMMENT ON FUNCTION fn_today() IS
  'Today for the active-season rule (ADR-031 amendment 2026-10-06): '
  'spws.today when a test sets it, else CURRENT_DATE.';

-- 2. The active season, derived on every read
CREATE OR REPLACE FUNCTION fn_active_season_id()
RETURNS integer
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT id_season FROM tbl_season
      WHERE dt_start <= fn_today() AND dt_end >= fn_today()
      LIMIT 1),
    (SELECT id_season FROM tbl_season
      WHERE dt_start > fn_today()
      ORDER BY dt_start
      LIMIT 1))
$$;

COMMENT ON FUNCTION fn_active_season_id() IS
  'The active season (ADR-031): the season whose dates contain today, else the '
  'nearest future season, else NULL. Computed on read; nothing stores it.';

-- 3. The computed field. A function may share a column's name: PostgreSQL
--    resolves s.bool_active to the column while it exists and to this
--    function once step 7 drops it.
CREATE OR REPLACE FUNCTION bool_active(p_season tbl_season)
RETURNS boolean
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
BEGIN
  RETURN p_season.id_season = fn_active_season_id();
END;
$$;

COMMENT ON FUNCTION bool_active(tbl_season) IS
  'Computed field (ADR-031 amendment 2026-10-06): s.bool_active and PostgREST '
  'bool_active resolve here. True for the active season only.';

-- 4. Anyone may read the active season; nobody writes it (ADR-083: reads only)
REVOKE ALL ON FUNCTION fn_today() FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_active_season_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION bool_active(tbl_season) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_today() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION fn_active_season_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION bool_active(tbl_season) TO anon, authenticated, service_role;

-- 5. Readers that named the column without an alias read the function instead

CREATE OR REPLACE FUNCTION public._resolve_event_prefix(p_prefix text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_event_id INT;
  v_active_season INT;
BEGIN
  v_active_season := fn_active_season_id();
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  SELECT id_event INTO v_event_id
  FROM tbl_event
  WHERE id_season = v_active_season
    AND txt_code LIKE p_prefix || '%'
  LIMIT 1;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'No event matching prefix "%" in active season', p_prefix;
  END IF;

  RETURN v_event_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_category_ranking(p_weapon enum_weapon_type, p_gender enum_gender_type, p_category enum_age_category)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_active_season INT;
BEGIN
  v_active_season := fn_active_season_id();
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(row_data ORDER BY total_score DESC), '[]'::JSONB)
    FROM (
      SELECT jsonb_build_object(
        'fencer', f.txt_surname || ' ' || f.txt_first_name,
        'total_score', ROUND(SUM(r.num_final_score), 2)
      ) AS row_data,
      SUM(r.num_final_score) AS total_score
      FROM tbl_result r
      JOIN tbl_fencer f ON r.id_fencer = f.id_fencer
      JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
      JOIN tbl_event e ON t.id_event = e.id_event
      WHERE e.id_season = v_active_season
        AND t.enum_weapon = p_weapon
        AND fn_effective_gender(f.enum_gender, t.enum_gender, t.id_event, t.enum_weapon, t.enum_age_category) = p_gender  -- ADR-034
        AND t.enum_age_category = p_category
        AND t.enum_type IN ('PPW', 'MPW')  -- domestic only
      GROUP BY f.id_fencer, f.txt_surname, f.txt_first_name
      ORDER BY total_score DESC
      LIMIT 5
    ) ranked
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_season_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_active_season INT;
BEGIN
  v_active_season := fn_active_season_id();
  IF v_active_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_code', e.txt_code,
      'event_name', e.txt_name,
      'status', e.enum_status,
      'dt_start', e.dt_start,
      'tournament_count', (SELECT COUNT(*) FROM tbl_tournament t WHERE t.id_event = e.id_event),
      'result_count', (SELECT COUNT(*) FROM tbl_result r JOIN tbl_tournament t ON r.id_tournament = t.id_tournament WHERE t.id_event = e.id_event),
      'is_international', (SELECT EXISTS(SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event AND t.enum_type IN ('PEW', 'MEW', 'MSW')))
    ) ORDER BY e.dt_start), '[]'::JSONB)
    FROM tbl_event e
    WHERE e.id_season = v_active_season
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_season_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_season INT;
BEGIN
  v_season := fn_active_season_id();
  IF v_season IS NULL THEN
    RAISE EXCEPTION 'No active season';
  END IF;

  RETURN (
    SELECT jsonb_build_object(
      'season_code', (SELECT txt_code FROM tbl_season WHERE id_season = v_season),
      'fencers', (SELECT COUNT(*) FROM tbl_fencer),
      'events', (SELECT COUNT(*) FROM tbl_event WHERE id_season = v_season),
      'tournaments', (SELECT COUNT(*) FROM tbl_tournament t
                      JOIN tbl_event e ON t.id_event = e.id_event
                      WHERE e.id_season = v_season
                        AND EXISTS(SELECT 1 FROM tbl_result r WHERE r.id_tournament = t.id_tournament)),
      'results', (SELECT COUNT(*) FROM tbl_result r
                  JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
                  JOIN tbl_event e ON t.id_event = e.id_event
                  WHERE e.id_season = v_season),
      'scored', (SELECT COUNT(*) FROM tbl_result r
                 JOIN tbl_tournament t ON r.id_tournament = t.id_tournament
                 JOIN tbl_event e ON t.id_event = e.id_event
                 WHERE e.id_season = v_season
                   AND r.num_final_score IS NOT NULL)
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_delete_season_skeleton(p_id_season integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_code   TEXT;
  v_active BOOLEAN;
  v_n      INT;
BEGIN
  SELECT s.txt_code, s.bool_active INTO v_code, v_active
    FROM tbl_season s WHERE s.id_season = p_id_season;
  IF v_code IS NULL THEN
    RAISE EXCEPTION 'fn_delete_season_skeleton: season % not found', p_id_season;
  END IF;

  -- Not-active guard: deleting the live season would blank the ranklist.
  IF v_active THEN
    RAISE EXCEPTION 'fn_delete_season_skeleton: season % is active — refused', v_code;
  END IF;

  -- Childless guard: once any event has a tournament child, results may exist.
  IF EXISTS (
    SELECT 1 FROM tbl_tournament t
      JOIN tbl_event e ON e.id_event = t.id_event
     WHERE e.id_season = p_id_season
  ) THEN
    RAISE EXCEPTION
      'fn_delete_season_skeleton: season % has events with tournament children — refused', v_code;
  END IF;

  SELECT COUNT(*)::INT INTO v_n FROM tbl_event WHERE id_season = p_id_season;

  DELETE FROM tbl_event          WHERE id_season = p_id_season;
  DELETE FROM tbl_scoring_config WHERE id_season = p_id_season;
  DELETE FROM tbl_season         WHERE id_season = p_id_season;

  RETURN jsonb_build_object('season_code', v_code, 'events_deleted', v_n);
END;
$function$;

-- 6. The one writer of the stored column stops writing it
CREATE OR REPLACE FUNCTION public.fn_create_season(p_code text, p_dt_start date, p_dt_end date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO tbl_season (txt_code, dt_start, dt_end)
  VALUES (p_code, p_dt_start, p_dt_end)
  RETURNING id_season INTO v_id;
  RETURN v_id;
END;
$function$;

-- 7. The refresh path goes (its trigger, its wrapper, the writer itself), and
--    last of all the stored flag. lint/safety/banDropColumn is the intended
--    change: nothing may read the stored copy once the computed field exists.
--    Kept last, so no statement runs while it holds ACCESS EXCLUSIVE.
DROP TRIGGER IF EXISTS trg_season_refresh_active ON tbl_season;
DROP FUNCTION IF EXISTS fn_trg_refresh_active_season();
DROP FUNCTION IF EXISTS fn_refresh_active_season();

NOTIFY pgrst, 'reload schema';

ALTER TABLE tbl_season DROP COLUMN bool_active;

COMMIT;
