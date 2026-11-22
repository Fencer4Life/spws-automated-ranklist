-- FR-171 (plan evf-ranking-country-lomianki-2026-11-21, rev 1, D1 A): what the
-- monthly read of the EVF ranking keeps of each ranked fencer, so an entry
-- without a country can be filled from it (python/tools/fill_registration_country.py).
--
-- EVF id, names, gender, category and country, as EVF publishes them; never
-- points, place or birth date (the public ranking carries none). The table is
-- created empty and filled only by the job (evf-ranking-sync.yml): real names
-- are never committed. Nobody but the jobs reads it: row security on, no grant
-- to a visitor or a signed-in user.

SET lock_timeout = '2s';

CREATE TABLE IF NOT EXISTS tbl_evf_ranking_fencer (
  -- EVF's own fencer id, a UUID on every row of the ranking.
  id_evf         UUID PRIMARY KEY,
  txt_surname    TEXT NOT NULL,
  txt_first_name TEXT NOT NULL,
  enum_gender    enum_gender_type NOT NULL,
  int_category   SMALLINT NOT NULL CHECK (int_category BETWEEN 1 AND 4),
  -- As EVF writes it: a fencing code, or EVF's own OTH, which is not one.
  txt_country    TEXT NOT NULL CHECK (txt_country ~ '^[A-Z]{3}$'),
  ts_read        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tbl_evf_ranking_fencer IS
  'FR-171: each fencer on the EVF ranking as last read by evf-ranking-sync.yml (EVF id, names, gender, '
  'category, country). Fills the country of an entry that has none; links nothing. Read by the jobs only.';

ALTER TABLE tbl_evf_ranking_fencer ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tbl_evf_ranking_fencer FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON tbl_evf_ranking_fencer TO service_role;
