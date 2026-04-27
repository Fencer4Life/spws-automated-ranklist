"""
Discover and populate tournament result URLs from event pages (ADR-029).

Supports three platforms:
- FencingTimeLive (FTL): scrape event schedule HTML
- Engarde: XML API for competition listing
- 4Fence: deterministic URL generation from parameters

Usage:
    python -m python.tools.populate_tournament_urls --event-code PP4-2025-2026 [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET

from python.scrapers.base import detect_platform
from python.tools.scrape_ftl_event_urls import (
    parse_event_schedule,
    parse_tournament_name,
    build_result_url,
)


# ── FTL Discovery ────────────────────────────────────────────────────────


def _discover_ftl(html: str) -> list[dict]:
    """Discover tournament URLs from FTL event schedule HTML."""
    tournaments = parse_event_schedule(html)
    results = []
    for t in tournaments:
        parsed = parse_tournament_name(t["name"])
        if parsed is None:
            continue
        entries = parsed if isinstance(parsed, list) else [parsed]
        for weapon, gender, category in entries:
            results.append({
                "weapon": weapon,
                "gender": gender,
                "category": category,
                "url": build_result_url(t["uuid"]),
                "source_name": t["name"],
            })
    return results


# ── Engarde Discovery (XML API) ──────────────────────────────────────────

ENGARDE_WEAPON_MAP = {"e": "EPEE", "f": "FOIL", "s": "SABRE"}
ENGARDE_GENDER_MAP = {"m": "M", "f": "F"}
ENGARDE_BASE = "https://engarde-service.com/competition"


def _parse_engarde_category(slug: str, titre: str) -> list[str]:
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


def _parse_engarde_gender(sexe: str, titre: str) -> str | None:
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


def parse_engarde_competitions_xml(
    xml_text: str, org: str, event: str
) -> list[dict]:
    """Parse Engarde getCompeForDisplay XML into tournament URL list.

    Filters out TABLE/DE entries (t_ prefix in slug) and non-individual events.
    """
    root = ET.fromstring(xml_text)
    results = []
    for comp in root.findall("comp"):
        slug = comp.get("compe", "")
        # Skip TABLE/DE sub-events
        if slug.startswith("t_"):
            continue
        # Skip non-individual
        if comp.get("estindividuelle") == "0":
            continue
        # Skip non-completed (Poules, empty, etc.)
        etat = comp.get("etat", "")
        if etat != "completed":
            continue

        arme = comp.get("arme", "")
        sexe = comp.get("sexe", "")
        titre = ""
        titre_el = comp.find("titre")
        if titre_el is not None and titre_el.text:
            titre = titre_el.text

        weapon = ENGARDE_WEAPON_MAP.get(arme)
        gender = _parse_engarde_gender(sexe, titre)
        if not weapon or not gender:
            continue

        categories = _parse_engarde_category(slug, titre)
        if not categories:
            continue

        url = f"{ENGARDE_BASE}/{org}/{event}/{slug}/clasfinal.htm"
        for cat in categories:
            results.append({
                "weapon": weapon,
                "gender": gender,
                "category": cat,
                "url": url,
                "source_name": titre,
                "slug": slug,
            })

    return results


# ── 4Fence Discovery (deterministic generation) ─────────────────────────

FOURFENCE_WEAPON_MAP = {
    "EPEE": "SP",
    "FOIL": "F",
    "SABRE": "SC",
}
FOURFENCE_CATEGORY_MAP = {
    "V0": "5",
    "V1": "6",
    "V2": "7",
    "V3": "8",
    "V4": "9",
}


def discover_dartagnan_tournament_urls(
    index_html: str, index_url: str
) -> list[dict]:
    """Discover Dartagnan per-category rankings URLs from an event index page.

    Returns [{weapon, gender, category, url, source_name}, ...].
    Combined rounds (V1/V2 Runde, etc.) are skipped by the underlying parser.
    """
    from python.scrapers.dartagnan import parse_dartagnan_event_index

    competitions = parse_dartagnan_event_index(index_html, index_url)
    results = []
    for c in competitions:
        results.append({
            "weapon": c["weapon"],
            "gender": c["gender"],
            "category": c["category"],
            "url": c["rankings_url"],
            "source_name": f"{c['weapon']} {c['gender']} {c['category']} ({c['id']})",
        })
    return results


def generate_fourfence_urls(base_url: str) -> list[dict]:
    """Generate all possible 4Fence tournament result URLs from base path.

    4Fence URLs are deterministic: base + query params for weapon/gender/category.
    """
    # Ensure base URL ends with /
    if not base_url.endswith("/"):
        base_url += "/"

    results = []
    for weapon, w_code in FOURFENCE_WEAPON_MAP.items():
        for gender in ("M", "F"):
            for category, c_code in FOURFENCE_CATEGORY_MAP.items():
                url = f"{base_url}index.php?a={w_code}&s={gender}&c={c_code}&f=clafinale"
                results.append({
                    "weapon": weapon,
                    "gender": gender,
                    "category": category,
                    "url": url,
                    "source_name": f"{weapon} {gender} {category}",
                })
    return results


# ── URL matching ─────────────────────────────────────────────────────────


def match_urls_to_tournaments(
    discovered: list[dict],
    tournaments: list[dict],
) -> tuple[list[dict], list[dict]]:
    """Match discovered URLs to DB tournament records by weapon+gender+category.

    Returns (matched, unmatched) where matched includes id_tournament + url.
    """
    # Build lookup: (weapon, gender, category) → tournament
    lookup: dict[tuple, dict] = {}
    for t in tournaments:
        key = (t["enum_weapon"], t["enum_gender"], t["enum_age_category"])
        lookup[key] = t

    matched = []
    unmatched = []
    for d in discovered:
        key = (d["weapon"], d["gender"], d["category"])
        if key in lookup:
            t = lookup[key]
            matched.append({
                "id_tournament": t["id_tournament"],
                "url": d["url"],
                "weapon": d["weapon"],
                "gender": d["gender"],
                "category": d["category"],
                "source_name": d.get("source_name", ""),
                "existing_url": t.get("url_results"),
            })
        else:
            unmatched.append(d)

    return matched, unmatched


# ── Top-level discovery dispatcher ───────────────────────────────────────


def discover_tournament_urls_from_html(
    html_or_xml: str, platform: str, **kwargs
) -> list[dict]:
    """Discover tournament URLs from page content (for testing without HTTP).

    Args:
        html_or_xml: Page content (HTML for FTL, XML for Engarde)
        platform: 'ftl', 'engarde', or 'fourfence'
        **kwargs: Platform-specific args (org/event for Engarde, base_url for 4Fence)
    """
    if platform == "ftl":
        return _discover_ftl(html_or_xml)
    elif platform == "engarde":
        return parse_engarde_competitions_xml(
            html_or_xml,
            org=kwargs.get("org", ""),
            event=kwargs.get("event", ""),
        )
    elif platform == "fourfence":
        return generate_fourfence_urls(kwargs.get("base_url", html_or_xml))
    elif platform == "dartagnan":
        return discover_dartagnan_tournament_urls(
            html_or_xml, index_url=kwargs.get("index_url", "")
        )
    else:
        raise ValueError(f"Unknown platform: {platform}")


def discover_tournament_urls_for_event(event: dict) -> list[dict]:
    """Iterate event-level URL slots (ADR-040) and merge per-(weapon,gender,
    category) results. First occurrence wins; collisions logged as warnings.

    `event` is a dict with keys ``url_event`` and ``url_event_2..5`` (any of
    which may be NULL/empty). Calls ``discover_tournament_urls`` once per
    non-empty slot, in slot order.
    """
    slots = [
        event.get("url_event"),
        event.get("url_event_2"),
        event.get("url_event_3"),
        event.get("url_event_4"),
        event.get("url_event_5"),
    ]
    seen: set[tuple[str, str, str]] = set()
    merged: list[dict] = []
    for slot_url in slots:
        if slot_url is None:
            continue
        url = str(slot_url).strip()
        if not url:
            continue
        results = discover_tournament_urls(url)
        for r in results:
            key = (r.get("weapon"), r.get("gender"), r.get("category"))
            if key in seen:
                print(
                    f"WARN: duplicate (weapon,gender,category)={key} from {url} "
                    f"— keeping first occurrence",
                    file=sys.stderr,
                )
                continue
            seen.add(key)
            merged.append(r)
    return merged


def discover_tournament_urls(event_url: str) -> list[dict]:
    """Fetch event page and discover tournament result URLs.

    Requires network access — use discover_tournament_urls_from_html for testing.
    """
    import httpx

    platform = detect_platform(event_url)

    if platform == "ftl":
        from python.scrapers.ftl_auth import get_authed_ftl_client
        with get_authed_ftl_client() as client:
            resp = client.get(event_url)
        resp.raise_for_status()
        return _discover_ftl(resp.text)

    elif platform == "engarde":
        # Extract org and event from URL: /tournament/{org}/{event}
        parts = event_url.rstrip("/").split("/")
        org = parts[-2]
        event = parts[-1]
        api_url = (
            f"https://engarde-service.com/prog/getCompeForDisplay.php"
            f"?option=competition&organism={org}&event={event}"
            f"&lang=en&nrows=50&page=no&orderby=competitions_tournament"
            f"&order=ASC&large=E&show_test=0&cache=1"
        )
        resp = httpx.get(api_url, timeout=15)
        resp.raise_for_status()
        return parse_engarde_competitions_xml(resp.text, org=org, event=event)

    elif platform == "fourfence":
        return generate_fourfence_urls(event_url)

    elif platform == "dartagnan":
        resp = httpx.get(event_url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return discover_dartagnan_tournament_urls(resp.text, index_url=event_url)

    else:
        raise ValueError(f"Unsupported platform: {event_url}")


# ── CLI ──────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="Populate tournament result URLs from event page"
    )
    parser.add_argument("--event-code", required=True, help="Event code (e.g., PP4-2025-2026)")
    parser.add_argument("--supabase-url", default=None, help="Supabase URL")
    parser.add_argument("--supabase-key", default=None, help="Supabase service role key")
    parser.add_argument("--dry-run", action="store_true", help="Preview only, don't update DB")
    args = parser.parse_args()

    import os
    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
    supabase_key = args.supabase_key or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

    import httpx

    # 1. Fetch event from DB (all 5 URL slots — ADR-040)
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}
    resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_event?txt_code=eq.{args.event_code}"
        f"&select=id_event,txt_code,url_event,url_event_2,url_event_3,url_event_4,url_event_5",
        headers=headers,
        timeout=10,
    )
    resp.raise_for_status()
    events = resp.json()
    if not events:
        print(f"ERROR: Event '{args.event_code}' not found", file=sys.stderr)
        sys.exit(1)
    event = events[0]
    slot_urls = [
        event.get(k) for k in ("url_event", "url_event_2", "url_event_3", "url_event_4", "url_event_5")
        if event.get(k)
    ]
    if not slot_urls:
        print(f"ERROR: Event '{args.event_code}' has no result-platform URLs", file=sys.stderr)
        sys.exit(1)

    print(
        f"Event: {event['txt_code']} → {len(slot_urls)} URL slot(s): "
        + ", ".join(slot_urls),
        file=sys.stderr,
    )

    # 2. Discover tournament URLs across all slots
    discovered = discover_tournament_urls_for_event(event)
    print(f"Discovered {len(discovered)} tournament URLs", file=sys.stderr)

    # 3. Fetch tournaments from DB
    resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_tournament?id_event=eq.{event['id_event']}"
        f"&select=id_tournament,txt_code,enum_weapon,enum_gender,enum_age_category,url_results",
        headers=headers,
        timeout=10,
    )
    resp.raise_for_status()
    tournaments = resp.json()
    print(f"DB has {len(tournaments)} tournaments for this event", file=sys.stderr)

    # 4. Match
    matched, unmatched = match_urls_to_tournaments(discovered, tournaments)

    # 5. Report
    new_urls = [m for m in matched if not m.get("existing_url")]
    existing = [m for m in matched if m.get("existing_url")]

    print(f"\nResults:", file=sys.stderr)
    print(f"  Matched: {len(matched)} ({len(new_urls)} new, {len(existing)} already had URL)", file=sys.stderr)
    print(f"  Unmatched (no DB tournament): {len(unmatched)}", file=sys.stderr)

    for m in new_urls:
        print(f"  NEW: {m['weapon']} {m['gender']} {m['category']} → {m['url']}", file=sys.stderr)
    for m in existing:
        print(f"  SKIP: {m['weapon']} {m['gender']} {m['category']} (already has URL)", file=sys.stderr)
    for u in unmatched:
        print(f"  MISS: {u['weapon']} {u['gender']} {u['category']} — {u.get('source_name', '')}", file=sys.stderr)

    if args.dry_run:
        print(f"\nDRY RUN — no DB updates", file=sys.stderr)
        return

    # 6. Update DB
    updated = 0
    for m in new_urls:
        resp = httpx.patch(
            f"{supabase_url}/rest/v1/tbl_tournament?id_tournament=eq.{m['id_tournament']}",
            json={"url_results": m["url"]},
            headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"},
            timeout=10,
        )
        if resp.status_code in (200, 204):
            updated += 1
        else:
            print(f"  FAIL: {m['weapon']} {m['gender']} {m['category']} — HTTP {resp.status_code}", file=sys.stderr)

    print(f"\nUpdated {updated}/{len(new_urls)} tournament URLs", file=sys.stderr)


if __name__ == "__main__":
    main()
