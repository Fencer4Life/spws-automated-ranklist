"""
Dartagnan parser (dartagnan.live).

Used by EVF Salzburg 2026 and potentially other European events.
The platform publishes per-competition pages under an event index:

    <event>/<de|en>/index.html             → competition list
    <event>/<de|en>/<ID>-rankings.html     → final classification

This module parses both formats into the shared scraper contract:
    {fencer_name, place, country}    (country = 3-letter ISO from flag img)

Labels on the index are mixed DE/EN ("Men Epee V1", "männlich, Degen") so
weapon/gender label maps accept both. Combined rounds like "V1/V2 Runde"
are skipped — they map to no single SPWS (weapon, gender, category).
"""

from __future__ import annotations

import re
import time
from urllib.parse import urljoin

from bs4 import BeautifulSoup

DARTAGNAN_HOSTS = ("dartagnan.live", "www.dartagnan.live")

WEAPON_LABELS = {
    "degen": "EPEE",   "epee": "EPEE",
    "florett": "FOIL", "foil": "FOIL",
    "säbel": "SABRE",  "sabel": "SABRE", "sabre": "SABRE",
}
GENDER_LABELS = {
    "herren": "M", "men": "M", "männlich": "M", "mannlich": "M",
    "damen": "F",  "women": "F", "weiblich": "F",
}


def _extract_single_category(text: str) -> str | None:
    """Extract a single V0-V4 category from competition text.

    Returns None when the text names a combined round (e.g. "V1/V2 Runde")
    or contains no category token — such entries don't map to a single SPWS
    tournament and must be skipped.
    """
    categories = re.findall(r"\bV([0-4])\b", text)
    if len(categories) == 1:
        return f"V{categories[0]}"
    return None


def _extract_weapon(text: str) -> str | None:
    lower = text.lower()
    for label, value in WEAPON_LABELS.items():
        if re.search(rf"\b{re.escape(label)}\b", lower):
            return value
    return None


def _extract_gender(text: str) -> str | None:
    lower = text.lower()
    for label, value in GENDER_LABELS.items():
        if re.search(rf"\b{re.escape(label)}\b", lower):
            return value
    return None


def parse_dartagnan_event_index(html: str, base_url: str) -> list[dict]:
    """Parse Dartagnan index.html → list of single-category competitions.

    Returns:
        [{"id": "6687", "weapon": "EPEE", "gender": "M", "category": "V1",
          "rankings_url": "https://.../6687-rankings.html"}, ...]

    Combined rounds (V1/V2, V3/V4 Runde, etc.) are filtered out.
    """
    soup = BeautifulSoup(html, "html.parser")
    competitions: list[dict] = []
    seen_ids: set[str] = set()

    # Primary competition blocks live inside <div class="compBox">.
    for box in soup.find_all("div", class_="compBox"):
        h3 = box.find("h3")
        anchor = box.find("a", href=True)
        if not h3 or not anchor:
            continue

        title = h3.get_text(strip=True)
        href = anchor["href"]
        m = re.search(r"(\d+)-[a-z]+\.html", href)
        if not m:
            continue
        comp_id = m.group(1)
        if comp_id in seen_ids:
            continue

        # Category must be a single V0-V4; combined "V1/V2 Runde" → skip.
        category = _extract_single_category(title)
        if category is None:
            continue

        # Combine title + descriptive text below h3 for weapon/gender lookup.
        descriptor = box.get_text(" ", strip=True)
        weapon = _extract_weapon(descriptor) or _extract_weapon(title)
        gender = _extract_gender(descriptor) or _extract_gender(title)
        if not weapon or not gender:
            continue

        rankings_url = urljoin(base_url, f"{comp_id}-rankings.html")
        competitions.append({
            "id": comp_id,
            "weapon": weapon,
            "gender": gender,
            "category": category,
            "rankings_url": rankings_url,
        })
        seen_ids.add(comp_id)

    return competitions


def _country_from_flag(cell) -> str:
    """Extract 3-letter ISO country code from a Nation cell's flag img src."""
    img = cell.find("img")
    if img is None:
        return ""
    src = img.get("src", "")
    m = re.search(r"/([A-Z]{3})\.[a-zA-Z]+$", src)
    if m:
        return m.group(1)
    return ""


def _normalize_name(surname: str, firstname: str) -> str:
    """Normalise 'Surname, Firstname' → 'SURNAME Firstname' (engarde-style)."""
    return f"{surname.strip().upper()} {firstname.strip()}".strip()


def parse_dartagnan_rankings_html(html: str) -> list[dict]:
    """Parse Dartagnan <ID>-rankings.html into scraper contract rows.

    Returns:
        [{"fencer_name": "PARTICS Péter", "place": 1, "country": "HUN"}, ...]

    - Empty table (unfinished tournament) → [] (no raise).
    - Ties: multiple rows share the same place.
    """
    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table", class_="lists")
    if table is None:
        return []

    results: list[dict] = []
    for row in table.find_all("tr"):
        if row.find("th"):
            continue
        cells = row.find_all("td")
        if len(cells) < 6:
            continue

        place_text = cells[0].get_text(strip=True)
        if not place_text or not place_text[0].isdigit():
            continue
        place = int(re.sub(r"[^0-9]", "", place_text))

        surname = cells[1].get_text(strip=True)
        firstname = cells[2].get_text(strip=True)
        fencer_name = _normalize_name(surname, firstname)
        if not fencer_name:
            continue

        country = _country_from_flag(cells[5])

        results.append({
            "fencer_name": fencer_name,
            "place": place,
            "country": country,
        })

    return results


def scrape_dartagnan_event(
    index_url: str,
    http_get=None,
    request_delay: float = 0.3,
) -> dict:
    """Fetch Dartagnan index, then each rankings page; return combined dict.

    Args:
        index_url: Event index URL (…/de/index.html).
        http_get: Callable(url) -> str. Defaults to httpx.get().text.
        request_delay: Polite delay between HTTP requests (seconds).

    Returns:
        {"event_url": index_url,
         "competitions": [
            {"id", "weapon", "gender", "category",
             "rankings_url", "results": [...]}]}
    """
    if http_get is None:
        import httpx

        def http_get(url: str) -> str:
            resp = httpx.get(url, follow_redirects=True, timeout=30)
            resp.raise_for_status()
            return resp.text

    index_html = http_get(index_url)
    competitions = parse_dartagnan_event_index(index_html, index_url)

    enriched: list[dict] = []
    for comp in competitions:
        if request_delay:
            time.sleep(request_delay)
        rankings_html = http_get(comp["rankings_url"])
        comp["results"] = parse_dartagnan_rankings_html(rankings_html)
        enriched.append(comp)

    return {"event_url": index_url, "competitions": enriched}
