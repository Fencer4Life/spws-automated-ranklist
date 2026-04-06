"""
EVF Calendar Scraper — veteransfencing.eu (ADR-028)

Parses calendar pages (past + future) for PEW/MEW event metadata.
Current season only. Team events stored as metadata but excluded from result scraping.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta

import httpx
from bs4 import BeautifulSoup

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None  # type: ignore[assignment]

EVF_CALENDAR_FUTURE = "https://www.veteransfencing.eu/calendar/"
EVF_CALENDAR_PAST = "https://www.veteransfencing.eu/calendar/list/?eventDisplay=past"


def parse_evf_calendar_html(html: str) -> list[dict]:
    """Parse veteransfencing.eu/calendar/ HTML into event dicts.

    Returns list of dicts with keys:
        name, dt_start, dt_end, location, address, country,
        weapons, is_team, url, fee, fee_currency
    """
    soup = BeautifulSoup(html, "html.parser")
    events: list[dict] = []

    for article in soup.select(".tribe-events-calendar-list__event"):
        # Title + URL
        title_el = article.select_one(
            ".tribe-events-calendar-list__event-title a"
        )
        name = title_el.get_text().strip() if title_el else ""
        if not name:
            continue
        url = title_el.get("href", "") if title_el else ""

        # Dates (datetime attribute on time elements)
        dt_els = article.select("[datetime]")
        dt_start = dt_els[0]["datetime"] if dt_els else ""
        dt_end = dt_els[1]["datetime"] if len(dt_els) > 1 else dt_start

        # Venue + address
        venue_el = article.select_one(
            ".tribe-events-calendar-list__event-venue-title"
        )
        venue = venue_el.get_text().strip() if venue_el else ""

        addr_el = article.select_one(
            ".tribe-events-calendar-list__event-venue-address"
        )
        address = addr_el.get_text().strip() if addr_el else ""

        # Extract country from address (last part after comma)
        country = ""
        if address:
            parts = [p.strip() for p in address.split(",")]
            if parts:
                country = parts[-1]

        # Weapons from CSS classes
        classes = article.get("class", [])
        weapons: list[str] = []
        if "cat_epee" in classes:
            weapons.append("EPEE")
        if "cat_foil" in classes:
            weapons.append("FOIL")
        if "cat_sabre" in classes:
            weapons.append("SABRE")

        # Team detection
        is_team = "team" in name.lower()

        # Entry fee from cost element
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

        events.append({
            "name": name,
            "dt_start": dt_start[:10] if dt_start else "",
            "dt_end": dt_end[:10] if dt_end else "",
            "location": venue,
            "address": address,
            "country": country,
            "weapons": weapons,
            "is_team": is_team,
            "url": url,
            "fee": fee,
            "fee_currency": fee_currency,
        })

    return events


def scrape_full_season_calendar(
    season_start: str, season_end: str
) -> list[dict]:
    """Fetch past + future calendar pages, merge, deduplicate, filter to season.

    Only includes circuit and championship events (filters out social/camp events).
    """
    all_events: list[dict] = []
    seen_keys: set[str] = set()

    for url in [EVF_CALENDAR_PAST, EVF_CALENDAR_FUTURE]:
        try:
            resp = httpx.get(url, timeout=30, follow_redirects=True)
            resp.raise_for_status()
            page_events = parse_evf_calendar_html(resp.text)
            for e in page_events:
                # Deduplicate by date+name
                key = f"{e['dt_start']}_{e['name']}"
                if key not in seen_keys:
                    seen_keys.add(key)
                    all_events.append(e)
        except Exception:
            continue

    # Filter to season range
    filtered = filter_by_season(all_events, season_start, season_end)

    # Only circuit and championship events (skip social, camp, outdoor)
    relevant = [
        e for e in filtered
        if "circuit" in e["name"].lower()
        or "championship" in e["name"].lower()
        or "criterium" in e["name"].lower()
    ]

    return relevant


def filter_by_season(
    events: list[dict], season_start: str, season_end: str
) -> list[dict]:
    """Filter events to those within the season date range (inclusive)."""
    return [
        e for e in events
        if e.get("dt_start", "") >= season_start
        and e.get("dt_start", "") <= season_end
    ]


def deduplicate_events(
    scraped: list[dict],
    existing: list[dict],
    date_tolerance: int = 7,
    name_threshold: float = 50.0,
) -> tuple[list[dict], list[dict]]:
    """Split scraped events into (new, already_imported).

    An event is considered already imported if an existing event has:
    - dt_start within +-date_tolerance days, AND
    - name fuzzy match >= name_threshold
    """
    new: list[dict] = []
    already: list[dict] = []

    for scraped_evt in scraped:
        s_date = scraped_evt.get("dt_start", "")
        s_name = scraped_evt.get("name", "")
        matched = False

        for ex in existing:
            ex_date = str(ex.get("dt_start", ""))
            ex_name = ex.get("txt_name", "")

            # Date proximity check
            try:
                sd = datetime.strptime(s_date, "%Y-%m-%d")
                ed = datetime.strptime(ex_date, "%Y-%m-%d")
                if abs((sd - ed).days) > date_tolerance:
                    continue
            except (ValueError, TypeError):
                continue

            # Name fuzzy match
            if fuzz is not None:
                score = fuzz.token_set_ratio(s_name, ex_name)
                if score >= name_threshold:
                    matched = True
                    break
            else:
                # Fallback: simple substring check
                if s_name.lower() in ex_name.lower() or ex_name.lower() in s_name.lower():
                    matched = True
                    break

        if matched:
            already.append(scraped_evt)
        else:
            new.append(scraped_evt)

    return new, already
