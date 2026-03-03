-- =============================================================================
-- M1 Migration: Row-Level Security Policies (§9.2.1)
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE tbl_season ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_scoring_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_fencer ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_organizer ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_tournament ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_result ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_match_candidate ENABLE ROW LEVEL SECURITY;
ALTER TABLE tbl_audit_log ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Anonymous (public) — SELECT only
-- ---------------------------------------------------------------------------
CREATE POLICY "Public read seasons"     ON tbl_season         FOR SELECT USING (true);
CREATE POLICY "Public read config"      ON tbl_scoring_config FOR SELECT USING (true);
CREATE POLICY "Public read fencers"     ON tbl_fencer         FOR SELECT USING (true);
CREATE POLICY "Public read organizers"  ON tbl_organizer      FOR SELECT USING (true);
CREATE POLICY "Public read events"      ON tbl_event          FOR SELECT USING (true);
CREATE POLICY "Public read tournaments" ON tbl_tournament     FOR SELECT USING (true);
CREATE POLICY "Public read results"     ON tbl_result         FOR SELECT USING (true);

-- No public read on match_candidate (admin-only data)
-- No public read on audit_log (admin-only data)

-- ---------------------------------------------------------------------------
-- Authenticated (admin) — Full CRUD
-- ---------------------------------------------------------------------------
CREATE POLICY "Admin all seasons"     ON tbl_season         FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all config"      ON tbl_scoring_config FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all fencers"     ON tbl_fencer         FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all organizers"  ON tbl_organizer      FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all events"      ON tbl_event          FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all tournaments" ON tbl_tournament     FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all results"     ON tbl_result         FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin all matches"     ON tbl_match_candidate FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Admin read audit"      ON tbl_audit_log      FOR SELECT USING (auth.role() = 'authenticated');
