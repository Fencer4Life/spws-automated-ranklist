-- =============================================================================
-- Scoring config for SPWS-2025-2026
-- =============================================================================
-- Domestic:      4 best PPW results + MPW (always counted, not droppable)
-- International: 4 best PPW + MPW + best 3 from pooled {PEW, MEW, MSW}
--
-- Loaded automatically via data/**/*.sql glob in config.toml.
-- Alphabetically before v2_m_epee.sql (s < v) so the season config row
-- already exists when tournament data is inserted.
--
-- To add PSW to the international pool when PSW events occur:
--   {"types": ["PEW", "MEW", "MSW", "PSW"], "best": 3}
-- =============================================================================
UPDATE tbl_scoring_config
SET
  bool_mpw_droppable = FALSE,
  bool_mew_droppable = FALSE,
  num_msw_multiplier = 1.2,
  json_ranking_rules = '{
    "domestic": [
      {"types": ["PPW"], "best": 4},
      {"types": ["MPW"], "always": true}
    ],
    "international": [
      {"types": ["PPW"], "best": 4},
      {"types": ["MPW"], "always": true},
      {"types": ["PEW", "MEW", "MSW"], "best": 3}
    ]
  }'::JSONB
WHERE id_season = (
  SELECT id_season FROM tbl_season WHERE txt_code = 'SPWS-2025-2026'
);
