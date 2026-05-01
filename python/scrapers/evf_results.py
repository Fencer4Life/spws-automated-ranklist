"""
EVF Results API Scraper — api.veteransfencing.eu (ADR-028)

Fetches full individual results from the EVF ranking system API.
Returns structured data: rank, name, country, DOB, points per competition.

API pattern discovered:
  1. GET nonce from https://www.veteransfencing.eu/fencing/results/
  2. POST /fe/events → list of events (id, name, location, date)
  3. POST /fe/events/competitions → competitions for event (weapon, category)
  4. POST /fe/results/{comp_id} → individual results with fencer details

All POST calls require: {"path": "...", "nonce": "...", "model": ...}
Results model: {"offset": 0, "pagesize": 10000, "filter": "", "sort": "pnc"}
"""

from __future__ import annotations

import re
import time
from io import BytesIO

import httpx

# EVF category/weapon mapping
WEAPON_MAP = {1: "FOIL", 2: "EPEE", 3: "SABRE"}
WEAPON_ABBR_MAP = {"MF": ("FOIL", "M"), "ME": ("EPEE", "M"), "MS": ("SABRE", "M"),
                   "WF": ("FOIL", "F"), "WE": ("EPEE", "F"), "WS": ("SABRE", "F")}
CATEGORY_MAP = {1: "V1", 2: "V2", 3: "V3", 4: "V4"}

EVF_PAGE_URL = "https://www.veteransfencing.eu/fencing/results/"
EVF_API_BASE = "https://api.veteransfencing.eu/fe"
RESULTS_MODEL = {"offset": 0, "pagesize": 10000, "filter": "", "sort": "pnc"}


class EvfApiClient:
    """Client for the EVF ranking API."""

    def __init__(self, request_delay: float = 0.5):
        self._client = httpx.Client(follow_redirects=True, timeout=60)
        self._nonce: str = ""
        self._headers: dict = {}
        self._delay = request_delay

    def connect(self) -> None:
        """Fetch the results page to get nonce, then establish API session."""
        page = self._client.get(EVF_PAGE_URL)
        m = re.search(r'"nonce":"([^"]+)"', page.text)
        if not m:
            raise RuntimeError("Could not extract EVF nonce from results page")
        self._nonce = m.group(1)
        self._headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Origin": "https://www.veteransfencing.eu",
            "Referer": "https://www.veteransfencing.eu/fencing/results/",
        }
        # Establish Laravel session
        self._post("/events", model="")

    def _post(self, path: str, model=None) -> dict:
        """POST to the EVF API with nonce and model."""
        body = {"path": path, "nonce": self._nonce, "model": model if model is not None else ""}
        time.sleep(self._delay)
        resp = self._client.post(
            f"{EVF_API_BASE}{path}",
            json=body,
            headers=self._headers,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"EVF API error ({resp.status_code}): {resp.text[:200]}")
        return resp.json()

    def get_events(self) -> list[dict]:
        """Get all events from the API."""
        data = self._post("/events", model="")
        return data.get("data", {}).get("list", [])

    def get_competitions(self, event_id: int) -> list[dict]:
        """Get competitions (weapon+category combos) for an event."""
        data = self._post("/events/competitions", model={"id": event_id})
        return data.get("data", {}).get("list", [])

    def get_results(self, competition_id: int) -> list[dict]:
        """Get full individual results for a competition."""
        data = self._post(f"/results/{competition_id}", model=RESULTS_MODEL)
        return data.get("data", {}).get("list", [])

    def discover_season_events(
        self,
        season_start: str,
        season_end: str,
        calendar_events: list[dict] | None = None,
        scan_range: tuple[int, int] = (26, 120),
    ) -> list[dict]:
        """Discover EVF events for a season by scanning API IDs.

        Scans event IDs via /events/competitions, filters by date,
        and cross-references with calendar events by date proximity.

        Returns enriched list:
            [{evf_id, name, date, location, weapons, competitions, total_fencers, is_team, ...}]
        """
        from datetime import datetime as dt

        found: list[dict] = []

        for eid in range(scan_range[0], scan_range[1]):
            try:
                comps = self.get_competitions(eid)
            except RuntimeError:
                continue
            if not comps:
                continue

            starts = comps[0].get("starts", "")
            if not starts or starts < season_start or starts > season_end:
                continue

            total = sum(c.get("total", 0) for c in comps)
            weapons_ids = set(c.get("weaponId") for c in comps)
            weapons = [WEAPON_MAP.get(w, "?") for w in sorted(weapons_ids) if w in WEAPON_MAP]
            cats = set(c.get("categoryId") for c in comps)
            categories = [CATEGORY_MAP.get(c, "?") for c in sorted(cats) if c in CATEGORY_MAP]

            # Cross-reference with calendar by date (+-3 days)
            name = f"Event {eid}"
            location = ""
            country = ""
            url = ""
            fee = None
            fee_currency = ""
            is_team = False

            if calendar_events:
                for ce in calendar_events:
                    ce_date = ce.get("dt_start", "")
                    if not ce_date:
                        continue
                    try:
                        d1 = dt.strptime(starts, "%Y-%m-%d")
                        d2 = dt.strptime(ce_date, "%Y-%m-%d")
                        if abs((d1 - d2).days) <= 3:
                            name = ce["name"]
                            location = ce.get("location", "")
                            country = ce.get("country", "")
                            url = ce.get("url", "")
                            fee = ce.get("fee")
                            fee_currency = ce.get("fee_currency", "")
                            is_team = ce.get("is_team", False)
                            break
                    except (ValueError, TypeError):
                        continue

            found.append({
                "evf_id": eid,
                "name": name,
                "date": starts,
                "location": location,
                "country": country,
                "weapons": weapons,
                "categories": categories,
                "competitions": len(comps),
                "total_fencers": total,
                "is_team": is_team,
                "url": url,
                "fee": fee,
                "fee_currency": fee_currency,
                "has_results": total > 0,
            })

        return sorted(found, key=lambda e: e["date"])

    def close(self) -> None:
        self._client.close()


