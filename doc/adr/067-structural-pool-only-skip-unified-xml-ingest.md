# ADR-067: Structural pool-only skip + unified XML ingest pipeline

**Status:** Implemented
**Date:** 2026-05-27
**Source:** User bug report 2026-05-27 (PPW4-V1-M-EPEE-2025-2026 / PPW5-V1-M-EPEE-2025-2026 showing 35 / 36 phantom participant counts)
**Related ADRs:** ADR-024 (Combined Category Splitting), ADR-034 (Cross-Gender Tournament Scoring), ADR-049 (Joint-pool split flag), ADR-050 (Phase 0 rebuild), ADR-055 (Ingest traceability), ADR-056 (V-cat assignment from birth year)

## Context

The SPWS ingest pipeline had two parallel XML-ingestion paths that diverged in behaviour:

1. **URL-scrape path** (`review_cli.py` → `run_pipeline` → `DraftStore` → `fn_commit_event_draft`) — runs the full S1-S7 pipeline, materializes drafts, and commits via the joint-pool-aware RPC.
2. **Legacy direct-write path** (`ingest_cli.run_ingest` → `orchestrator.process_xml_file`) — writes straight to `tbl_tournament` and `tbl_result`, bypassing `fn_commit_event_draft` entirely.

The legacy path was self-documented as "Phase 6 deletes this function entirely once review_cli.py + run_pipeline own the operational rebuild." Phase 6 never happened.

Independent of the two-path problem, SPWS FT-XML exports include two file kinds that look superficially identical:
- **ELIMINACJE qualifier files** (`<Poule>` elements only, no `<Tableau>`) — pool-round results that determine V-cat bracket seeding, not ranklist-relevant placements.
- **Per-V-cat DE bracket files** (`<Tableau>` elements present) — the actual ranking-relevant placements.

Both kinds were being ingested as if they contributed to scoring, with the splitter carving 47-fencer eliminacje pools into phantom V0-V4 buckets that did not correspond to any real bracket. On PPW4-V1-M-EPEE-2025-2026 and PPW5-V1-M-EPEE-2025-2026, this surfaced as `int_participant_count = 35 / 36` (POL-only sum across phantom siblings via the joint-pool re-sum logic).

## Decision

Three coordinated changes:

1. **Retire `process_xml_file` as the operational path.** Add `ingest_xml_unified(path, event_code, season_end_year, …)` to `python/pipeline/ingest_cli.py` which builds a `ParsedTournament` IR, runs the S1-S7 pipeline via `run_pipeline`, and materializes drafts via `DraftStore`. The caller commits via the existing `--commit-draft <run_id>` flag. The legacy `process_xml_file` is marked `@deprecated` with a runtime `DeprecationWarning` pointing at the replacement; deletion in a follow-up cycle.

2. **Structural pool-only skip.** Add `is_pool_only_qualifier: bool` to the `ParsedTournament` IR. The FT XML parser sets it based purely on data structure: **`<Poule>` present AND `<Tableau>` absent** (i.e. *has-pool-no-tableau*). `s1_validate_ir` halts with `HaltReason.POOL_ROUND_DETECTED` when set. Detection never relies on `AltName`, `Sexe`, or filename — those vary across organizers and years.

3. **Per-file URL fragments + Polish `kat. N` regex + ADR-34 gender default.** The unified XML ingest sets `source_url = "<url_event>#<filename>"` so each XML's draft rows share `url_results` only with siblings *from the same file* (legitimate combined-bracket joint pools), never across files (standalone V-cat brackets). The FT XML AltName regex recognizes both `vN` and the newer `kat. N` Polish convention. Per ADR-34, brackets where the parser cannot determine gender (e.g. `Sexe="X"` with no Polish gender keyword in AltName) are NOT halted; `s1_validate_ir` allows `gender=None` and the draft writer defaults to `'M'` (the `enum_gender` NOT NULL column accepts it; `fn_effective_gender` reassigns women's points at query time).

## Alternatives Considered

- **Name-based skip (filename or AltName)** — rejected per user instruction 2026-05-27: organizer naming conventions are unreliable across events and years. Structural detection on the actual data is the only durable signal.
- **Patch `process_xml_file` in place instead of retiring it** — rejected because keeping two parallel paths has been the source of every divergence bug since Phase 3. One ingestion machine, two entry points.
- **Add a new `enum_gender` value (`'X'` or `'MIXED'`)** — rejected because ADR-34 already specifies the cross-gender semantics at ranking-query time. Adding an enum value would require migrating every ranking function; defaulting to `'M'` keeps the schema stable.
- **Use a per-V-cat FTL URL where available, file:// otherwise** — deferred. For PPW5 we have per-V-cat FTL URLs from the event-schedule scrape; for PPW4 we have only the event URL. A follow-up can refine `url_results` to per-V-cat FTL URLs where the event-schedule provides them.

## Consequences

**Positive:**
- PPW4 / PPW5 2025-26 participant counts now reflect the real DE bracket pool size (10 / 8 for V1 M-Epee instead of phantom 35 / 36) and match FTL per-V-cat brackets exactly where FTL data is available.
- The bug class is structurally impossible to reproduce: any future eliminacje file gets skipped at the parser level regardless of filename, and any future legacy-path caller gets a clear migration warning.
- One ingestion machine; new parsers extend the IR contract, no parallel "legacy" branches.

**Negative / trade-offs:**
- The default-to-`'M'` for gender-undetermined brackets relies on ADR-34's query-time reassignment. If `fn_effective_gender` has bugs or is bypassed by a custom report query, women's points in gender-ambiguous brackets could be miscounted. Mitigation: existing fn_effective_gender tests, plus the draft writer logs `txt_source_url_used` to the ingest history for audit.
- The `url_event#filename` URL pattern leaks the source-file structure into a user-visible column. Acceptable trade-off because the URL is still clickable to the event page (browsers honour only the first `#`), but a follow-up can replace `#filename` with the per-V-cat FTL UUID where available.

## Implementation

- Commits: `b4dc173`, `93a2771`, `347eb19` on branch `fix/xml-ingest-unified-pipeline`.
- Tests: `python/tests/test_ingest_cli_unified.py` (4 assertions), `python/tests/test_pool_only_skip.py` (8 assertions), updated `python/tests/test_ir.py` (contract).
- LOCAL re-ingest verified: PPW4 24 tournaments / 87 results, PPW5 22 tournaments / 81 results. CERT/PROD promotion is operator-driven and out of scope for this ADR.
