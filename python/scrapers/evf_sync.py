"""
EVF Calendar + Results Sync CLI (ADR-028)

Orchestrates calendar scraping and result fetching from veteransfencing.eu.
Uses two sources: calendar HTML (past+future) and JSON API for results.

Usage:
    python -m python.scrapers.evf_sync --mode both --dry-run
    python -m python.scrapers.evf_sync --mode calendar
    python -m python.scrapers.evf_sync --mode results --event-code PEW4-2025-2026
"""

from __future__ import annotations

import argparse
import json
import os
import time

import httpx

from python.scrapers.evf_calendar import (
    scrape_full_season_calendar,
    deduplicate_events,
)
from python.scrapers.evf_results import (
    EvfApiClient,
    scrape_event_results,
    CATEGORY_MAP,
    WEAPON_MAP,
)


def _management_query(ref: str, token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API with retry."""
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
                raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text[:200]}")
            return resp.json()
        except httpx.ReadTimeout:
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("Management API: max retries exceeded")


def _telegram(bot_token: str, chat_id: str, msg: str) -> None:
    """Send Telegram notification."""
    if not bot_token or not chat_id:
        print(f"[Telegram] {msg}")
        return
    httpx.post(
        f"https://api.telegram.org/bot{bot_token}/sendMessage",
        data={"chat_id": chat_id, "text": msg, "parse_mode": "HTML"},
        timeout=10,
    )


def _get_active_season(ref: str, token: str) -> dict | None:
    """Get active season from CERT."""
    rows = _management_query(ref, token,
        "SELECT txt_code, dt_start::TEXT, dt_end::TEXT, id_season "
        "FROM tbl_season WHERE bool_active = TRUE"
    )
    return rows[0] if rows else None


def sync_calendar(ref: str, token: str, bot_token: str, chat_id: str, dry_run: bool = False) -> list[dict]:
    """Scrape EVF calendar (past+future) and sync to CERT.

    Returns the full list of season calendar events (for use by sync_results).
    """
    season = _get_active_season(ref, token)
    if not season:
        print("No active season found")
        return []

    print(f"Scraping EVF calendar for {season['txt_code']}...")
    cal_events = scrape_full_season_calendar(season["dt_start"], season["dt_end"])
    print(f"  Found {len(cal_events)} circuit/championship events")

    for e in cal_events:
        fee_str = f" {e['fee_currency']}{e['fee']}" if e.get('fee') else ""
        team_str = " [TEAM]" if e.get("is_team") else ""
        weapons = ",".join(e.get("weapons", []))
        print(f"  {e['dt_start']}  {e['name']:<45} {weapons:<15}{fee_str}{team_str}")

    if not dry_run:
        # Get existing events for dedup
        existing = _management_query(ref, token,
            f"SELECT txt_name, dt_start::TEXT FROM tbl_event "
            f"WHERE id_season = {season['id_season']}"
        )
        new, already = deduplicate_events(cal_events, existing)
        print(f"\n  {len(new)} new, {len(already)} already in CERT")

        if new:
            season_suffix = season["txt_code"].replace("SPWS-", "")
            for evt in new:
                loc = evt.get("location", "").split(",")[0].strip().upper().replace(" ", "")[:10]
                evt["code"] = f"PEW-{loc}-{season_suffix}" if not evt.get("is_team") else f"MEW-{loc}-{season_suffix}"

            events_json = json.dumps(new).replace("'", "''")
            _management_query(ref, token,
                f"SELECT fn_import_evf_events('{events_json}'::JSONB, {season['id_season']})"
            )
            _telegram(bot_token, chat_id,
                f"<b>EVF Calendar</b>\n{len(new)} new event(s) imported"
            )
    else:
        print("\n  [DRY RUN] No changes made")

    return cal_events


def sync_results(
    ref: str, token: str, bot_token: str, chat_id: str,
    cal_events: list[dict] | None = None,
    event_code: str = "",
    dry_run: bool = False,
) -> None:
    """Discover EVF events with results, scrape, and compare with CERT."""
    season = _get_active_season(ref, token)
    if not season:
        print("No active season found")
        return

    print("\nConnecting to EVF API...")
    client = EvfApiClient(request_delay=0.5)
    client.connect()

    try:
        # Discover all season events from API
        print("Discovering season events (scanning API IDs)...")
        evf_events = client.discover_season_events(
            season["dt_start"], season["dt_end"],
            calendar_events=cal_events,
        )
        print(f"  Found {len(evf_events)} events in EVF API")

        events_with_results = [e for e in evf_events if e["has_results"] and not e["is_team"]]
        print(f"  {len(events_with_results)} have individual results")

        for e in evf_events:
            tag = "RESULTS" if e["has_results"] else "NO DATA"
            if e["is_team"]:
                tag = "TEAM"
            print(f"  {e['date']}  {e['name']:<45} {tag:>8}  {e['total_fencers']:>5} fencers")

        if event_code:
            # Filter to specific event
            spws_event = _management_query(ref, token,
                f"SELECT dt_start::TEXT FROM tbl_event WHERE txt_code = '{event_code}'"
            )
            if not spws_event:
                print(f"  Event {event_code} not found in CERT")
                return
            target_date = spws_event[0]["dt_start"]
            events_with_results = [
                e for e in events_with_results
                if abs((_parse_date(e["date"]) - _parse_date(target_date)).days) <= 3
            ]
            if not events_with_results:
                print(f"  No EVF results for {event_code} (date {target_date})")
                return

        # Scrape results for each event
        for evf_evt in events_with_results:
            print(f"\n{'='*60}")
            print(f"Scraping: {evf_evt['name']} (EVF ID {evf_evt['evf_id']})")
            print(f"{'='*60}")

            all_results = scrape_event_results(evf_evt["evf_id"], client=client)
            print(f"  Total: {len(all_results)} fencers")

            # Match ALL EVF fencers against SPWS fencer DB (not just POL)
            spws_results = _match_against_spws(ref, token, all_results)
            print(f"  SPWS matches: {len(spws_results)}")

            # Compare with CERT data and optionally ingest
            _compare_and_ingest(ref, token, evf_evt, spws_results, dry_run, bot_token, chat_id)

    finally:
        client.close()


def _match_against_spws(
    ref: str, token: str, evf_results: list[dict],
) -> list[dict]:
    """Match EVF results against SPWS fencer DB using fuzzy matcher with diacritic folding.

    Returns only the EVF results that match a known SPWS fencer, enriched with
    the matched SPWS surname (with proper diacritics).
    """
    from python.matcher.fuzzy_match import find_best_match

    fencer_db = _management_query(ref, token,
        "SELECT id_fencer, txt_surname, txt_first_name, int_birth_year FROM tbl_fencer"
    )

    matched: list[dict] = []
    for r in evf_results:
        m = find_best_match(r["fencer_name"], fencer_db, use_diacritic_folding=True)
        if m and m.id_fencer and m.confidence >= 85:
            matched.append({
                **r,
                "spws_surname": m.matched_name.split()[0] if m.matched_name else r["fencer_name"].split()[0],
                "spws_id": m.id_fencer,
                "match_confidence": m.confidence,
            })

    return matched


def _compare_and_ingest(
    ref: str, token: str,
    evf_evt: dict, spws_results: list[dict],
    dry_run: bool, bot_token: str, chat_id: str,
) -> None:
    """Compare EVF-matched SPWS results with CERT data, ingest missing."""
    evf_date = evf_evt["date"]

    # Find matching CERT event by date
    cert_events = _management_query(ref, token,
        f"SELECT e.id_event, e.txt_code, e.txt_name, e.dt_start::TEXT "
        f"FROM tbl_event e "
        f"WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE bool_active = TRUE) "
        f"AND e.dt_start BETWEEN '{evf_date}'::DATE - INTERVAL '3 days' "
        f"AND '{evf_date}'::DATE + INTERVAL '3 days' "
        f"AND EXISTS(SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event AND t.enum_type IN ('PEW','MEW'))"
    )

    if not cert_events:
        print(f"  No matching CERT event for date {evf_date}")
        if dry_run:
            print(f"  [DRY RUN] Would create event + ingest {len(spws_results)} results")
            for r in spws_results:
                print(f"    {r['place']:>3} {r['spws_surname']:<20} {r['category']} {r['gender']} {r['weapon']}  ({r['country']})")
            return

        # Create the event
        cert_event_id = _create_cert_event(ref, token, evf_evt)
        if not cert_event_id:
            print(f"  ERROR: Failed to create event")
            return
        cert_code = _management_query(ref, token,
            f"SELECT txt_code FROM tbl_event WHERE id_event = {cert_event_id}"
        )[0]["txt_code"]
        print(f"  Created event: {cert_code} (id={cert_event_id})")

        # Ingest all SPWS results
        _ingest_evf_results(ref, token, cert_event_id, spws_results, evf_date)
        _telegram(bot_token, chat_id,
            f"<b>EVF Import</b>\n<pre>{cert_code}</pre>\n"
            f"{evf_evt['name']}\n"
            f"Created event + <b>{len(spws_results)}</b> results ingested"
        )
        return

    cert_code = cert_events[0]["txt_code"]
    print(f"  CERT match: {cert_code} ({cert_events[0]['txt_name']})")

    # Get CERT results (by fencer ID for precise matching)
    cert_results = _management_query(ref, token,
        f"SELECT r.id_fencer, f.txt_surname, f.txt_first_name, r.int_place, "
        f"t.enum_weapon::TEXT, t.enum_gender::TEXT, t.enum_age_category::TEXT "
        f"FROM tbl_result r "
        f"JOIN tbl_tournament t ON r.id_tournament = t.id_tournament "
        f"JOIN tbl_event e ON t.id_event = e.id_event "
        f"JOIN tbl_fencer f ON r.id_fencer = f.id_fencer "
        f"WHERE e.txt_code = '{cert_code}'"
    )

    # Build comparable sets using fencer ID (stable across diacritics)
    evf_set = set()
    evf_details: dict[tuple, dict] = {}
    for r in spws_results:
        key = (r["spws_id"], r["place"], r["category"], r["gender"], r["weapon"])
        evf_set.add(key)
        evf_details[key] = r

    cert_set = set()
    cert_details: dict[tuple, dict] = {}
    for r in cert_results:
        key = (r["id_fencer"], r["int_place"], r["enum_age_category"], r["enum_gender"], r["enum_weapon"])
        cert_set.add(key)
        cert_details[key] = r

    both = evf_set & cert_set
    evf_only = evf_set - cert_set
    cert_only = cert_set - evf_set

    print(f"\n  EVF SPWS: {len(spws_results)}, CERT: {len(cert_results)}")
    print(f"  Match: {len(both)}, EVF-only: {len(evf_only)}, CERT-only: {len(cert_only)}")

    if evf_only:
        print(f"\n  --- EVF only (missing from CERT) ---")
        for key in sorted(evf_only, key=lambda k: (k[4], k[3], k[2], k[1])):
            r = evf_details[key]
            print(f"    {r['place']:>3} {r['spws_surname']:<20} {r['category']} {r['gender']} {r['weapon']}  ({r['country']}, {r['match_confidence']:.0f}%)")

    if cert_only:
        print(f"\n  --- CERT only (not in EVF) ---")
        for key in sorted(cert_only, key=lambda k: (k[4], k[3], k[2], k[1])):
            r = cert_details[key]
            print(f"    {r['int_place']:>3} {r['txt_surname']:<20} {r['enum_age_category']} {r['enum_gender']} {r['enum_weapon']}")

    # Ingest EVF-only results
    if evf_only and not dry_run:
        cert_event_id = cert_events[0]["id_event"]
        evf_only_results = [evf_details[k] for k in evf_only]
        ingested = _ingest_evf_results(ref, token, cert_event_id, evf_only_results, evf_date)
        print(f"\n  Ingested {ingested} EVF-only results to CERT")

    summary = (
        f"<b>EVF vs CERT: {evf_evt['name']}</b>\n"
        f"<pre>{cert_code}</pre>\n"
        f"EVF SPWS: <b>{len(spws_results)}</b>  |  CERT: <b>{len(cert_results)}</b>\n"
        f"Match: <b>{len(both)}</b>  |  EVF-only: <b>{len(evf_only)}</b>  |  CERT-only: <b>{len(cert_only)}</b>"
    )
    if evf_only and not dry_run:
        summary += f"\n<b>{ingested}</b> new results ingested"
    if not dry_run:
        _telegram(bot_token, chat_id, summary)
    else:
        print(f"\n  [DRY RUN] Would send: {summary}")


def _create_cert_event(ref: str, token: str, evf_evt: dict) -> int | None:
    """Create a new PEW event on CERT from EVF data."""
    season = _management_query(ref, token,
        "SELECT id_season, txt_code FROM tbl_season WHERE bool_active = TRUE"
    )
    if not season:
        return None

    season_suffix = season[0]["txt_code"].replace("SPWS-", "")
    loc = evf_evt.get("location", "").split(",")[0].strip().upper().replace(" ", "")[:10]
    code = f"PEW-{loc}-{season_suffix}" if not evf_evt.get("is_team") else f"MEW-{loc}-{season_suffix}"
    name = evf_evt.get("name", code)
    dt_start = evf_evt["date"]
    location = evf_evt.get("location", "")
    country = evf_evt.get("country", "")

    # Create event
    result = _management_query(ref, token,
        f"INSERT INTO tbl_event (txt_code, txt_name, id_season, id_organizer, "
        f"dt_start, txt_location, txt_country, enum_status) "
        f"VALUES ('{code}', '{name.replace(chr(39), chr(39)+chr(39))}', {season[0]['id_season']}, "
        f"(SELECT id_organizer FROM tbl_organizer WHERE txt_code = 'SPWS'), "
        f"'{dt_start}', '{location.replace(chr(39), chr(39)+chr(39))}', "
        f"'{country.replace(chr(39), chr(39)+chr(39))}', 'COMPLETED') "
        f"RETURNING id_event"
    )
    if result:
        return result[0]["id_event"]
    return None


def _ingest_evf_results(
    ref: str, token: str,
    event_id: int, results: list[dict], event_date: str,
) -> int:
    """Ingest EVF results into CERT via fn_find_or_create_tournament + fn_ingest_tournament_results."""
    ingested = 0

    # Group results by weapon+gender+category
    groups: dict[tuple, list[dict]] = {}
    for r in results:
        key = (r["weapon"], r["gender"], r["category"])
        groups.setdefault(key, []).append(r)

    for (weapon, gender, category), group_results in groups.items():
        # Find or create tournament
        tourn_result = _management_query(ref, token,
            f"SELECT fn_find_or_create_tournament("
            f"{event_id}, '{weapon}', '{gender}', '{category}', "
            f"'{event_date}'::DATE, 'PEW')"
        )
        if not tourn_result:
            print(f"    ERROR: Could not create tournament {weapon} {gender} {category}")
            continue

        tourn_id = list(tourn_result[0].values())[0]

        # Build results JSON for fn_ingest_tournament_results
        results_json = []
        for r in group_results:
            results_json.append({
                "id_fencer": r["spws_id"],
                "int_place": r["place"],
                "txt_scraped_name": r["fencer_name"],
                "num_confidence": r["match_confidence"],
                "enum_match_status": "AUTO_MATCHED",
            })

        json_str = json.dumps(results_json).replace("'", "''")

        try:
            _management_query(ref, token,
                f"SELECT fn_ingest_tournament_results({tourn_id}, '{json_str}'::JSONB)"
            )
            ingested += len(group_results)
            print(f"    {weapon} {gender} {category}: {len(group_results)} results ingested")
        except Exception as e:
            print(f"    ERROR {weapon} {gender} {category}: {e}")

    return ingested


def _parse_date(s: str):
    from datetime import datetime
    return datetime.strptime(s[:10], "%Y-%m-%d")


def main() -> None:
    parser = argparse.ArgumentParser(description="EVF Calendar + Results Sync")
    parser.add_argument("--mode", choices=["calendar", "results", "both"], default="both")
    parser.add_argument("--event-code", default="", help="SPWS event code for single event results")
    parser.add_argument("--dry-run", action="store_true", help="Compare only, don't ingest")
    args = parser.parse_args()

    ref = os.environ.get("SUPABASE_CERT_REF", "")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "")
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")

    if not ref or not token:
        print("ERROR: SUPABASE_CERT_REF and SUPABASE_ACCESS_TOKEN required")
        return

    cal_events = None

    if args.mode in ("calendar", "both"):
        cal_events = sync_calendar(ref, token, bot_token, chat_id, args.dry_run)

    if args.mode in ("results", "both"):
        sync_results(ref, token, bot_token, chat_id, cal_events, args.event_code, args.dry_run)


if __name__ == "__main__":
    main()
