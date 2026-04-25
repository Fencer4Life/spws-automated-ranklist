# ADR-028: EVF Calendar + Results Import

**Status:** Accepted (revised 2026-04-20 rev 2 — URL-refresh path added + deadline harvest disabled pending real-world pattern data)
**Date:** 2026-04-06
**Relates to:** FR-58, ADR-025 (Event-Centric Ingestion), ADR-029 (`url_event`), ADR-030 (`url_registration`/`dt_registration_deadline`)

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
