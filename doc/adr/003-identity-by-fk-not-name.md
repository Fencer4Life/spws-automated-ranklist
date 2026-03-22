# ADR-003: Identity by FK, not by Name

**Status:** Accepted
**Date:** 2025-03-02 (M4)

## Context

The legacy Excel workbook uses XLOOKUP on fencer name strings to cross-reference results across tournament sheets. This breaks silently when names have typos, diacritical variations, or format differences between sources.

## Decision

Replace name-based lookups with an `id_fencer` foreign key in `tbl_result` pointing to `tbl_fencer`. A fuzzy matching pipeline (RapidFuzz `token_sort_ratio`) resolves scraped names to fencer IDs at import time.

## Consequences

- Fencer identity is a stable numeric ID, not a fragile string
- `tbl_fencer` is the single source of truth for identity (270 SPWS members)
- Name corrections in `tbl_fencer` don't break existing `id_fencer` links
- Ranking views join on integer FK — fast and unambiguous
- `tbl_result.id_fencer` is nullable: scrapers insert with NULL, the matcher links afterwards
- `tbl_result.txt_scraped_name` preserves the original scraped name for audit
- Unmatched names create `tbl_match_candidate` rows for admin review
- Trade-off: requires the identity resolution pipeline (M4) as a prerequisite for scoring
