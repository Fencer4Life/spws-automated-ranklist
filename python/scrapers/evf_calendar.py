"""
EVF Calendar Scraper — veteransfencing.eu + api.veteransfencing.eu (ADR-028)

Primary source: HTML calendar list at veteransfencing.eu (authoritative for
current/upcoming events).

JSON API reality (live-verified 2026-07-10 — the previous "historical events
with finalised results" claim here was wrong and has been replaced):
  * `EvfApiClient.get_events()` (`/events`) is effectively abandoned, not
    merely "historical" — a live call returned 20 events, the newest opening
    2020-05-21. Nothing from the current or any recent season is in it. The
    "HTML fails → fall through to API" failure-mode path below is therefore
    theoretical only: if HTML scraping ever breaks, this fallback will
    silently yield ~0 current-season events, not actually recover them.
  * `EvfApiClient.get_competitions(id)` (`/events/competitions`, scanned by
    raw integer id — this integer IS the real EVF event id, stored as
    `tbl_event.id_evf_event`) does cover the current season, but an id only
    exists once EVF has built out that event's competitions in their own
    backend, which lags behind the public calendar listing. Live scan
    2026-07-10: ids exist up to 91 (Dublin, opens 2026-05-31); ids 92-199 are
    all empty, even though events later than that (e.g. "EVF Circuit –
    Samorin (SVK)", 2026-09-12) are already published on the public HTML
    calendar with a confirmed date. A future/TBD-venue calendar event
    therefore has NO EVF id available at scrape time — the calendar-path
    dedup key cannot rely on `id_evf_event` alone.

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
    (see JSON API reality above: in practice this recovers ~nothing for the
    active season since `get_events()` is frozen at 2020)
  * Both fail / both empty and errored       → raise RuntimeError
    (workflow `if: failure()` step then fires Telegram alert)
  * Detail-page fetch fails per event        → log warning, keep other events
"""

from __future__ import annotations

import logging
import re
import unicodedata
from datetime import date, datetime
from io import BytesIO

import httpx
from bs4 import BeautifulSoup

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None  # type: ignore[assignment]

logger = logging.getLogger("evf.calendar")


# Stale-event gate: scraper only auto-creates / auto-updates events whose
# dt_end is within this many days of today AND status != 'COMPLETED' (ADR-039).
STALE_WINDOW_DAYS = 30

# Location fallback threshold for dedup when country is missing on either
# side (ADR-039 Step 4).
LOCATION_MATCH_THRESHOLD = 70.0

# CAMP entries are training activities, not competitions.  Match a complete
# word only: "Campbell" remains a legitimate event name.
_CAMP_WORD_RE = re.compile(r"\bcamp\b", re.IGNORECASE)
_PEW_NUMBER_RE = re.compile(r"^PEW(\d+)[efs]*-")
_WEAPON_LETTERS = {"EPEE": "e", "FOIL": "f", "SABRE": "s"}

# Detail-page weapon recovery.  The list page tags weapons only through the
# post's cat_epee/cat_foil/cat_sabre taxonomy classes; a post published without
# them arrives weaponless and fail-closes the season scrape.  The event's own
# detail page carries the same fact twice over -- in the category meta, and in
# the description line the organizers always open with ("EPEE + SABRE").
# Whole-word matching only, so "Epee" in a category list and "EPEE +FOIL" in a
# body written without spaces both read correctly while prose cannot invent a
# weapon.
_DETAIL_WEAPON_RE = re.compile(r"\b(EPEE|FOIL|SABRE)\b", re.IGNORECASE)

# One-time historical fact from the approved 2026-2027 repair manifest: this
# occurrence was already cancelled before its first authoritative import, but
# buggy scrapes previously gave it a positive code.  Once repaired, PEW0 also
# carries the fact without relying on this exception.
_KNOWN_FIRST_IMPORT_CANCELLATIONS = {5074}
_KNOWN_WEAPON_OVERRIDES = {
    # EVF calendar post omits categories; the organizer's published programme
    # lists men's and women's epee, foil and sabre (approved repair evidence).
    5070: ["EPEE", "FOIL", "SABRE"],
}


class LogicalIntegrityError(RuntimeError):
    """Raised when CERT contains a row with dt_start in the future AND
    enum_status='COMPLETED'. This is data corruption — admin must fix
    manually before the scraper can safely proceed (ADR-039 Step 0).
    """


class CalendarIntegrityError(RuntimeError):
    """Raised when the public EVF calendar cannot form a complete season snapshot."""


def is_ignored_calendar_entry(event: dict) -> bool:
    """Return whether an EVF calendar row must be excluded from all processing."""
    return bool(_CAMP_WORD_RE.search(str(event.get("name") or "")))


def _weapon_suffix(event: dict) -> str:
    """Build the canonical alphabetical e/f/s suffix for one EVF competition."""
    letters = {
        _WEAPON_LETTERS[str(weapon).upper()]
        for weapon in event.get("weapons", [])
        if str(weapon).upper() in _WEAPON_LETTERS
    }
    return "".join(sorted(letters))


