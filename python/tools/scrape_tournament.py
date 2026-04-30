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
from python.scrapers.ftl_auth import get_authed_ftl_client
from python.scrapers.engarde import parse_engarde_html
from python.scrapers.fourfence import parse_fourfence_html
from python.scrapers.dartagnan import parse_dartagnan_rankings_html


FTL_DATA_PREFIX = "https://www.fencingtimelive.com/events/results/data/"
FTL_RESULTS_PREFIX = "https://www.fencingtimelive.com/events/results/"


def existing_result_counts(
    supabase_url: str, headers: dict, tournament_ids: list[int]
) -> dict[int, int]:
    """Return {id_tournament: row_count} for the given tournament IDs.

    Uses PostgREST's `Prefer: count=exact` header to read counts cheaply
    without dragging the rows themselves into Python. Layer 4 idempotency
    guard: a non-zero count for a target row means re-ingest must run with
    --replace (and acknowledge the destructive delete).
    """
    counts: dict[int, int] = {}
    for tid in tournament_ids:
        resp = httpx.get(
            f"{supabase_url}/rest/v1/tbl_result"
            f"?id_tournament=eq.{tid}&select=id_result",
            headers={**headers, "Prefer": "count=exact", "Range-Unit": "items", "Range": "0-0"},
            timeout=10,
        )
        resp.raise_for_status()
        cr = resp.headers.get("content-range", "*/0")
        total = int(cr.split("/")[-1]) if "/" in cr else 0
        counts[tid] = total
    return counts


def delete_existing_results(
    supabase_url: str, headers: dict, tournament_ids: list[int]
) -> int:
    """DELETE every tbl_result row whose id_tournament is in the list.

    Runs only when --replace was passed. Returns the total number of rows
    deleted (sum across tournaments). Fail-fast on any HTTP error so the
    caller can abort before a partial reingest.
    """
    total_deleted = 0
    for tid in tournament_ids:
        resp = httpx.delete(
            f"{supabase_url}/rest/v1/tbl_result?id_tournament=eq.{tid}",
            headers={**headers, "Prefer": "return=representation"},
            timeout=30,
        )
        resp.raise_for_status()
        try:
            total_deleted += len(resp.json())
        except Exception:
            pass
    return total_deleted


def telegram_notify(msg: str) -> None:
    """Send a Telegram message if the env vars are configured; else stdout-log it.

    Layer 4 deliverable. Falls back to a stdout `[Telegram]` line when
    TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID are not set, so tests and local
    runs see the message even without a real bot.
    """
    bot = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat = os.environ.get("TELEGRAM_CHAT_ID", "")
    if not bot or not chat:
        print(f"[Telegram] {msg}", file=sys.stderr)
        return
    try:
        httpx.post(
            f"https://api.telegram.org/bot{bot}/sendMessage",
            data={"chat_id": chat, "text": msg, "parse_mode": "HTML"},
            timeout=10,
        )
    except Exception as exc:
        print(f"[Telegram] FAILED to send ({exc}): {msg}", file=sys.stderr)


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
        with get_authed_ftl_client() as client:
            resp = client.get(data_url)
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

    elif platform == "dartagnan":
        resp = httpx.get(url, follow_redirects=True, timeout=15)
        resp.raise_for_status()
        return parse_dartagnan_rankings_html(resp.text)

    else:
        raise ValueError(f"Unsupported platform: {url}")


