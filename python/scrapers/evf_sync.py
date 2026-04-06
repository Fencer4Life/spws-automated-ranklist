"""
EVF Calendar + Results Sync CLI (ADR-028)

Orchestrates calendar scraping and result PDF downloading from veteransfencing.eu.
Called by .github/workflows/evf-sync.yml.

Usage:
    python -m python.scrapers.evf_sync --mode both
    python -m python.scrapers.evf_sync --mode calendar
    python -m python.scrapers.evf_sync --mode results --event-code PEW7-2025-2026
"""

from __future__ import annotations

import argparse
import os
import time

import httpx

from python.scrapers.evf_calendar import (
    parse_evf_calendar_html,
    filter_by_season,
    deduplicate_events,
)
from python.scrapers.evf_results import parse_evf_result_pdf, evf_code_to_category

EVF_CALENDAR_URL = "https://www.veteransfencing.eu/calendar/"
EVF_RESULTS_URL = "https://www.veteransfencing.eu/fencing/results/"


def _management_query(ref: str, token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API."""
    resp = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"query": sql},
        timeout=60,
    )
    if resp.status_code >= 400:
        raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text}")
    return resp.json()


def _telegram(bot_token: str, chat_id: str, msg: str) -> None:
    """Send Telegram notification."""
    if not bot_token or not chat_id:
        return
    httpx.post(
        f"https://api.telegram.org/bot{bot_token}/sendMessage",
        data={"chat_id": chat_id, "text": msg, "parse_mode": "HTML"},
        timeout=10,
    )


def sync_calendar(ref: str, token: str, bot_token: str, chat_id: str) -> None:
    """Scrape EVF calendar and import new events to CERT."""
    print("Fetching EVF calendar...")
    resp = httpx.get(EVF_CALENDAR_URL, timeout=30, follow_redirects=True)
    resp.raise_for_status()

    events = parse_evf_calendar_html(resp.text)
    print(f"  Parsed {len(events)} events from calendar")

    # Get active season date range
    season = _management_query(ref, token,
        "SELECT txt_code, dt_start::TEXT, dt_end::TEXT FROM tbl_season WHERE bool_active = TRUE"
    )
    if not season:
        print("  No active season found, skipping")
        return

    s = season[0]
    filtered = filter_by_season(events, s["dt_start"], s["dt_end"])
    print(f"  {len(filtered)} events in season {s['txt_code']}")

    # Get existing events for dedup
    existing = _management_query(ref, token,
        f"SELECT txt_name, dt_start::TEXT FROM tbl_event "
        f"WHERE id_season = (SELECT id_season FROM tbl_season WHERE txt_code = '{s['txt_code']}')"
    )

    new, already = deduplicate_events(filtered, existing)
    print(f"  {len(new)} new, {len(already)} already imported")

    if not new:
        print("  No new events to import")
        return

    # Generate event codes and import
    season_suffix = s["txt_code"].replace("SPWS-", "")
    import_events = []
    for i, evt in enumerate(new):
        # Generate code: PEW{N}-{season} for circuit, IMEW-{season} for championship
        loc = evt.get("location", "").split(",")[0].strip().upper().replace(" ", "")[:10]
        code = f"PEW-{loc}-{season_suffix}" if not evt.get("is_team") else f"MEW-{loc}-{season_suffix}"
        evt["code"] = code
        import_events.append(evt)

    import json
    events_json = json.dumps(import_events).replace("'", "''")
    season_id = _management_query(ref, token,
        f"SELECT id_season FROM tbl_season WHERE txt_code = '{s['txt_code']}'"
    )[0]["id_season"]

    result = _management_query(ref, token,
        f"SELECT fn_import_evf_events('{events_json}'::JSONB, {season_id})"
    )
    print(f"  Import result: {result}")

    _telegram(bot_token, chat_id,
        f"<b>EVF Calendar Updated</b>\n{len(new)} new event(s) imported from veteransfencing.eu"
    )


def sync_results(ref: str, token: str, bot_token: str, chat_id: str, event_code: str = "") -> None:
    """Check for result PDFs and download+ingest if available."""
    # Find events needing results (PLANNED, dt_end >= 2 days ago)
    if event_code:
        where = f"e.txt_code = '{event_code}'"
    else:
        where = (
            "e.enum_status = 'PLANNED' "
            "AND e.dt_end IS NOT NULL "
            "AND e.dt_end <= CURRENT_DATE - INTERVAL '2 days' "
            "AND e.dt_end >= CURRENT_DATE - INTERVAL '16 days' "
            "AND EXISTS(SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event AND t.enum_type = 'PEW')"
        )

    events = _management_query(ref, token,
        f"SELECT e.txt_code, e.txt_name, e.dt_end::TEXT "
        f"FROM tbl_event e "
        f"WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE bool_active = TRUE) "
        f"AND {where} "
        f"ORDER BY e.dt_end"
    )

    if not events:
        print("  No events needing results")
        return

    # Process one event at a time
    evt = events[0]
    print(f"Checking results for {evt['txt_code']} ({evt['txt_name']})...")

    # TODO: Scrape EVF results page for PDF links matching this event's date
    # Then download PDFs with 2-minute delay between each
    # Then parse and ingest via pipeline
    # This requires matching EVF result page entries to our events by date

    print("  Results sync not yet implemented (PDF discovery + burst download)")
    _telegram(bot_token, chat_id,
        f"<b>EVF Results Check</b>\n<pre>{evt['txt_code']}</pre>\n<i>Checking for result PDFs...</i>"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="EVF Calendar + Results Sync")
    parser.add_argument("--mode", choices=["calendar", "results", "both"], default="both")
    parser.add_argument("--event-code", default="", help="Event code for results mode")
    args = parser.parse_args()

    ref = os.environ["SUPABASE_CERT_REF"]
    token = os.environ["SUPABASE_ACCESS_TOKEN"]
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")

    if args.mode in ("calendar", "both"):
        sync_calendar(ref, token, bot_token, chat_id)

    if args.mode in ("results", "both"):
        sync_results(ref, token, bot_token, chat_id, args.event_code)


if __name__ == "__main__":
    main()
