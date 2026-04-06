"""
EVF Calendar + Results Sync CLI (ADR-028)

Orchestrates calendar scraping and result fetching from veteransfencing.eu API.
Called by .github/workflows/evf-sync.yml.

Usage:
    python -m python.scrapers.evf_sync --mode both
    python -m python.scrapers.evf_sync --mode calendar
    python -m python.scrapers.evf_sync --mode results --event-code PEW7-2025-2026
"""

from __future__ import annotations

import argparse
import json
import os
import time

import httpx

from python.scrapers.evf_calendar import (
    parse_evf_calendar_html,
    filter_by_season,
    deduplicate_events,
)
from python.scrapers.evf_results import (
    EvfApiClient,
    scrape_event_results,
    CATEGORY_MAP,
    WEAPON_MAP,
)

EVF_CALENDAR_URL = "https://www.veteransfencing.eu/calendar/"


def _management_query(ref: str, token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API."""
    for attempt in range(3):
        try:
            resp = httpx.post(
                f"https://api.supabase.com/v1/projects/{ref}/database/query",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"query": sql},
                timeout=60,
            )
            if resp.status_code in (429, 503):
                time.sleep(3 * (attempt + 1))
                continue
            if resp.status_code >= 400:
                raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text}")
            return resp.json()
        except httpx.ReadTimeout:
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("Management API: max retries exceeded")


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
        "SELECT txt_code, dt_start::TEXT, dt_end::TEXT, id_season "
        "FROM tbl_season WHERE bool_active = TRUE"
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
        f"WHERE id_season = {s['id_season']}"
    )

    new, already = deduplicate_events(filtered, existing)
    print(f"  {len(new)} new, {len(already)} already imported")

    if not new:
        print("  No new events to import")
        return

    # Generate event codes and import
    season_suffix = s["txt_code"].replace("SPWS-", "")
    import_events = []
    for evt in new:
        loc = evt.get("location", "").split(",")[0].strip().upper().replace(" ", "")[:10]
        code = f"PEW-{loc}-{season_suffix}" if not evt.get("is_team") else f"MEW-{loc}-{season_suffix}"
        evt["code"] = code
        import_events.append(evt)

    events_json = json.dumps(import_events).replace("'", "''")
    result = _management_query(ref, token,
        f"SELECT fn_import_evf_events('{events_json}'::JSONB, {s['id_season']})"
    )
    print(f"  Import result: {result}")

    _telegram(bot_token, chat_id,
        f"<b>EVF Calendar Updated</b>\n{len(new)} new event(s) imported"
    )


def sync_results(ref: str, token: str, bot_token: str, chat_id: str, event_code: str = "") -> None:
    """Fetch results from EVF API and compare/ingest."""
    print("Connecting to EVF API...")
    client = EvfApiClient(request_delay=1.0)
    client.connect()

    try:
        evf_events = client.get_events()
        print(f"  {len(evf_events)} events in EVF database")

        if event_code:
            # Find the matching EVF event for a specific SPWS event
            # Get SPWS event date to match
            spws_event = _management_query(ref, token,
                f"SELECT dt_start::TEXT, txt_name FROM tbl_event "
                f"WHERE txt_code = '{event_code}'"
            )
            if not spws_event:
                print(f"  Event {event_code} not found in CERT")
                return

            date = spws_event[0]["dt_start"]
            # Find EVF event by date
            from python.scrapers.evf_results import find_event_by_date
            evf_event = find_event_by_date(evf_events, date)
            if not evf_event:
                print(f"  No EVF event found for date {date}")
                _telegram(bot_token, chat_id,
                    f"<b>EVF Results</b>\n<pre>{event_code}</pre>\n<i>No EVF data found for {date}</i>"
                )
                return

            print(f"  Found EVF event: {evf_event['name']} (id={evf_event['id']})")
            results = scrape_event_results(evf_event["id"], client=client)
            pol = [r for r in results if r["country"] == "POL"]

            print(f"  Total: {len(results)} results, {len(pol)} Polish fencers")
            _telegram(bot_token, chat_id,
                f"<b>EVF Results</b>\n<pre>{event_code}</pre>\n"
                f"{evf_event['name']}\n"
                f"Total: <b>{len(results)}</b> fencers\n"
                f"Polish: <b>{len(pol)}</b>"
            )
        else:
            # Check all events needing results
            print("  Full results sync not yet implemented")
    finally:
        client.close()


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
