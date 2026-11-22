-- =============================================================================
-- FR-176 — an organiser reads an event's declared revenue from a link with a key
-- =============================================================================
-- Plan doc/plans/event-revenue-forecast-2026-11-22.html, rev 3.
--
-- tbl_event_report_token       one live key per event; replaced, never deleted.
-- fn_registration_fee          the one fee rule (tier price, else the one-weapon
--                              fee times the weapons, else nothing).
-- fn_issue_event_report_token  a signed-in administrator creates or replaces it.
-- fn_event_revenue_report      what the report page reads: NULL for a key that
--                              is not the event's live key, otherwise the fees
--                              and one object per entry. Never a birth year,
--                              club, e-mail hash, edit token, country or
--                              fencer id.
-- =============================================================================

SET lock_timeout = '2s';

-- FR-176: the report key. One live key per event; replaced, never deleted.
CREATE TABLE IF NOT EXISTS tbl_event_report_token (
  uuid_token UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_event   INT NOT NULL REFERENCES tbl_event (id_event) ON DELETE CASCADE,
  ts_created TIMESTAMPTZ NOT NULL DEFAULT now(),
  ts_revoked TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_event_report_token_live
  ON tbl_event_report_token (id_event) WHERE ts_revoked IS NULL;
ALTER TABLE tbl_event_report_token ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admin reads event report tokens" ON tbl_event_report_token;
CREATE POLICY "Admin reads event report tokens" ON tbl_event_report_token
  FOR SELECT USING (auth.role() = 'authenticated');
REVOKE ALL ON TABLE tbl_event_report_token FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE tbl_event_report_token TO authenticated, service_role;
COMMENT ON TABLE tbl_event_report_token IS
  'FR-176: the per-event key that opens the revenue report. One live row per event (ts_revoked IS NULL); a replaced key is stamped, never deleted. A signed-in administrator reads it; it is written only by fn_issue_event_report_token.';

-- The one fee rule (R1, R2). NULL when nothing can be quoted.
CREATE OR REPLACE FUNCTION fn_registration_fee(
  p_weapons INT, p_fee NUMERIC, p_fee_2w NUMERIC, p_fee_3w NUMERIC)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE p_weapons
           WHEN 1 THEN p_fee
           WHEN 2 THEN COALESCE(p_fee_2w, p_fee * 2)
           WHEN 3 THEN COALESCE(p_fee_3w, p_fee * 3)
         END;
$$;
REVOKE ALL ON FUNCTION fn_registration_fee(INT, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_registration_fee(INT, NUMERIC, NUMERIC, NUMERIC) TO authenticated, service_role;
COMMENT ON FUNCTION fn_registration_fee(INT, NUMERIC, NUMERIC, NUMERIC) IS
  'FR-176: the fee of an entry by its number of weapons: the tier price when set, else the one-weapon fee times the weapons, else NULL (also NULL for 0 or more than 3 weapons). Not visitor-callable.';

-- A signed-in administrator creates the event's key, or replaces it.
CREATE OR REPLACE FUNCTION fn_issue_event_report_token(p_id_event INT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_token UUID;
BEGIN
  IF auth.role() IS DISTINCT FROM 'authenticated' THEN
    RAISE EXCEPTION 'REPORT_TOKEN_ADMIN_ONLY' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM tbl_event e
                  WHERE e.id_event = p_id_event AND e.bool_use_spws_registration) THEN
    RAISE EXCEPTION 'REPORT_NEEDS_SPWS_REGISTRATION';
  END IF;
  UPDATE tbl_event_report_token SET ts_revoked = now()
   WHERE id_event = p_id_event AND ts_revoked IS NULL;
  INSERT INTO tbl_event_report_token (id_event) VALUES (p_id_event)
  RETURNING uuid_token INTO v_token;
  RETURN v_token;
END; $$;
REVOKE ALL ON FUNCTION fn_issue_event_report_token(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_issue_event_report_token(INT) TO authenticated, service_role;
COMMENT ON FUNCTION fn_issue_event_report_token(INT) IS
  'FR-176: a signed-in administrator creates the event''s report key, or replaces it (the old key is stamped ts_revoked). Refused for an event without our registration. Not visitor-callable.';

-- What the report page reads. NULL for a key that is not this event's live key.
CREATE OR REPLACE FUNCTION fn_event_revenue_report(p_id_event INT, p_token UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v JSONB;
BEGIN
  IF p_token IS NULL OR NOT EXISTS (
       SELECT 1 FROM tbl_event_report_token t
        WHERE t.uuid_token = p_token AND t.id_event = p_id_event AND t.ts_revoked IS NULL) THEN
    RETURN NULL;
  END IF;
  SELECT jsonb_build_object(
    'ts_generated', now(),
    'currency', COALESCE(NULLIF(btrim(e.txt_entry_fee_currency), ''), 'PLN'),
    'fees', jsonb_build_object(
      '1', fn_registration_fee(1, e.num_entry_fee, e.num_entry_fee_2w, e.num_entry_fee_3w),
      '2', fn_registration_fee(2, e.num_entry_fee, e.num_entry_fee_2w, e.num_entry_fee_3w),
      '3', fn_registration_fee(3, e.num_entry_fee, e.num_entry_fee_2w, e.num_entry_fee_3w),
      'fallback_2', e.num_entry_fee_2w IS NULL, 'fallback_3', e.num_entry_fee_3w IS NULL),
    'entries', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id_registration', r.id_registration,
               'txt_surname', r.txt_surname, 'txt_first_name', r.txt_first_name,
               'enum_gender', r.enum_gender,
               'enum_age_category', fn_age_category(r.int_birth_year::INT, EXTRACT(year FROM s.dt_end)::INT),
               'arr_weapons', to_jsonb(r.arr_weapons),
               'num_fee', fn_registration_fee(cardinality(r.arr_weapons), e.num_entry_fee, e.num_entry_fee_2w, e.num_entry_fee_3w))
             ORDER BY r.id_registration)
        FROM tbl_registration r WHERE r.id_event = e.id_event), '[]'::jsonb))
    INTO v
    FROM tbl_event e JOIN tbl_season s ON s.id_season = e.id_season
   WHERE e.id_event = p_id_event;
  RETURN v;
END; $$;
REVOKE ALL ON FUNCTION fn_event_revenue_report(INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_event_revenue_report(INT, UUID) TO anon, authenticated, service_role;
COMMENT ON FUNCTION fn_event_revenue_report(INT, UUID) IS
  'FR-176: the event revenue report for the holder of its live key: the currency, the three tier fees and one object per entry (name, gender, category, weapons, fee). NULL for any other key. Never a birth year, club, e-mail hash, edit token, country or fencer id. STABLE; writes nothing.';