def _is_safe_to_renumber(existing_row: dict | None) -> bool:
    """Whether an event's code may shift when the chronological sequence shifts.

    A PEW number is chronological position, so a newly-announced mid-season
    event moves every later event down one.  A later cancellation is pinned to
    its stored number, and the two rules collide -- observed live on 2026-08-28
    when admitting Tampere moved Stockholm from PEW11 to PEW12 in the same
    scrape that cancelled it.

    Renaming is safe only while nothing is anchored to the old code: the event
    is still in the future and nobody has entered it.  Registration is the real
    anchor -- a fencer who has entered holds a code we must not move under
    them -- and results are anchored to it too, through the child tournament
    codes the ingest RPC rebuilds from the event code.

    A roster row that does not carry the counts cannot prove it is safe, so it
    is refused: unknown is not the same as zero.
    """
    if not existing_row:
        return False
    if "num_registrations" not in existing_row or "num_results" not in existing_row:
        return False
    if int(existing_row.get("num_registrations") or 0) > 0:
        return False
    if int(existing_row.get("num_results") or 0) > 0:
        return False

    raw_start = existing_row.get("dt_start")
    if not raw_start:
        return False
    try:
        return datetime.strptime(str(raw_start)[:10], "%Y-%m-%d").date() > date.today()
    except (TypeError, ValueError):
        return False


def plan_calendar_codes(events: list[dict], existing: list[dict], season_code: str) -> list[dict]:
    """Return a complete deterministic EVF code plan in chronological order.

    New events already cancelled at their first import receive base number zero
    and do not consume the positive sequence.  An existing cancelled event with
    a positive PEW number is a later cancellation: it remains in sequence and
    its base number must stay unchanged.  Equal dates are ordered by the stable
    public EVF calendar id.
    """
    season_suffix = re.sub(r"^SPWS-", "", season_code)
    existing_by_calendar_id = {
        int(row["id_evf_calendar_event"]): row
        for row in existing
        if row.get("id_evf_calendar_event") is not None
    }
    ordered = sorted(
        (dict(event) for event in events if not is_ignored_calendar_entry(event)),
        key=lambda event: (str(event.get("dt_start") or ""), int(event["evf_calendar_id"])),
    )

    positive: list[dict] = []
    zero: list[dict] = []
    for event in ordered:
        prior = existing_by_calendar_id.get(int(event["evf_calendar_id"]))
        prior_match = _PEW_NUMBER_RE.match(str(prior.get("txt_code") or "")) if prior else None
        prior_number = int(prior_match.group(1)) if prior_match else None
        if event.get("is_cancelled") and (
            prior_number is None
            or prior_number == 0
            or int(event["evf_calendar_id"]) in _KNOWN_FIRST_IMPORT_CANCELLATIONS
        ):
            zero.append(event)
        else:
            event["_prior_number"] = prior_number
            positive.append(event)

    for event in zero:
        event["desired_code"] = f"PEW0{_weapon_suffix(event)}-{season_suffix}"

    zero_codes = [event["desired_code"] for event in zero]
    duplicates = sorted({code for code in zero_codes if zero_codes.count(code) > 1})
    if duplicates:
        raise CalendarIntegrityError(
            "multiple first-import cancellations would share code " + ", ".join(duplicates)
        )

    for number, event in enumerate(positive, start=1):
        prior_number = event.pop("_prior_number", None)
        if event.get("is_cancelled") and prior_number not in (None, number):
            prior_row = existing_by_calendar_id.get(int(event["evf_calendar_id"]))
            if not _is_safe_to_renumber(prior_row):
                raise CalendarIntegrityError(
                    f"later cancellation {event.get('name')!r} must retain PEW{prior_number}, "
                    f"but chronological position is PEW{number}"
                )
            logger.info(
                "Sequence shift: %r moves PEW%s -> PEW%s (future, no registrations, "
                "no results — nothing is anchored to the old code)",
                event.get("name"),
                prior_number,
                number,
            )
        event["desired_code"] = f"PEW{number}{_weapon_suffix(event)}-{season_suffix}"

    return sorted(zero + positive, key=lambda event: (event["dt_start"], event["evf_calendar_id"]))


