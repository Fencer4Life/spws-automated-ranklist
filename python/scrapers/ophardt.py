"""
Ophardt parser (fencingworldwide.com — Ophardt Team Sportevent).

Server-rendered HTML, jQuery + Bootstrap. No SPA hydration; all data is
present in the initial GET payload (verified by spike — see
doc/audits/ophardt_format_research.md).

The parser targets the per-tournament results page:

    /{lang}/{tournamentId}-{year}/results/

Native source_row_id: every row links to ``/athlete/{id}/`` — Ophardt's
globally stable athlete ID. Format: ``f"ophardt:athlete{id}"``.

What Ophardt does NOT expose: birth year / DOB (treated as PII). Identity
resolution leans on (name, country, athlete_id) instead — the athlete_id
becomes the dominant signal once seen across multiple tournaments.

Locale-mixed: the breadcrumb on `/en/` URLs renders weapon/gender/V-cat
in German (Florett / Herren / V50). The rankings page itself uses ASCII
country codes and the standard table — locale-agnostic for IR purposes.

Phase 1 / part 2 — ADR-050.
"""

from __future__ import annotations

import re
from datetime import date
from urllib.parse import urljoin

from bs4 import BeautifulSoup

# Place cell text: "1.", "2.", "T3." (tied 3rd). Strip leading "T" + trailing ".".
_PLACE_RE = re.compile(r"^T?(\d+)\.?$")

# Athlete-link pattern: /athlete/1780/ or /athlete/1780
_ATHLETE_ID_RE = re.compile(r"/athlete/(\d+)/?")

# Country code: trailing 3-letter ISO (e.g. "ITA", "POL"). May be preceded
# by a flag <img>; we read the text after stripping HTML.
_COUNTRY_RE = re.compile(r"\b([A-Z]{3})\b")


def parse_results(
    html: str,
    source_url: str | None = None,
):
    """Parse an Ophardt results-page HTML into ParsedTournament.

    Source URL pattern: ``/{lang}/{tournamentId}-{year}/results/``.

    The tournament-level metadata (weapon / gender / category) lives in
    the breadcrumb of the parent ``/{tournamentId}-{year}/global/`` page,
    not the results page itself. The orchestrator either fetches both
    pages or supplies metadata from admin input. This factory only sees
    the results table.
    """
    from python.pipeline.ir import (
        ParsedResult,
        ParsedTournament,
        SourceKind,
    )

    soup = BeautifulSoup(html, "html.parser")

    # Find the results table — class contains "startlist".
    table = None
    for candidate in soup.find_all("table"):
        if "startlist" in (candidate.get("class") or []):
            table = candidate
            break

    parsed: list[ParsedResult] = []

    if table is not None:
        tbody = table.find("tbody") or table  # some pages omit <tbody>

        for row in tbody.find_all("tr"):
            if row.find("th"):  # defensive — skip header rows if any
                continue

            cells = row.find_all("td", recursive=False)
            if len(cells) < 3:
                continue

            # Place
            place_text = cells[0].get_text(strip=True)
            place_match = _PLACE_RE.match(place_text)
            if not place_match:
                continue
            place = int(place_match.group(1))

            # Country (trailing 3-letter ISO in nation cell)
            nation_text = cells[1].get_text(strip=True)
            country_match = _COUNTRY_RE.search(nation_text)
            country = country_match.group(1) if country_match else None

            # Athlete ID + name from the /athlete/{id}/ link
            athlete_id = None
            fencer_name = None
            for a_tag in cells[2].find_all("a"):
                href = str(a_tag.get("href", ""))
                id_match = _ATHLETE_ID_RE.search(href)
                if id_match:
                    athlete_id = id_match.group(1)
                    fencer_name = a_tag.get_text(strip=True)
                    break

            if not athlete_id or not fencer_name:
                continue

            parsed.append(
                ParsedResult(
                    source_row_id=f"ophardt:athlete{athlete_id}",
                    fencer_name=fencer_name,
                    place=place,
                    fencer_country=country,
                    # Ophardt does not expose birth year / DOB (PII).
                    birth_year=None,
                    birth_date=None,
                )
            )

    return ParsedTournament(
        source_kind=SourceKind.OPHARDT_HTML,
        results=parsed,
        raw_pool_size=len(parsed),
        source_url=source_url,
    )


