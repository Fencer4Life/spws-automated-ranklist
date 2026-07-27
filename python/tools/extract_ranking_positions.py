"""Collect each fencer's CURRENT position in the EVF and SPWS rankings.

The scrape tools in this directory gather *results* — what a fencer did at
individual events. This one gathers *standings*: where they presently sit in the
two ranking lists that a selection dossier has to quote, because a position is
the number a federation recognises at a glance.

Two sources, both per weapon x gender x age category:

* **EVF** — ``api.veteransfencing.eu`` ``/fe/ranking/list``, keyed by
  ``weapon_id`` (1-3 men's foil/epee/sabre, 4-6 women's) and ``category_id``
  (1-4 = V1-V4). Rows carry ``pos``, ``points`` and ``country``.
* **SPWS** — the local ranking database's own ``fn_ranking_ppw`` RPC, which is
  the authority for the domestic list.

EVF names are matched to ``tbl_fencer`` through the repo's fuzzy matcher; only
confident matches are kept, so a near-miss never attributes a European position
to the wrong person. SPWS rows already carry ``id_fencer``.

Usage::

    set -a; source .env; set +a
    python -m python.tools.extract_ranking_positions \\
        --country POL --out doc/reports/ranking-positions/pol.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path
from typing import Any

import httpx
from python.matcher.fuzzy_match import find_best_match
from python.scrapers.evf_results import EvfApiClient

# EVF weapon_id encodes weapon *and* gender in a single number.
EVF_WEAPONS = {
    1: ("FOIL", "M"), 2: ("EPEE", "M"), 3: ("SABRE", "M"),
    4: ("FOIL", "F"), 5: ("EPEE", "F"), 6: ("SABRE", "F"),
}
EVF_CATEGORIES = {1: "V1", 2: "V2", 3: "V3", 4: "V4"}

SPWS_WEAPONS = ("EPEE", "FOIL", "SABRE")
SPWS_GENDERS = ("M", "F")
SPWS_CATEGORIES = ("V0", "V1", "V2", "V3", "V4")


def bucket(weapon: str, gender: str, category: str) -> str:
    return f"{weapon}-{gender}-{category}"


def fetch_evf(client: EvfApiClient, country: str) -> list[dict[str, Any]]:
    """Every EVF ranking list, reduced to the target country's rows."""
    rows: list[dict[str, Any]] = []
    for wid, (weapon, gender) in EVF_WEAPONS.items():
        for cid, cat in EVF_CATEGORIES.items():
            try:
                data = client._post(  # noqa: SLF001 - the client exposes no public helper
                    "/ranking/list", model={"category_id": str(cid), "weapon_id": wid}
                )
            except RuntimeError as exc:
                print(f"  EVF {weapon}/{gender}/{cat}: {exc}", file=sys.stderr)
                continue
            results = (data.get("data") or {}).get("results") or []
            total = len(results)
            mine = [r for r in results
                    if str(r.get("country") or "").upper() == country.upper()]
            rows.extend(
                _merge_duplicates(mine, results, weapon, gender, cat, total)
            )
    return rows


def _fold(name: str) -> str:
    """Diacritic-insensitive key — EVF stores some fencers both ways."""
    import unicodedata
    s = name.replace("Ł", "L").replace("ł", "l")
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn").upper().strip()


def _merge_duplicates(
    mine: list[dict[str, Any]], field: list[dict[str, Any]],
    weapon: str, gender: str, cat: str, total: int,
) -> list[dict[str, Any]]:
    """Fold an EVF fencer's split records into one standing.

    EVF holds some fencers twice — once spelled with Polish diacritics and once
    without — which splits their points across two rows and publishes each at a
    worse position than the fencer actually earned. Where that happens, the
    points are summed and the position recomputed against the real field, with
    the original rows kept for evidence.
    """
    groups: dict[str, list[dict[str, Any]]] = {}
    for r in mine:
        nm = f'{r.get("name", "")} {r.get("firstname", "")}'.strip()
        groups.setdefault(_fold(nm), []).append(r)

    out: list[dict[str, Any]] = []
    for recs in groups.values():
        pts = sum(float(x.get("points") or 0) for x in recs)
        names = [f'{x.get("name", "")} {x.get("firstname", "")}'.strip() for x in recs]
        best = min(int(x.get("pos") or 9999) for x in recs)
        row = {
            "weapon": weapon, "gender": gender, "category": cat,
            "bucket": bucket(weapon, gender, cat),
            "pos": best, "of": total, "points": pts,
            "scraped_name": names[0],
        }
        if len(recs) > 1:
            # Position the merged total would hold: everyone outside this
            # fencer's own duplicate rows who still has more points.
            own = {id(x) for x in recs}
            ahead = sum(1 for x in field
                        if id(x) not in own and float(x.get("points") or 0) > pts)
            row.update(
                duplicate_records=names,
                published_pos=best,
                pos=ahead + 1,
                note="EVF prowadzi tego zawodnika w dwóch rekordach — punkty rozbite",
            )
        out.append(row)
    return out


