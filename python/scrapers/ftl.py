"""
FencingTimeLive (FTL) parser.

Supports two data sources:
- JSON API: /events/results/data/{EVENT_ID}
- CSV download: /events/results/download/{EVENT_ID}

Name format quirk: Some FTL tournaments (e.g., BVF) include age category
markers in names like "ATANASSOW 2 Aleksander". The parser strips these.
"""

from __future__ import annotations

import csv
import io
import re


# Pattern matches a standalone digit (age category) between surname and first name
# e.g., "ATANASSOW 2 Aleksander" → groups: ("ATANASSOW", "Aleksander")
_CATEGORY_RE = re.compile(r"^(\S+)\s+\d+\s+(.+)$")


def _clean_name(raw_name: str) -> str:
    """Strip age category marker from FTL name format.

    "ATANASSOW 2 Aleksander" → "ATANASSOW Aleksander"
    "ATANASSOW Aleksander" → "ATANASSOW Aleksander" (no change)
    """
    m = _CATEGORY_RE.match(raw_name.strip())
    if m:
        return f"{m.group(1)} {m.group(2)}"
    return raw_name.strip()


def _parse_place(place_str: str) -> int:
    """Parse FTL place string, stripping tie indicator.

    "1" → 1, "3T" → 3, "52T" → 52
    """
    return int(re.sub(r"[A-Za-z]", "", place_str))


def parse_ftl_json(data: list[dict]) -> list[dict]:
    """Parse FTL JSON API response into standardized result list.

    Args:
        data: List of dicts from /events/results/data/{EVENT_ID}

    Returns:
        List of dicts with keys: fencer_name, place, country
    """
    results = []
    for entry in data:
        if entry.get("excluded"):
            continue
        results.append({
            "fencer_name": _clean_name(entry["name"]),
            "place": _parse_place(str(entry["place"])),
            "country": entry.get("country", ""),
        })
    return results


def parse_ftl_csv(csv_text: str) -> list[dict]:
    """Parse FTL CSV download into standardized result list.

    CSV columns: Place, Name, Club(s), Division, Country
    """
    results = []
    reader = csv.DictReader(io.StringIO(csv_text))
    for row in reader:
        results.append({
            "fencer_name": _clean_name(row["Name"]),
            "place": _parse_place(row["Place"]),
            "country": row.get("Country", ""),
        })
    return results
