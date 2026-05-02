"""
Scrape FencingTimeLive event schedule pages to extract tournament result URLs.

Parses event schedule HTML to discover individual tournament links, maps them
to our tournament code format (e.g., PPW2-V2-M-EPEE-2025-2026), and outputs
SQL UPDATE statements for tbl_tournament.url_results.

Usage:
    python -m python.tools.scrape_ftl_event_urls
"""

from __future__ import annotations

import re
import sys

from bs4 import BeautifulSoup

# ── Tournament name → DB enum mappings (Polish + English) ──────────────────

WEAPON_MAP: dict[str, str] = {
    # Polish
    "FLORET": "FOIL",
    "SZABLA": "SABRE",
    "SZPADA": "EPEE",
    # English
    "FOIL": "FOIL",
    "SABRE": "SABRE",
    "SABER": "SABRE",
    "EPEE": "EPEE",
    "ÉPÉE": "EPEE",
}

GENDER_FEMALE = re.compile(r"KOBIET[AYE]?|WOMEN'?S?", re.IGNORECASE)
GENDER_MALE = re.compile(r"MĘŻCZYZN[I]?|MEN'?S?", re.IGNORECASE)
MIKST_PATTERN = re.compile(r"\bMIKS(?:T)?\b|\bMIXED\b", re.IGNORECASE)
# Skip DE (Direct Elimination) sub-events, amateur, junior/cadet/U-age events.
# NOT skipping "Senior" — for some FTL events Senior = V0 (heuristic mapping
# below). Per user feedback 2026-05-02: case-specific, treat as V0.
SKIP_PATTERNS = re.compile(
    r"\bDE\b|AMATOR|TURNIEJ\b.*AMATOR|ELIMINACJ|"
    r"\bJUNIOR\b|\bCADET\b|\bU\d+\b",
    re.IGNORECASE,
)
SENIOR_PATTERN = re.compile(r"\bSENIOR\b", re.IGNORECASE)

# FTL English veteran-category convention: "Vet-50" → V2, "Vet-60" → V3,
# "Vet-70" → V4, "Vet-40" → V1; bare "Vet" without number = combined-pool
# (all V-cats present; Stage 4 splits by per-fencer marker).
VET_AGE_RE = re.compile(r"\bVet[-\s]?(\d{2})\b", re.IGNORECASE)
VET_BARE_RE = re.compile(r"\bVet\b", re.IGNORECASE)


def _vet_age_to_vcat(age_str: str) -> str | None:
    """Map FTL veteran age threshold to SPWS V-cat enum.

    "40" → V1, "50" → V2, "60" → V3, "70"/"80"+ → V4. Returns None if the
    threshold doesn't fit any known bucket.
    """
    try:
        n = int(age_str)
    except ValueError:
        return None
    if 40 <= n < 50:
        return "V1"
    if 50 <= n < 60:
        return "V2"
    if 60 <= n < 70:
        return "V3"
    if n >= 70:
        return "V4"
    return None

FTL_RESULTS_BASE = "https://www.fencingtimelive.com/events/results"


# ── Parsing functions ──────────────────────────────────────────────────────


def parse_event_schedule(html: str, *, with_skips: bool = False):
    """Extract tournament links from an FTL event schedule page.

    Default mode (`with_skips=False`): returns list of dicts ``{uuid, name}``
    for brackets that pass the skip filters (Mixed/MIKST, DE, amateur, etc.).
    Backward-compatible with existing callers (`scrape_all`, etc.).

    With `with_skips=True`: returns ``(kept, skipped)`` where each entry in
    `skipped` is ``{uuid, name, reason}``. Used by Phase 5 runner so the
    operator can verify pool-round detection in the staging summary.
    """
    soup = BeautifulSoup(html, "html.parser")
    links = soup.find_all("a", href=lambda h: h and "/events/view/" in h)

    kept: list[dict[str, str]] = []
    skipped: list[dict[str, str]] = []
    for link in links:
        name = link.get_text(strip=True)
        uuid = link["href"].split("/events/view/")[-1]
        if MIKST_PATTERN.search(name):
            skipped.append({"uuid": uuid, "name": name,
                            "reason": "Mixed/MIKST (pool round)"})
            continue
        if SKIP_PATTERNS.search(name):
            skipped.append({"uuid": uuid, "name": name,
                            "reason": "DE / amateur / junior / U-age skip pattern"})
            continue
        kept.append({"uuid": uuid, "name": name})
    if with_skips:
        return kept, skipped
    return kept


