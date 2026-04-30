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
# Pattern matches a "(N)" suffix at the end (e.g., "KAMIŃSKA Gabriela (1)")
# FTL combined-pool events use this form to tag each fencer's V-cat.
_SUFFIX_CATEGORY_RE = re.compile(r"^(.+?)\s+\(\d+\)\s*$")


def _clean_name(raw_name: str) -> str:
    """Strip age category marker from FTL name format.

    Handles three forms:
      "ATANASSOW 2 Aleksander"     → "ATANASSOW Aleksander"   (mid-name)
      "KAMIŃSKA Gabriela (1)"      → "KAMIŃSKA Gabriela"      (suffix)
      "ATANASSOW Aleksander"       → "ATANASSOW Aleksander"   (no marker)

    The marker itself is age-category info; for downstream matching we want
    the bare name. Birth-year-based V-cat assignment happens in
    python.pipeline.age_split, not from these markers.
    """
    raw = raw_name.strip()
    m = _CATEGORY_RE.match(raw)
    if m:
        return f"{m.group(1)} {m.group(2)}"
    m2 = _SUFFIX_CATEGORY_RE.match(raw)
    if m2:
        return m2.group(1).strip()
    return raw


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


# Pattern preserves the standalone digit (or parenthesised digit) — the FTL
# age-category marker between surname and given name. ADR-024 + Phase 4 use
# this digit to split combined-category tournaments into per-category rows.
_MARKER_RE = re.compile(r"^(\S+)\s+\(?(\d+)\)?\s+(.+)$")


def parse_ftl_with_marker(data: list[dict]) -> list[dict]:
    """Parse FTL JSON preserving the per-fencer age-category marker.

    Returns rows with keys: fencer_name (cleaned), place, country, marker.
    `marker` is the integer digit found between surname and given name (e.g.
    '1' for V1, '2' for V2), or None when no marker is present. Combined-
    category re-split logic in python/tools/refix_combined_pools.py keys off
    this marker.
    """
    results = []
    for entry in data:
        if entry.get("excluded"):
            continue
        raw = entry["name"].strip()
        m = _MARKER_RE.match(raw)
        if m:
            cleaned = f"{m.group(1)} {m.group(3)}"
            marker = int(m.group(2))
        else:
            cleaned = raw
            marker = None
        results.append({
            "fencer_name": cleaned,
            "place": _parse_place(str(entry["place"])),
            "country": entry.get("country", ""),
            "marker": marker,
        })
    return results


_FTL_RESULTS_URL_RE = re.compile(
    r"fencingtimelive\.com/(?:events/results|tournaments/eventSchedule)/([0-9A-F]{32})",
    re.IGNORECASE,
)
_FTL_DATE_RE = re.compile(
    r"\b(January|February|March|April|May|June|July|"
    r"August|September|October|November|December)\s+"
    r"(\d{1,2}),?\s+(\d{4})\b"
)
_FTL_WEAPON_HINTS = {
    "SABRE": ("szabla", "sabre"),
    "FOIL":  ("floret", "foil"),
    "EPEE":  ("szpada", "epee", "épée", "epeé"),
}


def extract_ftl_uuid(url: str) -> str | None:
    """Extract the 32-char hex UUID from any FTL URL pattern."""
    m = _FTL_RESULTS_URL_RE.search(url or "")
    return m.group(1).upper() if m else None


def fetch_ftl_event_metadata(url: str, http_client) -> dict | None:
    """Fetch an FTL `/events/results/{UUID}` page and extract:

    - `date`: ISO date string `YYYY-MM-DD` of the event.
    - `weapon`: 'EPEE' / 'FOIL' / 'SABRE' if recognised in the title.
    - `title`: the page <title> raw text.

    Returns None on fetch failure / 404 / no recognisable date. Caller is
    responsible for closing `http_client`. The function only does GET — no
    auth handshake — so the caller must pass an already-authed client.
    """
    import datetime
    uuid = extract_ftl_uuid(url)
    if not uuid:
        return None
    page_url = f"https://www.fencingtimelive.com/events/results/{uuid}"
    try:
        r = http_client.get(page_url)
    except Exception:
        return None
    if r.status_code != 200:
        return None

    title_m = re.search(r"<title>([^<]+)</title>", r.text)
    title = title_m.group(1).strip() if title_m else ""

    date_m = _FTL_DATE_RE.search(r.text)
    if not date_m:
        return None
    month_name, day, year = date_m.groups()
    try:
        d = datetime.datetime.strptime(
            f"{month_name} {day} {year}", "%B %d %Y"
        ).date()
    except ValueError:
        return None

    title_low = title.lower()
    weapon: str | None = None
    for w, hints in _FTL_WEAPON_HINTS.items():
        if any(h in title_low for h in hints):
            weapon = w
            break

    return {
        "date": d.isoformat(),
        "weapon": weapon,
        "title": title,
    }


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
