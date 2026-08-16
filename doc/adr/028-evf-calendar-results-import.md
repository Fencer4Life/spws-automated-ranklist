# ADR-028: EVF Calendar + Results Import

**Status:** Accepted (revised 2026-08-08 rev 8 — source-verified historical fragment repair)
**Date:** 2026-04-06
**Relates to:** FR-58, ADR-025 (Event-Centric Ingestion), ADR-029 (`url_event`), ADR-030 (`url_registration`/`dt_registration_deadline`), ADR-039 (stale-event gate / dedup ladder rev 2), ADR-043 (event code allocator + classifier)
**Amended by:** [ADR-084](084-calendar-quarter-barrel-event-card.md) (carves out one-time curated enrichment of calendar-facing fields).

## Amendment (2026-08-09 — curated enrichment is permitted, once)

This ADR treats scraped EVF fields as source-owned: the sync overwrites them on every run. [ADR-084](084-calendar-quarter-barrel-event-card.md) surfaces fields the scrape does not populate well — venue address, country as an ISO code, a city distinguishable from a venue name — because the card renders them directly.

The carve-out: **one-time curated enrichment of presentation-only fields is permitted** where the scrape has no value to overwrite. It does not extend to identity or schedule fields (name, dates, `txt_evf_slug`, `id_evf_event`), which remain strictly source-owned and are re-synced by `fn_sync_evf_event_fields`.

The reason this needs saying: `txt_location` in CERT holds a venue where a city belongs, and the card demotes such a value to the address line rather than printing it as a city (EC.8, EC.9). That is a **rendering** accommodation of a data defect, not a fix — the defect stays recorded against the ingest.

## Amendment 2026-04-26 (rev 3)

The Python scraper no longer constructs venue-slug `code` values. Code allocation is delegated to `fn_import_evf_events_v2` (calendar path) and `fn_create_evf_event_from_results` (results path), both of which call the new allocator + classifier from ADR-043. `id_organizer` is set to `EVF` unconditionally (was incorrectly `SPWS` before). The bogus `MEW-{slug}-{year}` code pattern is gone — team events now go to the singleton `DMEW-{year}` and individual championships to `IMEW-{year}`. See ADR-043 for the allocator's three-step ladder + Telegram alert behaviour.

## Context

PEW/MEW events (international) are currently added manually to the database. The European Veterans Fencing (EVF) website at veteransfencing.eu publishes:
- **Calendar:** event names, dates, locations, weapons, entry fees
- **Results:** full individual classification PDFs per weapon/category (Engarde format)

Automating import saves admin effort and ensures timely data availability for carry-over scoring.

## Decision

Two data sources from veteransfencing.eu. Current season only (2025-2026). Category mapping: EVF Cat 1-4 = SPWS V1-V4 (skip V0).

### Calendar Scraping (API-first + HTML enrichment — revised 2026-04-20)
- **Primary source:** EVF JSON API (`api.veteransfencing.eu/fe/events`, `/events/competitions`) via the shared `EvfApiClient` — the same authenticated endpoint results scraping already uses. Stable structured JSON (`id`, `name`, `opens`, `closes`, `location`, `country_abbr`; weapons derived from `/events/competitions.weaponId`).
- **Secondary enrichment (HTML list page):** `veteransfencing.eu/calendar/` past + future pages are scraped only to supply fields the API does not expose: `num_entry_fee`, `txt_entry_fee_currency`, `url_event`, `txt_venue_address`. Merged into API rows by date (±3 days) + fuzzy name (RapidFuzz ≥ 80).
- **Tertiary enrichment (per-event detail page):** each event's `url_event` is fetched and parsed for `url_invitation` (PDF link heuristic), `url_registration` (Engarde / Ophardt / Fencing Time / `Zgłoszenia` heuristic), and `dt_registration_deadline` (EN + PL regex patterns). Per-event failures are logged and swallowed so one broken page does not abort the batch.
- **Failure semantics:** API ok + HTML fails → return API events (warn). HTML ok + API fails → return HTML events (warn, legacy path). Both fail → **raise `RuntimeError`** which the workflow's `if: failure()` step converts into a Telegram alert. No more silent zero-event runs.
- Auto-scrape every 3 days via GitHub Actions cron (`evf-sync.yml`). Manual trigger via `evf-cal-import` GAS command.
- Dedup against `tbl_event` by date overlap (±7 days) + fuzzy name match (RapidFuzz ≥ 80).
- Creates `tbl_event` (now with `url_event`/`url_invitation`/`url_registration`/`dt_registration_deadline`/`txt_venue_address`/`num_entry_fee`/`txt_entry_fee_currency`/`arr_weapons` populated when harvested) + child `tbl_tournament` (type PEW/MEW) via `fn_import_evf_events`. The RPC's JSONB contract is additive — old payloads (without the new keys) still work.

