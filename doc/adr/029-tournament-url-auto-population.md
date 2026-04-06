# ADR-029: Tournament URL Auto-Population

**Status:** Accepted
**Date:** 2026-04-06
**Relates to:** FR-53, FR-54, ADR-025 (Event-Centric Ingestion)

## Context

Each PPW event contains 28+ individual tournaments. After results are published on FencingTimeLive, Engarde, or 4Fence, the admin must manually enter `url_results` for every tournament — a tedious and error-prone process.

All three platforms follow predictable URL patterns that can be derived from the event-level `url_event` already stored in `tbl_event`.

## Decision

Automatically derive tournament `url_results` from the event's `url_event` using platform-specific discovery logic. Triggered via Telegram command `populate-urls <event_code>`.

### Platform Discovery Strategies

**FencingTimeLive (FTL):**
- Scrape event schedule HTML page
- Extract `/events/view/{UUID}` links for individual competitions
- Parse tournament names (Polish/English) to map to weapon/gender/category
- Build result URLs: `https://www.fencingtimelive.com/events/results/{UUID}`
- Existing logic in `python/tools/scrape_ftl_event_urls.py` (18 tests)

**Engarde:**
- Scrape event index HTML page at `/tournament/{org}/{event}/`
- Extract `/competition/{org}/{event}/{slug}` links
- Parse competition names (multilingual: FR/EN/ES/IT/DE/PL) to weapon/gender/category
- Result URL = competition link + `/clasfinal.htm` suffix

**4Fence (Italian):**
- No scraping needed — URLs are deterministic from base path
- Generate URLs using query parameters: `a` (weapon), `s` (gender), `c` (category), `f=clafinale`
- Weapon: SP=Epee, F=Foil, SC=Sabre
- Gender: M, F
- Category: 5=V0, 6=V1, 7=V2, 8=V3, 9=V4

### Workflow

1. Telegram `populate-urls PP4-2025-2026` → GAS → GitHub Actions
2. Python fetches `url_event` from DB
3. Platform auto-detected via `detect_platform()`
4. Discovery function returns `[{weapon, gender, category, url}]`
5. Matched to existing `tbl_tournament` records by weapon+gender+category
6. `url_results` updated via PostgREST PATCH
7. Telegram summary: N updated, N skipped, N unmatched

## Alternatives Considered

1. **Manual entry** — Current approach. Works but tedious for 28+ tournaments per event.
2. **Admin UI button** — Deferred to future iteration. Telegram-first validates the approach.
3. **Supabase Edge Function** — Python ecosystem (BeautifulSoup, httpx) not available in Deno.

## Consequences

- Reduces admin effort from ~30 manual URL entries to one Telegram command
- FTL and Engarde depend on HTML page structure (may break on redesign)
- 4Fence URLs are deterministic and resilient to UI changes
- Combined categories (e.g., "Category 1 and 2") map one URL to multiple tournaments
- `--dry-run` mode allows safe preview before committing changes
