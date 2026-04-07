# ADR-029: Tournament URL Auto-Population + Admin CRUD

**Status:** Accepted
**Date:** 2026-04-07 (updated)
**Relates to:** FR-53, FR-54, ADR-025 (Event-Centric Ingestion)

## Context

Each PPW event contains 28+ individual tournaments. After results are published on FencingTimeLive, Engarde, or 4Fence, the admin must manually enter `url_results` for every tournament — a tedious and error-prone process.

All three platforms follow predictable URL patterns that can be derived from the event-level `url_event` already stored in `tbl_event`.

Additionally, the Event Admin accordion needed full tournament CRUD (create, edit code/url/status, delete with confirmation, import via URL scraping).

## Decision

### 1. URL Auto-Population

Automatically derive tournament `url_results` from the event's `url_event` using platform-specific discovery logic.

**Triggers:**
- Admin UI: ⬇ button on event row → triggers `populate-urls.yml` via GitHub Actions API
- Telegram: `populate-urls <event_code>` (CERT) / `populate-urls-prod <event_code>` (PROD)

**Platform Discovery Strategies:**

**FencingTimeLive (FTL):**
- Scrape event schedule HTML page
- Extract `/events/view/{UUID}` links for individual competitions
- Parse tournament names (Polish/English) to map to weapon/gender/category
- Build result URLs: `https://www.fencingtimelive.com/events/results/{UUID}`

**Engarde:**
- XML API at `/prog/getCompeForDisplay.php` (not HTML scraping)
- Returns structured XML with `<comp>` elements: slug, sexe, arme, titre, etat
- Category parsed from title V-notation first ("V1", "V2"), slug fallback
- Gender from title keywords (Men's/Women's) overrides buggy `sexe` attribute
- Only `etat="completed"` entries included (Poules/empty filtered out)
- Multilingual: tested with Spanish (Madrid), English (Stockholm), Hungarian (Budapest)

**4Fence (Italian):**
- No scraping needed — URLs are deterministic from base path
- Generate URLs using query parameters: `a` (weapon), `s` (gender), `c` (category), `f=clafinale`
- Weapon: SP=Epee, F=Foil, SC=Sabre; Category: 5=V0..9=V4

### 2. Tournament Admin CRUD

**Edit Tournament** — inline form in accordion with fields:
- `txt_code` (editable via extended `fn_update_tournament` with `p_code` parameter)
- `url_results`, `enum_import_status`, `txt_import_status_reason`

**Create Tournament** — inline form with weapon/gender/category/type/url, auto-generates code.

**Delete Tournament** — with `confirm()` dialog.

**Import via URL Scrape** — ⬇ button on tournament row:
- Checks `url_results` is set
- Triggers `scrape-tournament.yml` via GitHub Actions API
- `scrape_tournament.py`: detect platform → fetch → parse → fuzzy match → `fn_ingest_tournament_results`

### 3. Promotion URL Carry

`promote.py` now reads `url_results` from CERT tournaments and updates PROD tournaments after creation.

### 4. PROD Read-Only Commands

Telegram commands for querying PROD without writes:
- `status-prod`, `results-prod`, `evf-status-prod`
- Uses Management API with `SUPABASE_PROD_REF` (same access token as CERT)

## Alternatives Considered

1. **Manual entry** — Tedious for 28+ tournaments per event.
2. **Telegram-only** — Initial approach; replaced by Admin UI direct GHA trigger.
3. **Supabase Edge Function** — Python ecosystem not available in Deno.
4. **HTML scraping for Engarde** — Engarde uses JS-rendered pages; XML API is more reliable.

## Consequences

- Reduces admin effort from ~30 manual URL entries to one button click
- FTL depends on HTML page structure (may break on redesign)
- Engarde XML API is stable and structured
- 4Fence URLs are deterministic and resilient to UI changes
- Combined categories map one URL to multiple tournaments
- `--dry-run` mode allows safe preview
- Admin UI requires `github-pat` and `github-repo` attributes for GHA trigger
- 15 pytest tests (url_discovery + scrape_tournament), 2 pgTAP tests (txt_code update), 4 vitest tests (edit/create forms)