### Results Scraping (JSON API)
- **Discovery:** EVF has a Laravel-based API at `api.veteransfencing.eu/fe` that returns full individual results with fencer names, DOB, country, places, and EVF ranking points.
- **API pattern:** POST with `{path, nonce, model}` body. Nonce extracted from WP page. Results model: `{offset: 0, pagesize: 10000, filter: "", sort: "pnc"}`.
- **Endpoints:** `/events` → event list, `/events/competitions` → weapon+category combos, `/results/{comp_id}` → full individual placements.
- **Team events excluded** — only individual championships and circuit events trigger result scraping.
- 2 days after event `dt_end`, start checking EVF API for results.
- If not found: retry next day (max 14 days), then stop.
- Once results appear: fetch all competitions for the event (24 requests with 1s delay = ~30s).
- Returns structured JSON with fencer_name, place, country, DOB, EVF points per competition.
- Only Polish fencers ingested via fuzzy matcher (international rules from ADR-025).
- **PDF fallback:** Legacy `parse_evf_result_pdf()` retained for older championships that only have PDFs.

### Refresh Semantics (amendment, 2026-04-20 rev 2)

The original "create-only, idempotent-by-code" import contract is **preserved** for `fn_import_evf_events`: a re-run with a payload whose `txt_code` already exists still skips the row. That contract remains for callers that rely on it (seeding, manual backfills, administrator imports).

A companion RPC `fn_refresh_evf_event_urls(p_updates JSONB)` handles the case where the scraper re-discovers an event that was already imported (or seeded) and has fresh URL/enrichment data to contribute. The Python side pairs each scraped event with its matched `tbl_event` row via `match_scraped_to_existing()` (same date±7d + RapidFuzz ≥ 80 rule used for dedup) and sends the `id_event` list to the refresh RPC.

**Invariant (enforced at the SQL layer):** `fn_refresh_evf_event_urls` only writes a column whose current value is `NULL` or empty string. It never overwrites an existing value. This protects admin edits made via the Event CRUD UI (FR-60) — the scraper's heuristic must not stomp a manually-entered URL or deadline. Verified by pgTAP 12.11 and by a live sentinel check in the 2026-04-20 validation run.

- **Columns refreshed** when currently NULL/empty: `url_event`, `url_invitation`, `url_registration`, `dt_registration_deadline`, `txt_venue_address`, `num_entry_fee`, `txt_entry_fee_currency`, `arr_weapons`.
- **Columns never refreshed:** `txt_code`, `txt_name`, `id_season`, `id_organizer`, `enum_status`, `dt_start`, `dt_end`, `txt_location`, `txt_country`, `ts_updated` (trigger-maintained).
- Unknown `id_event` is a no-op, not an error. RPC return shape: `{touched: INT, refreshed: INT}`.

### Deadline Harvesting (disabled 2026-04-20 rev 2)

The `dt_registration_deadline` regex heuristic had a 0/13 hit rate on live EVF detail pages on 2026-04-20 — the detail pages either embed deadlines inside linked PDFs or use phrasings not covered by the initial patterns. The extraction is gated behind the module-level `HARVEST_DEADLINE = False` flag in [python/scrapers/evf_calendar.py](../python/scrapers/evf_calendar.py); the regex list, fixtures, and column remain in place so re-enabling is a 1-line flip once we have observed real-world phrasings to add.