# Country-name aliases used by EVF + seed data. Each canonical form below
# matches any of its aliases after diacritic-folding + case-folding.
# ADR-028 dedup key depends on these.
_COUNTRY_ALIASES = {
    "poland": {"polska"},
    "germany": {"deutschland"},
    "italy": {"italia"},
    "austria": {"osterreich"},  # diacritic-folded from Österreich
    "spain": {"espana"},  # diacritic-folded from España
    "belgium": {"belgique", "belgie"},  # fr + nl
    "greece": {"hellas", "ellada"},
    "netherlands": {"holland", "nederland"},
    "france": {},
    "hungary": {"magyarorszag"},
    "czechia": {"czech republic", "ceska republika"},
    "sweden": {"sverige"},
    "norway": {"norge"},
    "finland": {"suomi"},
    "denmark": {"danmark"},
    "switzerland": {"schweiz", "suisse", "svizzera"},
    "great britain": {"united kingdom", "uk", "england", "britain"},
    "ireland": {"eire"},
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


def _extract_evf_slug(url: str | None) -> str:
    """Extract the last path segment of an EVF calendar detail-page URL.

    'https://www.veteransfencing.eu/event/evf-circuit-samorin-svk/' -> 'evf-circuit-samorin-svk'.
    Returns "" for blank/unparseable input, same convention as _normalize_country.
    Mirrors the SQL backfill's regexp_replace(TRIM(TRAILING '/' FROM url), '^.*/', '')
    exactly, so a slug computed at scrape time and one backfilled from historical
    url_event values always agree.
    """
    if not url:
        return ""
    path = url.split("?", 1)[0].split("#", 1)[0].rstrip("/")
    if "/" not in path:
        return ""
    return path.rsplit("/", 1)[-1].strip()


# TODO(ADR-028): disabled 2026-04-20 — live hit rate was 0/13 against EVF detail
# pages. Re-enable once real-world deadline phrasings have been observed and the
# `_DEADLINE_PATTERNS` regex list is tuned against them.
HARVEST_DEADLINE = False

EVF_CALENDAR_FUTURE = "https://www.veteransfencing.eu/calendar/"
EVF_CALENDAR_PAST = "https://www.veteransfencing.eu/calendar/list/?eventDisplay=past"

WEAPON_MAP = {1: "FOIL", 2: "EPEE", 3: "SABRE"}

_PUBLIC_EVENT_KEYS = (
    "name",
    "dt_start",
    "dt_end",
    "location",
    "address",
    "country",
    "weapons",
    "is_team",
    "url",
    "fee",
    "fee_currency",
    "url_invitation",
    "url_registration",
    "dt_registration_deadline",
    "evf_slug",
    "evf_calendar_id",
    "is_cancelled",
)

_REGISTRATION_HOSTS = (
    "engarde-escrime.com",
    "engarde-service.com",
    "fencingtimelive.com",
    "ophardt.online",
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
    re.compile(
        r"registration\s+(?:closes|deadline|ends)[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})",
        re.IGNORECASE,
    ),
    re.compile(r"registration\s+(?:closes|deadline|ends)[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(
        r"entries?\s+close[s]?(?:\s+on)?[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})", re.IGNORECASE
    ),
    re.compile(r"entries?\s+close[s]?(?:\s+on)?[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(r"(?:deadline|closes|termin)[:\s]+(\d{4}-\d{2}-\d{2})", re.IGNORECASE),
    re.compile(r"(?:deadline|closes|termin)[:\s]+(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})", re.IGNORECASE),
    re.compile(r"closes\s+on\s+(\d{1,2}\s+\w+\s+\d{4})", re.IGNORECASE),
    re.compile(r"closes\s+(\d{1,2}\s+\w+\s+\d{4})", re.IGNORECASE),
]


def _blank_event() -> dict:
    """Return an event dict with all public keys initialised to neutral defaults."""
    return {
        "name": "",
        "dt_start": "",
        "dt_end": "",
        "location": "",
        "address": "",
        "country": "",
        "weapons": [],
        "is_team": False,
        "url": "",
        "fee": None,
        "fee_currency": "",
        "url_invitation": None,
        "url_registration": None,
        "dt_registration_deadline": None,
        "evf_slug": "",
        "evf_calendar_id": None,
        "is_cancelled": False,
    }


# =============================================================================
# HTML list page parsing (evf.1–evf.3)
# =============================================================================


def _tribe_event_end_date(article, dt_start: str) -> str:
    """Resolve The Events Calendar's visible range end.

    Tribe emits only one ``datetime`` attribute for list rows; multi-day end
    dates live in a text span such as ``22 August``.  Reuse the start year and
    roll into the following year only when the parsed month/day precedes start.
    """
    start_text = dt_start[:10]
    try:
        start = datetime.strptime(start_text, "%Y-%m-%d").date()
    except ValueError:
        return start_text

    end_el = article.select_one(".tribe-event-date-end")
    if end_el is None:
        return start_text
    end_text = end_el.get_text(" ", strip=True)
    for fmt in ("%d %B %Y", "%d %b %Y", "%B %d %Y", "%b %d %Y"):
        try:
            end = datetime.strptime(f"{end_text} {start.year}", fmt).date()
        except ValueError:
            continue
        if end < start:
            end = end.replace(year=end.year + 1)
        return end.isoformat()
    return start_text


def parse_evf_calendar_html(html: str) -> list[dict]:
    """Parse veteransfencing.eu/calendar/ HTML into event dicts.

    Returns list of dicts with keys matching ``_PUBLIC_EVENT_KEYS``.
    Raises CalendarIntegrityError for a named entry with missing date data.
    """
    soup = BeautifulSoup(html, "html.parser")
    events: list[dict] = []

    for article in soup.select(".tribe-events-calendar-list__event"):
        title_el = article.select_one(".tribe-events-calendar-list__event-title a")
        name = title_el.get_text().strip() if title_el else ""
        if not name:
            continue
        if is_ignored_calendar_entry({"name": name}):
            continue
        url = title_el.get("href", "") if title_el else ""

        dt_els = article.select("[datetime]")
        if not dt_els:
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} has missing date")
        dt_start = dt_els[0].get("datetime", "") or ""
        dt_end = _tribe_event_end_date(article, str(dt_start))
        if not dt_start:
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} has missing date")

        identity_text = " ".join(article.get("class") or []) + " " + str(article.get("id") or "")
        calendar_id_match = re.search(r"(?:^|\s)post-(\d+)(?:\s|$)", identity_text)
        evf_calendar_id = int(calendar_id_match.group(1)) if calendar_id_match else None

        venue_el = article.select_one(".tribe-events-calendar-list__event-venue-title")
        venue = venue_el.get_text().strip() if venue_el else ""

        addr_el = article.select_one(".tribe-events-calendar-list__event-venue-address")
        address = addr_el.get_text().strip() if addr_el else ""

        country = ""
        if address:
            parts = [p.strip() for p in address.split(",")]
            if parts:
                country = parts[-1]

        classes = article.get("class") or []
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
        evt.update(
            {
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
                "evf_slug": _extract_evf_slug(str(url) if url else ""),
                "evf_calendar_id": evf_calendar_id,
                "is_cancelled": "cancelled" in name.casefold(),
            }
        )
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
            key = (
                f"calendar:{e['evf_calendar_id']}"
                if e.get("evf_calendar_id") is not None
                else f"{e['dt_start']}_{e['name']}"
            )
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
            evt.update(
                {
                    "name": api_evt.get("name") or "",
                    "dt_start": opens,
                    "dt_end": dt_end,
                    "location": api_evt.get("location") or "",
                    "country": api_evt.get("country_abbr") or api_evt.get("country") or "",
                    "weapons": sorted(weapons_set),
                    "is_team": is_team,
                }
            )
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
    for fmt in (
        "%Y-%m-%d",
        "%d.%m.%Y",
        "%d/%m/%Y",
        "%d-%m-%Y",
        "%d.%m.%y",
        "%d/%m/%y",
        "%d-%m-%y",
        "%d %B %Y",
        "%d %b %Y",
    ):
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
        href = str(a.get("href") or "").strip()
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
            href = str(a.get("href") or "").strip()
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
        "weapons": _weapons_from_detail_soup(soup, body),
    }


