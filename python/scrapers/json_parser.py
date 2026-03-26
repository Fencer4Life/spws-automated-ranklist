"""
JSON file parser.

Handles two common formats:
1. Array of objects: [{"place": 1, "fencer_name": "..."}, ...]
2. Wrapper object: {"results": [...]} or {"data": [...]}

Normalizes various key names to the standard fencer_name/place/country.
"""

from __future__ import annotations

import json

# Key normalization: common JSON export key names -> standard keys
_KEY_MAP = {
    "place": "place", "rank": "place", "miejsce": "place", "position": "place",
    "fencer_name": "fencer_name", "name": "fencer_name", "nazwisko": "fencer_name",
    "fencer": "fencer_name", "athlete": "fencer_name",
    "country": "country", "nat": "country", "nationality": "country", "kraj": "country",
}


def parse_json(file_bytes: bytes) -> list[dict]:
    """Parse JSON file into standardized result list.

    Args:
        file_bytes: Raw JSON file content (UTF-8).

    Returns:
        list[dict] with keys: fencer_name (str), place (int), country (str).

    Raises:
        ValueError: If JSON structure is not a recognized format.
    """
    data = json.loads(file_bytes.decode("utf-8"))

    # Unwrap if data is an object with a known array key
    if isinstance(data, dict):
        for key in ("results", "data", "fencers", "participants"):
            if key in data and isinstance(data[key], list):
                data = data[key]
                break
        else:
            raise ValueError(
                "JSON object must contain a 'results' or 'data' array"
            )

    if not isinstance(data, list):
        raise ValueError("JSON must be an array or object with results array")

    results = []
    for entry in data:
        row: dict[str, object] = {}
        for raw_key, value in entry.items():
            normalized = raw_key.strip().lower()
            if normalized in _KEY_MAP:
                row[_KEY_MAP[normalized]] = value

        if "place" not in row or "fencer_name" not in row:
            continue

        results.append({
            "fencer_name": str(row["fencer_name"]).strip(),
            "place": int(row["place"]),
            "country": str(row.get("country", "")).strip(),
        })

    return results