def fetch_tournament_with_siblings(supabase_url, headers, tournament_code):
    """Fetch the anchor tournament and every sibling (same event/weapon/gender)
    that shares its url_results.

    Returns:
        (anchor: dict, siblings: list[dict], season_end_year: int)

    Raises:
        SystemExit if the anchor doesn't exist or has no url_results.
    """
    # Anchor — include id_event so we can find siblings under the same event.
    resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_tournament"
        f"?txt_code=eq.{tournament_code}"
        f"&select=id_tournament,id_event,txt_code,url_results,enum_weapon,enum_gender,enum_age_category,enum_type",
        headers=headers, timeout=10,
    )
    resp.raise_for_status()
    rows = resp.json()
    if not rows:
        print(f"ERROR: Tournament '{tournament_code}' not found", file=sys.stderr)
        sys.exit(1)
    anchor = rows[0]
    if not anchor.get("url_results"):
        print(f"ERROR: Tournament '{tournament_code}' has no url_results", file=sys.stderr)
        sys.exit(1)

    # Siblings: every tournament under the same event/weapon/gender that has
    # the same url_results. This is the V-cat set the (combined) pool covers.
    sib_resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_tournament"
        f"?id_event=eq.{anchor['id_event']}"
        f"&enum_weapon=eq.{anchor['enum_weapon']}"
        f"&enum_gender=eq.{anchor['enum_gender']}"
        f"&url_results=eq.{anchor['url_results']}"
        f"&select=id_tournament,txt_code,enum_age_category,enum_type",
        headers=headers, timeout=10,
    )
    sib_resp.raise_for_status()
    siblings = sib_resp.json()

    # Season end year — needed for fn_age_category derivation.
    sey_resp = httpx.get(
        f"{supabase_url}/rest/v1/tbl_event"
        f"?id_event=eq.{anchor['id_event']}"
        f"&select=id_season,tbl_season(dt_end)",
        headers=headers, timeout=10,
    )
    sey_resp.raise_for_status()
    ev = sey_resp.json()[0]
    season_end_year = int(ev["tbl_season"]["dt_end"][:4])

    return anchor, siblings, season_end_year


