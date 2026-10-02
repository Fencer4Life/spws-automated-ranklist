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
import xml.etree.ElementTree as ET
from datetime import date

from bs4 import BeautifulSoup

ENGARDE_WEAPON_MAP = {"e": "EPEE", "f": "FOIL", "s": "SABRE"}
ENGARDE_GENDER_MAP = {"m": "M", "f": "F"}
ENGARDE_COMPETITION_BASE = "https://engarde-service.com/competition"
ENGARDE_LIST_URL = (
    "https://engarde-service.com/prog/getCompeForDisplay.php"
    "?option=competition&organism={org}&event={event}"
    "&lang=en&nrows=50&page=no&orderby=competitions_tournament"
    "&order=ASC&large=E&show_test=0&cache=1"
)
_TOURNAMENT_RE = re.compile(r"engarde-service\.com/tournament/([^/?#]+)/([^/?#]+)", re.IGNORECASE)
_POOL_RE = re.compile(r"\b(poules?|pools?)\b", re.IGNORECASE)


def parse_engarde_category(slug: str, titre: str) -> list[str]:
    """Extract age categories from Engarde slug and title.

    Priority: title V-notation > slug pattern > title bare digits.

    Handles:
    - Title "Men's Epee V1 (40)" → ["V1"]
    - Title "Women's Epee V1-V2 Poules (40-50)" → ["V1", "V2"]
    - Slug "ef-2" → ["V2"]
    - Slug "em-3-4" → ["V3", "V4"]  (combined)
    - Slug "shv2" → ["V2"]
    - Title "EPEE FEMALE - 2" → ["V2"]
    """
    # 1. Try V-notation from title: "V1", "V2", "V1-V2", etc.
    v_from_title = re.findall(r"V([0-4])", titre)
    if v_from_title:
        return [f"V{d}" for d in v_from_title]

    # 2. Try slug patterns
    # "ef-3-4" or "em-1-2" — combined via dash-digit
    slug_combined = re.findall(r"-([0-4])(?!\d)", slug)
    if len(slug_combined) >= 2:
        return [f"V{d}" for d in slug_combined]
    if len(slug_combined) == 1:
        return [f"V{slug_combined[0]}"]

    # "shv2", "ehv1" — v-suffix
    v_match = re.search(r"v([0-4])$", slug)
    if v_match:
        return [f"V{v_match.group(1)}"]

    # 3. Fallback: bare digits in title: "EPEE FEMALE - 2"
    title_digits = re.findall(r"\b([0-4])\b", titre)
    if title_digits:
        return [f"V{d}" for d in title_digits]

    return []


def parse_engarde_gender(sexe: str, titre: str) -> str | None:
    """Extract gender from sexe attribute, with title fallback.

    Some events have wrong sexe attribute (e.g. Budapest me70 has sexe='f').
    Title keywords override: Men's/Women's/Homme/Femme/Dame.
    """
    upper = titre.upper()
    if "WOMEN" in upper or "FEMME" in upper or "DAME" in upper or "FEMALE" in upper:
        return "F"
    if "MEN'S" in upper or "HOMME" in upper or " MALE" in upper or upper.startswith("MEN"):
        return "M"
    return ENGARDE_GENDER_MAP.get(sexe)


def engarde_tournament(url: str) -> tuple[str, str] | None:
    """(organism, event) of an Engarde tournament URL, or None for any other URL."""
    m = _TOURNAMENT_RE.search(url or "")
    return (m.group(1), m.group(2)) if m else None


