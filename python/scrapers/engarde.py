"""
Engarde parser.

Parses the final classification HTML page from engarde-service.com.
Handles multilingual headers (EN, FR, ES, IT, DE, PL, HU).

Structure:
- <table class="liste"> contains the results
- First column (class="GBD") = place/rank
- Subsequent columns = surname, first name, country
- Participant count in <h3> text: "Overall ranking (57 fencers)"
"""

from __future__ import annotations

import re

from bs4 import BeautifulSoup


def _extract_participant_count(soup: BeautifulSoup) -> int | None:
    """Extract participant count from <h3> text like 'Overall ranking (57 fencers)'."""
    for h3 in soup.find_all("h3"):
        text = h3.get_text()
        m = re.search(r"\((\d+)\s", text)
        if m:
            return int(m.group(1))
    return None


def parse_engarde_html(html: str) -> list[dict]:
    """Parse Engarde final classification HTML into standardized result list.

    Args:
        html: Full HTML content of the classification page

    Returns:
        List of dicts with keys: fencer_name, place, country
    """
    soup = BeautifulSoup(html, "html.parser")

    # Find the results table (class="liste")
    table = soup.find("table", class_="liste")
    if table is None:
        raise ValueError("No table with class='liste' found in Engarde HTML")

    results = []
    rows = table.find_all("tr")

    for row in rows:
        # Skip header rows (contain <th>)
        if row.find("th"):
            continue

        cells = row.find_all("td")
        if len(cells) < 4:
            continue

        # First cell = place (class="GBD", right-aligned)
        place_text = cells[0].get_text(strip=True)
        if not place_text or not place_text[0].isdigit():
            continue

        place = int(re.sub(r"[^0-9]", "", place_text))

        # Second cell = surname, third cell = first name
        surname = cells[1].get_text(strip=True).replace("\xa0", "")
        firstname = cells[2].get_text(strip=True).replace("\xa0", "")

        # Fourth cell = country (may have a <span> inside)
        country_cell = cells[3]
        country_span = country_cell.find("span", attrs={"translate": "no"})
        if country_span:
            country = country_span.get_text(strip=True)
        else:
            country = country_cell.get_text(strip=True).replace("\xa0", "")

        fencer_name = f"{surname} {firstname}".strip()
        if not fencer_name:
            continue

        results.append({
            "fencer_name": fencer_name,
            "place": place,
            "country": country,
        })

    return results
