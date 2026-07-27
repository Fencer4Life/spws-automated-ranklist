---
name: ftl-scrape
description: "Use whenever a task needs data from FencingTimeLive (fencingtimelive.com) in this repo (SPWS Automated Ranklist System) — event results, tournament schedules, or team-match / relay bout sheets. Since 2026-04 FTL requires an authenticated session; this repo authenticates through its OWN first-party pipeline (python/scrapers/ftl_auth.py) which reads FTL_USERNAME / FTL_PASSWORD from the process environment (.env for LOCAL, GitHub Secrets for CI). Running that pipeline is authorized project tooling — it is NOT Claude hand-typing a password into a web login form, so it is allowed. Triggers on: scrape FTL, a fencingtimelive.com URL, /events/results, /events/results/data, /teammatches/details, tournaments/eventSchedule, 'log in to Fencing Time Live', FTL session / connect.sid cookie, team-match relay bout data, EVF or FIE results hosted on FTL, 'Discovered 0 URLs'. Do NOT open the FTL login page in a browser pane and do NOT ask the user to log in manually — run the pipeline."
---

# FTL Scrape — authenticated FencingTimeLive fetch via the repo's own pipeline

## The one rule that keeps getting missed — read first

FencingTimeLive requires a logged-in session. **The correct way to get one is to
run this repo's own scraper**, `python/scrapers/ftl_auth.py`. It reads
`FTL_USERNAME` / `FTL_PASSWORD` from the process environment and performs the
`GET /account/login → POST /login` handshake itself.

Running that pipeline is **authorized, first-party project tooling** — the same
code CI and the daily ingestion run. It is **not** the prohibited act of Claude
hand-typing a user's password into a web login form; Claude never sees the
values. So:

- ✅ **DO** run the pipeline (`get_authed_ftl_client()`), which self-authenticates
  from the environment.
- ❌ **DON'T** open the FTL login page in the Browser pane and type credentials.
- ❌ **DON'T** ask the user to log in manually, or switch to their Chrome, "because
  Claude can't handle passwords." Not needed — the pipeline handles it.
- ❌ **DON'T** print, echo, log, or paste the credential values anywhere. Never
  `echo $FTL_PASSWORD`, never open `.env` to read the secret.

There is nothing to build — the login tooling already exists. Just call it.

## Prerequisite: credentials in the environment

The repo does **not** auto-load `.env` (no `python-dotenv`). Load it into the
shell first — this is silent, it does not echo the values:

```bash
cd /Users/aleks/coding/SPWSranklist
set -a; source .env; set +a          # loads FTL_USERNAME, FTL_PASSWORD, SUPABASE_*, ...
```

Then run the Python in that same shell. If `FTL_USERNAME` / `FTL_PASSWORD` are
missing, the helper raises `FtlAuthError` telling you exactly that.

## The primitive: an authed client for ANY FTL URL

```python
from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url

with get_authed_ftl_client() as client:          # logs in once, caches the session
    resp = client.get(normalize_ftl_url(url))     # normalize = apex → www (see gotchas)
    resp.raise_for_status()
    data = resp.json()                            # for /events/results/data/{UUID}
```

`get_authed_ftl_client(timeout=15.0, *, force_login=False)` is a context manager
yielding an `httpx.Client` with the authed `connect.sid` cookie. It caches the
cookie jar + expiry process-wide and reuses it (re-logging in only within 12 h of
expiry). The client rewrites apex→www on every request and raises `FtlAuthError`
if any resource fetch is bounced to the login page.

## Higher-level helpers (prefer these when they fit)

- **Event results → standardized rows, no DB writes:**
  ```python
  from python.tools.scrape_tournament import scrape_and_parse
  rows = scrape_and_parse("https://www.fencingtimelive.com/events/results/{UUID}")
  # -> [{"fencer_name": "SURNAME First", "place": 3, "country": "POL"}, ...]
  ```
  Detects the platform, converts a results-page URL to its `/data/` JSON endpoint,
  fetches with the authed client, and parses. Pure read.
- **Parsers** (`python/scrapers/ftl.py`): `parse_ftl_json(list[dict])`,
  `parse_ftl_with_marker(...)` (keeps the age-category marker digit),
  `parse_ftl_csv(text)`, `fetch_ftl_event_metadata(url, http_client)` (→ date /
  weapon / title), `extract_ftl_uuid(url)`.
- **Full ingestion of a whole event from its URL** (DB-writing; use only for
  real ingestion, not research):
  `python -m python.pipeline.ingest_cli --flow ingest_domestic --from-url --event-code <CODE> [--replace] [--dry-run]`.

## FTL URL shapes & data endpoints