def _weapons_from_text(text: str) -> list[str]:
    """Canonical weapons named in a blob of text, or [] if it names none.

    Whole-word matching only.  "EPEE +FOIL +SABRE" (written without spaces)
    reads correctly, while prose such as "three weapons" cannot invent one.
    """
    return sorted({m.group(1).upper() for m in _DETAIL_WEAPON_RE.finditer(text or "")})


def _weapons_from_pdf_bytes(pdf_bytes: bytes) -> list[str]:
    """Weapons named in an invitation PDF, or [] if it is unreadable or silent.

    Mirrors the tolerant extraction already used for Engarde result PDFs in
    ``evf_results.parse_evf_result_pdf`` -- a malformed or image-only letter is
    simply no evidence, never an error.
    """
    try:
        import pypdf
    except ImportError:  # pragma: no cover — pypdf is a declared dependency
        return []

    try:
        reader = pypdf.PdfReader(BytesIO(pdf_bytes))
    except Exception:
        return []

    parts: list[str] = []
    for page in reader.pages:
        try:
            parts.append(page.extract_text() or "")
        except Exception:
            continue
    return _weapons_from_text(" ".join(parts))


def _weapons_from_detail_soup(soup, body) -> list[str]:
    """Derive an event's weapons from its detail page, or [] if it says nothing.

    Two sources, in order of authority.  The category meta is the same
    taxonomy the list page renders as cat_* classes, so it agrees with the
    primary path by construction.  The description line is the fallback for a
    post published with no categories at all -- the only place such an event
    states its weapons.  Silence returns [] so the caller's integrity guard
    still fires rather than a weapon being guessed.
    """
    for node in (soup.select_one(".tribe-events-event-categories"), body):
        if node is None:
            continue
        found = _weapons_from_text(node.get_text(" ", strip=True))
        if found:
            return found
    return []


def repair_missing_weapons(events: list[dict], delay: float = 0.5) -> list[dict]:
    """Fill weapons from real evidence for entries the list page left blank.

    The list page tags weapons only through the post's cat_epee/cat_foil/
    cat_sabre taxonomy classes.  When a post is published without them, three
    further sources are tried, in descending authority:

      1. the detail page's category meta -- the same taxonomy, so it agrees
         with the list page by construction;
      2. the detail page's description line, which organizers open with
         ("EPEE + SABRE").  This is the only source for a post carrying no
         categories at all;
      3. the linked invitation letter (PDF), for a post whose description names
         no weapon ("Two genders, three weapons, four days");
      4. ``_KNOWN_WEAPON_OVERRIDES`` -- approved manual evidence, last so that
         real EVF data always wins over a hand-entered fact that may have gone
         stale.

    Only weaponless entries are fetched, so a fully tagged calendar costs no
    requests at all.  Per-event failures are logged and swallowed; an entry
    still weaponless afterwards is left for ``partition_unweaponed`` to skip.
    """
    import time

    repaired = 0
    pending = [evt for evt in events if not _weapon_suffix(evt)]

    for i, evt in enumerate(pending):
        weapons: list[str] = []
        url = str(evt.get("url") or "")

        if url:
            if i > 0 and delay:
                try:
                    time.sleep(delay)
                except Exception:
                    pass
            weapons, source = _weapons_from_detail_page(url, evt)
        else:
            source = ""

        if not weapons:
            calendar_id = evt.get("evf_calendar_id")
            override = (
                _KNOWN_WEAPON_OVERRIDES.get(int(calendar_id)) if calendar_id is not None else None
            )
            if override:
                weapons, source = list(override), "approved override"

        if weapons:
            evt["weapons"] = weapons
            repaired += 1
            logger.info(
                "Weapon repair: %r had no calendar categories; %s gives %s",
                evt.get("name"),
                source,
                "+".join(weapons),
            )
        else:
            logger.warning(
                "Weapon repair: %r states no weapons anywhere (%s)",
                evt.get("name"),
                url or "no detail URL",
            )

    if pending:
        logger.info("Weapon repair: %d/%d weaponless entries recovered", repaired, len(pending))
    return events