def parse_tournament_name(
    name: str,
) -> tuple[str, str, str] | list[tuple[str, str, str]] | None:
    """Parse a tournament name (Polish or English) into (weapon, gender, category).

    Returns:
        - tuple (weapon, gender, category) for single-category tournaments
        - list of tuples for combined categories ("Category 3 and 4")
        - None for MIKST/mixed, DE sub-events, or unparseable names
    """
    upper = name.upper()

    # Skip MIKST
    if MIKST_PATTERN.search(upper):
        return None

    # Skip DE sub-events
    if SKIP_PATTERNS.search(name):
        return None

    # Extract weapon (try longest match first to avoid "EPEE" matching inside "ÉPÉE")
    weapon = None
    for keyword, db_enum in sorted(WEAPON_MAP.items(), key=lambda x: -len(x[0])):
        if keyword in upper:
            weapon = db_enum
            break
    if weapon is None:
        return None

    # Extract gender — check WOMEN before MEN to avoid "MEN" matching inside "WOMEN"
    if GENDER_FEMALE.search(name):
        gender = "F"
    elif GENDER_MALE.search(name):
        gender = "M"
    else:
        return None

    # Check for combined categories: "Category 3 and 4" or "1+2+3 + 4"
    combined_match = re.search(
        r"(?:Category|kat\.?)\s+(\d)\s+and\s+(\d)", name, re.IGNORECASE
    )
    if combined_match:
        cats = [f"V{combined_match.group(1)}", f"V{combined_match.group(2)}"]
        return [(weapon, gender, c) for c in cats]

    # Check for "v0v1v2" style combined categories (e.g., "FLORET MĘŻCZYZN v0v1v2")
    v_combined = re.findall(r"v([0-4])", name, re.IGNORECASE)
    if len(v_combined) >= 2:
        return [(weapon, gender, f"V{d}") for d in v_combined]

    # Single v-prefixed digit (e.g., "SZPADA MĘŻCZYZN v2")
    if len(v_combined) == 1:
        return (weapon, gender, f"V{v_combined[0]}")

    # FTL English veteran convention: "Vet-50" / "Vet-60" / "Vet-70" / "Vet-40"
    vet_age_match = VET_AGE_RE.search(name)
    if vet_age_match:
        vcat = _vet_age_to_vcat(vet_age_match.group(1))
        if vcat:
            return (weapon, gender, vcat)

    # "Senior" → V0 (per user feedback 2026-05-02: case-specific, this dataset
    # uses Senior as the under-40 / V0 bucket).
    if SENIOR_PATTERN.search(name):
        return (weapon, gender, "V0")

    # Bare "Vet [Gender] [Weapon]" (no age suffix) = V1, the base veteran
    # category (40-49). Pool rounds are emitted as "Mixed [Weapon]" not
    # "Vet [Gender]…", and the Mixed branch is skipped above via MIKST_PATTERN.
    if VET_BARE_RE.search(name):
        return (weapon, gender, "V1")

    # Extract category digit (0-4) as standalone word
    # Handle letter "O" as digit 0 (common FTL typo: "MĘŻCZYZN O WETERANI")
    cat_match = re.search(r"\b([0-4])\b", name)
    if cat_match:
        category = f"V{cat_match.group(1)}"
    elif re.search(r"\b[Oo]\b", name) and not re.search(r"\b[0-4]\b", name):
        # Standalone letter O likely means 0
        category = "V0"
    else:
        # No category specified — weapon + gender only → all V0-V4
        return [(weapon, gender, f"V{i}") for i in range(5)]

    return (weapon, gender, category)


def build_tournament_code(
    event_prefix: str, weapon: str, gender: str, category: str, season: str
) -> str:
    """Build tournament code: PPW2-V2-M-EPEE-2025-2026."""
    return f"{event_prefix}-{category}-{gender}-{weapon}-{season}"


def build_result_url(uuid: str) -> str:
    """Build FTL results URL from UUID."""
    return f"{FTL_RESULTS_BASE}/{uuid}"


# ── CLI: scrape live pages and output SQL ──────────────────────────────────

EVENT_URLS: dict[str, str] = {
    "PPW2": "https://fencingtimelive.com/tournaments/eventSchedule/BC4FAB2F4A5E466DAA8FC46EB73E50F6",
    "PPW3": "https://fencingtimelive.com/tournaments/eventSchedule/D099355BC4334343949BD91172023B49",
    "PPW4": "https://fencingtimelive.com/tournaments/eventSchedule/D586C1250E8C41D3BB9B9E5772CB998F",
}

SEASON = "2025-2026"


def scrape_all() -> list[dict[str, str]]:
    """Fetch all event schedule pages and return tournament URL mappings."""
    from python.scrapers.ftl_auth import get_authed_ftl_client

    mappings = []
    with get_authed_ftl_client() as client:
        for event_prefix, url in EVENT_URLS.items():
            print(f"Fetching {event_prefix}: {url}", file=sys.stderr)
            resp = client.get(url)
            resp.raise_for_status()

            tournaments = parse_event_schedule(resp.text)
            for t in tournaments:
                parsed = parse_tournament_name(t["name"])
                if parsed is None:
                    print(f"  SKIP: {t['name']}", file=sys.stderr)
                    continue
                # Handle combined categories (list of tuples) and single (tuple)
                entries = parsed if isinstance(parsed, list) else [parsed]
                for weapon, gender, category in entries:
                    code = build_tournament_code(event_prefix, weapon, gender, category, SEASON)
                    result_url = build_result_url(t["uuid"])
                    mappings.append({
                        "tournament_code": code,
                        "url_results": result_url,
                        "ftl_name": t["name"],
                    })
                    print(f"  {code} → {t['uuid']}", file=sys.stderr)

    return mappings


def generate_sql(mappings: list[dict[str, str]]) -> str:
    """Generate SQL UPDATE statements for tournament URLs."""
    lines = [
        "-- Phase 3: Populate tournament result URLs (scraped from FTL event schedule pages)",
        "-- PPW2/PPW3/PPW4 only; PPW1 (Opole) has no FTL event page.",
    ]
    for m in sorted(mappings, key=lambda x: x["tournament_code"]):
        lines.append(
            f"UPDATE tbl_tournament SET url_results = '{m['url_results']}'\n"
            f"WHERE txt_code = '{m['tournament_code']}';"
        )
    return "\n".join(lines)


if __name__ == "__main__":
    mappings = scrape_all()
    print(f"\n-- {len(mappings)} tournament URLs scraped\n", file=sys.stderr)
    print(generate_sql(mappings))
