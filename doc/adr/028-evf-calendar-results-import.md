# ADR-028: EVF Calendar + Results Import

**Status:** Accepted
**Date:** 2026-04-06
**Relates to:** FR-58, ADR-025 (Event-Centric Ingestion)

## Context

PEW/MEW events (international) are currently added manually to the database. The European Veterans Fencing (EVF) website at veteransfencing.eu publishes:
- **Calendar:** event names, dates, locations, weapons, entry fees
- **Results:** full individual classification PDFs per weapon/category (Engarde format)

Automating import saves admin effort and ensures timely data availability for carry-over scoring.

## Decision

Two data sources from veteransfencing.eu. Current season only (2025-2026). Category mapping: EVF Cat 1-4 = SPWS V1-V4 (skip V0).

### Calendar Scraping (HTML)
- Auto-scrape every 3 days via GitHub Actions cron (`evf-sync.yml`)
- Single HTML page fetch per run (light footprint)
- Dedup by date overlap (+-7 days) + fuzzy name match (RapidFuzz >= 80)
- Creates `tbl_event` + child `tbl_tournament` (type PEW) via `fn_import_evf_events`

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

### Rate Limiting
- **Calendar:** 1 HTML fetch every 3 days (cron)
- **Results (probing):** 1 API request/day per event until results appear
- **Results (burst):** ~25 API requests per event (1 competitions list + 24 result fetches), 1s delay between. Total ~30s per event.
- Under 30 EVF API requests per burst — well below any reasonable rate limit.

### Telegram Commands
- `evf-import` — manual calendar scrape (bypass 3-day schedule)
- `evf-results <event>` — manual result fetch for specific event (starts burst immediately)
- `evf-status` — show events with pending results

## Alternatives Considered

1. **PDF-only approach** — Original plan. EVF publishes Engarde PDFs for championships. Works but: truncated names, slower (1 PDF per 2 min), only championships not circuits. JSON API is superior.
2. **Browser-side fetch** — CORS blocks veteransfencing.eu (API requires `Origin: https://www.veteransfencing.eu`). Server-side only.
3. **Supabase Edge Function** — Python ecosystem not available in Deno. Rejected.
4. **Historical data import** — EVF has 35 years. Unnecessary. Current season only.

## Consequences

- Dependency on EVF website HTML structure (may break on redesign)
- PDF parsing depends on Engarde format consistency
- pypdf added as dependency (already installed for seed export)
- 3 new Telegram commands added to GAS script
