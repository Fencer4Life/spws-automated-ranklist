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
                href = a_tag.get("href", "")
                id_match = _ATHLETE_ID_RE.search(href)
                if id_match:
                    athlete_id = id_match.group(1)
                    fencer_name = a_tag.get_text(strip=True)
                    break

            if not athlete_id or not fencer_name:
                continue

            parsed.append(ParsedResult(
                source_row_id=f"ophardt:athlete{athlete_id}",
                fencer_name=fencer_name,
                place=place,
                fencer_country=country,
                # Ophardt does not expose birth year / DOB (PII).
                birth_year=None,
                birth_date=None,
            ))

    return ParsedTournament(
        source_kind=SourceKind.OPHARDT_HTML,
        results=parsed,
        raw_pool_size=len(parsed),
        source_url=source_url,
    )
