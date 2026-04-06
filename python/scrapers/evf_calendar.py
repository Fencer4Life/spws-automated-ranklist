"""
EVF Calendar Scraper — veteransfencing.eu (ADR-028)

Parses the calendar page HTML to extract PEW/MEW event metadata.
Current season only. Team events stored as metadata but excluded from result scraping.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from bs4 import BeautifulSoup

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None  # type: ignore[assignment]


def parse_evf_calendar_html(html: str) -> list[dict]:
    """Parse veteransfencing.eu/calendar/ HTML into event dicts.

    Returns list of dicts with keys:
        name, dt_start, dt_end, location, address, country, weapons, is_team
    """
    soup = BeautifulSoup(html, "html.parser")
    events: list[dict] = []

    for article in soup.select(".tribe-events-calendar-list__event"):
        # Title
        title_el = article.select_one(
            ".tribe-events-calendar-list__event-title a"
        )
        name = title_el.get_text().strip() if title_el else ""
        if not name:
            continue

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

        events.append({
            "name": name,
            "dt_start": dt_start[:10] if dt_start else "",
            "dt_end": dt_end[:10] if dt_end else "",
            "location": venue,
            "address": address,
            "country": country,
            "weapons": weapons,
            "is_team": is_team,
        })

    return events


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