def evf_code_to_category(code: str) -> tuple[str, str, str]:
    """Convert EVF result code to (weapon, gender, category).

    Examples:
        EHV2 → (EPEE, M, V2)
        SDV3 → (SABRE, F, V3)
        FHV1 → (FOIL, M, V1)
    """
    if len(code) < 4:
        raise ValueError(f"Invalid EVF code: {code}")
    _WEAPON_MAP = {"E": "EPEE", "F": "FOIL", "S": "SABRE"}
    _GENDER_MAP = {"H": "M", "D": "F"}
    _CAT_MAP = {"1": "V1", "2": "V2", "3": "V3", "4": "V4"}

    weapon = _WEAPON_MAP.get(code[0].upper())
    gender = _GENDER_MAP.get(code[1].upper())
    category = _CAT_MAP.get(code[3] if len(code) > 3 else code[-1])
    if not weapon or not gender or not category:
        raise ValueError(f"Cannot map EVF code: {code}")
    return weapon, gender, category


def parse_evf_result_pdf(pdf_bytes: bytes) -> list[dict]:
    """Extract final classification from Engarde-generated EVF result PDF.

    Legacy fallback — prefer get_results() API method.

    Returns list of dicts matching scraper contract:
        [{"fencer_name": "SURNAME FirstName", "place": 1, "country": "POL"}, ...]
    """
    try:
        import pypdf
    except ImportError:
        return []

    try:
        reader = pypdf.PdfReader(BytesIO(pdf_bytes))
    except Exception:
        return []

    results: list[dict] = []
    seen: set[tuple[int, str]] = set()

    for page in reader.pages:
        try:
            text = page.extract_text()
        except Exception:
            continue
        if not text:
            continue
        if "lassement" not in text.lower() and "general" not in text.lower():
            continue

        lines = text.split("\n")
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            m = re.match(r"^(\d{1,3})\s*(.+)", line)
            if m:
                rank = int(m.group(1))
                name_part = m.group(2).strip()
                country = ""
                if i + 1 < len(lines):
                    cm = re.match(r"^([A-Z]{3})", lines[i + 1].strip())
                    if cm:
                        country = cm.group(1)
                        i += 1
                name_part = re.sub(r"\s+", " ", name_part).strip()
                key = (rank, name_part)
                if key not in seen and country:
                    seen.add(key)
                    results.append({"fencer_name": name_part, "place": rank, "country": country})
            i += 1

    results.sort(key=lambda r: r["place"])
    return results