def main():
    parser = argparse.ArgumentParser(
        description="Scrape tournament results from url_results and ingest, "
                    "splitting combined-pool sources by birth-year-derived V-cat."
    )
    parser.add_argument("--tournament-code", required=True)
    parser.add_argument("--supabase-url", default=None)
    parser.add_argument("--supabase-key", default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Delete existing tbl_result rows on every sibling tournament "
             "before re-ingesting. REQUIRED when any target row already has "
             "results — without it, re-ingest aborts to protect prior writes.",
    )
    args = parser.parse_args()

    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321")
    supabase_key = args.supabase_key or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    headers = {"apikey": supabase_key, "Authorization": f"Bearer {supabase_key}"}

    # 1. Anchor + siblings + season_end_year
    anchor, siblings, season_end_year = fetch_tournament_with_siblings(
        supabase_url, headers, args.tournament_code
    )
    sib_cats = sorted({s["enum_age_category"] for s in siblings})
    print(f"Tournament: {anchor['txt_code']} → {anchor['url_results']}", file=sys.stderr)
    print(f"  Siblings sharing this URL: {len(siblings)} V-cat(s) {sib_cats}", file=sys.stderr)
    print(f"  Season end year: {season_end_year}", file=sys.stderr)

    # 2. Scrape and parse the combined pool (one fetch, regardless of V-cats)
    parsed_rows = scrape_and_parse(anchor["url_results"])
    print(f"  Scraped {len(parsed_rows)} entries from source", file=sys.stderr)

    # Layer 4 idempotency guard: if any sibling already has results, abort
    # unless --replace was explicitly passed. This is the safety net against
    # silent double-ingestion (which Layer 6 replay relies on for clean data).
    sib_ids = [s["id_tournament"] for s in siblings]
    counts = existing_result_counts(supabase_url, headers, sib_ids)
    occupied = [(tid, counts[tid]) for tid in sib_ids if counts[tid] > 0]
    if occupied and not args.replace:
        print("ERROR: existing results found on:", file=sys.stderr)
        sib_by_id = {s["id_tournament"]: s for s in siblings}
        for tid, n in occupied:
            print(f"  {sib_by_id[tid]['txt_code']}: {n} row(s)", file=sys.stderr)
        print("Re-run with --replace to delete and re-ingest.", file=sys.stderr)
        sys.exit(2)

    if args.dry_run:
        for r in parsed_rows[:5]:
            print(f"    {r['place']:3d}. {r['fencer_name']}", file=sys.stderr)
        if len(parsed_rows) > 5:
            print(f"    ... and {len(parsed_rows) - 5} more", file=sys.stderr)
        if occupied:
            print(
                f"DRY RUN — would --replace {sum(n for _, n in occupied)} "
                f"existing row(s) across {len(occupied)} tournament(s) "
                f"before re-ingest",
                file=sys.stderr,
            )
        print("DRY RUN — no DB writes", file=sys.stderr)
        return

    if args.replace and occupied:
        deleted = delete_existing_results(
            supabase_url, headers, [tid for tid, _ in occupied]
        )
        print(
            f"  --replace: deleted {deleted} existing row(s) across "
            f"{len(occupied)} tournament(s)",
            file=sys.stderr,
        )

    # 3. Fetch fencer DB and split parsed rows per V-cat using birth_year truth
    from python.pipeline.db_connector import DbConnector
    from python.pipeline.age_split import split_combined_results

    db = DbConnector(supabase_url, supabase_key)
    fencer_db = db.fetch_fencer_db()

    # split_combined_results uses each fencer's birth_year (from fencer_db) to
    # assign them to the matching V-cat in `sib_cats`. Re-ranks within each
    # bucket. Fencers with no DOB lookup go into `unresolved` AND lowest cat.
    split = split_combined_results(parsed_rows, sib_cats, fencer_db, season_end_year)

    # 4. Per-V-cat: resolve identities, build payload, ingest into target row
    from python.matcher.pipeline import resolve_tournament_results
    import json

    sibling_by_cat = {s["enum_age_category"]: s for s in siblings}
    total_ingested = 0
    for cat, bucket_rows in split.buckets.items():
        target = sibling_by_cat.get(cat)
        if target is None:
            print(f"  WARN: V-cat {cat} has {len(bucket_rows)} fencer(s) but no DB row for it", file=sys.stderr)
            continue
        if not bucket_rows:
            print(f"  {cat}: 0 fencers in this V-cat, skipping", file=sys.stderr)
            continue

        scraped_names = [r["fencer_name"] for r in bucket_rows]
        scraped_countries = [r.get("country") for r in bucket_rows]
        resolved = resolve_tournament_results(
            scraped_names, fencer_db, target["enum_type"],
            cat, season_end_year,
            scraped_countries=scraped_countries,
        )

        payload = []
        for r in bucket_rows:
            m = next(
                (x for x in resolved.matched if x.scraped_name == r["fencer_name"]),
                None,
            )
            if m is None:
                continue
            payload.append({
                "id_fencer": m.id_fencer,
                "int_place": r["place"],
                "txt_scraped_name": r["fencer_name"],
                "num_confidence": float(m.confidence) if m.confidence else 0,
                "enum_match_status": m.status,
            })

        # int_participant_count = number of fencers placed in this V-cat
        # (per ADR-038, this is the per-cat field count, not the combined pool)
        ingest_resp = httpx.post(
            f"{supabase_url}/rest/v1/rpc/fn_ingest_tournament_results",
            json={
                "p_tournament_id": target["id_tournament"],
                "p_results": json.dumps(payload),
                "p_participant_count": len(bucket_rows),
            },
            headers={**headers, "Content-Type": "application/json"},
            timeout=30,
        )
        if ingest_resp.status_code >= 400:
            print(f"  ERROR ingesting {target['txt_code']}: {ingest_resp.text}", file=sys.stderr)
            sys.exit(1)

        print(f"  {target['txt_code']}: ingested {len(payload)}/{len(bucket_rows)} placements", file=sys.stderr)
        total_ingested += len(payload)

    if split.unresolved:
        print(f"  UNRESOLVED (no DOB, assigned to lowest cat): {len(split.unresolved)}", file=sys.stderr)
        for u in split.unresolved:
            print(f"    - {u['fencer_name']} (place {u['place']})", file=sys.stderr)

    print(f"Done. Total ingested: {total_ingested} placements across {len(split.buckets)} V-cat(s).", file=sys.stderr)

    replace_note = " (--replace)" if args.replace and occupied else ""
    telegram_notify(
        f"<b>scrape_tournament{replace_note}</b>\n"
        f"<pre>{anchor['txt_code']}</pre>\n"
        f"V-cats: {sib_cats}\n"
        f"Ingested: <b>{total_ingested}</b> placements"
        + (f"\nUnresolved: <b>{len(split.unresolved)}</b>" if split.unresolved else "")
    )


if __name__ == "__main__":
    main()