def fetch_spws(base: str, headers: dict[str, str]) -> list[dict[str, Any]]:
    """Every SPWS sub-ranking via the database's own ranking function."""
    rows: list[dict[str, Any]] = []
    for weapon in SPWS_WEAPONS:
        for gender in SPWS_GENDERS:
            for cat in SPWS_CATEGORIES:
                resp = httpx.post(
                    f"{base}/rest/v1/rpc/fn_ranking_ppw",
                    headers={**headers, "Content-Type": "application/json"},
                    json={"p_weapon": weapon, "p_gender": gender,
                          "p_category": cat, "p_rolling": True},
                    timeout=90,
                )
                if resp.status_code >= 400:
                    continue
                data = resp.json()
                total = len(data)
                for r in data:
                    rows.append({
                        "weapon": weapon, "gender": gender, "category": cat,
                        "bucket": bucket(weapon, gender, cat),
                        "pos": r.get("rank"), "of": total,
                        "points": float(r.get("total_score") or 0),
                        "id_fencer": r.get("id_fencer"),
                        "name": r.get("fencer_name"),
                    })
    return rows


def resolve_evf(
    rows: list[dict[str, Any]], fencer_db: list[dict[str, Any]]
) -> tuple[dict[int, list[dict[str, Any]]], list[dict[str, Any]]]:
    """Attach EVF standings to fencer ids; report names that do not auto-match."""
    cache: dict[str, Any] = {}
    by_id: dict[int, list[dict[str, Any]]] = {}
    unresolved: dict[str, dict[str, Any]] = {}
    for row in rows:
        name = row["scraped_name"]
        if name not in cache:
            cache[name] = find_best_match(
                name, fencer_db, use_diacritic_folding=True, use_token_set_ratio=True
            )
        m = cache[name]
        if m.id_fencer is None or m.status != "AUTO_MATCHED":
            u = unresolved.setdefault(
                name, {"name": name, "confidence": float(m.confidence or 0),
                       "status": m.status, "buckets": []})
            u["buckets"].append(row["bucket"])
            continue
        by_id.setdefault(m.id_fencer, []).append(row)
    return by_id, sorted(unresolved.values(), key=lambda u: -u["confidence"])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--country", default="POL")
    ap.add_argument("--delay", type=float, default=0.3)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    client = EvfApiClient(request_delay=args.delay)
    try:
        client.connect()
        evf_rows = fetch_evf(client, args.country)
    finally:
        client.close()
    print(f"EVF: {len(evf_rows)} {args.country} standing(s)", file=sys.stderr)

    base = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", "")
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}
    spws_rows = fetch_spws(base, headers)
    print(f"SPWS: {len(spws_rows)} standing(s)", file=sys.stderr)

    from python.pipeline.db_connector import create_db_connector

    fencer_db = create_db_connector().fetch_fencer_db()
    evf_by_id, unresolved = resolve_evf(evf_rows, fencer_db)

    spws_by_id: dict[int, list[dict[str, Any]]] = {}
    for r in spws_rows:
        spws_by_id.setdefault(r["id_fencer"], []).append(r)

    db_by_id = {f["id_fencer"]: f for f in fencer_db}
    fencers = []
    for fid in sorted(set(evf_by_id) | set(spws_by_id)):
        f = db_by_id.get(fid, {})
        fencers.append({
            "id_fencer": fid,
            "name": f"{f.get('txt_surname', '')} {f.get('txt_first_name', '')}".strip(),
            "birth_year": f.get("int_birth_year"),
            "evf": sorted(evf_by_id.get(fid, []), key=lambda r: r["pos"] or 999),
            "spws": sorted(spws_by_id.get(fid, []), key=lambda r: r["pos"] or 999),
        })

    data = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "country": args.country,
        "sources": {"evf": "api.veteransfencing.eu /fe/ranking/list",
                    "spws": "fn_ranking_ppw (rolling)"},
        "fencers": fencers,
        "unresolved_evf": unresolved,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out} — {len(fencers)} fencer(s), {len(unresolved)} unresolved EVF name(s).",
          file=sys.stderr)


if __name__ == "__main__":
    main()