def scrape_event_results(
    event_id: int,
    client: EvfApiClient | None = None,
    country_filter: str | None = None,
) -> list[dict]:
    """Scrape all competition results for an EVF event.

    Args:
        event_id: EVF event ID (e.g. 85 for Naples 2026)
        client: Optional pre-connected EvfApiClient
        country_filter: If set, only return fencers from this country (e.g. "POL")

    Returns list of dicts matching scraper contract:
        [{"fencer_name": "SURNAME FirstName", "place": 1, "country": "POL",
          "weapon": "EPEE", "gender": "M", "category": "V2",
          "dob": "1970-01-01", "evf_points": 158.6}, ...]
    """
    own_client = client is None
    if own_client:
        client = EvfApiClient()
        client.connect()

    try:
        competitions = client.get_competitions(event_id)
        all_results: list[dict] = []

        for comp in competitions:
            comp_id = comp["id"]
            weapon = WEAPON_MAP.get(comp.get("weaponId"), "?")
            category = CATEGORY_MAP.get(comp.get("categoryId"), "?")

            results = client.get_results(comp_id)

            for r in results:
                country = r.get("country_abbr", "")
                if country_filter and country != country_filter:
                    continue

                # Detect gender from weapon_abbr (ME=Men's Epee, WF=Women's Foil)
                weapon_abbr = r.get("weapon_abbr", "")
                if weapon_abbr in WEAPON_ABBR_MAP:
                    weapon, gender = WEAPON_ABBR_MAP[weapon_abbr]
                else:
                    gender = "M" if weapon_abbr.startswith("M") else "F"

                surname = r.get("fencer_surname", "")
                first_name = r.get("fencer_firstname", "")
                fencer_name = f"{surname} {first_name}".strip()

                all_results.append({
                    "fencer_name": fencer_name,
                    "place": int(r.get("place", 0)),
                    "country": country,
                    "weapon": weapon,
                    "gender": gender,
                    "category": category,
                    "dob": r.get("fencer_dob", ""),
                    "evf_points": float(r.get("total_points", 0)),
                    "competition_id": comp_id,
                })

        return all_results

    finally:
        if own_client:
            client.close()


def find_event_by_name(events: list[dict], name_substr: str) -> dict | None:
    """Find an event by substring match on name."""
    for e in events:
        if name_substr.lower() in e.get("name", "").lower():
            return e
    return None


def find_event_by_date(events: list[dict], date: str) -> dict | None:
    """Find an event by date (YYYY-MM-DD)."""
    for e in events:
        if e.get("opens", "")[:10] == date:
            return e
    return None


# =============================================================================
# IR factory (Phase 1 / part 2 — ADR-050)
#
# parse_results is a pure function on the raw EVF API response (a list of
# result dicts from /results/{comp_id}). No HTTP, no client lifecycle.
# The orchestrator calls EvfApiClient.get_results(comp_id) and passes the
# resulting list to parse_results, along with the per-competition metadata
# (weapon / gender / category / date) it learned from /events/competitions.
# =============================================================================

def parse_results(
    raw_results: list[dict],
    weapon: str | None = None,
    gender: str | None = None,
    category_hint: str | None = None,
    parsed_date=None,
    source_url: str | None = None,
):
    """Parse an EVF results-list response into ParsedTournament.

    Args:
        raw_results: list of result dicts (e.g. from EvfApiClient.get_results).
            Each row is expected to carry fencer_surname, fencer_firstname,
            country_abbr, place, fencer_dob (ISO string or empty),
            total_points (numeric), and optionally weapon_abbr.
        weapon, gender, category_hint, parsed_date, source_url: metadata
            supplied by the orchestrator from the parent /events/competitions
            response.

    EVF rows have no per-row stable ID — uses make_synthetic_id with the
    1-based row index.
    """
    from datetime import datetime as _dt

    from python.pipeline.ir import (
        ParsedResult, ParsedTournament, SourceKind, make_synthetic_id,
    )

    parsed: list[ParsedResult] = []
    for i, r in enumerate(raw_results, start=1):
        surname = r.get("fencer_surname", "")
        first_name = r.get("fencer_firstname", "")
        fencer_name = f"{surname} {first_name}".strip()

        place = int(r.get("place", 0))
        country = r.get("country_abbr") or None

        dob_str = (r.get("fencer_dob") or "").strip()
        if dob_str:
            try:
                bd = _dt.strptime(dob_str, "%Y-%m-%d").date()
                birth_date, birth_year = bd, bd.year
            except ValueError:
                birth_date, birth_year = None, None
        else:
            birth_date, birth_year = None, None

        parsed.append(ParsedResult(
            source_row_id=make_synthetic_id(
                SourceKind.EVF_API,
                row_index=i,
                place=place,
                name=fencer_name,
            ),
            fencer_name=fencer_name,
            place=place,
            fencer_country=country,
            birth_date=birth_date,
            birth_year=birth_year,
        ))

    return ParsedTournament(
        source_kind=SourceKind.EVF_API,
        results=parsed,
        raw_pool_size=len(parsed),
        weapon=weapon,
        gender=gender,
        category_hint=category_hint,
        parsed_date=parsed_date,
        source_url=source_url,
    )
