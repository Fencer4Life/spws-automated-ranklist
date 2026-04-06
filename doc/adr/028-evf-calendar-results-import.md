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

Scrape veteransfencing.eu for calendar metadata and result PDFs. Current season only (2025-2026). Category mapping: EVF Cat 1-4 = SPWS V1-V4 (skip V0).

### Calendar Scraping
- Auto-scrape every 3 days via GitHub Actions cron (`evf-sync.yml`)
- Single HTML page fetch per run (light footprint)
- Dedup by date overlap (+-7 days) + fuzzy name match (RapidFuzz >= 80)
- Creates `tbl_event` + child `tbl_tournament` (type PEW) via `fn_import_evf_events`

### Results Scraping
- **Team events excluded** — calendar imports metadata for team events but never scrapes results. Only individual championships and circuit events trigger result scraping.
- 2 days after event `dt_end`, check results page for PDF links
- If no PDFs found: retry next day (max 14 days), then stop
- Once first PDF found: switch to burst mode — fetch 1 PDF every 2 minutes until all published PDFs downloaded
- **Completion detection:** scrape the results page to discover all available PDF links first (1 request). The actual count depends on the event — could be 24 (full championship) or fewer (circuit). We download exactly what's published, no assumptions.
- PDF text extraction via pypdf (Engarde format: rank, name, country)
- Only Polish fencers ingested (international rules from ADR-025)
- Results feed into existing matcher pipeline

### Rate Limiting
- **Calendar:** 1 HTML fetch every 3 days (cron)
- **Results (probing):** 1 request/day per event until PDFs appear
- **Results (burst):** 1 PDF every 2 minutes once data starts showing up. Single event at a time. ~18 requests per burst (1 page check + 17 PDFs)
- Burst implemented as GitHub Actions workflow with `sleep 120` between downloads

### Telegram Commands
- `evf-import` — manual calendar scrape (bypass 3-day schedule)
- `evf-results <event>` — manual result fetch for specific event (starts burst immediately)
- `evf-status` — show events with pending results

## Alternatives Considered

1. **EVF API** — No public API available. Rankings page uses authenticated WordPress AJAX.
2. **Browser-side fetch** — CORS blocks veteransfencing.eu. Rejected.
3. **Supabase Edge Function** — Python ecosystem not available in Deno. Rejected.
4. **Historical data import** — 35 years available but unnecessary. Current season only.

## Consequences

- Dependency on EVF website HTML structure (may break on redesign)
- PDF parsing depends on Engarde format consistency
- pypdf added as dependency (already installed for seed export)
- 3 new Telegram commands added to GAS script
