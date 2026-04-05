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
from dataclasses import dataclass, field
from datetime import datetime

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

# Age category → (min_age, max_age) inclusive
_CATEGORY_AGE_RANGE = {
    "V0": (30, 39),
    "V1": (40, 49),
    "V2": (50, 59),
    "V3": (60, 69),
    "V4": (70, 999),
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


def _birth_year_from_dob(dob_iso: str | None) -> int | None:
    """Extract year from ISO date string, or None."""
    if not dob_iso:
        return None
    return int(dob_iso[:4])


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


@dataclass
class SplitResult:
    """Result of splitting combined-category results (ADR-024)."""

    buckets: dict[str, list[dict]] = field(default_factory=dict)
    unresolved: list[dict] = field(default_factory=list)


def split_combined_results(
    enriched_results: list[dict],
    categories: list[str],
    fencer_db: list[dict],
    season_end_year: int,
) -> SplitResult:
    """Split combined-category results into per-category ranked lists.

    For each fencer:
    1. Use birth_date from XML if available
    2. Cross-reference fencer_db by name if DOB missing
    3. If still unknown → add to unresolved AND assign to lowest category
       (ADR-024: flag PENDING for admin review, don't silently assign)

    Re-ranks within each split: place 1..N per category.

    Args:
        enriched_results: From parse_fencingtime_xml_enriched()
        categories: List of categories to split into (e.g., ["V0", "V1"])
        fencer_db: Master fencer list for DOB cross-reference
        season_end_year: End year for age calculation

    Returns:
        SplitResult with buckets (category → results) and unresolved list
    """
    # Build name→birth_year lookup from fencer_db
    db_lookup: dict[str, int] = {}
    for f in fencer_db:
        surname = f.get("txt_surname", "")
        first_name = f.get("txt_first_name", "")
        name = f"{surname} {first_name}".strip() if first_name else surname
        by = f.get("int_birth_year")
        if by is not None:
            db_lookup[name.upper()] = by

    # Assign each fencer to a category
    buckets: dict[str, list[dict]] = {cat: [] for cat in categories}
    unresolved: list[dict] = []
    lowest_cat = categories[0]  # e.g., "V0" for ["V0", "V1"]

    # Sort by original place to preserve relative ordering
    sorted_results = sorted(enriched_results, key=lambda r: r["place"])

    for result in sorted_results:
        birth_year = _birth_year_from_dob(result.get("birth_date"))

        # Cross-reference fencer_db if DOB missing
        if birth_year is None:
            birth_year = db_lookup.get(result["fencer_name"].upper())

        # Determine category from birth year
        assigned_cat = None
        if birth_year is not None:
            age = season_end_year - birth_year
            for cat in categories:
                age_range = _CATEGORY_AGE_RANGE.get(cat)
                if age_range and age_range[0] <= age <= age_range[1]:
                    assigned_cat = cat
                    break

        # ADR-024: unknown DOB → assign to lowest but track as unresolved
        if assigned_cat is None:
            assigned_cat = lowest_cat
            unresolved.append(dict(result))

        buckets[assigned_cat].append(dict(result))

    # Re-rank within each category
    for cat, fencers in buckets.items():
        for i, fencer in enumerate(fencers, 1):
            fencer["place"] = i

    return SplitResult(buckets=buckets, unresolved=unresolved)
