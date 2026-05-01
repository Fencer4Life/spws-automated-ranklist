# SuperFive Pool Results (Phase 3 backlog)

*Extracted from Project Specification §9.8 + Appendix B in Phase 0.5 (2026-05-01). Implementation deferred to Phase 3.*

SuperFive is a separate ranking based on **pool-round performance** (not DE/placement results). It relates only to PPW pool rounds (Pool 1 and Pool 2). A dedicated table will store pool-level metrics.

## Proposed schema: `tbl_pool_result`

```mermaid
erDiagram
    tbl_pool_result {
        SERIAL id_pool_result PK
        INT id_fencer FK "→ tbl_fencer"
        INT id_tournament FK "→ tbl_tournament (PPW only)"
        INT int_pool_number "1 or 2"
        INT int_victories "Wins in the pool"
        INT int_matches "Total bouts in the pool"
        INT int_touches_scored "TS"
        INT int_touches_received "TR"
        INT int_indicator "TS − TR"
        NUMERIC num_vm_ratio "V/M — victories ÷ matches"
        TIMESTAMPTZ ts_created
    }

    tbl_fencer ||--o{ tbl_pool_result : "has pool results"
    tbl_tournament ||--o{ tbl_pool_result : "contains pool results"
```

## Proposed view: `vw_ranking_superfive` (Phase 3)

- Filters to PPW tournaments only
- Aggregates pool metrics across the season
- Ranking criteria and aggregation rules to be defined during Phase 3 implementation

## Implementation note

SuperFive scraping requires different parsing logic than DE/placement results. Separate scraper modules will be developed in Phase 3.

## Cross-references

- Project Specification §9.8 (placeholder pointing here)
- Project Specification Phase 3 backlog (Implementation Phasing in `doc/development_history.md`)