### Rate Limiting
- **Calendar:** 1 HTML fetch every 3 days (cron)
- **Results (probing):** 1 API request/day per event until results appear
- **Results (burst):** ~25 API requests per event (1 competitions list + 24 result fetches), 1s delay between. Total ~30s per event.
- Under 30 EVF API requests per burst — well below any reasonable rate limit.

### Telegram Commands
- `evf-cal-import` — manual calendar scrape (bypass 3-day schedule)
- `evf-results-import <event>` — manual result fetch + import for specific event
- `evf-status` — show past international events missing results (dt_end < today, result_count = 0)

## Alternatives Considered

1. **PDF-only approach** — Original plan. EVF publishes Engarde PDFs for championships. Works but: truncated names, slower (1 PDF per 2 min), only championships not circuits. JSON API is superior.
2. **Browser-side fetch** — CORS blocks veteransfencing.eu (API requires `Origin: https://www.veteransfencing.eu`). Server-side only.
3. **Supabase Edge Function** — Python ecosystem not available in Deno. Rejected.
4. **Historical data import** — EVF has 35 years. Unnecessary. Current season only.

## Consequences

- **HTML redesign no longer breaks calendar discovery silently.** The API is primary; HTML failures are logged as warnings and the scrape still returns API events. Only a full (API + HTML) outage raises `RuntimeError`, and that raises a Telegram alert.
- **Event-level URL fields are now populated automatically** (`url_event`, `url_invitation`, `url_registration`, `dt_registration_deadline`) from the detail-page scrape — previously all four were `NULL` on every EVF-sourced event.
- Per-event detail-page fetch adds ~30 HTTP requests per 3-day cron (0.5 s polite delay). One failing detail page does not abort the batch — it is logged and skipped.
- Integration smoke test (plan ID evf.12, `@pytest.mark.integration`) hits the live API + one live detail page; runnable via `pytest -m integration`, excluded from default CI run.
- PDF parsing still depends on Engarde format consistency.
- pypdf added as dependency (already installed for seed export).
- 3 Telegram commands in GAS script unchanged. Calendar sync now sends a URL-enrichment summary line (`inv=... reg=... deadline=...`).
- Migration `20260420000001_evf_import_urls.sql` extends `fn_import_evf_events` — additive, idempotent, no breaking change. pgTAP grows by 5 (12.5–12.9) to 277 total.
- Migration `20260420000002_evf_refresh_urls.sql` introduces `fn_refresh_evf_event_urls` — new RPC, does not alter `fn_import_evf_events`. pgTAP grows by 4 (12.10–12.13) to 281 total.
- Admin edits via the Event CRUD UI (FR-60) are protected end-to-end: the refresh RPC is the only auto-write path that touches existing events, and it never overwrites a populated column.
- Deadline harvesting disabled pending real-world pattern data (`HARVEST_DEADLINE = False` in [python/scrapers/evf_calendar.py](../python/scrapers/evf_calendar.py)). The DB column, regex patterns, and test fixtures remain so re-enabling is a one-line flip.

## Amendment 2026-04-25 — Algorithm rev 3 (superseded by ADR-039)

The original `(dt_start exact + canonical country)` primary / `±N day window + fuzzy-name ≥ threshold` fallback dedup design produced three duplicate event rows during the 2025-26 season when EVF mid-season-renamed three events. The fuzzy-name path scored Napoli↔Naples below the 80% threshold, allowing the rename to be inserted as a fresh row.

**The algorithm is now defined by [ADR-039](039-stale-event-gate.md) — read that as the canonical spec.** Headline changes:

- **Name comparison removed entirely.** EVF rename behaviour means name fuzz cannot be tuned to be both safe (no false negatives) and tight (no false positives).
- **Location step added** as the fallback when country is missing (Step 4 in ADR-039).
- **Stale-event gate added** (Step 1): the scraper does not auto-create or auto-update events with `(today − dt_end) ≥ 30 days` or `enum_status = 'COMPLETED'`. Admin handles those manually.
- **Logical-integrity guard added** (Step 0): a future-COMPLETED row halts the sync via Telegram alert. The scraper refuses to operate on top of corrupted state.
- **Single matcher across calendar + results paths.** The previous ad-hoc `BETWEEN ±3 days + EXISTS(tournament)` query in `_compare_and_ingest` is gone; both paths now go through `_find_existing_match`.

