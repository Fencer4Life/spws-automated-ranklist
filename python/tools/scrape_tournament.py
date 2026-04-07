"""
Scrape tournament results from url_results and ingest (ADR-029 §2.9).

Given a tournament code, reads its url_results from DB, scrapes the page,
parses results, fuzzy-matches fencers, and ingests via fn_ingest_tournament_results.

Usage:
    python -m python.tools.scrape_tournament --tournament-code PPW4-V2-M-EPEE-2025-2026
"""

from __future__ import annotations

import argparse
import os
import sys

import httpx

from python.scrapers.base import detect_platform
from python.scrapers.ftl import parse_ftl_json
from python.scrapers.engarde import parse_engarde_html
from python.scrapers.fourfence import parse_fourfence_html


FTL_DATA_PREFIX = "https://www.fencingtimelive.com/events/results/data/"
FTL_RESULTS_PREFIX = "https://www.fencingtimelive.com/events/results/"


def scrape_and_parse(url: str | None) -> list[dict]:
    """Fetch URL and parse results using platform-appropriate parser.

    Returns standardized list of {fencer_name, place, country}.
    """
    if not url:
        raise ValueError("No URL provided for scraping")

    platform = detect_platform(url)

    if platform == "ftl":
        # FTL results page → convert to JSON API endpoint
        data_url = url
        if FTL_RESULTS_PREFIX in url and "/data/" not in url:
            uuid = url.split(FTL_RESULTS_PREFIX)[-1].split("?")[0].split("#")[0]
            data_url = f"{FTL_DATA_PREFIX}{uuid}"
        resp = httpx.get(data_url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_ftl_json(resp.json())

    elif platform == "engarde":
        resp = httpx.get(url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_engarde_html(resp.text)

    elif platform == "fourfence":
        resp = httpx.get(url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_fourfence_html(resp.text)

    else:
        raise ValueError(f"Unsupported platform: {url}")


def main():
    parser = argparse.ArgumentParser(
        description="Scrape tournament results from url_results and ingest"
    )
    parser.add_argument("--tournament-code", required=True)
    parser.add_argument("--supabase-url", default=None)
    parser.add_argument("--supabase-key", default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
    supabase_key = args.supabase_key or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

    # 1. Fetch tournament from DB
    resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_tournament"
        f"?txt_code=eq.{args.tournament_code}"
        f"&select=id_tournament,txt_code,url_results,enum_weapon,enum_gender,enum_age_category,enum_type",
        headers=headers, timeout=10,
    )
    resp.raise_for_status()
    tournaments = resp.json()
    if not tournaments:
        print(f"ERROR: Tournament '{args.tournament_code}' not found", file=sys.stderr)
        sys.exit(1)

    tourn = tournaments[0]
    if not tourn.get("url_results"):
        print(f"ERROR: Tournament '{args.tournament_code}' has no url_results", file=sys.stderr)
        sys.exit(1)

    print(f"Tournament: {tourn['txt_code']} → {tourn['url_results']}", file=sys.stderr)

    # 2. Scrape and parse
    results = scrape_and_parse(tourn["url_results"])
    print(f"Scraped {len(results)} results", file=sys.stderr)

    if args.dry_run:
        for r in results[:5]:
            print(f"  {r['place']:3d}. {r['fencer_name']}", file=sys.stderr)
        if len(results) > 5:
            print(f"  ... and {len(results) - 5} more", file=sys.stderr)
        print("DRY RUN — no DB writes", file=sys.stderr)
        return

    # 3. Fuzzy match against fencer DB
    from python.pipeline.db_connector import DbConnector
    db = DbConnector(supabase_url, supabase_key)
    fencer_db = db.fetch_fencer_db()

    from python.matcher.pipeline import resolve_tournament_results
    is_domestic = tourn["enum_type"] in ("PPW", "MPW")
    matched = resolve_tournament_results(results, fencer_db, domestic=is_domestic)

    # 4. Build JSONB payload
    import json
    payload = []
    for m in matched:
        payload.append({
            "id_fencer": m.get("id_fencer"),
            "int_place": m["place"],
            "txt_scraped_name": m["fencer_name"],
            "num_confidence": m.get("confidence"),
            "enum_match_status": m.get("match_status", "AUTO_MATCHED"),
        })

    # 5. Ingest
    resp = httpx.post(
        f"{supabase_url}/rest/v1/rpc/fn_ingest_tournament_results",
        json={"p_tournament_id": tourn["id_tournament"], "p_results": json.dumps(payload)},
        headers={**headers, "Content-Type": "application/json"},
        timeout=30,
    )
    if resp.status_code >= 400:
        print(f"ERROR: Ingest failed — {resp.text}", file=sys.stderr)
        sys.exit(1)

    print(f"Ingested {len(payload)} results for {tourn['txt_code']}", file=sys.stderr)


if __name__ == "__main__":
    main()
