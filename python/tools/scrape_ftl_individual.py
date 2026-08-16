"""Scrape championship INDIVIDUAL results for a country from an FTL eventSchedule.

Companion to :mod:`python.tools.scrape_team_events`. That tool takes the team
relays from a championship; this one takes the individual tournaments of the
same championship — the World (MSW) and European (MEW) events that sit at the
top of the provenance ladder and are absent from the EVF ranking API, which
only covers EVF-sanctioned circuit events.

Each result is tagged with its provenance tier (``WORLD`` / ``EUROPEAN``,
falling back to field-depth bands) and resolved to ``tbl_fencer`` through the
repo's fuzzy matcher, so it lands in the same shape as
:mod:`python.tools.scrape_evf_individual`.

Usage::

    set -a; source .env; set +a
    python -m python.tools.scrape_ftl_individual \\
        --schedule D7E898476AE94A41BBB553FCF26A9AEF \\
        --name "MSW Manama 2025" --country POL \\
        --out doc/reports/ftl-individual/msw-manama-2025.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

import httpx
from python.matcher.fuzzy_match import find_best_match
from python.scrapers.ftl import fetch_ftl_event_metadata
from python.scrapers.ftl_auth import get_authed_ftl_client, normalize_ftl_url
from python.tools.scrape_evf_individual import TIER_ORDER, classify_tier
from python.tools.scrape_team_events import FTL, classify_event, parse_event_list

# Championship-code -> ladder tier. MSW = Mistrzostwa Świata (FIE World
# Championships), MEW = Mistrzostwa Europy (European Championships).
_TIER_BY_CODE = {"MSW": "WORLD", "MEW": "EUROPEAN"}


def tier_for(championship: str, entry: int | None) -> str:
    """Tier from the championship label, else fall back to field depth."""
    head = (championship or "").strip().upper()
    for code, tier in _TIER_BY_CODE.items():
        if head.startswith(code):
            return tier
    return classify_tier(championship, entry)


def is_team_event(name: str) -> bool:
    return "team" in (name or "").lower()


def scrape_individual(
    client: httpx.Client, schedule: str, championship: str, country: str
) -> list[dict[str, Any]]:
    """Pull every individual tournament's results for ``country``."""
    page = client.get(normalize_ftl_url(f"{FTL}/tournaments/eventSchedule/{schedule}")).text
    events = [e for e in parse_event_list(page) if not is_team_event(e["name"])]
    print(f"{championship}: {len(events)} individual tournament(s)", file=sys.stderr)

    rows: list[dict[str, Any]] = []
    for ev in events:
        eid = ev["eid"]
        try:
            data = client.get(normalize_ftl_url(f"{FTL}/events/results/data/{eid}")).json()
        except (ValueError, httpx.HTTPError):
            continue
        entries = [r for r in data if not r.get("excluded")]
        if not entries:
            continue
        meta = fetch_ftl_event_metadata(f"{FTL}/events/results/{eid}", client) or {}
        mine = [r for r in entries if str(r.get("country", "")).upper() == country.upper()]
        if mine:
            print(
                f"  ✓ {ev['name'][:34]:34s} {len(mine):2d}/{len(entries):3d} {country}",
                file=sys.stderr,
            )
        for r in mine:
            place = str(r.get("place") or "").strip()
            rows.append(
                {
                    "eid": eid,
                    "event_name": ev["name"],
                    "championship": championship,
                    "date": meta.get("date") or "",
                    **classify_event(ev["name"]),
                    "scraped_name": r.get("name") or "",
                    "place": int("".join(ch for ch in place if ch.isdigit()) or 0) or None,
                    "entry": len(entries),
                    "tier": tier_for(championship, len(entries)),
                }
            )
    return rows


def resolve(
    rows: list[dict[str, Any]], fencer_db: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Group rows per resolved fencer; report names that do not auto-match."""
    cache: dict[str, Any] = {}
    by_id: dict[int, dict[str, Any]] = {}
    unresolved: dict[str, dict[str, Any]] = {}
    db_by_id = {f["id_fencer"]: f for f in fencer_db}

    for row in rows:
        name = row["scraped_name"]
        if name not in cache:
            cache[name] = find_best_match(
                name, fencer_db, use_diacritic_folding=True, use_token_set_ratio=True
            )
        m = cache[name]
        if m.id_fencer is None or m.status != "AUTO_MATCHED":
            u = unresolved.setdefault(
                name,
                {
                    "name": name,
                    "confidence": float(m.confidence or 0),
                    "status": m.status,
                    "results": 0,
                },
            )
            u["results"] += 1
            continue
        rec = by_id.setdefault(
            m.id_fencer,
            {
                "id_fencer": m.id_fencer,
                "name": "",
                "birth_year": None,
                "aliases": [],
                "tier_counts": {},
                "results": [],
            },
        )
        if name not in rec["aliases"]:
            rec["aliases"].append(name)
        rec["tier_counts"][row["tier"]] = rec["tier_counts"].get(row["tier"], 0) + 1
        rec["results"].append(row)

    for fid, rec in by_id.items():
        f = db_by_id.get(fid, {})
        rec["name"] = f"{f.get('txt_surname', '')} {f.get('txt_first_name', '')}".strip()
        rec["birth_year"] = f.get("int_birth_year")
        rec["results"].sort(key=lambda r: r["date"], reverse=True)
        rec["best_tier"] = min(
            (r["tier"] for r in rec["results"]),
            key=lambda t: TIER_ORDER.index(t) if t in TIER_ORDER else 99,
            default=None,
        )
    return (
        sorted(by_id.values(), key=lambda r: -len(r["results"])),
        sorted(unresolved.values(), key=lambda u: -u["results"]),
    )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--schedule", required=True, help="eventSchedule UUID")
    ap.add_argument("--name", required=True, help="e.g. 'MSW Manama 2025'")
    ap.add_argument("--country", default="POL")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with get_authed_ftl_client(timeout=30.0) as client:
        rows = scrape_individual(client, args.schedule.upper(), args.name, args.country)

    from python.pipeline.db_connector import create_db_connector

    fencers, unresolved = resolve(rows, create_db_connector().fetch_fencer_db())

    data = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "source": f"{FTL}/tournaments/eventSchedule/{args.schedule.upper()}",
        "championship": args.name,
        "country": args.country,
        "tier_order": TIER_ORDER,
        "fencers": fencers,
        "unresolved": unresolved,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Wrote {out} — {len(rows)} result(s), {len(fencers)} fencer(s), "
        f"{len(unresolved)} unresolved.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