The legacy duplicates that prompted the rev 3 design were cleaned up via existing `fn_delete_event` (no merge tooling needed — they were empty rows).

## Amendment (2026-07-11, ADR-081)

The CERT→PROD calendar-promotion mechanism described here is superseded by the **event
reconciler** (ADR-081): `fn_import_evf_events` is retired and replaced by
`fn_mirror_events_to_prod` (full Create/Update/Delete, organizer-agnostic, guarded DELETE).
The CERT-side ingest RPC `fn_import_evf_events_v2` is renamed **`fn_ingest_evf_calendar`** and
gains an **identity-first pre-check**: a current-season row already carrying the scrape's
`id_evf_event`/`txt_evf_slug` is reused (CURRENT_SLOT_REUSE) *before* the location-gated
`fn_allocate_evf_event_code` runs — closing that allocator's blank-location blind spot at the
SQL layer (Steps A/B skip on blank location → Step C previously minted a fresh code every
scrape). This mirrors the Python `id→slug` dedup ladder (ADR-039 rev 2) in SQL. See ADR-081.

## Amendment (2026-07-26, ADR-039 rev 4)

`url_event` — the event's results pointer — is now recorded **only once the event has concluded**
(`dt_end < today`). The calendar scraper described above wrote it for *every* event, so future
events carried a schedule/registration page in a field the operator and `ingest_cli` treat as the
results source. The **Refresh Semantics** "Columns refreshed" list is unchanged, but `url_event`
specifically is gated by `url_event_if_concluded` before it reaches `fn_ingest_evf_calendar`
(create) or `fn_refresh_evf_event_urls` (refresh). `url_invitation` and `url_registration` — the
organizer's invitation letter and registration link — are **unaffected** and still harvested for
upcoming events. The fill-blank invariant continues to hold: once concluded, the link is filled
and a later manual edit is never overwritten. Canonical spec and the one-time CERT/PROD data
correction: [ADR-039](039-stale-event-gate.md) rev 4.

## Amendment (2026-08-07, rev 5) — authoritative calendar snapshot

The public EVF HTML calendar is the authority for event existence. Its WordPress
`post-N` id is stored in `tbl_event.id_evf_calendar_event`. The EVF results database
remains secondary: `id_evf_event` identifies a results occurrence but does not
replace original scoring-provider links such as FTL, Engarde, 4Fence or Dartagnan.

Every scrape validates one complete season snapshot before writing. The count `N`
includes every distinct EVF calendar entry wholly contained within the season,
including cancelled, camp, open and non-scoring entries. Missing/unparseable dates,
duplicate calendar ids and a boundary-spanning event are hard errors. Each attempt
is recorded in `tbl_evf_calendar_scrape_run` with counts, calendar ids and verdict.

Only circuit/championship/criterium entries become SPWS event rows, but all entries
contribute to `N`. Ingestion calls `fn_ingest_evf_calendar(payload, season, N)` and
may not allocate `PEWn` where `n > N`. Repeated calendar ids refresh one row instead
of allocating. An authoritative cancellation marker moves a pre-scoring,
results-free event to `CANCELLED`; terminal or scored rows are refused.

Implementation: [calendar scraper](../../python/scrapers/evf_calendar.py),
[sync orchestration](../../python/scrapers/evf_sync.py),
[migration](../../supabase/migrations/20260807000001_evf_calendar_identity_bound.sql)
and [pgTAP contract](../../supabase/tests/53_evf_calendar_identity_bound.sql).

## Amendment (2026-08-07, rev 6) — every entry becomes a coded event row

The rev-5 distinction “all entries count, only circuit/championship/criterium entries
become rows” is superseded. Every valid public-calendar entry becomes exactly one
`tbl_event` row, including camps, opens, non-scoring and cancelled entries. The full
snapshot is sorted by `(dt_start, id_evf_calendar_event)` and assigned exact ordinal
codes under ADR-043; ADR-046 supplies the mandatory weapon suffix.