def _weapons_from_detail_page(url: str, evt: dict) -> tuple[list[str], str]:
    """Detail-page rungs for one event: HTML first, then the invitation PDF."""
    try:
        resp = httpx.get(url, timeout=20, follow_redirects=True)
        resp.raise_for_status()
        parsed = parse_event_detail_html(resp.text)
    except (httpx.HTTPError, ValueError, KeyError, IndexError) as exc:
        logger.warning("Weapon repair: detail page fetch failed for %s: %s", url, exc)
        return [], ""
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("Weapon repair: unexpected error for %s: %s", url, exc)
        return [], ""

    weapons = parsed.get("weapons") or []
    if weapons:
        return list(weapons), "detail page"

    pdf_url = str(parsed.get("url_invitation") or evt.get("url_invitation") or "")
    if not pdf_url.lower().endswith(".pdf"):
        return [], ""

    try:
        pdf_resp = httpx.get(pdf_url, timeout=30, follow_redirects=True)
        pdf_resp.raise_for_status()
        weapons = _weapons_from_pdf_bytes(pdf_resp.content)
    except (httpx.HTTPError, ValueError, KeyError, IndexError) as exc:
        logger.warning("Weapon repair: invitation PDF failed for %s: %s", pdf_url, exc)
        return [], ""
    except Exception as exc:  # pragma: no cover — defensive
        logger.warning("Weapon repair: unexpected PDF error for %s: %s", pdf_url, exc)
        return [], ""

    return (list(weapons), "invitation PDF") if weapons else ([], "")


