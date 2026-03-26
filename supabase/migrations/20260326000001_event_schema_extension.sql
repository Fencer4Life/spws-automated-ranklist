-- =============================================================================
-- T8.1: tbl_event Schema Extension (FR-48)
-- =============================================================================
-- Adds 4 new nullable columns to tbl_event for calendar display and admin
-- event management. All columns nullable, no defaults — backward compatible.
-- =============================================================================

ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS txt_country TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS txt_venue_address TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS url_invitation TEXT;
ALTER TABLE tbl_event ADD COLUMN IF NOT EXISTS num_entry_fee NUMERIC;
