-- =============================================================================
-- The refresh carries PROD's results links to CERT (D2 A, ADR-117 amendment)
-- =============================================================================
-- An administrator sets an event's results links (Admin: "URL wyników") in
-- PROD's Admin; no calendar automation writes them (ADR-117). The refresh that
-- `ingest` runs first (python/pipeline/promotion/refresh.py, ADR-113 §7) reads
-- them from PROD and hands them to this function on CERT, so a plain
-- `ingest <code>` reads the link the administrator set. This is not a calendar
-- write: it copies an administrator's value between environments.
--
-- When PROD holds a link, CERT's five slots become PROD's, compacted; when
-- PROD holds none, CERT keeps its own. service_role only (ADR-083).
-- doc/plans/pzsz-results-url-rca-2026-10-25.html. pgTAP CALURL.22.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_copy_event_result_links(p_event_code TEXT, p_links JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id  INT;
  v_old TEXT[];
  v_new TEXT[];
BEGIN
  SELECT e.id_event,
         ARRAY[e.url_event, e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5]
    INTO v_id, v_old
    FROM tbl_event e
   WHERE e.txt_code = p_event_code;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'fn_copy_event_result_links: no event %', p_event_code;
  END IF;

  v_new := fn_compact_urls(p_links ->> 'url_event', p_links ->> 'url_event_2',
                           p_links ->> 'url_event_3', p_links ->> 'url_event_4',
                           p_links ->> 'url_event_5');
  IF v_new[1] IS NULL THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'PROD holds no results link');
  END IF;
  IF v_new IS NOT DISTINCT FROM v_old THEN
    RETURN jsonb_build_object('changed', false, 'reason', 'equal to PROD');
  END IF;

  UPDATE tbl_event
     SET url_event   = v_new[1],
         url_event_2 = v_new[2],
         url_event_3 = v_new[3],
         url_event_4 = v_new[4],
         url_event_5 = v_new[5]
   WHERE id_event = v_id;
  RETURN jsonb_build_object('changed', true, 'from', to_jsonb(v_old), 'to', to_jsonb(v_new));
END;
$$;

REVOKE EXECUTE ON FUNCTION fn_copy_event_result_links(TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION fn_copy_event_result_links(TEXT, JSONB) TO service_role;