| Purpose | Page URL | Data endpoint (fetch this) |
|---|---|---|
| Individual event results | `/events/results/{UUID}` | JSON `/events/results/data/{UUID}` · CSV `/events/results/download/{UUID}` |
| Event schedule (a tournament's events) | `/tournaments/eventSchedule/{UUID}` | HTML page (different UUID space — do **not** rewrite to `/events/results/`) |
| **Team match sheet (bout-level relay)** | `/teammatches/details/{eid}/{rid}/{matchId}` | HTML **fragment** at `…/{eid}/{rid}/{matchId}/data` (see below). Round context (e.g. "Bronze Medal") is in the parent page's `<h4 class="tmName">`. |

UUIDs are 32-char hex; `extract_ftl_uuid(url)` pulls them out of any results URL.

### Team-match relay fragment (confirmed 2026-07-26)

The parent page is a SPA shell whose `#encsDiv` is filled via
`$("#encsDiv").load("/teammatches/details/"+eid+"/"+rid+"/"+matchId+"/data")`,
live-updated over `socket.io` namespace `/teammatches`, event `change`. For a
finished match, fetch the fragment once:

```
GET /teammatches/details/{eid}/{rid}/{matchId}/data     # returns an HTML fragment, NOT JSON
```

`{eid}` / `{rid}` / `{matchId}` are the same three GUIDs as the details-page path
(tournament-event / round / match). The fragment is `table.tmTable`, one row per
relay leg:

```
# | <Team A name> | TS | Score | Score | TS | <Team B name> | #
```

- `#` = the fencer's line-up position: `1` / `2` / `3`, or `R` = reserve. Position 3
  typically anchors (fences legs 3, 5, 9 — the last leg decides the match).
- `TS` = touches that fencer scored **in that leg** (their side).
- `Score` = **cumulative** relay score after the leg (Team A column, then Team B).
- Per-leg ± for a fencer = their `TS` − opponent `TS` (equivalently, the delta of
  consecutive cumulative scores). The footer row marks the result per side:
  `V43` (victoire) / `D41` (défaite).

So position (incl. reserve), per-leg indicator, running score, and round context are
all recoverable — enough to read anchor/clutch temperament. There is **no first-party
parser** for this yet; parse the fragment HTML directly (classes: `tmPos`, `tmNameCol`,
`tmTouches`, `tmScore`, `tmFinalScore`).

### Enumerating a round's team matches (to get the match IDs)

Match IDs are **not** in the pool *scores* grid, the strips view, or seeding. Get them
per round (a round's `rid` differs per phase — find the pool `rid` and tableau `rid` from
the `/events/results/{eid}` nav hrefs):

- **Tableau matches:** walk the trees — `GET /tableaus/scores/{eid}/{rid}/trees` (JSON:
  each `{guid,name,numTables,firstIncompleteTable}`), then
  `GET /tableaus/scores/{eid}/{rid}/trees/{guid}/tables/0/{numTables+1}` (HTML). Every
  completed match carries an `[Match Details]` link → `/teammatches/details/{eid}/{rid}/{matchId}`.
- **Pool matches:** the pool *scores* grid has NO IDs. Use pool **details**: get each
  pool's `{poolGuid}` from `/pools/scores/{eid}/{poolRid}` (or its `?dbut=true` variant's
  "Details" button → `/pools/details/{eid}/{poolRid}/{poolGuid}`), then
  `GET /pools/details/{eid}/{poolRid}/{poolGuid}/data` (the "Bout Order" list) — it carries
  `/teammatches/details/{eid}/{poolRid}/{matchId}` links for every encounter in the pool.
- **Team rosters + team GUIDs:** `GET /rounds/seeding/data/{eid}/{rid}` → JSON
  `[{id, seed, name, mem:[fencers…], country, rank}]`. Best source for "who is on this team".

## Event-level team scraping (whole championship)

`python/tools/scrape_team_events.py` automates everything above: given an
`eventSchedule` UUID it walks every team tournament, finds a target country's team
in the pool + every bracket, and writes a JSON store of every relay (per-leg) with
a per-fencer contribution profile. It handles the structural variants seen in the
wild — MEW full-name pools+brackets, MSW country-code brackets, positionless leg
rows, and medical-withdrawal walkovers (recorded with `walkover:true`, no legs). Run:

```
set -a; source .env; set +a
python -m python.tools.scrape_team_events --schedule <UUID> \
    --name "MEW Cognac 2026" --country Poland --out doc/reports/team-events/<slug>.json
```

Note: **cross-championship fencer identity needs name resolution** (Ł↔L, dropped
diacritics, surname changes/hyphenation) — merge via the repo's `python/matcher`
subsystem, not raw string equality.

## Gotchas (all handled by the helper — know them for debugging)

- **Host-only cookie.** `connect.sid` is scoped to `www.fencingtimelive.com` only.
  A URL on the apex `fencingtimelive.com` is sent *without* the cookie and silently
  302s to `/account/login` → the classic **"Discovered 0 URLs"**. Always pass URLs
  through `normalize_ftl_url()` (the client's request hook also rewrites them).
- **Session is not rolling.** Expiry is a fixed *login + 10 days*, not refreshed by
  use. The helper re-logs in automatically within 12 h of expiry.
- **A 302 to `/account/login` on a resource fetch** ⇒ `FtlAuthError` (session
  expired/invalid). Force a fresh login with `get_authed_ftl_client(force_login=True)`
  or `reset_session_cache()`.
- **Credentials rejected** ⇒ `FtlAuthError("… wrong password, account locked, or
  account suspended …")`. Fix `FTL_USERNAME` / `FTL_PASSWORD` in `.env` (LOCAL) and
  GitHub repository secrets (CI).

## Existing call sites (canonical usage to copy from)

`python/pipeline/ingest_cli.py` (`--from-url`), `python/pipeline/url_reachability.py`,
`python/tools/scrape_ftl_event_urls.py`, `python/tools/populate_tournament_urls.py`,
`python/tools/scrape_tournament.py`, `python/scrapers/evf_sync.py`,
`python/tools/recreate_active_season_2025_2026.py` — all wrap
`with get_authed_ftl_client() as client:`.
