"""
4Fence parser.

Parses results from 4fence.it competition pages.

Structure:
- <tr class="null767"> rows contain participant data
- Cell indices: [2]=Place, [4]=Surname, [5]=Name, [7]=Club
- Header rows have surname="COGNOME" — these are filtered out
- Secondary rows with class="nullmax" are ignored
"""

from __future__ import annotations

import re

from bs4 import BeautifulSoup

# Matches &nbsp (with or without semicolon), case-insensitive
_NBSP_RE = re.compile(r"&nbsp;?", re.IGNORECASE)


def _clean_text(text: str) -> str:
    """Strip non-breaking spaces in all forms from extracted text."""
    return _NBSP_RE.sub("", text).replace("\xa0", "").strip()


def parse_fourfence_html(html: str) -> list[dict]:
    """Parse 4Fence results HTML into standardized result list.

    Args:
        html: Full HTML content of the results page

    Returns:
        List of dicts with keys: fencer_name, place, country (empty for 4Fence)
    """
    soup = BeautifulSoup(html, "html.parser")

    results = []
    rows = soup.find_all("tr", class_="null767")

    for row in rows:
        cells = row.find_all("td")
        if len(cells) < 9:
            continue

        surname = _clean_text(cells[4].get_text(strip=True))
        name = _clean_text(cells[5].get_text(strip=True))

        # Skip header rows (Italian labels)
        if surname.upper() == "COGNOME" or name.upper() == "NOME":
            continue

        # Place is in cell[2] ("Cla Gir")
        place_text = cells[2].get_text(strip=True)
        if not place_text or not place_text[0].isdigit():
            continue
        place = int(place_text)

        # Format name as "SURNAME FirstName" with proper casing for first name
        fencer_name = f"{surname} {name.title()}".strip() if name else surname

        # Club in cell[7]
        club = _clean_text(cells[7].get_text(strip=True))

        results.append({
            "fencer_name": fencer_name,
            "place": place,
            "country": "",  # 4Fence doesn't reliably provide country codes
            "club": club,
        })

    return results
