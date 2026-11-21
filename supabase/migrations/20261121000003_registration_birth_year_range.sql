-- =============================================================================
-- FR-168: a registration's birth year lies inside its season's range
-- (ADR-079 amendment 2026-11-21; plan registration-form-names-year-country
-- rev 10, release 2)
-- =============================================================================
-- PROD on 21 Nov 2026 held two impossible years: 47 (the entrant typed her
-- age) and -1972 (a minus sign the number box accepted). Both were shown as V4.
-- They were corrected by hand the same day; this rule stops the next one.
--
-- The youngest year is the event's season's later year minus 30, the V0 rule
-- itself (fn_age_category gives no category under 30); the oldest is this year
-- minus 120. Both are computed on every write (fn_registration_birth_year_bounds):
-- 1906–1997 for 2026/27 in 2026, 1911–2002 for 2031/32 in 2031. The form offers only those years (frontend/src/lib/
-- birthYearRange.ts); the table refuses any other on every write path: the
-- visitor's create and edit, an administrator's direct update and the PROD →
-- CERT copy (fn_replace_event_registrations). The refusal names the range so
-- the form can show it as its own line.
--
-- Checked read-only before release: no stored entry on PROD (195) or CERT (90)
-- is outside the range. The trigger fires only when the year or the event is
-- written, so a stored row of a past season is never re-judged.
--
-- Tests: supabase/tests/131_registration_birth_year.sql (RFYEAR.07–10).
-- =============================================================================

-- The range itself, from the season's later year and a date: nothing in it is
-- a fixed year, so it moves with every season and every new year. The trigger
-- passes today's date; the tests pass fixed dates five years apart.
CREATE OR REPLACE FUNCTION fn_registration_birth_year_bounds(p_season_end_year INT, p_today DATE)
RETURNS TABLE (int_oldest INT, int_youngest INT)
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT extract(year FROM p_today::DATE)::INT - 120, p_season_end_year::INT - 30;
$$;

COMMENT ON FUNCTION fn_registration_birth_year_bounds(INT, DATE) IS
  'FR-168: the birth years a registration accepts — this year − 120 … the season''s later year − 30.';

REVOKE EXECUTE ON FUNCTION fn_registration_birth_year_bounds(INT, DATE) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION fn_registration_birth_year_range()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_youngest INT;
  v_oldest INT;
BEGIN
  SELECT b.int_oldest, b.int_youngest
    INTO v_oldest, v_youngest
    FROM tbl_event e
    JOIN tbl_season s ON s.id_season = e.id_season
   CROSS JOIN LATERAL fn_registration_birth_year_bounds(extract(year FROM s.dt_end)::INT, current_date) b
   WHERE e.id_event = NEW.id_event;

  IF v_youngest IS NULL THEN
    -- No season to read: the event's own foreign key refuses the row next.
    RETURN NEW;
  END IF;

  IF NEW.int_birth_year < v_oldest OR NEW.int_birth_year > v_youngest THEN
    RAISE EXCEPTION 'REG_BIRTH_YEAR_OUT_OF_RANGE: % outside %–%', NEW.int_birth_year, v_oldest, v_youngest
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_registration_birth_year_range() IS
  'FR-168: refuses a registration birth year outside its season''s range (later year − 30 … this year − 120).';

REVOKE EXECUTE ON FUNCTION fn_registration_birth_year_range() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_registration_birth_year_range ON tbl_registration;
CREATE TRIGGER trg_registration_birth_year_range
  BEFORE INSERT OR UPDATE OF int_birth_year, id_event ON tbl_registration
  FOR EACH ROW EXECUTE FUNCTION fn_registration_birth_year_range();
