-- =============================================================================
-- Migration: vw_eligible_event view
-- =============================================================================
-- Phase 1B step 5 — single source of truth for "what events contribute to a
-- season's rolling-score pool". Replaces the prefix-based completed_positions
-- + carried_eligible CTEs in the legacy engine.
--
-- Two branches:
--   1. Direct  — current-season events whose status implies results exist
--                (NOT in the not-yet-happened or cancelled bucket).
--   2. Carried — prior-season events linked via id_prior_event to a current-
--                season slot whose status is NOT yet SCORED or COMPLETED, AND
--                whose dt_end + season.int_carryover_days >= today.
--
-- Carry-stop trigger: when the linked current slot reaches SCORED (so prior
-- carry stops as soon as current results are available, before the formal
-- COMPLETED transition).
-- =============================================================================

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
  AND prior.dt_end + (s.int_carryover_days * INTERVAL '1 day') >= CURRENT_DATE;

GRANT SELECT ON vw_eligible_event TO anon, authenticated;

COMMENT ON VIEW vw_eligible_event IS
  'Phase 1B / ADR-042: single source of truth for events contributing to a '
  'season''s rolling-score pool. is_carried=FALSE for direct current-season '
  'events; is_carried=TRUE for prior-season events linked via id_prior_event. '
  'Carry stops when the linked current slot reaches SCORED, OR when '
  'prior.dt_end + season.int_carryover_days < today.';
