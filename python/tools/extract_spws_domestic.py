"""Extract SPWS domestic results from the ranking database, tiered by field depth.

The third source in the selection dossier, alongside the FIE (World) and EVF
(European / circuit) evidence. Unlike those, this needs no scraping and no name
resolution: the SPWS ranking system already owns these results, and every row is
already keyed to ``tbl_fencer.id_fencer``.

Domestic rows (``PPW`` cup rounds and the ``MPW`` national championship) are
tagged with the domestic rungs of the provenance ladder — ``SPWS-16+`` down to
``SPWS-4-`` — which sit below every EVF rung by design: SPWS fields are the
shallowest in the system, so a domestic points haul is not equivalent evidence
to an international one even when the point totals match.

Only tournaments the ranking system itself accepted (``enum_import_status`` not
``REJECTED``) are included, so the dossier inherits the pipeline's own
data-quality gate rather than re-deciding it.

Usage::

    set -a; source .env; set +a
    python -m python.tools.extract_spws_domestic \\
        --months 24 --out doc/reports/spws-domestic/pol-24m.json
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
from python.tools.scrape_evf_individual import TIER_ORDER

# Domestic field-depth bands, widest first.
_SPWS_BANDS = ((16, "SPWS-16+"), (8, "SPWS-8+"), (4, "SPWS-4+"))

DOMESTIC_TYPES = ("PPW", "MPW")


def classify_spws_tier(participants: int | None) -> str:
    n = participants or 0
    for threshold, label in _SPWS_BANDS:
        if n >= threshold:
            return label
    return "SPWS-4-"


def window_start(months: int, today: dt.date | None = None) -> str:
    """First day of the rolling window, ``months`` back from today."""
    d = today or dt.date.today()
    y, m = divmod((d.year * 12 + d.month - 1) - months, 12)
    return dt.date(y, m + 1, min(d.day, 28)).isoformat()


def fetch_rows(
    base_url: str, headers: dict[str, str], since: str, page_size: int = 1000
) -> list[dict[str, Any]]:
    """Fetch domestic results since ``since`` with their tournament + fencer context.

    Paged explicitly: PostgREST caps a response at its configured maximum (1000
    rows by default) and says so only in the ``Content-Range`` header, so an
    unpaged read silently truncates the dossier instead of failing.
    """
    select = (
        "int_place,num_final_score,id_fencer,"
        "tbl_tournament!inner(txt_code,enum_type,dt_tournament,int_participant_count,"
        "enum_weapon,enum_gender,enum_age_category,enum_import_status),"
        "tbl_fencer!inner(txt_surname,txt_first_name,int_birth_year)"
    )
    url = (
        f"{base_url}/rest/v1/tbl_result"
        f"?select={select}"
        f"&tbl_tournament.enum_type=in.({','.join(DOMESTIC_TYPES)})"
        f"&tbl_tournament.dt_tournament=gte.{since}"
        f"&tbl_tournament.enum_import_status=neq.REJECTED"
        f"&order=id_result.asc"
    )
    rows: list[dict[str, Any]] = []
    offset = 0
    while True:
        resp = httpx.get(
            url,
            headers={
                **headers,
                "Range-Unit": "items",
                "Range": f"{offset}-{offset + page_size - 1}",
            },
            timeout=120,
        )
        resp.raise_for_status()
        page = resp.json()
        rows.extend(page)
        if len(page) < page_size:
            return rows
        offset += page_size


def build(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Group raw result rows into one record per fencer."""
    by_id: dict[int, dict[str, Any]] = {}
    for r in rows:
        t = r.get("tbl_tournament") or {}
        f = r.get("tbl_fencer") or {}
        fid = r["id_fencer"]
        rec = by_id.setdefault(
            fid,
            {
                "id_fencer": fid,
                "name": f"{f.get('txt_surname', '')} {f.get('txt_first_name', '')}".strip(),
                "birth_year": f.get("int_birth_year"),
                "tier_counts": {},
                "results": [],
            },
        )
        tier = classify_spws_tier(t.get("int_participant_count"))
        rec["tier_counts"][tier] = rec["tier_counts"].get(tier, 0) + 1
        rec["results"].append(
            {
                "tournament": t.get("txt_code"),
                "type": t.get("enum_type"),
                "date": t.get("dt_tournament"),
                "weapon": t.get("enum_weapon"),
                "gender": t.get("enum_gender"),
                "category": t.get("enum_age_category"),
                "place": r.get("int_place"),
                "entry": t.get("int_participant_count"),
                "score": r.get("num_final_score"),
                "tier": tier,
            }
        )
    for rec in by_id.values():
        rec["results"].sort(key=lambda x: x["date"] or "", reverse=True)
        rec["best_tier"] = min(
            (x["tier"] for x in rec["results"]),
            key=lambda t: TIER_ORDER.index(t) if t in TIER_ORDER else 99,
            default=None,
        )
    return sorted(by_id.values(), key=lambda r: -len(r["results"]))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--months", type=int, default=24, help="Rolling window length")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    base = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", "")
    if not key:
        print("SUPABASE_KEY / SUPABASE_SERVICE_ROLE_KEY not set", file=sys.stderr)
        raise SystemExit(2)
    headers = {"apikey": key, "Authorization": f"Bearer {key}"}

    since = window_start(args.months)
    rows = fetch_rows(base, headers, since)
    fencers = build(rows)
    print(f"{len(rows)} domestic result(s) since {since}", file=sys.stderr)

    data = {
        "generated_at": dt.datetime.now(dt.UTC).isoformat(),
        "source": "SPWS ranking database (tbl_result / tbl_tournament)",
        "window": {"months": args.months, "from": since},
        "tier_order": TIER_ORDER,
        "fencers": fencers,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out} — {len(fencers)} fencer(s).", file=sys.stderr)


if __name__ == "__main__":
    main()
