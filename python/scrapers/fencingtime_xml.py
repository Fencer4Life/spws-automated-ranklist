"""
FencingTime XML parser.

Parses competition result files exported by FencingTime v4.7+.
Format: <CompetitionIndividuelle> root with <Tireurs>/<Tireur> elements.

Key attributes:
  - Classement: final place (1-based)
  - Nom/Prenom: surname/first name
  - DateNaissance: birth date (DD.MM.YYYY), often missing
  - AltName (root): category info in Polish (e.g., "SZPADA MĘŻCZYZN v0v1")

Supports combined-category splitting (e.g., V0+V1 run together)
using birth year to assign fencers to their correct age category.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from datetime import datetime

# Splitter symbols moved to python.pipeline.age_split (2026-04-29) so every
# ingestion path can use the same logic. Re-exported below for backward
# compatibility with existing imports (`from python.scrapers.fencingtime_xml
# import split_combined_results`, …).
from python.pipeline.age_split import (
    _CATEGORY_AGE_RANGE,
    _birth_year_from_dob,
    SplitResult,
    split_combined_results,
)

# Polish weapon names → English
_WEAPON_MAP = {
    "SZPADA": "EPEE",
    "FLORET": "FOIL",
    "SZABLA": "SABRE",
}

# Polish gender keywords → M/F
_GENDER_MAP = {
    "MĘŻCZYZN": "M",
    "KOBIET": "F",
}

ALL_CATEGORIES = ["V0", "V1", "V2", "V3", "V4"]


def _parse_root(file_bytes: bytes) -> ET.Element:
    """Parse XML bytes and return root element."""
    return ET.fromstring(file_bytes)


def _parse_dob(dob_str: str | None) -> str | None:
    """Parse 'DD.MM.YYYY' → 'YYYY-MM-DD', or None if missing/empty."""
    if not dob_str or not dob_str.strip():
        return None
    try:
        dt = datetime.strptime(dob_str.strip(), "%d.%m.%Y")
        return dt.strftime("%Y-%m-%d")
    except ValueError:
        return None


def parse_fencingtime_xml(file_bytes: bytes) -> list[dict]:
    """Parse FencingTime XML into standardized result list.

    Returns:
        list[dict] with keys: fencer_name (str), place (int), country (str).
        Matches the format used by other parsers (xlsx, csv, json).
    """
    root = _parse_root(file_bytes)
    tireurs = root.find("Tireurs")
    if tireurs is None:
        return []

    results = []
    for tireur in tireurs.findall("Tireur"):
        nom = tireur.attrib.get("Nom", "")
        prenom = tireur.attrib.get("Prenom", "")
        name = f"{nom} {prenom}".strip() if prenom else nom
        place = int(tireur.attrib.get("Classement", "0"))
        country = tireur.attrib.get("Nation", "")
        results.append({
            "fencer_name": name,
            "place": place,
            "country": country,
        })

    return results


def parse_fencingtime_xml_enriched(file_bytes: bytes) -> list[dict]:
    """Parse FencingTime XML with additional fields for identity resolution.

    Returns:
        list[dict] with keys: fencer_name, place, country,
        birth_date (ISO str or None), club (str), fencer_id_xml (str).
    """
    root = _parse_root(file_bytes)
    tireurs = root.find("Tireurs")
    if tireurs is None:
        return []

    results = []
    for tireur in tireurs.findall("Tireur"):
        nom = tireur.attrib.get("Nom", "")
        prenom = tireur.attrib.get("Prenom", "")
        name = f"{nom} {prenom}".strip() if prenom else nom
        place = int(tireur.attrib.get("Classement", "0"))
        country = tireur.attrib.get("Nation", "")
        dob = _parse_dob(tireur.attrib.get("DateNaissance"))
        club = tireur.attrib.get("Club", "")
        xml_id = tireur.attrib.get("ID", "")
        results.append({
            "fencer_name": name,
            "place": place,
            "country": country,
            "birth_date": dob,
            "club": club,
            "fencer_id_xml": xml_id,
        })

    return results


def parse_xml_metadata(file_bytes: bytes) -> dict:
    """Extract competition metadata from XML root attributes.

    Returns:
        dict with keys: weapon, gender, date, title, alt_name, federation.
    """
    root = _parse_root(file_bytes)
    arme = root.attrib.get("Arme", "")
    sexe = root.attrib.get("Sexe", "")
    alt_name = root.attrib.get("AltName", "")

    # Map weapon code to English
    weapon_map = {"E": "EPEE", "F": "FOIL", "S": "SABRE"}
    weapon = weapon_map.get(arme, arme)

    # Map gender — prefer AltName parsing over Sexe (which can be 'X')
    gender = sexe
    for pl_gender, en_gender in _GENDER_MAP.items():
        if pl_gender in alt_name.upper():
            gender = en_gender
            break

    return {
        "weapon": weapon,
        "gender": gender,
        "date": root.attrib.get("Date", ""),
        "title": root.attrib.get("TitreLong", ""),
        "alt_name": alt_name,
        "federation": root.attrib.get("Federation", ""),
    }


def detect_categories_from_altname(alt_name: str) -> list[str]:
    """Parse AltName to extract age categories.

    Examples:
        "SZPADA MĘŻCZYZN v2"     → ["V2"]
        "SZPADA MĘŻCZYZN v0v1"   → ["V0", "V1"]
        "FLORET MĘŻCZYZN v0v1v2" → ["V0", "V1", "V2"]
        "SZABLA KOBIET"           → ["V0", "V1", "V2", "V3", "V4"]

    When no vN suffix is present, returns all 5 categories (the event
    ran all age categories combined).
    """
    # Find vN patterns at the end of the string
    match = re.search(r"(v\d(?:v\d)*)\s*$", alt_name, re.IGNORECASE)
    if not match:
        return list(ALL_CATEGORIES)

    v_str = match.group(1).lower()
    # Split "v0v1v2" → ["v0", "v1", "v2"]
    cats = re.findall(r"v\d", v_str)
    return [c.upper() for c in cats]


# split_combined_results / SplitResult / _CATEGORY_AGE_RANGE / _birth_year_from_dob
# moved to python.pipeline.age_split (2026-04-29). Re-exported above for
# backward compatibility with existing callers and tests.


# =============================================================================
# IR factory (Phase 1 / part 2 — ADR-050)
#
# parse() emits ParsedTournament. Native source_row_id from Tireur.ID.
# Metadata (weapon, gender, date, category_hint) extracted from root attrs.
# =============================================================================

def _parse_date_dmy(s: str | None):
    """Parse 'DD.MM.YYYY' → datetime.date, or None if missing/invalid."""
    if not s or not s.strip():
        return None
    try:
        return datetime.strptime(s.strip(), "%d.%m.%Y").date()
    except ValueError:
        return None


def _extract_category_hint(alt_name: str | None) -> str | None:
    """Pull the trailing 'vN' or 'vNvM…' suffix from AltName, uppercased.

    'SZPADA MĘŻCZYZN v2'   -> 'V2'
    'FLORET KOBIET v0v1'   -> 'V0V1'
    'SZABLA KOBIET'        -> None
    """
    if not alt_name:
        return None
    m = re.search(r"(v\d(?:v\d)*)\s*$", alt_name, re.IGNORECASE)
    return m.group(1).upper() if m else None


def parse(
    file_bytes: bytes,
    source_url: str | None = None,
):
    """Parse FencingTime XML into ParsedTournament.

    Native source_row_id comes from Tireur.ID (`f"ft_xml:{ID}"`); falls
    back to synthetic if ID is empty. Birth date parsed from
    DateNaissance (DD.MM.YYYY). Tournament metadata pulled from the root
    element's attributes.
    """
    from python.pipeline.ir import (
        ParsedResult, ParsedTournament, SourceKind, make_synthetic_id,
    )
    from datetime import date  # noqa: F401  (used in birth_date typing)

    root = _parse_root(file_bytes)
    tireurs = root.find("Tireurs")

    # Metadata from root attrs:
    arme = root.attrib.get("Arme", "")
    weapon_map = {"E": "EPEE", "F": "FOIL", "S": "SABRE"}
    weapon = weapon_map.get(arme) or None

    sexe = root.attrib.get("Sexe", "")
    alt_name = root.attrib.get("AltName", "")
    gender = sexe if sexe in ("M", "F") else None
    for pl_gender, en_gender in _GENDER_MAP.items():
        if pl_gender in alt_name.upper():
            gender = en_gender
            break

    parsed_date = _parse_date_dmy(root.attrib.get("Date"))
    category_hint = _extract_category_hint(alt_name)

    parsed_results: list[ParsedResult] = []
    if tireurs is not None:
        for i, tireur in enumerate(tireurs.findall("Tireur"), start=1):
            nom = tireur.attrib.get("Nom", "")
            prenom = tireur.attrib.get("Prenom", "")
            name = f"{nom} {prenom}".strip() if prenom else nom
            place = int(tireur.attrib.get("Classement", "0"))
            country = tireur.attrib.get("Nation") or None
            xml_id = tireur.attrib.get("ID", "").strip()
            dob_str = _parse_dob(tireur.attrib.get("DateNaissance"))
            birth_date = (
                datetime.strptime(dob_str, "%Y-%m-%d").date()
                if dob_str else None
            )

            sid = (
                f"ft_xml:{xml_id}" if xml_id
                else make_synthetic_id(
                    SourceKind.FENCINGTIME_XML,
                    row_index=i, place=place, name=name,
                )
            )
            parsed_results.append(ParsedResult(
                source_row_id=sid,
                fencer_name=name,
                place=place,
                fencer_country=country,
                birth_date=birth_date,
                birth_year=birth_date.year if birth_date else None,
            ))

    return ParsedTournament(
        source_kind=SourceKind.FENCINGTIME_XML,
        results=parsed_results,
        raw_pool_size=len(parsed_results),
        weapon=weapon,
        gender=gender,
        parsed_date=parsed_date,
        category_hint=category_hint,
        source_url=source_url,
    )
