-- =============================================================================
-- Migration: fn_event_position
-- =============================================================================
-- ADR-018: Rolling Score for Active Season
-- Extracts the position prefix from an event code (e.g. PPW1-2024-2025 → PPW1).
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_event_position(p_code TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$ SELECT split_part(p_code, '-', 1) $$;
