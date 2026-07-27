"""Merge per-championship team relay profiles into one career profile per fencer.

:mod:`python.tools.scrape_team_events` writes one JSON store per championship,
keyed by the fencer name exactly as FencingTimeLive printed it. Those spellings
are not stable across championships — diacritics are dropped (``SĘKOWSKI`` vs
``SEKOWSKI``), ``Ł`` is transliterated (``ZABŁOCKI`` vs ``ZABLOCKI``), and
surnames change or gain hyphens (``KORONA`` -> ``KORONA-TRZEBSKI``). Merging on
the raw string therefore splits one fencer into several career records.

This resolves every name through the repo's own identity subsystem
(:func:`python.matcher.fuzzy_match.find_best_match`) against ``tbl_fencer``,
which carries the curated ``json_name_aliases``, so the career profile is keyed
by ``id_fencer`` rather than by spelling. Names that do not reach the auto-match
threshold are reported as unresolved instead of being silently merged.

Usage::

    set -a; source .env; set +a
    python -m python.tools.resolve_team_fencers \\
        --in doc/reports/team-events \\
        --out doc/reports/team-events/career-profiles.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

from python.matcher.fuzzy_match import find_best_match

# Team relays are international events; the name is all we have to go on, so the
# diacritic-folding + token-set comparators are enabled (they are what bridges
# SĘKOWSKI/SEKOWSKI and ZABŁOCKI/ZABLOCKI).

_METRICS = ("matches", "legs", "net", "scored", "conceded", "anchor_legs", "anchor_net")


def blank_career() -> dict[str, Any]:
    rec: dict[str, Any] = {m: 0 for m in _METRICS}
    rec.update(id_fencer=None, name="", aliases=[], championships=[], tournaments=[])
    return rec


def load_stores(indir: Path) -> list[dict[str, Any]]:
    """Load every championship JSON in ``indir`` (skips the merged output)."""
    stores: list[dict[str, Any]] = []
    for path in sorted(indir.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "tournaments" not in data:
            continue
        stores.append(data)
    return stores


def resolve_name(
    name: str, fencer_db: list[dict[str, Any]], cache: dict[str, Any]
) -> dict[str, Any]:
    """Resolve one scraped name to a fencer, memoised per run."""
    if name not in cache:
        m = find_best_match(
            name,
            fencer_db,
            use_diacritic_folding=True,
            use_token_set_ratio=True,
        )
        cache[name] = {
            "id_fencer": m.id_fencer,
            "confidence": float(m.confidence or 0),
            "status": m.status,
        }
    return cache[name]


def merge_stores(
    stores: list[dict[str, Any]], fencer_db: list[dict[str, Any]]
) -> dict[str, Any]:
    """Fold every championship's per-tournament profiles into career records."""
    by_id: dict[int, dict[str, Any]] = {}
    unresolved: dict[str, dict[str, Any]] = {}
    cache: dict[str, Any] = {}
    db_by_id = {f["id_fencer"]: f for f in fencer_db}

    for store in stores:
        champ = store.get("championship", "?")
        for t in store.get("tournaments", []):
            if not (t.get("present") and t.get("is_team")):
                continue
            label = f"{t.get('category')} {t.get('gender')} {t.get('weapon')}"
            for raw_name, prof in (t.get("fencer_profile") or {}).items():
                hit = resolve_name(raw_name, fencer_db, cache)
                # Only AUTO_MATCHED (>=95) is fused into a career record. A
                # PENDING guess (50-94) merging silently would attribute one
                # fencer's relay record to another — it is reported for review
                # instead, as the matcher's own contract intends.
                if hit["id_fencer"] is None or hit["status"] != "AUTO_MATCHED":
                    u = unresolved.setdefault(
                        raw_name,
                        {
                            "name": raw_name,
                            "confidence": hit["confidence"],
                            "status": hit["status"],
                            "candidate_id": hit["id_fencer"],
                            "seen": [],
                        },
                    )
                    u["seen"].append(f"{champ} / {label}")
                    continue
                rec = by_id.setdefault(hit["id_fencer"], blank_career())
                rec["id_fencer"] = hit["id_fencer"]
                for m in _METRICS:
                    rec[m] += prof.get(m, 0)
                if raw_name not in rec["aliases"]:
                    rec["aliases"].append(raw_name)
                if champ not in rec["championships"]:
                    rec["championships"].append(champ)
                rec["tournaments"].append(
                    {
                        "championship": champ,
                        "tournament": label,
                        **{m: prof.get(m, 0) for m in _METRICS},
                    }
                )

    for fid, rec in by_id.items():
        f = db_by_id.get(fid, {})
        surname = f.get("txt_surname", "")
        first = f.get("txt_first_name", "")
        rec["name"] = f"{surname} {first}".strip() or (rec["aliases"] or [""])[0]
        rec["birth_year"] = f.get("int_birth_year")

    return {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "source_championships": [s.get("championship") for s in stores],
        "fencers": sorted(by_id.values(), key=lambda r: -r["net"]),
        "unresolved": sorted(unresolved.values(), key=lambda u: -u["confidence"]),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--in", dest="indir", default="doc/reports/team-events")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    from python.pipeline.db_connector import create_db_connector

    db = create_db_connector()
    fencer_db = db.fetch_fencer_db()
    stores = load_stores(Path(args.indir))
    print(
        f"{len(stores)} championship store(s), {len(fencer_db)} fencers in tbl_fencer",
        file=sys.stderr,
    )

    merged = merge_stores(stores, fencer_db)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(merged, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Wrote {out} — {len(merged['fencers'])} resolved fencer(s), "
        f"{len(merged['unresolved'])} unresolved name(s).",
        file=sys.stderr,
    )
    for u in merged["unresolved"]:
        print(
            f"  UNRESOLVED {u['name']:28s} best={u['confidence']:.0f} "
            f"status={u['status']} candidate={u['candidate_id']}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
