# Dartagnan Scraper — Implementation Runbook

> **Status:** Plan approved 2026-04-20 by user. Not yet implemented.
> **Fresh-session runbook:** self-contained. Read top-to-bottom before writing any code.

---

## 1. One-line summary

Build `python/scrapers/dartagnan.py` with the same functionality, tests, and integration as [ftl.py](../python/scrapers/ftl.py), [engarde.py](../python/scrapers/engarde.py), [fourfence.py](../python/scrapers/fourfence.py). Use it end-to-end to ingest EVF Salzburg results into CERT (which flips `PEW7-2025-2026` from `PLANNED` → `IN_PROGRESS`).

## 2. Live URL + event context

| Field | Value |
|---|---|
| Event on SPWS | `PEW7-2025-2026` (EVF Circuit Salzburg) |
| Event date | 2026-04-18 |
| Event results host | Dartagnan (`dartagnan.live`) — NEW platform, first time SPWS sees it |
| Live event index | `https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html` |
| Currently on CERT | `enum_status = 'PLANNED'`, child tournaments exist (created by EVF calendar scraper), zero results |
| Active season | `SPWS-2025-2026` (id_season = 3 on local/CERT, 5 on PROD — verify before use) |

## 3. Dartagnan URL structure (discovered via WebFetch, 2026-04-20)

**Event index** (`/<event-slug>/de/index.html`): lists all competitions (weapon × gender × category). Each competition has an integer ID and sub-pages under the same base:

| Sub-page URL | Purpose |
|---|---|
| `<ID>-formula.html` | Tournament format |
| `<ID>-fencers.html` | Eligible fencers |
| `<ID>-starters.html` | Starters |
| `<ID>-pools.html` | Pool rounds |
| `<ID>-matches.html` | DE matches |
| **`<ID>-rankings.html`** | **Final classification — the only one we ingest** |

**Real competition IDs from the live Salzburg page (WebFetch sample):**
- `6687` = Men Epee V1
- `6695` = Men Epee V2
- `6903` = Men Foil V1
- `6989` = Women Foil V2
- `7027` = Women Foil V4
(full list lives on the live index — there are more; fetch the full page when capturing the fixture)

### Rankings page structure (from live `6687-rankings.html`)

**Columns (in order):** `Platz | Name | Vorname | Verein | Landesverband | Nation`

**Sample rows verbatim from live page:**
```
Place 1: Partics, Péter          | Danubius RSC          | Hungary
Place 2: Korona, Radoslaw        | SchermCentrum Amsterdam | Netherlands
Place 3: Pásztor, Attila         | Danubius RSC          | Hungary    (tie)
Place 3: Rusev, Rosislav         | Cherno More           | Bulgaria   (tie)
Place 5: Tokola, Teemu Johannes  | Oulun Miekkailuseura  | Finland
```

### Parsing facts

- **Ties:** duplicate `Platz` numbers (two rows at "3"). Both get `place = 3` in output.
- **Country:** full name in `Nation` column; **also** present as 3-letter ISO in flag `<img>` src (e.g. `…/HUN.svg`). **Prefer the flag-img ISO code** (reliable) over name mapping.
- **Fencer label:** page shows `"Surname, Firstname"` → **normalise to `"SURNAME Firstname"`** (matches engarde.py output convention, e.g. `"ATANASSOW Aleksander"`). Uppercase the surname.
- **Labels on index page:** `/de/` path shows German ("Degen Herren V1"); `/en/` might exist with English. **Parse both languages** (see weapon/gender maps below).
- **Empty page:** not-yet-finished tournaments return an empty rankings table. Scraper must return `[]`, not raise.

### Weapon / gender / category mapping

```python
WEAPON_LABELS = {
    "degen": "EPEE",   "epee": "EPEE",
    "florett": "FOIL", "foil": "FOIL",
    "säbel": "SABRE",  "sabel": "SABRE", "sabre": "SABRE",
}
GENDER_LABELS = {
    "herren": "M", "men": "M", "männlich": "M",
    "damen": "F",  "women": "F", "weiblich": "F",
}
# Categories V1/V2/V3/V4 are already in SPWS enum format — identity mapping.
```

## 4. Architecture the scraper plugs into

Before writing any code, read these — they define the pattern:

| File | Why |
|---|---|
| [python/scrapers/base.py](../python/scrapers/base.py) lines 1-152 | Protocol contract. `detect_platform(url)` at line 20-33 — extend this. |
| [python/scrapers/engarde.py](../python/scrapers/engarde.py) lines 31-88 | Cleanest HTML-table parser in the codebase. Entry: `parse_engarde_html(html) -> list[dict]`. Returns `{fencer_name, place, country}`. Mimic this shape. |
| [python/scrapers/ftl.py](../python/scrapers/ftl.py) | Platform with multi-page discovery. |
| [python/scrapers/evf_results.py](../python/scrapers/evf_results.py) | URL-based orchestrator (httpx) precedent — closest analog for Dartagnan's multi-page flow. |
| [python/scrapers/file_import.py](../python/scrapers/file_import.py) lines 1-42 | Extension router. Dartagnan is URL-based, so **no change here** unless also supporting file uploads. |
| [python/tools/populate_tournament_urls.py](../python/tools/populate_tournament_urls.py) | Per-platform URL discovery. Add `discover_dartagnan_tournament_urls()`. |
| [python/pipeline/orchestrator.py](../python/pipeline/orchestrator.py) lines 177-245 | Where scraped rows become DB inserts. Not changed — same consumer for all scrapers. |
| [python/tests/test_scrapers.py](../python/tests/test_scrapers.py) lines 1-150 | Fixture-based test pattern. Helper `_assert_valid_result()` at line 24-31 — reuse. |

### Ingestion chain (no change, just context)

Scraper returns `list[dict]` with min `{fencer_name, place}` (+ `country, weapon, gender, category` optional)
→ [orchestrator.py](../python/pipeline/orchestrator.py) fuzzy-matches fencer names against `tbl_fencer` (via [python/matcher/fuzzy_match.py](../python/matcher/fuzzy_match.py))
→ Converts to ingestion payload: `{id_fencer, int_place, txt_scraped_name, num_confidence, enum_match_status}`
→ Calls `fn_ingest_tournament_results(tournament_id, jsonb_payload)` RPC
→ Side effect: event flips `PLANNED → IN_PROGRESS` (ADR-025).

## 5. Module design — `python/scrapers/dartagnan.py`

```python
DARTAGNAN_HOSTS = ("dartagnan.live", "www.dartagnan.live")

def parse_dartagnan_event_index(html: str, base_url: str) -> list[dict]:
    """Parse index.html → list of competitions with metadata + rankings URL.
    Returns:
        [{"id": "6687", "weapon": "EPEE", "gender": "M", "category": "V1",
          "rankings_url": "https://…/6687-rankings.html"}, …]
    """

def parse_dartagnan_rankings_html(html: str) -> list[dict]:
    """Parse <ID>-rankings.html → final classification rows.
    Returns:
        [{"fencer_name": "PARTICS Péter", "place": 1, "country": "HUN"}, …]

    - Empty table → [] (not raise)
    - Ties → multiple rows with same place
    - fencer_name normalised "SURNAME Firstname"
    - country = 3-letter ISO from flag <img src> (not Nation column text)
    """

def scrape_dartagnan_event(index_url: str, http_get=None) -> dict:
    """Orchestrator. Fetch index, then each rankings page. Returns:
    {
        "event_url": index_url,
        "competitions": [
            {"weapon": "EPEE", "gender": "M", "category": "V1",
             "rankings_url": "…/6687-rankings.html",
             "results": [{"fencer_name": …, "place": …, "country": …}, …]},
            …
        ]
    }

    http_get is httpx.get by default; inject a fake for tests.
    Polite 0.3s delay between requests (match evf_calendar enrichment style).
    """
```

## 6. Integration changes

### `python/scrapers/base.py`
Extend `detect_platform()`:
```python
elif "dartagnan.live" in host:
    return "dartagnan"
```

### `python/tools/populate_tournament_urls.py`
Add:
```python
def discover_dartagnan_tournament_urls(index_url: str, http_get=None) -> list[dict]:
    """Returns [{weapon, gender, category, url_results}, …]."""
```
And dispatch it from the platform-agnostic entry point (follow the Engarde pattern in same file).

### No change to
- `file_import.py` — Dartagnan is URL-based, not file-based.
- Frontend — `t-scrape` admin flow picks up new platform automatically via `detect_platform`.
- Any migration, RPC, or schema.

## 7. Fixtures + tests

### Fixtures (capture from live URLs at implementation time via WebFetch)

Save to `python/tests/fixtures/dartagnan/`:

| File | Source URL | Why |
|---|---|---|
| `index.html` | `https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html` | Covers all competitions + language labels |
| `6687-rankings.html` | `https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/6687-rankings.html` | Finished comp with ties — good edge case |
| `7027-rankings-empty.html` | (a comp that isn't finished yet — inspect index for candidates, or synthesise from 6687 by stripping the table body) | Empty / unfinished edge case |

**Capture method:** use WebFetch to retrieve the live HTML, then Write to the fixture path. Do NOT commit minified / pretty-printed — save verbatim.

### Tests

Plan test IDs **dart.1–dart.8 + dart.url.1**. Add to [python/tests/test_scrapers.py](../python/tests/test_scrapers.py) unless noted:

| ID | Name | Assertion |
|---|---|---|
| **dart.1** | `test_parse_dartagnan_event_index_returns_competitions` | ≥1 competition, each has `{id, weapon, gender, category, rankings_url}` |
| **dart.2** | `test_parse_dartagnan_rankings_returns_fencer_rows` | Rows pass `_assert_valid_result` (fencer_name non-empty, place >= 1) |
| **dart.3** | `test_parse_dartagnan_rankings_country_is_iso3` | `country == "HUN"` not `"Hungary"`, extracted from flag img src |
| **dart.4** | `test_parse_dartagnan_rankings_handles_ties` | Two rows at `place = 3` both present |
| **dart.5** | `test_parse_dartagnan_rankings_empty_returns_empty_list` | Unfinished page → `[]`, no raise |
| **dart.6** | `test_scrape_dartagnan_event_orchestrator` | Injected httpx fetches index + every rankings URL once; returns combined dict |
| **dart.7** | `test_detect_platform_dartagnan` | In [test_scrape_tournament.py](../python/tests/test_scrape_tournament.py) — `detect_platform("https://www.dartagnan.live/…") == "dartagnan"` |
| **dart.8** | `test_live_dartagnan_reachable` | `@pytest.mark.integration` — real HTTP call to Salzburg URL, ≥1 competition with ≥1 result |
| **dart.url.1** | `test_discover_dartagnan_tournament_urls` | In [test_url_discovery.py](../python/tests/test_url_discovery.py) — given fixture HTML, returns expected `[{weapon, gender, category, url_results}, …]` |

## 8. Salzburg ingestion (end-to-end use AFTER scraper is green)

Do this as a one-shot script in `/tmp/dart_ingest_salzburg.py`. **Do not commit** — the durable artifact is the scraper module + tests.

Steps:

1. `scrape_dartagnan_event("https://www.dartagnan.live/turniere/EuropeanVeteransCup_2026/de/index.html")` → get competitions + results.
2. Connect to local CERT: `postgresql://postgres:postgres@127.0.0.1:54322/postgres` (via psycopg2, as done in `/tmp/run_evf_local.py` pattern).
3. `UPDATE tbl_event SET url_event = '<index_url>' WHERE txt_code = 'PEW7-2025-2026'`.
4. For each competition in the scrape:
   - Find the matching child tournament: `SELECT id_tournament FROM tbl_tournament WHERE id_event = (SELECT id_event FROM tbl_event WHERE txt_code = 'PEW7-2025-2026') AND enum_weapon = <weapon> AND enum_gender = <gender> AND enum_age_category = <category>`
   - `UPDATE tbl_tournament SET url_results = '<rankings_url>' WHERE id_tournament = <tid>`
   - Fuzzy-match fencer names → build ingest payload with `{id_fencer, int_place, txt_scraped_name, num_confidence, enum_match_status}`
   - `SELECT fn_ingest_tournament_results(<tid>, '<payload>'::JSONB)`
5. Verify: `SELECT enum_status FROM tbl_event WHERE txt_code = 'PEW7-2025-2026'` → expect `IN_PROGRESS`.
6. Report counts per tournament.

**Fuzzy matcher reuse:** import `find_best_match` from [python/matcher/fuzzy_match.py](../python/matcher/fuzzy_match.py) (used by evf_sync.py `_match_against_spws`). Use `use_diacritic_folding=True` and `confidence >= 85` threshold.

## 9. Documentation updates

| File | Change |
|---|---|
| [doc/Project Specification. SPWS Automated Ranklist System.md](../Project%20Specification.%20SPWS%20Automated%20Ranklist%20System.md) | RTM FR-54 row: extend to mention Dartagnan + add `dart.1–dart.8, dart.url.1` to Tests column. Appendix D pytest count `274 → 282` (+8 new, excluding dart.8 which is integration-marked). |
| No new ADR | Dartagnan is just another format alongside FTL/Engarde/4fence — same architectural pattern. |
| No update to memory | Project memory is for the user's persistent preferences, not per-feature notes. |

## 10. Verification gates (strict order)

```bash
# 1. RED (tests fail because scraper doesn't exist)
source .venv/bin/activate && python -m pytest python/tests/test_scrapers.py -k dart -v
# Expect: ImportError / AssertionError

# 2. GREEN (implement, then all pass)
python -m pytest python/tests/test_scrapers.py -k dart -v
python -m pytest python/tests/test_url_discovery.py -k dart -v
python -m pytest python/tests/test_scrape_tournament.py -k dart -v

# 3. Full pytest regression (expected 282 passed)
python -m pytest python/tests/ -m "not integration"

# 4. pgTAP regression (expected 281 unchanged)
supabase test db

# 5. Vitest regression (expected 267 unchanged)
cd frontend && npm test -- --run

# 6. Coherence gate
bash scripts/check-coherence.sh

# 7. Live integration smoke (OPTIONAL; confirm post-launch)
python -m pytest python/tests/test_scrapers.py -m integration -k dart

# 8. Salzburg ingestion (after commit+push+CI green)
python /tmp/dart_ingest_salzburg.py
# Verify:
docker exec supabase_db_SPWSranklist psql -U postgres -d postgres -c \
  "SELECT txt_code, enum_status, url_event FROM tbl_event WHERE txt_code = 'PEW7-2025-2026';"
# Expect: enum_status = IN_PROGRESS, url_event populated
```

## 11. Commit message

```
Add Dartagnan results scraper (parity with FTL / Engarde / 4fence)

Dartagnan (dartagnan.live) is a new tournament-results platform used
by EVF Salzburg 2026. Scraper follows the same contract as ftl.py /
engarde.py / fourfence.py: parse HTML → list[dict] with
{fencer_name, place, country}, routed via base.py:detect_platform,
URL-discovered by populate_tournament_urls.py for per-weapon /
gender / category result URLs.

Handles: index page → per-competition rankings pages, ties
(duplicate places), 3-letter ISO country from flag images, EN + DE
weapon/gender labels, empty rankings (unfinished tournaments) → [].

- python/scrapers/dartagnan.py: new parsers + orchestrator
- python/scrapers/base.py: detect_platform domain match
- python/tools/populate_tournament_urls.py: discovery dispatch
- python/tests/test_scrapers.py: dart.1–dart.6 + dart.8 (integration)
- python/tests/test_url_discovery.py: dart.url.1
- python/tests/test_scrape_tournament.py: dart.7
- python/tests/fixtures/dartagnan/: 3 fixtures
- Project Specification: RTM FR-54 + Appendix D pytest count

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Never include `frontend/node_modules/.vite/vitest/results.json` in `git add`. Use `git stash push` on that file before `git pull --rebase origin main` if remote has CI-bot commits.

## 12. Environment facts (copy-paste ready)

```bash
# Python
cd /Users/aleks/coding/SPWSranklist
source .venv/bin/activate

# Local DB
DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
# psql via docker (no local psql binary):
docker exec supabase_db_SPWSranklist psql -U postgres -d postgres -c "<query>"

# Admin UI
http://localhost:5173/?admin=1
# Local admin: admin@spws.local / admin123 (recreated by reset-dev.sh)

# DB reset (NEVER bare `supabase db reset`)
./scripts/reset-dev.sh

# Current test baseline (2026-04-20):
# - pgTAP: 281  (documented in Appendix D line `pgTAP total: 281 assertions`)
# - pytest: 274 ("not integration"), + 9 skipped + 1 deselected
# - vitest: 267 / 267
```

## 13. What's already in place (DON'T re-build)

- EVF calendar scraper ([evf_calendar.py](../python/scrapers/evf_calendar.py), [evf_sync.py](../python/scrapers/evf_sync.py)) — writes to CERT every 3 days via cron.
- EVF results scraper ([evf_results.py](../python/scrapers/evf_results.py)) — URL-based JSON API for EVF, not Dartagnan.
- `fn_import_evf_events` + `fn_refresh_evf_event_urls` RPCs — idempotent, admin-edit-safe.
- Calendar promote CERT→PROD ([promote.py](../python/pipeline/promote.py) `--mode calendar`) — auto-runs after EVF sync cron.
- "Awaiting results" display status ([frontend/src/lib/eventStatus.ts](../frontend/src/lib/eventStatus.ts)) — past PLANNED events render amber.
- Salzburg event PEW7-2025-2026 already exists on CERT + PROD with URL enrichment (except results).
- Existing FTL / Engarde / 4fence scrapers — follow same pattern.

## 14. What NOT to do

- **No new ADR.** Dartagnan = format parity. Register it via RTM FR-54 update only.
- **No new migration.** Same ingestion RPCs as every other scraper.
- **No enum_status touching.** `fn_ingest_tournament_results` flips the status automatically.
- **No direct PROD writes from this work.** CERT only. PROD gets results via existing manual event-promote (ADR-026 original contract), and URL fields via the calendar-promote cron we already shipped.
- **No ingestion from the scraper module itself.** The scraper returns data; the orchestrator writes it. Separation of concerns like all other scrapers.

## 15. Rollback

If `dartagnan.py` misbehaves after push: revert the commit. Scraper is isolated, no shared state. Calendar scraper + event-promote continue working independently.

If Salzburg ingest wrote bad data to CERT: `SELECT fn_rollback_event('PEW7')` resets the event to PLANNED and deletes all ingested tournaments/results.
