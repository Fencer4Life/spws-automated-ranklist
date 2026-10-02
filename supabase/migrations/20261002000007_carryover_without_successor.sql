-- =============================================================================
-- A result whose event has no row in the next season yet still carries
-- =============================================================================
-- ADR-042 amendment (2026-10-02), decision S B in
-- doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html.
--
-- vw_eligible_event carried a previous-season event only through the next
-- season's row linked to it (id_prior_event), until that row is held: a
-- cancelled or not yet held edition kept carrying. An event whose next edition
-- had no row at all dropped out at once. The Criterium Mondial Vétérans 2026
-- (EVF, July 2026) fell in that gap: EVF publishes the next edition late in the
-- season, and ADR-091 forbids a placeholder row.
--
-- Branch 3 carries such an event into the season right after its own, for the
-- same window (its end date plus the season's int_carryover_days). When the
-- next edition's row appears, branch 2 takes over through the link and branch 3
-- stops, so the event is carried once. Columns and grants are unchanged.
--
-- Consumers: the four EVENT_FK_MATCHING functions (fn_fencer_scores_rolling_*,
-- fn_ranking_full_*, fn_ranking_kadra_*, fn_ranking_ppw_*), so the drilldown
-- and every ranking move together. Tests: supabase/tests/94 (CARRY.NS.01-07).
-- =============================================================================

SET LOCAL lock_timeout = '2s';

CREATE OR REPLACE VIEW vw_eligible_event AS
-- Branch 1: current-season events with results (any status that implies results exist)
SELECT
  e.id_event,
  e.id_season AS effective_season_id,
  e.id_event  AS source_event_id,
  FALSE       AS is_carried
FROM tbl_event e
WHERE e.enum_status NOT IN ('CREATED','PLANNED','SCHEDULED','CHANGED','CANCELLED')
UNION ALL
-- Branch 2: prior events linked to a non-SCORED/non-COMPLETED current slot,
--           within the carry-over window
SELECT
  prior.id_event AS id_event,
  curr.id_season AS effective_season_id,
  prior.id_event AS source_event_id,
  TRUE           AS is_carried
FROM tbl_event curr
JOIN tbl_event prior ON prior.id_event = curr.id_prior_event
JOIN tbl_season s    ON s.id_season   = curr.id_season
WHERE curr.enum_status NOT IN ('SCORED','COMPLETED')
  AND prior.enum_status NOT IN ('CREATED','PLANNED','SCHEDULED','CHANGED','CANCELLED')
  AND prior.dt_end + (s.int_carryover_days * INTERVAL '1 day') >= CURRENT_DATE
UNION ALL
-- Branch 3: held events of the season right before, whose next edition has no
--           row in this season yet, within the same carry-over window
SELECT
  prior.id_event AS id_event,
  s.id_season    AS effective_season_id,
  prior.id_event AS source_event_id,
  TRUE           AS is_carried
FROM tbl_season s
JOIN LATERAL (
  SELECT ps.id_season FROM tbl_season ps
   WHERE ps.dt_start < s.dt_start
   ORDER BY ps.dt_start DESC
   LIMIT 1
) previous ON TRUE
JOIN tbl_event prior ON prior.id_season = previous.id_season
WHERE prior.enum_status NOT IN ('CREATED','PLANNED','SCHEDULED','CHANGED','CANCELLED')
  AND NOT EXISTS (
        SELECT 1 FROM tbl_event curr
         WHERE curr.id_season = s.id_season AND curr.id_prior_event = prior.id_event)
  AND COALESCE(prior.dt_end, prior.dt_start) + (s.int_carryover_days * INTERVAL '1 day') >= CURRENT_DATE;

COMMENT ON VIEW vw_eligible_event IS
  'ADR-042: single source of truth for events contributing to a season''s '
  'rolling-score pool. is_carried=FALSE for direct current-season events; '
  'is_carried=TRUE for previous-season events, through the linked current slot '
  '(id_prior_event) until it reaches SCORED, or, while the next edition has no '
  'row yet, directly (2026-10-02 amendment). Both stop when '
  'prior.dt_end + season.int_carryover_days < today.';
