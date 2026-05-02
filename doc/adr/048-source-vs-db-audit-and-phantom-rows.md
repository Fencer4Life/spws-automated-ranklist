# ADR-048: Source-vs-DB audit + phantom-row policy

**Status:** Accepted; tooling in place. Bulk phantom-row resolution deferred to the from-scratch re-scrape.
**Date:** 2026-04-30
**Relates to:** ADR-024 (Combined Category Splitting), ADR-047 (V-cat invariant trigger)

## Context

The V-cat invariant guard from ADR-047 catches a specific class of bug — fencer placed in a tournament whose `enum_age_category` disagrees with `fn_age_category(BY, season_end_year)`. It does not catch a different, larger class: result rows for fencers who **never appeared in the source** at all.

Discovered 2026-04-30 while resolving the last 9 V-cat orphan moves: GRODNER Michał had a `tbl_result` row in `PEW5ef-V4-M-EPEE-2025-2026` (Stockholm), but cross-checking against the live Engarde URL (`https://engarde-service.com/competition/sthlm/vet2026/me*`) showed no GRODNER in any V-cat fencer list. The row was fabricated by an earlier ingest. The same pattern was found for NOWAK Szymon (PEW6efs), KAZIK Martin (IMEW women's sabre), BORKOWSKI Andrzej (PEW10), BAZAK Jacek (PEW2) and others.

A full vendor-source audit on LOCAL (2655 result rows, 538 unique URLs across FTL / Engarde / 4Fence / Dartagnan / EVF API) found:
- 1948 OK matches (73 %)
- 37 weak matches (low-confidence fuzzy hit, mostly diacritic noise)
- 670 phantom rows (URL fetched + parsed but DB fencer not present, OR URL missing/broken)

670 phantoms broke down further: 291 `name_not_in_source` (URL works, fencer simply isn't there), 221 `no_url` (no source to check), 158 URL/parse errors. Phantom rows are **not** an international-only problem — domestic events held 309 phantoms, international 317.

## Decision

### Audit tooling

**`python/tools/audit_vcat_violations.py`** — read-only CLI surface for `vw_vcat_violation` (V-cat invariant violators).

**Source-vs-DB audit script** — kept at `/tmp/source_audit.py` for one-shot use; logic is to be folded into a permanent `python/tools/audit_phantom_rows.py` after the from-scratch re-scrape lands. The script:
1. Pulls every `(id_result, fencer_name, tournament_code, url_results)` from LOCAL via docker exec psql.
2. Groups by URL; loads the FTL audit cache (`/tmp/ppw_audit_ftl_data.json`); for each non-cached URL, fetches live (FTL with auth, Engarde / 4Fence / Dartagnan plain HTTP, EVF API).
3. Parses each into a `[fencer_name]` list using the platform-specific parser already in `python/scrapers/`.
4. For each DB row: diacritic-fold + uppercase + token-Jaccard + surname-prefix bonus. Threshold ≥ 85 = OK; 60–84 = WEAK_MATCH; < 60 = PHANTOM.

### Verdict policy

Per user direction (2026-04-30): URL-error / no-URL / unsupported-platform / parse-error all collapse into **PHANTOM**. Reason captured separately for diagnostics. Rationale: any condition where the source can't confirm the fencer is the same evidence — no source backing.

### Per-row deletion discipline

Phantom rows are not auto-deleted. The historical `feedback_no_delete_without_asking.md` memory rule (deleted 2026-05-02; will be reintroduced post-rebuild) required explicit per-row admin approval before any tournament/result/event delete. The 8 deletes applied 2026-04-30 (GRODNER 7913, NOWAK 8010, KAZIK 10096, BORKOWSKI 10410, BAZAK 10472, OWCZAREK 9217, LIPKOWSKA 9298, KOWALSKA 9299, plus PAWŁOWSKI's ineligible PEW6efs row 8014) were each individually authorised after the user verified against the source URL.

### "Results lost" event flag — deferred

Some events have legitimate `no_url` (e.g. PPW1-2025-2026, where the original results were lost and the data was ingested from xlsx — ADR-024 § "Standing exception"). The audit currently treats every `no_url` as PHANTOM, producing false positives for these events.

A future schema field `tbl_event.bool_results_lost` (or equivalent) would let the audit exclude legitimately-no-URL events. Deferred until after the from-scratch re-scrape, when the full set of events is known.

### Joint-pool reference field — superseded by ADR-049

Original proposal here was a self-referential FK `tbl_tournament.id_joint_pool_parent`. That design was implemented and reverted on 2026-04-30 in favour of a simpler boolean `bool_joint_pool_split` recorded by the ingester at write time. See ADR-049 for the accepted design and rationale.

## Alternatives considered

- **Auto-delete phantoms** — rejected; would have nuked legitimately-no-URL events (PPW1-2025-2026 etc.) and the user has explicitly forbidden auto-deletes.
- **Trust DB BY over source** — rejected; the GRODNER / NOWAK / PAWŁOWSKI / KAZIK / BORKOWSKI / BAZAK / OWCZAREK / LIPKOWSKA / KOWALSKA cases prove BY math is not a reliable source-of-truth when individual fencer BYs are wrong. Source is the ground truth.
- **Round-2 of the V-cat replay (BY-derived "move-to-correct-cat" + create missing siblings)** — implemented and reverted within the same session. The Stockholm verification proved the moves were fabricating rows where the source had nothing.

## Consequences

- LOCAL data state, post-cleanup: 0 V-cat invariant violators; 8 confirmed-fabricated rows deleted; 670 audit-flagged phantoms remaining (deferred to re-scrape).
- CERT and PROD seeded from LOCAL on 2026-04-30 — they hold the same intermediate state. The 670 phantoms are inherited.
- Layer 6 FATAL flip applied to LOCAL only. CERT/PROD still on NOTICE-only mode pending the re-scrape to clear phantoms first.
- The `replay_vcat_violations.py` tool is committed but flagged "do NOT re-run without reading ADR-047" in its docstring.

## Tests

- pytest `test_audit_vcat_violations.py` — 7 tests covering CLI summary shapes (counts by season, grouping by tournament).
- pgTAP `24_vw_vcat_violation.sql` — 4 tests for the admin view.
- No automated test for the source-vs-DB script itself; it's a one-shot CLI relying on live vendor URLs.
