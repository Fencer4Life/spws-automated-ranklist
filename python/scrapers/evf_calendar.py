"""
EVF Calendar Scraper — veteransfencing.eu + api.veteransfencing.eu (ADR-028)

Primary source: HTML calendar list at veteransfencing.eu (authoritative for
current/upcoming events — the EVF JSON API `/events` endpoint only returns
historical events with finalised results).

Enrichment layers:
  * Per-event detail pages → url_invitation, url_registration,
    dt_registration_deadline (keyword + regex heuristics, EN + PL).
  * JSON API cross-reference → weapons normalisation for events already
    recorded with results in the API (best-effort diagnostic).

Failure semantics:
  * HTML ok, API ok                          → use HTML, log API info
  * HTML ok, API fails                       → use HTML, log warning
  * HTML empty+valid, API returns events     → fall through to API (edge case)
  * HTML fails, API ok with events           → fall through to API, log warning
  * Both fail / both empty and errored       → raise RuntimeError
    (workflow `if: failure()` step then fires Telegram alert)
  * Detail-page fetch fails per event        → log warning, keep other events
"""

from __future__ import annotations

import logging
import re
from datetime import datetime

import httpx
import unicodedata
from bs4 import BeautifulSoup

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None  # type: ignore[assignment]

logger = logging.getLogger("evf.calendar")


# Country-name aliases used by EVF + seed data. Each canonical form below
# matches any of its aliases after diacritic-folding + case-folding.
# ADR-028 dedup key depends on these.
_COUNTRY_ALIASES = {
    "poland":     {"polska"},
    "germany":    {"deutschland"},
    "italy":      {"italia"},
    "austria":    {"osterreich"},  # diacritic-folded from Österreich
    "spain":      {"espana"},       # diacritic-folded from España
    "belgium":    {"belgique", "belgie"},  # fr + nl
    "greece":     {"hellas", "ellada"},
    "netherlands": {"holland", "nederland"},
    "france":     {},
    "hungary":    {"magyarorszag"},
    "czechia":    {"czech republic", "ceska republika"},
    "sweden":     {"sverige"},
    "norway":     {"norge"},
    "finland":    {"suomi"},
    "denmark":    {"danmark"},
    "switzerland": {"schweiz", "suisse", "svizzera"},
    "great britain": {"united kingdom", "uk", "england", "britain"},
    "ireland":    {"eire"},
}

# Reverse index: any variant → canonical. Canonicals also map to themselves.
_COUNTRY_CANONICAL: dict[str, str] = {}
for canonical, aliases in _COUNTRY_ALIASES.items():
    _COUNTRY_CANONICAL[canonical] = canonical
    for alias in aliases:
        _COUNTRY_CANONICAL[alias] = canonical