Calendar ordinals and prior-season identity are independent. `id_prior_event`
preserves a verified geographic/event-series relationship, including the approved
Athens→Chania link, while prior code digits never influence the new season. The EVF
results database remains secondary provenance and original scoring-provider URLs
remain authoritative.

A complete scrape aborts before writing if any entry lacks a stable calendar ID,
valid contained date range or authoritative weapon set. Reflow is allowed only for
unscored rows; any required rename of a results-bearing row is an error requiring a
reviewed migration.

## Amendment (2026-08-07, rev 7) — CAMP exclusion and cancellation base zero

Rev 6 is narrowed by two approved domain rules:

1. An entry whose name contains case-insensitive whole-word `CAMP` is ignored
   completely. It creates no row, expects no results and contributes neither a zero
   nor a positive number. Filtering occurs before season validation/counting, so a
   malformed camp date cannot block competition ingestion. Substrings such as
   “Campbell” do not match.
2. A retained event already marked cancelled at its first authoritative import is
   stored at `PEW0{letters}-{season}` and excluded from positive chronology. An event
   cancelled after receiving a positive code keeps that code; cancellation never
   triggers a season-wide reflow.

The current source has five ignored camps, Samorin at `PEW0efs`, and sixteen
positive competitions numbered `PEW1…PEW16`. If two first-import cancellations
would produce the same full zero code (same weapon suffix and season), ingestion
fails before mutation rather than inventing another numbering shape.

## Amendment (2026-08-08, rev 8) — original-provider facts govern historical repair

The 2025–2026 data contained scored fragments for the same physical weekends,
including Guildford under five event rows and Munich under two. This supersedes
the earlier operational assumption that EVF calendar duplicates were always empty
and could simply be deleted.

Historical consolidation follows this evidence hierarchy:

1. the original scoring provider (Fencing Time Live, FencingWorldwide, Engarde,
   4Fence, Dartagnan or equivalent) supplies places, full field sizes, competition
   dates and result URLs;
2. the EVF results database is secondary evidence and never replaces an available
   original-provider link;
3. only when both are unavailable may a specifically approved repair use the
   stored full-field tournament snapshot, pinned by exact input counts.

The reviewed migration
[`20260808000003_evf_historical_event_fragment_repair.sql`](../../supabase/migrations/20260808000003_evf_historical_event_fragment_repair.sql)
applies that rule to Guildford, Munich, Faches, Stockholm and Chania. It preserves
the historical event bases, including `PEW62` for Guildford, and does not reflow
the season. FencingWorldwide facts replace the Munich fragments; the inaccessible
Guildford/Faches sources and one March 2025 result use the explicitly approved
full-field fallback. Child `url_results` values remain original scoring-site URLs.
The 25-assertion contract is
[`55_evf_historical_event_fragment_repair.sql`](../../supabase/tests/55_evf_historical_event_fragment_repair.sql).

## Amendment (2026-08-09, rev 9) — predecessor-season fragment consolidation

The same physical-event fragmentation predates 2025–2026. Six reviewed clusters
in 2023–2024 and 2024–2025 are consolidated by an atomic, fail-closed migration:
Budapest, Terni and Stockholm in the first season; Guildford, Terni and
Warsaw/Jabłonna in the second. The lowest existing PEW base survives in each
cluster and receives the suffix for the weapons actually present. This is a
targeted historical correction, not a chronological reflow and not a generic
merge path.

The repair pins every input code and the expected tournament/result counts,
refuses registrations, conserves any match-candidate provenance by unchanged
result identity, rejects overlapping weapon/gender/
age-category slots, preserves all 157 result rows in the six reviewed clusters and every stored score field,
then deletes only the named donor events. Original scoring-provider URLs stay on
their tournaments. No EVF results-database identity is invented, and three
reviewed unrelated `id_prior_event` links are cleared without replacement.
The distinct `PEW8f-2024-2025` Guildford foil event and its 20 results are retained.

Implementation and acceptance evidence:
[`20260809000001_evf_predecessor_event_fragment_repair.sql`](../../supabase/migrations/20260809000001_evf_predecessor_event_fragment_repair.sql)
and [`56_evf_predecessor_event_fragment_repair.sql`](../../supabase/tests/56_evf_predecessor_event_fragment_repair.sql).