def parse_competition_list(xml_text: str, org: str, event: str) -> tuple[list[dict], list[dict]]:
    """Split an Engarde competition list (getCompeForDisplay XML) into the
    category finals and the competitions that are not brackets.

    A final is individual, completed, not a pool round, and names exactly one
    category; its weapon comes from Engarde's ``arme``, its gender and
    category from the published title (the ``sexe`` attribute is wrong at
    some organisers). Everything else is returned with the reason it was
    skipped, so the staging summary lists it for review.
    """
    kept: list[dict] = []
    skipped: list[dict] = []
    for comp in ET.fromstring(xml_text).findall("comp"):
        slug = comp.get("compe", "")
        title = (comp.findtext("titre") or "").strip()
        weapon = ENGARDE_WEAPON_MAP.get(comp.get("arme", ""))
        url = f"{ENGARDE_COMPETITION_BASE}/{org}/{event}/{slug}"
        state = comp.get("etat", "")
        categories = sorted(set(parse_engarde_category(slug, title)))
        if comp.get("estindividuelle") == "0":
            reason = "team event"
        elif _POOL_RE.search(title):
            reason = "pool round"
        elif state != "completed":
            reason = f"not completed ({state})"
        elif not categories:
            reason = "no category in the title"
        elif len(categories) > 1:
            reason = "spans categories " + ", ".join(categories)
        else:
            reason = None
        gender = parse_engarde_gender(comp.get("sexe", ""), title)
        if reason is None and (weapon is None or gender is None):
            reason = "no weapon or gender"
        if reason is not None:
            skipped.append(
                {"slug": slug, "name": title, "weapon": weapon, "url": url, "reason": reason}
            )
            continue
        y, m, d = (int(x) for x in comp.get("date", "").split())
        kept.append(
            {
                "slug": slug,
                "weapon": weapon,
                "gender": gender,
                "category": categories[0],
                "title": title,
                "date": date(y, m, d),
                "url": url,
            }
        )
    return kept, skipped


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

        results.append(
            {
                "fencer_name": fencer_name,
                "place": place,
                "country": country,
            }
        )

    return results


# =============================================================================
# IR factory (Phase 1 / part 2 — ADR-050)
#
# parse_html emits ParsedTournament. The legacy parse_engarde_html stays
# until Phase 6 collapses callers.
# =============================================================================


def parse_html(
    html: str,
    source_url: str | None = None,
):
    """Parse Engarde final-classification HTML into a ParsedTournament.

    Engarde tables are position-based and locale-agnostic — same parser
    handles EN / FR / ES / IT / DE / PL / HU pages (R012). No native row
    IDs available; uses synthetic IDs via ``make_synthetic_id``.
    """
    from python.pipeline.ir import (
        ParsedResult,
        ParsedTournament,
        SourceKind,
        make_synthetic_id,
    )

    soup = BeautifulSoup(html, "html.parser")
    table = soup.find("table", class_="liste")
    if table is None:
        raise ValueError("No table with class='liste' found in Engarde HTML")

    parsed_results: list[ParsedResult] = []
    row_index = 0

    for row in table.find_all("tr"):
        if row.find("th"):
            continue
        cells = row.find_all("td")
        if len(cells) < 4:
            continue

        place_text = cells[0].get_text(strip=True)
        if not place_text or not place_text[0].isdigit():
            continue
        place = int(re.sub(r"[^0-9]", "", place_text))

        surname = cells[1].get_text(strip=True).replace("\xa0", "")
        firstname = cells[2].get_text(strip=True).replace("\xa0", "")

        country_cell = cells[3]
        country_span = country_cell.find("span", attrs={"translate": "no"})
        if country_span:
            country = country_span.get_text(strip=True)
        else:
            country = country_cell.get_text(strip=True).replace("\xa0", "")

        fencer_name = f"{surname} {firstname}".strip()
        if not fencer_name:
            continue

        row_index += 1
        parsed_results.append(
            ParsedResult(
                source_row_id=make_synthetic_id(
                    SourceKind.ENGARDE,
                    row_index=row_index,
                    place=place,
                    name=fencer_name,
                ),
                fencer_name=fencer_name,
                place=place,
                fencer_country=country or None,
            )
        )

    # The header counts the whole bracket, including a fencer listed without a
    # place (DNS); EVF scores with that count (ENG.EVT.05).
    header_count = _extract_participant_count(soup) or 0
    return ParsedTournament(
        source_kind=SourceKind.ENGARDE,
        results=parsed_results,
        raw_pool_size=max(header_count, len(parsed_results)),
        source_url=source_url,
    )
