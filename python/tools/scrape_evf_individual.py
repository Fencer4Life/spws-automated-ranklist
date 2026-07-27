"""Scrape EVF individual results for a country and classify them by field depth.

Pulls every individual result from the EVF ranking API
(:mod:`python.scrapers.evf_results`, ADR-028) inside a date window, keeps the
target country's fencers, resolves each to ``tbl_fencer`` through the repo's
fuzzy matcher, and tags every result with a **provenance tier**.

The tier is the point. A ranking total says only *how many* points a fencer
holds; it hides *where they came from*. A podium in a 12-entry event and a
podium at the European Championships are not the same evidence, yet they add
into the same number. Each result is therefore classified by the authority of
the event and the depth of the field it was won in:

    WORLD > EUROPEAN > EVF-64+ > EVF-32+ > EVF-16+ > EVF-8+ > EVF-4+ > EVF-4-

so a fencer's record can be read as a shape (where do their points cluster?)
rather than a single figure.

Usage::

    set -a; source .env; set +a
    python -m python.tools.scrape_evf_individual \\
        --from 2024-07-01 --to 2026-12-31 --country POL \\
        --out doc/reports/evf-individual/pol-2024-2026.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

from python.matcher.fuzzy_match import find_best_match
from python.scrapers.evf_results import EvfApiClient

# Field-depth bands for ordinary EVF circuit events, widest first.
_EVF_BANDS = ((64, "EVF-64+"), (32, "EVF-32+"), (16, "EVF-16+"), (8, "EVF-8+"), (4, "EVF-4+"))

# The provenance ladder, strongest first. Authority outranks field depth: any
# World result sits above any European one, and every EVF circuit result sits
# above every domestic SPWS one, because SPWS fields are the shallowest. Within
# a body, depth of field orders the rungs.
TIER_ORDER = [
    "WORLD", "EUROPEAN",
    "EVF-64+", "EVF-32+", "EVF-16+", "EVF-8+", "EVF-4+", "EVF-4-",
    "SPWS-16+", "SPWS-8+", "SPWS-4+", "SPWS-4-",
]


def _birth_year(dob: Any) -> int | None:
    """Reduce an EVF date of birth to its year (see the note at the call site)."""
    try:
        return int(str(dob)[:4])
    except (TypeError, ValueError):
        return None


def classify_tier(event_name: str, entry: int | None) -> str:
    """Classify a result by the authority of the event and its field depth."""
    low = (event_name or "").lower()
    if "world" in low:
        return "WORLD"
    if "european" in low and "championship" in low:
        return "EUROPEAN"
    n = entry or 0
    for threshold, label in _EVF_BANDS:
        if n >= threshold:
            return label
    return "EVF-4-"


def discover_events(
    client: EvfApiClient, date_from: str, date_to: str, scan: tuple[int, int]
) -> list[dict[str, Any]]:
    """Scan EVF event ids and keep those whose competitions fall in the window."""
    out: list[dict[str, Any]] = []
    for eid in range(scan[0], scan[1]):
        try:
            comps = client.get_competitions(eid)
        except RuntimeError:
            continue
        if not comps:
            continue
        keep = [
            c
            for c in comps
            if (c.get("starts") or "") >= date_from
            and (c.get("starts") or "") <= date_to
            and (c.get("total") or 0) > 0
        ]
        if keep:
            out.append({"evf_id": eid, "competitions": keep})
    return out


def collect_results(
    client: EvfApiClient, events: list[dict[str, Any]], country: str
) -> list[dict[str, Any]]:
    """Fetch every competition's results and keep the target country's rows."""
    rows: list[dict[str, Any]] = []
    for ev in events:
        for comp in ev["competitions"]:
            try:
                res = client.get_results(comp["id"])
            except RuntimeError:
                continue
            for r in res:
                if str(r.get("country_abbr") or "").upper() != country.upper():
                    continue
                entry = r.get("entry")
                rows.append(
                    {
                        "evf_event_id": ev["evf_id"],
                        "competition_id": comp["id"],
                        "event_name": r.get("event_name") or "",
                        "date": r.get("event_date") or comp.get("starts") or "",
                        "weapon": r.get("weapon_abbr") or "",
                        "category": r.get("category_name") or "",
                        "scraped_name": f"{r.get('fencer_surname', '')} "
                                        f"{r.get('fencer_firstname', '')}".strip(),
                        # Birth YEAR only. The API returns a full date of birth,
                        # but this repo is public and has only ever tracked a
                        # year (tbl_fencer.int_birth_year); the day and month are
                        # dropped here rather than written to a tracked path.
                        "birth_year": _birth_year(r.get("fencer_dob")),
                        "place": r.get("place"),
                        "entry": entry,
                        "total_points": r.get("total_points"),
                        "ranked": r.get("ranked"),
                        "tier": classify_tier(r.get("event_name") or "", entry),
                    }
                )
    return rows


def _disambiguate_by_birth_year(
    name: str, year: int, fencer_db: list[dict[str, Any]]
) -> Any | None:
    """Re-match ``name`` against only the fencers born in ``year``.

    Returns the match when the restricted candidate set yields a single
    confident hit, else ``None`` (leaving the original PENDING verdict alone).
    """
    subset = [f for f in fencer_db if f.get("int_birth_year") == year]
    if not subset:
        return None
    m = find_best_match(
        name, subset, use_diacritic_folding=True, use_token_set_ratio=True
    )
    return m if m.status == "AUTO_MATCHED" else None


def resolve_rows(
    rows: list[dict[str, Any]], fencer_db: list[dict[str, Any]]
) -> tuple[dict[int, dict[str, Any]], list[dict[str, Any]]]:
    """Group results per resolved fencer; report names that do not auto-match."""
    cache: dict[str, Any] = {}
    by_id: dict[int, dict[str, Any]] = {}
    unresolved: dict[str, dict[str, Any]] = {}
    db_by_id = {f["id_fencer"]: f for f in fencer_db}

    for row in rows:
        name = row["scraped_name"]
        if name not in cache:
            m = find_best_match(
                name, fencer_db, use_diacritic_folding=True, use_token_set_ratio=True
            )
            # Duplicate names (the documented KRAWCZYK Paweł 1954/1989 and
            # MŁYNEK Janusz 1951/1984 pairs) score 100 but are forced PENDING
            # because the name alone cannot say which person it is. EVF ships an
            # exact date of birth, so retry against only the candidates born that
            # year — if that leaves exactly one, the ambiguity is genuinely gone.
            if m.status == "PENDING" and row.get("birth_year"):
                m = _disambiguate_by_birth_year(name, row["birth_year"], fencer_db) or m
            cache[name] = m
        m = cache[name]
        # Only a confident match may carry a result into a fencer's dossier.
        if m.id_fencer is None or m.status != "AUTO_MATCHED":
            u = unresolved.setdefault(
                name,
                {
                    "name": name,
                    "confidence": float(m.confidence or 0),
                    "status": m.status,
                    "birth_year": row.get("birth_year"),
                    "results": 0,
                },
            )
            u["results"] += 1
            continue
        rec = by_id.setdefault(
            m.id_fencer,
            {"id_fencer": m.id_fencer, "name": "", "birth_year": None,
             "aliases": [], "tier_counts": {}, "results": []},
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
    return by_id, sorted(unresolved.values(), key=lambda u: -u["results"])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--from", dest="date_from", required=True, help="YYYY-MM-DD")
    ap.add_argument("--to", dest="date_to", required=True, help="YYYY-MM-DD")
    ap.add_argument("--country", default="POL", help="IOC code, e.g. POL")
    ap.add_argument("--scan", default="26,160", help="EVF event-id scan range")
    ap.add_argument("--delay", type=float, default=0.15)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    lo, hi = (int(x) for x in args.scan.split(","))
    client = EvfApiClient(request_delay=args.delay)
    try:
        client.connect()
        events = discover_events(client, args.date_from, args.date_to, (lo, hi))
        comps = sum(len(e["competitions"]) for e in events)
        print(f"{len(events)} event(s), {comps} competition(s) in window", file=sys.stderr)
        rows = collect_results(client, events, args.country)
        print(f"{len(rows)} {args.country} result row(s)", file=sys.stderr)
    finally:
        client.close()

    from python.pipeline.db_connector import create_db_connector

    fencer_db = create_db_connector().fetch_fencer_db()
    by_id, unresolved = resolve_rows(rows, fencer_db)

    data = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "source": "EVF ranking API (api.veteransfencing.eu)",
        "window": {"from": args.date_from, "to": args.date_to},
        "country": args.country,
        "tier_order": TIER_ORDER,
        "fencers": sorted(by_id.values(), key=lambda r: -len(r["results"])),
        "unresolved": unresolved,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Wrote {out} — {len(data['fencers'])} resolved fencer(s), "
        f"{len(unresolved)} unresolved name(s).",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