def _normalize_country(name: str | None) -> str:
    """Canonicalise a country name for dedup comparison.

    Steps: strip → lower → diacritic-fold → alias-map. Returns "" for
    None/empty so the fallback path (fuzzy name) kicks in cleanly.
    """
    if not name:
        return ""
    s = unicodedata.normalize("NFKD", name.strip().lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return _COUNTRY_CANONICAL.get(s, s)

# TODO(ADR-028): disabled 2026-04-20 — live hit rate was 0/13 against EVF detail
# pages. Re-enable once real-world deadline phrasings have been observed and the
# `_DEADLINE_PATTERNS` regex list is tuned against them.
HARVEST_DEADLINE = False

EVF_CALENDAR_FUTURE = "https://www.veteransfencing.eu/calendar/"
EVF_CALENDAR_PAST = "https://www.veteransfencing.eu/calendar/list/?eventDisplay=past"

WEAPON_MAP = {1: "FOIL", 2: "EPEE", 3: "SABRE"}

_PUBLIC_EVENT_KEYS = (
    "name", "dt_start", "dt_end", "location", "address", "country",
    "weapons", "is_team", "url", "fee", "fee_currency",
    "url_invitation", "url_registration", "dt_registration_deadline",
)

_REGISTRATION_HOSTS = (
    "engarde-escrime.com", "engarde-service.com",
    "fencingtimelive.com", "ophardt.online",
)
_REGISTRATION_KEYWORDS = re.compile(
    r"register|registration|entry|entries|zgłoszenia|zgloszenia",
    re.IGNORECASE,
)
_INVITATION_KEYWORDS = re.compile(
    r"invitation|prospectus|regulation|zaproszenie|regulamin",
    re.IGNORECASE,
)
_DEADLINE_PATTERNS = [
    re.compile(r"registration\s+(?:closes|deadline|ends)[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})", re.IGNORECASE),
    re.compile(r"registration\s+(?:closes|deadline|ends)[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(r"entries?\s+close[s]?(?:\s+on)?[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})", re.IGNORECASE),
    re.compile(r"entries?\s+close[s]?(?:\s+on)?[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(r"(?:deadline|closes|termin)[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(r"(?:deadline|closes|termin)[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})", re.IGNORECASE),
    re.compile(r"closes\s+on\s+(\d{1,2}\s+\w+\s+\d{4})", re.IGNORECASE),
    re.compile(r"closes\s+(\d{1,2}\s+\w+\s+\d{4})", re.IGNORECASE),
]


def _blank_event() -> dict:
    """Return an event dict with all public keys initialised to neutral defaults."""
    return {
        "name": "", "dt_start": "", "dt_end": "",
        "location": "", "address": "", "country": "",
        "weapons": [], "is_team": False,
        "url": "", "fee": None, "fee_currency": "",
        "url_invitation": None, "url_registration": None,
        "dt_registration_deadline": None,
    }


# =============================================================================
# HTML list page parsing (evf.1–evf.3)
# =============================================================================


def parse_evf_calendar_html(html: str) -> list[dict]:
    """Parse veteransfencing.eu/calendar/ HTML into event dicts.

    Returns list of dicts with keys matching ``_PUBLIC_EVENT_KEYS``.
    Skips articles with missing/unparseable date data rather than raising.
    """
    soup = BeautifulSoup(html, "html.parser")
    events: list[dict] = []

    for article in soup.select(".tribe-events-calendar-list__event"):
        title_el = article.select_one(".tribe-events-calendar-list__event-title a")
        name = title_el.get_text().strip() if title_el else ""
        if not name:
            continue
        url = title_el.get("href", "") if title_el else ""

        dt_els = article.select("[datetime]")
        if not dt_els:
            continue
        dt_start = dt_els[0].get("datetime", "") or ""
        dt_end = dt_els[1].get("datetime", "") if len(dt_els) > 1 else dt_start
        if not dt_start:
            continue

        venue_el = article.select_one(".tribe-events-calendar-list__event-venue-title")
        venue = venue_el.get_text().strip() if venue_el else ""

        addr_el = article.select_one(".tribe-events-calendar-list__event-venue-address")
        address = addr_el.get_text().strip() if addr_el else ""

        country = ""
        if address:
            parts = [p.strip() for p in address.split(",")]
            if parts:
                country = parts[-1]

        classes = article.get("class", []) or []
        weapons: list[str] = []
        if "cat_epee" in classes:
            weapons.append("EPEE")
        if "cat_foil" in classes:
            weapons.append("FOIL")
        if "cat_sabre" in classes:
            weapons.append("SABRE")

        is_team = "team" in name.lower()

        cost_el = article.select_one(".tribe-events-calendar-list__event-cost")
        fee = None
        fee_currency = ""
        if cost_el:
            cost_text = cost_el.get_text().strip()
            fee_match = re.search(r"[€$£]?\s*(\d+(?:\.\d+)?)", cost_text)
            if fee_match:
                fee = float(fee_match.group(1))
                if "€" in cost_text:
                    fee_currency = "EUR"
                elif "£" in cost_text:
                    fee_currency = "GBP"
                elif "$" in cost_text:
                    fee_currency = "USD"

        evt = _blank_event()
        evt.update({
            "name": name,
            "dt_start": dt_start[:10],
            "dt_end": dt_end[:10] if dt_end else dt_start[:10],
            "location": venue,
            "address": address,
            "country": country,
            "weapons": weapons,
            "is_team": is_team,
            "url": url,
            "fee": fee,
            "fee_currency": fee_currency,
        })
        events.append(evt)

    return events


def _fetch_html_list() -> list[dict]:
    """Fetch past+future HTML calendar pages, parse, merge, dedupe by date+name.

    Raises RuntimeError only if both URLs fail at network/HTTP level. Returns
    a possibly-empty list on parseable-but-empty responses.
    """
    all_events: list[dict] = []
    seen_keys: set[str] = set()
    errors: list[str] = []
    successes = 0

    for url in (EVF_CALENDAR_PAST, EVF_CALENDAR_FUTURE):
        try:
            resp = httpx.get(url, timeout=30, follow_redirects=True)
            resp.raise_for_status()
            page_events = parse_evf_calendar_html(resp.text)
        except httpx.HTTPError as exc:
            errors.append(f"{url}: {type(exc).__name__}: {exc}")
            logger.warning("HTML calendar fetch failed for %s: %s", url, exc)
            continue
        except (ValueError, KeyError, IndexError) as exc:
            errors.append(f"{url}: parser {type(exc).__name__}: {exc}")
            logger.warning("HTML calendar parse failed for %s: %s", url, exc)
            continue

        successes += 1
        for e in page_events:
            key = f"{e['dt_start']}_{e['name']}"
            if key not in seen_keys:
                seen_keys.add(key)
                all_events.append(e)

    if successes == 0:
        raise RuntimeError("HTML calendar scrape failed on all URLs: " + " | ".join(errors))

    return all_events


# =============================================================================
# JSON API primary path (evf.6)
# =============================================================================


def fetch_calendar_from_api(client, season_start: str, season_end: str) -> list[dict]:
    """Fetch season events from the EVF JSON API.

    Uses ``client.get_events()`` for the authoritative event list, then
    ``client.get_competitions(event_id)`` to derive weapons, is_team, dt_end.

    Raises RuntimeError on full-API failure. Empty list is a valid result.
    """
    try:
        events = client.get_events()
    except Exception as exc:  # network / auth / shape change
        raise RuntimeError(f"EVF API /events failed: {type(exc).__name__}: {exc}") from exc

    if not isinstance(events, list):
        raise RuntimeError(f"EVF API /events returned non-list: {type(events).__name__}")

    out: list[dict] = []
    for api_evt in events:
        try:
            eid = api_evt.get("id")
            opens = (api_evt.get("opens") or "")[:10]
            closes = (api_evt.get("closes") or opens)[:10]
            if not opens:
                continue
            if opens < season_start or opens > season_end:
                continue

            weapons_set: set[str] = set()
            is_team = "team" in (api_evt.get("name") or "").lower()
            dt_end = closes
            if eid is not None:
                try:
                    comps = client.get_competitions(eid) or []
                except Exception as exc:
                    logger.warning("EVF API competitions(%s) failed: %s", eid, exc)
                    comps = []
                for c in comps:
                    w = WEAPON_MAP.get(c.get("weaponId"))
                    if w:
                        weapons_set.add(w)
                    cs = (c.get("starts") or "")[:10]
                    if cs and cs > dt_end:
                        dt_end = cs
                    if c.get("teamId"):
                        is_team = True

            evt = _blank_event()
            evt.update({
                "name": api_evt.get("name") or "",
                "dt_start": opens,
                "dt_end": dt_end,
                "location": api_evt.get("location") or "",
                "country": api_evt.get("country_abbr") or api_evt.get("country") or "",
                "weapons": sorted(weapons_set),
                "is_team": is_team,
            })
            out.append(evt)
        except Exception as exc:
            logger.warning("Skipping malformed API event %r: %s", api_evt, exc)

    return out


def _merge_html_into_api(api_events: list[dict], html_events: list[dict]) -> list[dict]:
    """Copy HTML-only fields (fee, fee_currency, url, address) onto API events
    when date + fuzzy-name match.
    """
    if not html_events:
        return api_events

    for api_evt in api_events:
        best = None
        best_score = 0.0
        for h in html_events:
            try:
                d1 = datetime.strptime(api_evt["dt_start"], "%Y-%m-%d")
                d2 = datetime.strptime(h.get("dt_start", ""), "%Y-%m-%d")
                if abs((d1 - d2).days) > 3:
                    continue
            except (ValueError, TypeError):
                continue
            if fuzz is not None:
                score = fuzz.token_set_ratio(api_evt.get("name", ""), h.get("name", ""))
            else:
                a = api_evt.get("name", "").lower()
                b = h.get("name", "").lower()
                score = 100.0 if (a in b or b in a) else 0.0
            if score >= 80 and score > best_score:
                best = h
                best_score = score

        if best is not None:
            for key in ("fee", "fee_currency", "url", "address"):
                if not api_evt.get(key) and best.get(key):
                    api_evt[key] = best[key]
            if not api_evt.get("country") and best.get("country"):
                api_evt["country"] = best["country"]

    return api_events


# =============================================================================
# Per-event detail page (evf.7–evf.10)
# =============================================================================


def _normalise_date(raw: str) -> str | None:
    """Try multiple formats, return ISO yyyy-mm-dd or None."""
    raw = raw.strip()
    for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y", "%d-%m-%Y",
                "%d.%m.%y", "%d/%m/%y", "%d-%m-%y",
                "%d %B %Y", "%d %b %Y"):
        try:
            return datetime.strptime(raw, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return None


def parse_event_detail_html(html: str) -> dict:
    """Extract url_invitation, url_registration, dt_registration_deadline
    from an EVF event detail page (WordPress + The Events Calendar).
    """
    soup = BeautifulSoup(html, "html.parser")
    body = (
        soup.select_one(".tribe-events-content")
        or soup.select_one(".tribe-events-single-event")
        or soup
    )

    url_invitation: str | None = None
    url_registration: str | None = None

    # Pass 1: explicit keyword matches on anchor text
    for a in body.select("a[href]"):
        href = (a.get("href") or "").strip()
        text = a.get_text(" ", strip=True)
        if not href:
            continue
        if url_registration is None:
            if any(host in href for host in _REGISTRATION_HOSTS):
                url_registration = href
            elif _REGISTRATION_KEYWORDS.search(text):
                url_registration = href
        if url_invitation is None:
            if href.lower().endswith(".pdf") and _INVITATION_KEYWORDS.search(text):
                url_invitation = href

    # Pass 2: fallback — any PDF inside the body
    if url_invitation is None:
        for a in body.select("a[href]"):
            href = (a.get("href") or "").strip()
            if href.lower().endswith(".pdf"):
                url_invitation = href
                break

    # Deadline — search full visible text of the body
    dt_registration_deadline: str | None = None
    if HARVEST_DEADLINE:
        text_blob = body.get_text(" ", strip=True)
        for pat in _DEADLINE_PATTERNS:
            m = pat.search(text_blob)
            if m:
                dt_registration_deadline = _normalise_date(m.group(1))
                if dt_registration_deadline:
                    break

    return {
        "url_invitation": url_invitation,
        "url_registration": url_registration,
        "dt_registration_deadline": dt_registration_deadline,
    }


def enrich_event_details(events: list[dict], delay: float = 0.5) -> list[dict]:
    """For each event with a detail URL, fetch the page and merge URL fields.

    Per-event failures are logged and swallowed — one bad page must not abort
    the batch. Fields are only overwritten when the detail page provides a
    non-empty value.
    """
    import time

    inv_hits = reg_hits = dl_hits = 0

    for i, evt in enumerate(events):
        url = evt.get("url")
        if not url:
            continue
        if i > 0 and delay:
            try:
                time.sleep(delay)
            except Exception:
                pass

        try:
            resp = httpx.get(url, timeout=20, follow_redirects=True)
            resp.raise_for_status()
            extracted = parse_event_detail_html(resp.text)
        except (httpx.HTTPError, ValueError, KeyError, IndexError) as exc:
            logger.warning("Detail page fetch failed for %s: %s", url, exc)
            continue
        except Exception as exc:  # pragma: no cover — defensive
            logger.warning("Detail page unexpected error for %s: %s", url, exc)
            continue

        if extracted.get("url_invitation") and not evt.get("url_invitation"):
            evt["url_invitation"] = extracted["url_invitation"]
            inv_hits += 1
        if extracted.get("url_registration") and not evt.get("url_registration"):
            evt["url_registration"] = extracted["url_registration"]
            reg_hits += 1
        if (
            HARVEST_DEADLINE
            and extracted.get("dt_registration_deadline")
            and not evt.get("dt_registration_deadline")
        ):
            evt["dt_registration_deadline"] = extracted["dt_registration_deadline"]
            dl_hits += 1

    logger.info("Detail-page enrichment: inv=%d reg=%d deadline=%d (over %d events)",
                inv_hits, reg_hits, dl_hits, len(events))
    return events


# =============================================================================
# Orchestration (evf.11)
# =============================================================================


def scrape_full_season_calendar(
    season_start: str,
    season_end: str,
    *,
    client=None,
    skip_details: bool = False,
) -> list[dict]:
    """Scrape EVF season calendar.

    Primary source: HTML calendar list at veteransfencing.eu (authoritative).
    Secondary source: JSON API — only useful as fall-through when HTML fails
    or returns nothing; the `/events` endpoint lists historical events only.

    Only circuit / championship / criterium events are returned.

    Args:
        season_start, season_end: ISO date strings (inclusive).
        client: optional pre-connected EvfApiClient. If None, constructed &
            closed internally.
        skip_details: if True, skip per-event detail-page enrichment (useful
            in tests).

    Raises:
        RuntimeError: if both sources errored (HTML and API both threw).
    """
    api_events: list[dict] | None = None
    html_events: list[dict] | None = None
    errors: list[str] = []

    # --- Primary: HTML calendar list -------------------------------------
    try:
        html_events = _fetch_html_list()
        logger.info("EVF HTML list returned %d events", len(html_events))
    except Exception as exc:
        errors.append(f"HTML: {type(exc).__name__}: {exc}")
        logger.warning("EVF HTML calendar path failed: %s", exc)

    # --- Secondary: JSON API (cross-reference / fallback) ----------------
    own_client = False
    try:
        if client is None:
            from python.scrapers.evf_results import EvfApiClient
            client = EvfApiClient()
            client.connect()
            own_client = True
        api_events = fetch_calendar_from_api(client, season_start, season_end)
        logger.info(
            "EVF API returned %d events in [%s, %s]",
            len(api_events), season_start, season_end,
        )
    except Exception as exc:
        errors.append(f"API: {type(exc).__name__}: {exc}")
        logger.warning("EVF API calendar path failed: %s", exc)
    finally:
        if own_client and client is not None:
            try:
                client.close()
            except Exception:
                pass

    # --- Decide primary source ------------------------------------------
    html_errored = html_events is None
    api_errored = api_events is None
    have_html = bool(html_events)
    have_api = bool(api_events)

    if html_errored and api_errored:
        raise RuntimeError(
            "EVF calendar scrape failed on all sources: " + " | ".join(errors)
        )

    if have_html:
        merged = html_events  # type: ignore[assignment]
        if have_api:
            _merge_html_into_api(api_events, html_events)  # type: ignore[arg-type]
    elif have_api:
        logger.warning(
            "Falling back to API-only calendar (HTML returned no events)"
        )
        merged = api_events  # type: ignore[assignment]
    else:
        # Both sources succeeded but returned empty lists — nothing in window
        logger.warning(
            "EVF calendar: no events returned from any source in [%s, %s]",
            season_start, season_end,
        )
        return []

    filtered = filter_by_season(merged, season_start, season_end)
    relevant = [
        e for e in filtered
        if (
            "circuit" in e["name"].lower()
            or "championship" in e["name"].lower()
            or "criterium" in e["name"].lower()
        )
    ]

    # --- Tertiary: per-event detail pages --------------------------------
    if not skip_details:
        try:
            enrich_event_details(relevant)
        except Exception as exc:
            logger.warning("Detail-page batch enrichment failed (non-fatal): %s", exc)

    return relevant


def filter_by_season(events: list[dict], season_start: str, season_end: str) -> list[dict]:
    """Filter events to those within the season date range (inclusive)."""
    return [
        e for e in events
        if e.get("dt_start", "") >= season_start
        and e.get("dt_start", "") <= season_end
    ]


def _find_existing_match(
    s_evt: dict,
    existing: list[dict],
    date_tolerance: int,
    name_threshold: float,
) -> dict | None:
    """Find the best existing-row match for a scraped event (ADR-028 dedup key).

    Primary: exact dt_start + normalized country. This is the natural key
    for EVF-organized events (cannot have two different EVF events on the
    same day in the same country).

    Fallback: date tolerance ±N days + fuzzy name ≥ threshold, with
    diacritic folding so "Jablonna" matches "Jabłonna". Used when country
    is missing (legacy rows / scrapers that don't emit country).
    """
    s_date = s_evt.get("dt_start", "")
    s_country = _normalize_country(s_evt.get("country", ""))

    # Primary match: exact dt_start + same canonical country
    if s_country:
        for ex in existing:
            if str(ex.get("dt_start", "")) != s_date:
                continue
            if _normalize_country(ex.get("txt_country", "")) == s_country:
                return ex

    # Fallback: date tolerance + fuzzy name (diacritic-folded)
    try:
        sd = datetime.strptime(s_date, "%Y-%m-%d")
    except (ValueError, TypeError):
        return None

    s_name_folded = _diacritic_fold(s_evt.get("name", ""))
    best: dict | None = None
    best_score = 0.0

    for ex in existing:
        ex_date = str(ex.get("dt_start", ""))
        try:
            ed = datetime.strptime(ex_date, "%Y-%m-%d")
        except (ValueError, TypeError):
            continue
        if abs((sd - ed).days) > date_tolerance:
            continue

        ex_name_folded = _diacritic_fold(ex.get("txt_name", ""))
        if fuzz is not None:
            score = float(fuzz.token_set_ratio(s_name_folded, ex_name_folded))
        else:
            score = 100.0 if (
                s_name_folded.lower() in ex_name_folded.lower()
                or ex_name_folded.lower() in s_name_folded.lower()
            ) else 0.0

        if score >= name_threshold and score > best_score:
            best = ex
            best_score = score

    return best


def _diacritic_fold(text: str) -> str:
    """NFKD + strip combining marks — 'Jabłonna' → 'Jablonna'."""
    if not text:
        return ""
    s = unicodedata.normalize("NFKD", text)
    return "".join(c for c in s if not unicodedata.combining(c))


def match_scraped_to_existing(
    scraped: list[dict],
    existing: list[dict],
    date_tolerance: int = 7,
    name_threshold: float = 80.0,
) -> list[tuple[dict, dict]]:
    """Pair each scraped event with its best-matching existing DB row, if any.

    Uses (dt_start exact + country) primary, fuzzy-name fallback. Returns
    `[(scraped_evt, existing_row), ...]` for every scraped event that matched
    an existing row. Existing rows must carry at least `txt_name` + `dt_start`
    (+ `txt_country` for the primary path, + `id_event` when the caller plans
    to feed the refresh RPC).
    """
    pairs: list[tuple[dict, dict]] = []
    for s_evt in scraped:
        match = _find_existing_match(s_evt, existing, date_tolerance, name_threshold)
        if match is not None:
            pairs.append((s_evt, match))
    return pairs


def deduplicate_events(
    scraped: list[dict],
    existing: list[dict],
    date_tolerance: int = 7,
    name_threshold: float = 80.0,
) -> tuple[list[dict], list[dict]]:
    """Split scraped events into (new, already_imported).

    Primary dedup key: dt_start (exact) + country (normalised). This catches
    EVF renames like "Napoli"→"Naples (ITA)" that defeat token_set_ratio.
    Fallback: ±date_tolerance days + fuzzy name ≥ threshold with diacritic
    folding (keeps backward compat when country is missing). See ADR-028.
    """
    new: list[dict] = []
    already: list[dict] = []
    for s_evt in scraped:
        match = _find_existing_match(s_evt, existing, date_tolerance, name_threshold)
        if match is not None:
            already.append(s_evt)
        else:
            new.append(s_evt)
    return new, already
