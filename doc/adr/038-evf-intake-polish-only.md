# ADR-038: EVF-Organized Tournaments Ingest POL-Only Rows

**Status:** Accepted
**Date:** 2026-04-20
**Relates to:** ADR-019 (Domestic-Only Fencer Seed), ADR-020 (Seed Generator Domestic Auto-Create), ADR-025 (Event-Centric Ingestion)

## Context

ADR-019 and ADR-020 established the principle that `tbl_fencer` is the SPWS domestic member pool: domestic (PPW/MPW) tournaments may auto-create unknown fencers, international (PEW/MEW/MSW) tournaments may not.

The live pipeline (`python/matcher/pipeline.py:resolve_tournament_results`) implements this rule only for the **UNMATCHED** tier: international unmatched fencers are skipped, no fencer creation. But the pipeline still passes **AUTO_MATCHED** and **PENDING** tiers through for international tournaments — including non-Polish scraped names that fuzzy-glue to Polish SPWS fencers at sub-threshold scores.

Real-world impact (EVF Circuit Salzburg, 2026-04-18, Dartagnan scrape):

- 171 scraped rows across 16 single-category finals (mix of nationalities)
- After intake: 113 PENDING rows created linking foreign competitors to unrelated Polish SPWS fencers at 48–75 % confidence. Example garbage: Hungarian "KOLCZONAY ERNŐNÉ Judit" → Polish "KOWALCZYK Piotr" at 64 %, Austrian "HINTERSEER Ursula" → Polish "KARMAN Irene" at 48 %.
- The identity queue became unusable: every row required manual dismissal, with no signal separating legitimate low-confidence matches (same-name Poles) from accidental cross-nationality collisions.

The PENDING tier was designed as an admin-review queue for legitimately ambiguous Polish same-name pairs. It was never intended to absorb every foreign competitor.

## Decision

For **EVF-organized tournaments** (`enum_type ∈ {PEW, MEW, MSW}`), ingestion filters scraped rows by country **before** the matching pipeline runs. Only rows with `country = "POL"` are considered for matching; all others are dismissed at the gate — no `tbl_result` row, no `tbl_fencer` entry, no identity-queue entry.

For **SPWS-organized tournaments** (`enum_type ∈ {PPW, MPW}`), no country filter applies — every participant is scraped and ingested (existing behavior).

Implementation:

1. `resolve_tournament_results(scraped_names, fencer_db, tournament_type, age_category, season_end_year, scraped_countries=None)` accepts a parallel `scraped_countries` list.
2. When the tournament is international and `scraped_countries` is provided, rows with `country != "POL"` (or missing) are appended to `result.skipped` and excluded from all match tiers.
3. Callers (orchestrator, scrape_tournament tool, one-shot ingestion scripts) must thread `country` from scraper output through to the matcher.
4. Scrapers that don't emit country (legacy CSV) default to "POL" for domestic tournaments; for international tournaments without country data the filter treats missing as non-POL and drops the row (fail-closed).

## Alternatives Considered

1. **Drop only PENDING for international; keep AUTO_MATCHED unconditional.** Rejected: a high-confidence name collision across nationalities (e.g. "Jan Kowalski" both in SPWS DB and in a foreign delegation) would still wrongly link. Country is the authoritative signal, not name.
2. **Filter post-match inside `resolve_tournament_results` instead of pre-match.** Rejected: wastes fuzzy-match cycles on rows destined for the trash can; also risks leaking partial state into telemetry.
3. **Require the scraper to filter non-POL rows.** Rejected: the scraper's job is faithful platform → list-of-dicts translation; the filter is a business rule that belongs in the pipeline. A single policy point is easier to audit than per-scraper filters.
4. **Configurable country set per season.** Rejected: YAGNI — SPWS ranks Polish veterans. If this ever changes, add the column to `tbl_season` then.

## Consequences

- Identity queue size for EVF events drops from ~100s to the legitimate Polish-same-name count (usually 0–2 per event).
- `tbl_fencer` can no longer acquire foreign identities via PEW/MEW/MSW fuzzy collisions.
- Pre-existing pollution from earlier EVF imports is not automatically cleaned — each affected event needs `fn_rollback_event('<code>')` + re-ingest under the new rule.
- Scrapers without `country` output (plain text / legacy CSV) are effectively blocked from ingesting into EVF tournaments; operators must extend the scraper or manually add country before ingest.
- Superseding effect: ADR-020's "International unmatched → skip" rule still holds; this ADR **widens** the skip to also cover AUTO_MATCHED and PENDING for non-POL rows at EVF events.