def partition_unweaponed(
    events: list[dict], known_calendar_ids: set[int] | None = None
) -> tuple[list[dict], list[dict]]:
    """Split a scraped calendar into (ready, pending-weapons).

    An entry whose weapons are still unknown after the evidence ladder is an
    event EVF has not finished announcing.  To a fencer that is indistinguishable
    from an event EVF has not posted at all, so it is held back rather than
    imported with invented data -- and picked up automatically on a later run.

    Holding it back keeps ``validate_season_calendar``'s contract intact: that
    guard stays fatal on every identity and date error, it simply never sees an
    unannounced stub.

    An event already imported is never held back.  If EVF edits a live post and
    its categories vanish, that is a regression, not a stub, and the existing
    row must keep the weapons it already has.
    """
    known = known_calendar_ids or set()
    ready: list[dict] = []
    pending: list[dict] = []
    for evt in events:
        calendar_id = evt.get("evf_calendar_id")
        already_imported = calendar_id is not None and int(calendar_id) in known
        if _weapon_suffix(evt) or already_imported:
            ready.append(evt)
        else:
            pending.append(evt)
    return ready, pending


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

    logger.info(
        "Detail-page enrichment: inv=%d reg=%d deadline=%d (over %d events)",
        inv_hits,
        reg_hits,
        dl_hits,
        len(events),
    )
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
    known_calendar_ids: set[int] | None = None,
    pending_weapons: list[dict] | None = None,
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
        known_calendar_ids: EVF calendar ids already imported into CERT.  An
            event in this set is never held back for unknown weapons -- losing
            its categories upstream is a regression, not an unannounced stub.
        pending_weapons: optional list which receives the entries held back
            because their weapons are still unknown, so the caller can report
            them.  The snapshot itself excludes them.

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
            len(api_events),
            season_start,
            season_end,
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
        raise RuntimeError("EVF calendar scrape failed on all sources: " + " | ".join(errors))

    if have_html:
        merged = html_events  # type: ignore[assignment]
        if have_api:
            _merge_html_into_api(api_events, html_events)  # type: ignore[arg-type]
    elif have_api:
        logger.warning("Falling back to API-only calendar (HTML returned no events)")
        merged = api_events  # type: ignore[assignment]
    else:
        # Both sources succeeded but returned empty lists — nothing in window
        logger.warning(
            "EVF calendar: no events returned from any source in [%s, %s]",
            season_start,
            season_end,
        )
        return []

    # Recover weapons for any entry the list page left untagged, then hold back
    # whatever is still unknown -- BOTH before the integrity guard runs, which
    # stays strict and must never see an unannounced stub.
    repair_missing_weapons(merged)  # type: ignore[arg-type]
    ready, pending = partition_unweaponed(merged, known_calendar_ids)  # type: ignore[arg-type]
    if pending:
        logger.warning(
            "EVF calendar: holding back %d entr%s with unknown weapons: %s",
            len(pending),
            "y" if len(pending) == 1 else "ies",
            ", ".join(repr(e.get("name")) for e in pending),
        )
    if pending_weapons is not None:
        pending_weapons.extend(pending)

    filtered = validate_season_calendar(ready, season_start, season_end)
    relevant = [
        e
        for e in filtered
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

    return filtered


def validate_season_calendar(events: list[dict], season_start: str, season_end: str) -> list[dict]:
    """Return the retained, strictly valid EVF snapshot contained in one season.

    Whole-word CAMP entries are discarded before validation and never count.
    Every other public entry counts, including cancelled and non-circuit events.
    Boundary overlap is a season-definition error; it is never assigned
    heuristically. Stable calendar ids and weapons are mandatory.
    """
    try:
        season_start_date = datetime.strptime(season_start, "%Y-%m-%d").date()
        season_end_date = datetime.strptime(season_end, "%Y-%m-%d").date()
    except (TypeError, ValueError) as exc:
        raise CalendarIntegrityError(
            f"unparseable season date range {season_start!r}..{season_end!r}"
        ) from exc

    if season_end_date < season_start_date:
        raise CalendarIntegrityError(
            f"season end {season_end} precedes season start {season_start}"
        )

    snapshot: list[dict] = []
    seen_calendar_ids: set[int] = set()
    for event in events:
        if is_ignored_calendar_entry(event):
            continue
        event = dict(event)
        name = event.get("name") or "<unnamed>"
        raw_start = event.get("dt_start")
        raw_end = event.get("dt_end")
        if not raw_start or not raw_end:
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} has missing date")
        try:
            event_start = datetime.strptime(str(raw_start)[:10], "%Y-%m-%d").date()
            event_end = datetime.strptime(str(raw_end)[:10], "%Y-%m-%d").date()
        except (TypeError, ValueError) as exc:
            raise CalendarIntegrityError(
                f"EVF calendar entry {name!r} has unparseable date"
            ) from exc

        if event_end < event_start:
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} ends before it starts")

        overlaps = event_start <= season_end_date and event_end >= season_start_date
        contained = event_start >= season_start_date and event_end <= season_end_date
        if overlaps and not contained:
            raise CalendarIntegrityError(
                f"EVF calendar entry {name!r} crosses season boundary {season_start}..{season_end}"
            )
        if not contained:
            continue

        calendar_id = event.get("evf_calendar_id")
        if calendar_id is None:
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} has missing EVF calendar id")
        calendar_id = int(calendar_id)
        if calendar_id in seen_calendar_ids:
            raise CalendarIntegrityError(f"duplicate EVF calendar id {calendar_id}")
        seen_calendar_ids.add(calendar_id)

        if not _weapon_suffix(event) and calendar_id in _KNOWN_WEAPON_OVERRIDES:
            event["weapons"] = list(_KNOWN_WEAPON_OVERRIDES[calendar_id])

        if not _weapon_suffix(event):
            raise CalendarIntegrityError(f"EVF calendar entry {name!r} has missing weapons")
        snapshot.append(event)

    return snapshot


def is_evf_scoring_event(event: dict) -> bool:
    """Whether an all-calendar entry belongs in SPWS EVF event ingestion."""
    name = (event.get("name") or "").casefold()
    return "circuit" in name or "championship" in name or "criterium" in name


def filter_by_season(events: list[dict], season_start: str, season_end: str) -> list[dict]:
    """Filter events to those within the season date range (inclusive)."""
    return [
        e
        for e in events
        if e.get("dt_start", "") >= season_start and e.get("dt_start", "") <= season_end
    ]


