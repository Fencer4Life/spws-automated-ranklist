-- =============================================================================
-- Drop stale function overloads created by migrations 000002 and 000005.
--
-- Migrations 000005 and 000007 added parameters to fn_create_event and
-- fn_update_event using CREATE OR REPLACE, but since the parameter lists
-- differ, PostgreSQL created overloads instead of replacing. This causes
-- ambiguous function calls and fingerprint divergence between environments.
--
-- Keep only the latest (most complete) signatures from migration 000007.
-- =============================================================================

-- fn_create_event: drop 12-param (from 000002) and 13-param (from 000005)
DROP FUNCTION IF EXISTS fn_create_event(
  TEXT, TEXT, INT, INT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC
);
DROP FUNCTION IF EXISTS fn_create_event(
  TEXT, TEXT, INT, INT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT
);

-- fn_update_event: drop 10-param (from 000002) and 12-param (from 000005)
DROP FUNCTION IF EXISTS fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC
);
DROP FUNCTION IF EXISTS fn_update_event(
  INT, TEXT, TEXT, DATE, DATE, TEXT, TEXT, TEXT, TEXT, NUMERIC, TEXT, INT
);
