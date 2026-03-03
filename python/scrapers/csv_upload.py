"""
CSV upload handler.

Parses CSV files in FTL format (Place,Name,Club(s),Division,Country)
into the standardized result format.
"""

from __future__ import annotations

import csv
import io
import re


def _parse_place(place_str: str) -> int:
    """Parse place string, stripping tie indicator. '3T' → 3."""
    return int(re.sub(r"[A-Za-z]", "", place_str))


def parse_csv_upload(csv_text: str) -> list[dict]:
    """Parse a CSV file (FTL format) into standardized result list.

    Expected columns: Place, Name, Club(s), Division, Country
    Also handles minimal CSVs with just Place and Name.
    """
    results = []
    reader = csv.DictReader(io.StringIO(csv_text))
    for row in reader:
        results.append({
            "fencer_name": row.get("Name", "").strip(),
            "place": _parse_place(row.get("Place", "0")),
            "country": row.get("Country", "").strip(),
        })
    return results
