# ADR-014: Delete + Re-import in Transaction

**Status:** Accepted
**Date:** 2026-03-25 (M9)

## Context

When a tournament's results need re-importing — due to a scraper fix, source data correction, or admin request — the system must handle existing `tbl_result` rows for that tournament. The operation must also re-run identity resolution and scoring after the new data is imported.

Key constraints:
- `tbl_result` rows have `id_fencer` links established by identity resolution
- `tbl_match_candidate` rows track the matching decisions
- Audit log must capture what happened
- The system is single-operator (one admin)

## Decision

Use **delete + re-import in a single database transaction**. The full sequence within one transaction:

1. Delete all `tbl_match_candidate` rows for the tournament
2. Delete all `tbl_result` rows for the tournament
3. Re-run scraper for the tournament URL
4. Insert new `tbl_result` rows
5. Re-run identity resolution for the new results
6. Re-run scoring engine
7. Commit

On any failure, the transaction rolls back — the original data is preserved unchanged.

## Alternatives Considered

1. **Merge/upsert by scraped name** — Match new results to existing rows by `txt_scraped_name`. Complex to implement correctly: doesn't handle removed results (fencer DQ'd), renamed fencers, or changed participant counts. Partial updates leave the dataset in an inconsistent state.

2. **Soft-delete with versioning** — Keep old rows with a `version` column, insert new rows as a new version. Preserves history but doubles storage, complicates queries (must always filter by latest version), and is over-engineered for a single-operator system where the admin can simply check the audit log.

3. **Side-by-side comparison** — Import new results into a staging table, show a diff UI, let admin approve changes. Requires a complex diff UI, staging table management, and merge logic. Significant implementation effort for a scenario that occurs rarely (re-imports are exceptional, not routine).

## Consequences

- Simple, atomic, predictable — either the full re-import succeeds or nothing changes
- Identity resolution must re-run after re-import (existing `id_fencer` links are deleted with the old results)
- Previously AUTO_MATCHED fencers will likely re-match automatically (same names, same master data)
- PENDING matches will need re-review by admin
- Audit log captures the delete+reimport as a single timestamped operation
- No staging tables, versioning columns, or diff UI required
- Works identically for single-tournament and bulk re-import scenarios