def _find_existing_match(
    s_evt: dict,
    existing: list[dict],
    date_tolerance: int = 7,
    name_threshold: float = 80.0,  # ignored in rev 2; kept for signature compat
) -> dict | None:
    """Find the best existing-row match for a scraped event (ADR-039 dedup key).

    Algorithm (ADR-039 rev 5):
      Step 0 — PRIMARY: public EVF calendar post id (`evf_calendar_id` /
               `id_evf_calendar_event`) — no date gate. This identity exists
               before results and survives renames/reschedules.
      Step 1 — SECONDARY: EVF results numeric id (`evf_id` / `id_evf_event`) — no date
               gate (a reschedule must still match). Live-verified
               2026-07-10: structurally absent from calendar-path HTML
               scrapes (EVF assigns ids to an event in their own backend
               later than the public listing) — present when called from
               the results path (`EvfApiClient.discover_season_events`).
      Step 2 — FALLBACK: EVF slug (`evf_slug` / `txt_evf_slug`), the last
               path segment of the calendar detail-page URL — also no date
               gate. Always available at calendar-scrape time, even for a
               future event with no venue/id yet. This is what fixes the
               "EVF Circuit – Samorin (SVK)" duplicate-row bug: country and
               location were blank on both the scrape and the CERT row, so
               neither Step 3 nor Step 4 below could ever match, and a
               fresh duplicate was created on every cron run.
      Step 3 — date gate: |dt_start − dt_start| ≤ date_tolerance days.
      Step 4 — BACKUP/STRONG: same canonical country → match.
      Step 5 — BACKUP/MEDIUM: country missing on either side, location
               token-set-ratio (diacritic-folded) ≥ LOCATION_MATCH_THRESHOLD
               → match.
      Step 6 — no match → return None.

    Steps 1 and 2 are deliberately NOT nested inside the date-gated loop —
    an id/slug match must win even when the scraped date has drifted beyond
    `date_tolerance` (a reschedule), which is exactly the case the caller's
    diff-and-sync step (`fn_sync_evf_event_fields`) is meant to catch.

    Steps 0 (logical-integrity guard) and pre-Step-3 (stale-event gate) are
    caller concerns — they are applied to `existing` BEFORE this function is
    called. See `assert_no_future_completed` and `is_in_scope`.

    Name comparison was REMOVED in rev 2 and stays removed in rev 5: EVF
    actively renames events mid-season (Napoli → Naples (ITA)) and name
    fuzz produced the PEW-PALAVESUVI-class duplicates. Date + country +
    location remain the backup ladder's physical properties that can't be
    renamed away; calendar id/results id/slug are explicit identities and rank ahead
    of them.

    The `name_threshold` parameter is kept for backwards-compatible call
    sites but is never read.
    """
    # Step 0 — PRIMARY calendar identity: public WordPress post id.
    s_calendar_id = s_evt.get("evf_calendar_id")
    if s_calendar_id is not None:
        for ex in existing:
            if ex.get("id_evf_calendar_event") == s_calendar_id:
                return ex

    # Step 1 — secondary EVF results-database id.
    s_evf_id = s_evt.get("evf_id")
    if s_evf_id:
        for ex in existing:
            if ex.get("id_evf_event") == s_evf_id:
                return ex

    # Step 2 — FALLBACK: EVF slug.
    s_slug = s_evt.get("evf_slug", "")
    if s_slug:
        for ex in existing:
            ex_slug = ex.get("txt_evf_slug")
            if ex_slug and ex_slug == s_slug:
                return ex

    # Step 3 (backup ladder start) — date gate.
    s_date = s_evt.get("dt_start", "")
    s_country = _normalize_country(s_evt.get("country", ""))

    try:
        sd = datetime.strptime(s_date, "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return None

    s_location_folded = _diacritic_fold(s_evt.get("location", "")).strip()

    for ex in existing:
        # Step 3 — date gate.
        ex_date = str(ex.get("dt_start", ""))
        try:
            ed = datetime.strptime(ex_date, "%Y-%m-%d").date()
        except (ValueError, TypeError):
            continue
        if abs((sd - ed).days) > date_tolerance:
            continue

        # Step 4 — country STRONG match.
        ex_country = _normalize_country(ex.get("txt_country", ""))
        if s_country and ex_country and s_country == ex_country:
            return ex

        # Step 5 — location MEDIUM match (only when country missing on either side).
        if not (s_country and ex_country):
            ex_location_folded = _diacritic_fold(ex.get("txt_location", "")).strip()
            if s_location_folded and ex_location_folded:
                # Normalise punctuation/case so token_set_ratio sees clean
                # word tokens. "Stockholm, Sweden" → "stockholm sweden".
                a = re.sub(r"[^\w\s]", " ", s_location_folded.lower()).strip()
                b = re.sub(r"[^\w\s]", " ", ex_location_folded.lower()).strip()
                if fuzz is not None:
                    score = float(fuzz.token_set_ratio(a, b))
                else:
                    score = 100.0 if (a in b or b in a) else 0.0
                if score >= LOCATION_MATCH_THRESHOLD:
                    return ex

    return None


def is_in_scope(event: dict, today: date | None = None) -> bool:
    """Return True iff the scraper may auto-create / auto-update this event (ADR-039 Step 1).

    Out-of-scope when:
      * enum_status == 'COMPLETED', OR
      * (today − dt_end) ≥ STALE_WINDOW_DAYS days.

    Scraped events from EVF carry no enum_status; only the date clause
    applies (status defaults absent → treated as not-COMPLETED).
    The dt_end field falls back to dt_start if missing.
    """
    if today is None:
        today = date.today()

    if event.get("enum_status") == "COMPLETED":
        return False

    end_str = event.get("dt_end") or event.get("dt_start") or ""
    try:
        end = datetime.strptime(str(end_str), "%Y-%m-%d").date()
    except (ValueError, TypeError):
        # No parseable date → treat as in-scope; the date gate elsewhere
        # will still reject it from dedup matches.
        return True

    return (today - end).days < STALE_WINDOW_DAYS


def url_event_if_concluded(event: dict, today: date | None = None) -> str:
    """Return the scraped EVF event link only once the event has concluded.

    The calendar link (``event['url']``) is written to ``tbl_event.url_event``,
    which the operator and the ingest pipeline treat as the event's *results*
    pointer. On a future or in-progress event it points at a schedule/
    registration page with no results, so recording it there is misleading —
    the reported bug. We therefore withhold it until the event is over.

    Rule: return ``event['url']`` iff ``dt_end < today`` (the event is fully in
    the past). ``dt_end`` falls back to ``dt_start``. A missing URL or an
    unparseable date returns ``''`` — we never record a link we cannot confirm
    points at a concluded event.

    Invitation and registration URLs are deliberately **not** governed here:
    those are wanted *before* the event and flow through unchanged.
    """
    if today is None:
        today = date.today()

    url = str(event.get("url") or "").strip()
    if not url:
        return ""

    end_str = event.get("dt_end") or event.get("dt_start") or ""
    try:
        end = datetime.strptime(str(end_str), "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return ""

    return url if end < today else ""


def find_future_completed(events: list[dict], today: date | None = None) -> list[dict]:
    """Return the rows that are future-COMPLETED — dt_start > today AND
    enum_status = 'COMPLETED' (ADR-039 Step 0).

    A future event cannot have already completed; such a row is data
    corruption. Shared by `assert_no_future_completed` (hard guard) and the
    self-healing fallback (ADR-070).
    """
    if today is None:
        today = date.today()

    violators: list[dict] = []
    for ev in events:
        if ev.get("enum_status") != "COMPLETED":
            continue
        try:
            start = datetime.strptime(str(ev.get("dt_start", "")), "%Y-%m-%d").date()
        except (ValueError, TypeError):
            continue
        if start > today:
            violators.append(ev)
    return violators


def assert_no_future_completed(events: list[dict], today: date | None = None) -> None:
    """Raise LogicalIntegrityError if any row is future-COMPLETED (ADR-039 Step 0).

    A future event cannot have already completed — that's data corruption.
    The caller must abort the sync, send a Telegram alert, and exit non-zero
    so the admin notices. As of ADR-070 the caller first attempts to
    auto-heal each violator from its authoritative FTL date; this guard is the
    last line of defence for rows that could not be healed.
    """
    violators = find_future_completed(events, today=today)
    if violators:
        msg_parts = []
        for v in violators:
            msg_parts.append(
                f"{v.get('txt_code', '?')} dt_start={v.get('dt_start', '?')} "
                f"status={v.get('enum_status', '?')}"
            )
        raise LogicalIntegrityError(
            "Future-COMPLETED event(s) detected — manual fix required: " + "; ".join(msg_parts)
        )


def compute_future_completed_corrections(
    violators: list[dict],
    date_lookup,
    today: date | None = None,
) -> tuple[list[dict], list[dict]]:
    """Decide how to heal each future-COMPLETED violator (ADR-039 rev 2).

    For every violator, ``date_lookup(event)`` returns a list of ISO date
    strings (``YYYY-MM-DD``) recovered from the authoritative source — the
    event URL (FTL eventSchedule), the matched EVF calendar event, or an FTL
    results page. A violator is **date-healable** iff at least one recovered
    date is valid and ``<= today``: a COMPLETED row whose real date is still in
    the future would just swap one impossible state for another.

    Returns ``(corrections, status_flips)``:

    * ``corrections`` — ``{txt_code, id_event, dt_start, dt_end}`` (earliest
      recovered date → dt_start, latest → dt_end). Status stays COMPLETED.
    * ``status_flips`` — violators with no recoverable date. Per the locked
      design (event URL NULL / unrecoverable → demote), the caller flips
      ``enum_status`` away from COMPLETED so the Step 0 guard stops erroring
      and the pipeline survives. The sync no longer hard-halts on this class.
    """
    if today is None:
        today = date.today()

    corrections: list[dict] = []
    status_flips: list[dict] = []
    for ev in violators:
        valid: list[date] = []
        for raw in date_lookup(ev) or []:
            try:
                d = datetime.strptime(str(raw), "%Y-%m-%d").date()
            except (ValueError, TypeError):
                continue
            if d <= today:
                valid.append(d)
        if not valid:
            status_flips.append(ev)
            continue
        corrections.append(
            {
                "txt_code": ev.get("txt_code"),
                "id_event": ev.get("id_event"),
                "dt_start": min(valid).isoformat(),
                "dt_end": max(valid).isoformat(),
            }
        )
    return corrections, status_flips


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
    name_threshold: float = 80.0,  # ignored in rev 2; kept for signature compat
) -> list[tuple[dict, dict]]:
    """Pair each scraped event with its best-matching existing DB row, if any.

    Uses ADR-039 rev 2 dedup ladder: ±date_tolerance day window → canonical
    country (STRONG) → location token-similarity (MEDIUM, when country missing
    on either side). Caller is responsible for filtering `existing` through
    `is_in_scope` and `assert_no_future_completed` before calling this.

    Returns `[(scraped_evt, existing_row), ...]` for every scraped event that
    matched an existing row.
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
    name_threshold: float = 80.0,  # ignored in rev 2; kept for signature compat
) -> tuple[list[dict], list[dict]]:
    """Split scraped events into (new, already_imported) per ADR-039 rev 2.

    Dedup ladder:
      1. Date gate: |dt_start − dt_start| ≤ date_tolerance days.
      2. STRONG match: canonical country equal on both sides.
      3. MEDIUM match: country missing on either side → location
         token_set_ratio (diacritic-folded) ≥ 70.

    Name comparison removed: EVF mid-season renames produced duplicates.
    Date + country + location are physical properties.

    Caller is responsible for filtering `existing` through `is_in_scope` and
    running `assert_no_future_completed` first.
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