# =============================================================================
# Tournament page (OPH.EVT, doc/plans/evf-circuit-four-events-organiser-sources-plan-2026-10-02.html)
#
# /{lang}/{tournamentId}-{year}/tournament/ lists every competition in a
# dropdown: "<small>08.12.:</small> <span title="Individual">… Foil Men's O50".
# The number after the dash is Ophardt's season, not the year (Chania, 2 May
# 2026, is 32819-2025); a competition's year comes from its results page.
# =============================================================================

_COMPETITION_HREF_RE = re.compile(r"^/(\w{2})/(\d+-\d{4})/global/?$")
_DAY_MONTH_RE = re.compile(r"(\d{1,2})\.(\d{1,2})\.")
_TRANSMISSION_RE = re.compile(r"(\d{1,2})\.(\d{1,2})\.(\d{4})")
_WEAPONS = {
    "foil": "FOIL",
    "florett": "FOIL",
    "fleuret": "FOIL",
    "epee": "EPEE",
    "degen": "EPEE",
    "épée": "EPEE",
    "sabre": "SABRE",
    "säbel": "SABRE",
    "sabel": "SABRE",
}
_GENDERS = {
    "men's": "M",
    "men": "M",
    "herren": "M",
    "hommes": "M",
    "women's": "F",
    "women": "F",
    "damen": "F",
    "dames": "F",
}
# EVF age bands: 40+, 50+, 60+, 70+ (V1-V4). Any other band is not an EVF
# category and is skipped, never mapped to the nearest one.
_EVF_BANDS = {"O40": "V1", "O50": "V2", "O60": "V3", "O70": "V4"}
_BAND_RE = re.compile(r"\b([OU]\d{2})\b")


def parse_tournament_competitions(html: str, base_url: str) -> tuple[list[dict], list[dict]]:
    """List a tournament page's competitions as brackets (OPH.EVT.01-03).

    Returns (kept, skipped). A kept competition is individual, of one weapon,
    one gender and one EVF age band: {"id", "weapon", "gender", "category",
    "title", "day_month": (day, month), "url"} with ``url`` its results page.
    A team event, a mixed event or an age band outside EVF's is skipped as
    {"weapon", "name", "url", "reason"}.
    """
    soup = BeautifulSoup(html, "html.parser")
    kept: list[dict] = []
    skipped: list[dict] = []
    seen: set[str] = set()
    for a in soup.find_all("a", href=True):
        m = _COMPETITION_HREF_RE.match(str(a["href"]))
        small = a.find("small")
        if not m or small is None or m.group(2) in seen:
            continue
        lang, cid = m.groups()
        seen.add(cid)
        dm = _DAY_MONTH_RE.search(small.get_text())
        kind = a.find("span", title=True)
        small.extract()
        title = " ".join(a.get_text(" ", strip=True).split())
        url = urljoin(base_url, f"/{lang}/{cid}/results/")
        words = title.lower().split()
        weapon = next((_WEAPONS[w] for w in words if w in _WEAPONS), None)
        gender = next((_GENDERS[w] for w in words if w in _GENDERS), None)
        band = _BAND_RE.search(title)
        reason = None
        if kind is not None and str(kind["title"]).lower() != "individual":
            reason = "team event"
        elif weapon is None:
            reason = "no weapon"
        elif gender is None:
            reason = "no single gender"
        elif band is None or band.group(1) not in _EVF_BANDS:
            reason = f"no EVF category ({band.group(1) if band else 'none'})"
        if reason is not None or dm is None:
            skipped.append(
                {"weapon": weapon, "name": title, "url": url, "reason": reason or "no date"}
            )
            continue
        assert band is not None  # narrowed by the reason chain above
        kept.append(
            {
                "id": cid,
                "weapon": weapon,
                "gender": gender,
                "category": _EVF_BANDS[band.group(1)],
                "title": title,
                "day_month": (int(dm.group(1)), int(dm.group(2))),
                "url": url,
            }
        )
    return kept, skipped


def transmission_date(html: str) -> date | None:
    """The day a results page was last transmitted ("Last transmission:
    08.12.2024 13:02"), or None when the page has no full date (OPH.EVT.04)."""
    m = _TRANSMISSION_RE.search(BeautifulSoup(html, "html.parser").get_text(" "))
    if m is None:
        return None
    try:
        return date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
    except ValueError:
        return None


def resolve_day_month(day_month: tuple[int, int], anchor: date) -> date:
    """The latest date with this day and month on or before ``anchor``: a
    competition is fenced before its results are transmitted (OPH.EVT.04)."""
    day, month = day_month
    for year in (anchor.year, anchor.year - 1):
        try:
            d = date(year, month, day)
        except ValueError:
            continue
        if d <= anchor:
            return d
    return date(anchor.year - 1, month, day)
