-- =============================================================================
-- M4: Make tbl_result.id_fencer nullable for identity resolution workflow
-- =============================================================================
-- Scrapers import results before identity resolution runs. During that window,
-- id_fencer is NULL (unknown fencer). The matcher pipeline later links fencers.
-- Also add txt_scraped_name to tbl_result to preserve the original scraped name.
-- =============================================================================

-- Allow NULL id_fencer on tbl_result (unmatched results)
ALTER TABLE tbl_result ALTER COLUMN id_fencer DROP NOT NULL;

-- Store the original scraped name so the matcher can work on it
ALTER TABLE tbl_result ADD COLUMN txt_scraped_name TEXT;

-- Drop the existing unique constraint (id_fencer, id_tournament) because
-- NULL id_fencer rows would not be caught by it. Replace with a partial
-- unique index that only applies when id_fencer IS NOT NULL.
ALTER TABLE tbl_result DROP CONSTRAINT IF EXISTS uq_result_fencer_tournament;

CREATE UNIQUE INDEX uq_result_fencer_tournament
    ON tbl_result (id_fencer, id_tournament)
    WHERE id_fencer IS NOT NULL;

-- Unique constraint for scraped names within a tournament (idempotency)
CREATE UNIQUE INDEX uq_result_scraped_name_tournament
    ON tbl_result (txt_scraped_name, id_tournament)
    WHERE txt_scraped_name IS NOT NULL;
