# ADR-047: V-cat invariant trigger + combined-pool splitter consolidation

**Status:** Accepted (LOCAL: Layers 1–6 implemented + 8 row-level deletes applied; CERT/PROD: NOTICE-only trigger + view migrations pending; FATAL flip pending full re-scrape)
**Date:** 2026-04-30
**Relates to:** ADR-024 (Combined Category Splitting), ADR-022 (Ingestion Transaction Strategy)

## Context

The combined-pool ingestion bug discovered 2026-04-29 produced 209 V-cat-mismatched result rows on LOCAL (and corresponding rows on CERT/PROD). Root cause: only the FencingTime XML path had a per-V-cat splitter; FTL JSON, Engarde HTML, 4Fence, Dartagnan, and CSV/xlsx paths dumped the entire combined pool into whichever V-cat tournament admin had pasted the URL onto.

Two distinct symptoms presented:
1. **Combined-pool corruption** — a V0+V1 pool with 6 fencers ended up duplicated across both V0 and V1 tournaments, producing 178 dupe rows on LOCAL.
2. **V-cat-vs-BY mismatch** — each fencer's `tbl_tournament.enum_age_category` disagreed with `fn_age_category(int_birth_year, season_end_year)` for either intentional reasons (admin error) or unintentional reasons (combined-pool corruption).

Layer 5 of the fix introduced a read-only admin view; Layer 2 introduced a NOTICE-only trigger; Layer 6 was supposed to flip the trigger to RAISE EXCEPTION after a one-shot replay tool moved the corrupted rows. The replay tool's BY-derived "move-to-correct-V-cat" logic later proved partially wrong (Stockholm-class fabrications surfaced — see ADR-048), and the round-2 orphan moves were fully reversed.

## Decision

### Splitter consolidation
A single Python module `python/pipeline/age_split.py` exports both `split_combined_results(...)` (the original ADR-024 splitter) and `birth_year_to_vcat(birth_year, season_end_year)` (a pure helper). Every ingestion path imports from this module instead of inlining its own logic:
- `python/scrapers/fencingtime_xml.py` re-exports the symbols for backward compatibility.
- `python/tools/scrape_tournament.py` reads sibling V-cat tournaments sharing a URL, calls `split_combined_results` with the canonical fencer DB, and ingests per-V-cat.
- `python/scrapers/evf_sync.py` adds a Layer 1E defensive `WARN` cross-check between EVF's `categoryId` and the BY-derived V-cat. **No reassignment** in EVF flow — EVF API is per-category by design, so a mismatch indicates either a fabricated SPWS-DB row or a wrong BY, not a splitter bug.
- `python/tools/import_results.py` left untouched ("no-op by design") — its admin convention is per-V-cat-source-file; the trigger is the safety net.

### Database invariant (NOTICE → FATAL)
Migration `20260429000004_assert_result_vcat_trigger.sql` installs:
- `fn_vcat_violation_msg(birth_year, tour_vcat, season_end_year, fencer_name, tour_code) RETURNS TEXT` — a pure expression-only helper that returns the violation message (or NULL when consistent). Tested in pgTAP (23.1–23.5).
- `fn_assert_result_vcat()` trigger function calling the helper.
- `trg_assert_result_vcat` `BEFORE INSERT OR UPDATE OF id_fencer, id_tournament` on `tbl_result`, NOTICE-only mode.

Migration `20260430000002_assert_result_vcat_fatal.sql` flips the trigger to `RAISE EXCEPTION`. **Applied on LOCAL only**; CERT/PROD pending until full re-scrape clears all V-cat-violating rows.

### Admin surface
Migration `20260430000001_vw_vcat_violation.sql` adds the view `vw_vcat_violation` exposing every result row whose tournament V-cat disagrees with `fn_age_category(BY, season_end_year)`, plus the formatted message identical to the trigger output. Re-used by `python/tools/audit_vcat_violations.py` for read-only admin sweeps.

### Test fixture bypass
9 pgTAP test files (`01_database_foundation`, `02_scoring_engine`, `03_views_api`, `07_auth_revoke`, `08_crud_functions`, `09_rolling_score`, `10_ingest_pipeline`, `11_identity_resolution`, `19_phase3_wizard`) wrap their setup in `ALTER TABLE tbl_result DISABLE TRIGGER trg_assert_result_vcat;` to keep their arbitrary-V-cat fixtures functional. Targeted disable (not `session_replication_role = replica`) preserves audit + status-transition triggers.

## Alternatives considered

- **Per-path inline splitter** — rejected; drift across paths was the original bug, consolidation is the fix.
- **Auto-reassign on trigger fire** — rejected; reassignment means writing to a sibling tournament, which would need application-level logic in a DB trigger. Trigger only validates.
- **`session_replication_role = replica` for test bypass** — rejected; bypassed too many triggers (audit, status-transition validators), broke unrelated tests.
- **In-DB redo via the BY-derived splitter** (the abandoned Layer 6 round-2 approach) — partially executed then reversed. The audit (ADR-048) showed BY math is not always correct; in-DB redo without source verification produces phantoms.

## Consequences

- Future combined-pool ingest cannot duplicate rows across V-cats; the splitter is single-source-of-truth.
- The trigger blocks any future write that would create a V-cat-vs-BY mismatch, once flipped to FATAL.
- Test files require explicit trigger-disable for legacy fixtures using arbitrary V-cats. New tests should use V-cat-consistent BYs.
- LOCAL data state: 0 V-cat invariant violators after Layers 1–6 + 8 row-level deletes. Per-season counts: 23/290/1086 (2023-24); 17/237/843 (2024-25); 20/229/720 (2025-26).
- CERT/PROD still hold the original violators; replication via seed-remote.sh is the chosen path (see development_history.md 2026-04-30 entry).

## Tests

- pgTAP `23_assert_result_vcat_trigger.sql` — 7 tests (helper branches + FATAL trigger smoke).
- pgTAP `24_vw_vcat_violation.sql` — 4 tests (view shape + violator surfacing).
- pytest `test_age_split.py` — 13 tests (V-cat boundaries + FTL-shape splitter).
- pytest `test_audit_vcat_violations.py` — 7 tests (CLI summary shapes).
- pytest `test_scrape_tournament.py` — 4 new tests (idempotency + Telegram).
- vitest `TournamentManager.test.ts` test 9.312 — sibling-shared URL contract.
