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
    match_scraped_to_existing,
    is_in_scope,
    assert_no_future_completed,
    LogicalIntegrityError,
    STALE_WINDOW_DAYS,
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
    Raises RuntimeError if all scrape sources fail; the workflow's
    `if: failure()` step then sends a Telegram alert too.
    """
    season = _get_active_season(ref, token)
    if not season:
        print("No active season found")
        return []

    print(f"Scraping EVF calendar for {season['txt_code']}...")
    try:
        cal_events = scrape_full_season_calendar(season["dt_start"], season["dt_end"])
    except RuntimeError as exc:
        _telegram(bot_token, chat_id,
            f"<b>EVF Calendar FAILED</b>\n<pre>{str(exc)[:500]}</pre>"
        )
        raise
    print(f"  Found {len(cal_events)} circuit/championship events")

    inv = sum(1 for e in cal_events if e.get("url_invitation"))
    reg = sum(1 for e in cal_events if e.get("url_registration"))
    dln = sum(1 for e in cal_events if e.get("dt_registration_deadline"))
    print(f"  URL enrichment: inv={inv} reg={reg} deadline={dln}")

    for e in cal_events:
        fee_str = f" {e['fee_currency']}{e['fee']}" if e.get('fee') else ""
        team_str = " [TEAM]" if e.get("is_team") else ""
        weapons = ",".join(e.get("weapons", []))
        print(f"  {e['dt_start']}  {e['name']:<45} {weapons:<15}{fee_str}{team_str}")

    # Fetch the full active-season event roster ONCE (used for invariant
    # guard, in-scope filter, and dedup). Includes the columns the new
    # ADR-039 algorithm requires: country, location, dt_end, enum_status.
    existing = _management_query(ref, token,
        f"SELECT id_event, txt_code, txt_name, "
        f"dt_start::TEXT, dt_end::TEXT, "
        f"txt_country, txt_location, enum_status::TEXT "
        f"FROM tbl_event WHERE id_season = {season['id_season']}"
    )

    # Step 0 — logical-integrity guard: a future row marked COMPLETED is
    # data corruption; halt the sync and alert the admin.
    try:
        assert_no_future_completed(existing)
    except LogicalIntegrityError as exc:
        _telegram(bot_token, chat_id,
            f"<b>EVF Sync HALT</b>\n<pre>{str(exc)[:400]}</pre>\n"
            f"Manual fix required."
        )
        raise

    # Match scraped events against the FULL existing roster (so a COMPLETED
    # PEW7 still hides Salzburg from being auto-created as a venue-coded
    # duplicate). Then post-filter: only feed in-scope ones to insert/refresh
    # paths. Out-of-scope matches are silently skipped — admin territory.
    new, already = deduplicate_events(cal_events, existing)

    # Drop scraped events that are themselves stale — never auto-create
    # for a date that's > 30 days past.
    new_in_scope = [e for e in new if is_in_scope(e)]
    skipped_stale_new = len(new) - len(new_in_scope)
    if skipped_stale_new:
        print(f"  Stale-gate: not auto-creating {skipped_stale_new} stale scraped event(s) "
              f"(>{STALE_WINDOW_DAYS} days past)")
    new = new_in_scope

    if not dry_run:
        print(f"\n  {len(new)} new, {len(already)} already in CERT")

        if new:
            # Phase 2 (ADR-043): allocator owns the code; payload omits `code`.
            payload: list[dict] = []
            for evt in new:
                payload.append({
                    "name": evt.get("name", ""),
                    "dt_start": evt.get("dt_start", ""),
                    "dt_end": evt.get("dt_end") or evt.get("dt_start", ""),
                    "location": evt.get("location", ""),
                    "country": evt.get("country", ""),
                    "weapons": evt.get("weapons", []),
                    "is_team": bool(evt.get("is_team", False)),
                    "url_event": evt.get("url", "") or "",
                    "url_invitation": evt.get("url_invitation") or "",
                    "url_registration": evt.get("url_registration") or "",
                    "dt_registration_deadline": evt.get("dt_registration_deadline") or "",
                    "address": evt.get("address", ""),
                    "fee": "" if evt.get("fee") is None else str(evt["fee"]),
                    "fee_currency": evt.get("fee_currency", ""),
                })

            events_json = json.dumps(payload).replace("'", "''")
            result = _management_query(ref, token,
                f"SELECT fn_import_evf_events_v2('{events_json}'::JSONB, "
                f"{season['id_season']}) AS r"
            )
            r = result[0].get("r") if result else {}
            if isinstance(r, str):
                r = json.loads(r)
            r = r or {}
            created      = int(r.get("created", 0))
            slot_reused  = int(r.get("slot_reused", 0))
            prior_match  = int(r.get("prior_matched", 0))
            alerts       = r.get("alerts") or []

            # One Telegram message per NEXT_FREE_ALLOC alert (admin must
            # confirm the new city). Reuse / prior-match are summary-only.
            for a in alerts:
                _telegram(bot_token, chat_id,
                    f"🆕 <b>{a.get('code')}</b> — new city "
                    f"<b>{a.get('location') or '?'}</b> "
                    f"({a.get('country') or '?'}) — please confirm in admin"
                )

            _telegram(bot_token, chat_id,
                f"<b>EVF Calendar</b>\n"
                f"created={created}, slot_reused={slot_reused}, "
                f"prior_matched={prior_match}, alerts={len(alerts)}\n"
                f"URL fields: inv={inv} reg={reg} deadline={dln}"
            )

        # Refresh URL/enrichment fields on already-imported events (ADR-028
        # amendment). Only fills NULL/empty columns; admin edits preserved.
        # Skip refresh on COMPLETED/stale rows — those are admin territory.
        in_scope_existing = [e for e in existing if is_in_scope(e)]
        matched_pairs = match_scraped_to_existing(cal_events, in_scope_existing)
        refresh_payload: list[dict] = []
        for scraped, existing_row in matched_pairs:
            refresh_payload.append({
                "id_event": existing_row["id_event"],
                "url_event": scraped.get("url", "") or "",
                "url_invitation": scraped.get("url_invitation") or "",
                "url_registration": scraped.get("url_registration") or "",
                "dt_registration_deadline": scraped.get("dt_registration_deadline") or "",
                "address": scraped.get("address", ""),
                "fee": "" if scraped.get("fee") is None else str(scraped["fee"]),
                "fee_currency": scraped.get("fee_currency", ""),
                "weapons": scraped.get("weapons", []),
            })

        if refresh_payload:
            refresh_json = json.dumps(refresh_payload).replace("'", "''")
            result = _management_query(ref, token,
                f"SELECT fn_refresh_evf_event_urls('{refresh_json}'::JSONB) AS r"
            )
            r = result[0].get("r") if result else {}
            if isinstance(r, str):
                r = json.loads(r)
            touched = (r or {}).get("touched", 0)
            refreshed = (r or {}).get("refreshed", 0)
            print(f"  URL refresh: touched={touched} refreshed={refreshed}")
            _telegram(bot_token, chat_id,
                f"<b>EVF URL refresh</b>\nTouched: {touched}, refreshed: {refreshed}"
            )
    else:
        print(f"\n  [DRY RUN] {len(new)} new, {len(already)} already in CERT")
        for evt in new:
            print(f"  [DRY RUN] Would create: {evt.get('dt_start')} {evt.get('name')}")

    return cal_events


def sync_results(
    ref: str, token: str, bot_token: str, chat_id: str,
    cal_events: list[dict] | None = None,
    event_code: str = "",
    dry_run: bool = False,
    filter_stale: bool = False,
) -> None:
    """Discover EVF events with results, scrape, and compare with CERT."""
    season = _get_active_season(ref, token)
    if not season:
        print("No active season found")
        return
    season_end_year = int(season["dt_end"][:4])

    # Fetch active-season CERT events ONCE — used for invariant guard,
    # scope filter, and per-event dedup via the shared matcher.
    cert_events = _management_query(ref, token,
        f"SELECT id_event, txt_code, txt_name, "
        f"dt_start::TEXT, dt_end::TEXT, "
        f"txt_country, txt_location, enum_status::TEXT "
        f"FROM tbl_event WHERE id_season = {season['id_season']}"
    )

    # Step 0 — logical-integrity guard.
    try:
        assert_no_future_completed(cert_events)
    except LogicalIntegrityError as exc:
        _telegram(bot_token, chat_id,
            f"<b>EVF Sync HALT</b>\n<pre>{str(exc)[:400]}</pre>\n"
            f"Manual fix required."
        )
        raise

    # We pass the FULL CERT list (not pre-filtered) to _compare_and_ingest
    # so the matcher still sees COMPLETED/stale rows and avoids creating
    # venue-coded duplicates. The post-match scope check decides whether
    # to actually update the matched row.

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

        if filter_stale:
            # Skip events whose CERT row already has any tbl_result rows under
            # any child tournament (status SCORED/COMPLETED) so the daily cron
            # doesn't re-scrape what's already ingested. Keep only events whose
            # date is past dt_start AND their CERT row is empty (no results).
            scored_dates = _management_query(ref, token,
                f"SELECT DISTINCT e.dt_start::TEXT AS dt FROM tbl_event e "
                f"JOIN tbl_tournament t ON t.id_event = e.id_event "
                f"JOIN tbl_result r ON r.id_tournament = t.id_tournament "
                f"WHERE e.id_season = {season['id_season']}"
            )
            already_scored = {r["dt"] for r in scored_dates}
            before = len(events_with_results)
            events_with_results = [
                e for e in events_with_results
                if e["date"] not in already_scored
            ]
            skipped = before - len(events_with_results)
            print(f"  filter-stale: {skipped} skipped (already scored), "
                  f"{len(events_with_results)} eligible")

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

        # Scrape results for each event (the per-event scope check is done
        # inside _compare_and_ingest after we know which CERT row matches).
        for evf_evt in events_with_results:
            print(f"\n{'='*60}")
            print(f"Scraping: {evf_evt['name']} (EVF ID {evf_evt['evf_id']})")
            print(f"{'='*60}")

            all_results = scrape_event_results(evf_evt["evf_id"], client=client)
            print(f"  Total: {len(all_results)} fencers")

            # Match ALL EVF fencers against SPWS fencer DB (not just POL)
            spws_results = _match_against_spws(ref, token, all_results)
            print(f"  SPWS matches: {len(spws_results)}")

            # Compare with CERT data and optionally ingest (pass all_results for participant count)
            _compare_and_ingest(ref, token, evf_evt, spws_results, dry_run,
                                bot_token, chat_id, all_results=all_results,
                                cert_events_pool=cert_events,
                                season_end_year=season_end_year)

    finally:
        client.close()


def _match_against_spws(
    ref: str, token: str, evf_results: list[dict],
) -> list[dict]:
    """Match EVF results against SPWS fencer DB using fuzzy matcher with diacritic folding.

    Returns only the EVF results that match a known SPWS fencer, enriched with
    the matched SPWS surname (with proper diacritics) and SPWS birth year
    (used by the Layer 1E V-cat cross-check).
    """
    from python.matcher.fuzzy_match import find_best_match

    fencer_db = _management_query(ref, token,
        "SELECT id_fencer, txt_surname, txt_first_name, int_birth_year FROM tbl_fencer"
    )
    by_lookup = {f["id_fencer"]: f.get("int_birth_year") for f in fencer_db}

    matched: list[dict] = []
    for r in evf_results:
        m = find_best_match(r["fencer_name"], fencer_db, use_diacritic_folding=True)
        if m and m.id_fencer and m.confidence >= 85:
            matched.append({
                **r,
                "spws_surname": m.matched_name.split()[0] if m.matched_name else r["fencer_name"].split()[0],
                "spws_id": m.id_fencer,
                "spws_birth_year": by_lookup.get(m.id_fencer),
                "match_confidence": m.confidence,
            })

    return matched


def _compare_and_ingest(
    ref: str, token: str,
    evf_evt: dict, spws_results: list[dict],
    dry_run: bool, bot_token: str, chat_id: str,
    all_results: list[dict] | None = None,
    cert_events_pool: list[dict] | None = None,
    season_end_year: int | None = None,
) -> None:
    """Compare EVF-matched SPWS results with CERT data, ingest missing.

    Uses the shared `_find_existing_match` (ADR-039) when `cert_events_pool`
    is provided — same dedup ladder as the calendar path. Match candidates
    include COMPLETED/stale rows so we don't create venue-coded duplicates;
    the post-match scope check decides whether to update.
    """
    evf_date = evf_evt["date"]

    # Layer 1E defensive cross-check (2026-04-29). EVF API is per-category,
    # so no splitter is needed — but EVF's category for a given fencer can
    # disagree with `birth_year_to_vcat(spws_BY, season_end_year)` (different
    # age-as-of date, different season boundaries). Reassigning would break
    # the per-competition ranking, so we WARN here and let the Layer 2 DB
    # trigger be the FATAL guard.
    if season_end_year is not None:
        from python.pipeline.age_split import birth_year_to_vcat
        for r in spws_results:
            by = r.get("spws_birth_year")
            spws_vcat = birth_year_to_vcat(by, season_end_year)
            if spws_vcat and spws_vcat != r.get("category"):
                print(f"  WARN [Layer 1E] {r.get('spws_surname','?')} "
                      f"BY={by} → SPWS {spws_vcat}, but EVF places in "
                      f"{r.get('category','?')} (competition {r.get('competition_id','?')})")

    cert_events: list[dict] = []
    if cert_events_pool is not None:
        # Map the EVF API event onto the calendar-shape dict the matcher expects.
        scraped_shape = {
            "name": evf_evt.get("name", ""),
            "dt_start": evf_date,
            "country": evf_evt.get("country", ""),
            "location": evf_evt.get("location", ""),
        }
        from python.scrapers.evf_calendar import _find_existing_match
        match = _find_existing_match(scraped_shape, cert_events_pool)
        if match is not None:
            # Post-match scope gate: if matched row is COMPLETED or stale,
            # skip silently — admin owns it; do NOT auto-create a duplicate.
            if not is_in_scope(match):
                print(f"  Matched CERT event {match.get('txt_code')} is "
                      f"COMPLETED or stale — skipping (admin territory).")
                return
            cert_events = [match]
    else:
        # Legacy fallback: ad-hoc per-event query.
        cert_events = _management_query(ref, token,
            f"SELECT e.id_event, e.txt_code, e.txt_name, e.dt_start::TEXT "
            f"FROM tbl_event e "
            f"WHERE e.id_season = (SELECT id_season FROM tbl_season WHERE bool_active = TRUE) "
            f"AND e.dt_start BETWEEN '{evf_date}'::DATE - INTERVAL '3 days' "
            f"AND '{evf_date}'::DATE + INTERVAL '3 days'"
        )

    if not cert_events:
        print(f"  No matching CERT event for date {evf_date}")
        if dry_run:
            print(f"  [DRY RUN] Would create event + ingest {len(spws_results)} results")
            for r in spws_results:
                print(f"    {r['place']:>3} {r['spws_surname']:<20} {r['category']} {r['gender']} {r['weapon']}  ({r['country']})")
            return

        # Auto-create only when the EVF event itself is in scope (Step 1).
        scraped_shape = {
            "dt_end": evf_date, "dt_start": evf_date,
        }
        if not is_in_scope(scraped_shape):
            print(f"  Stale-gate: not auto-creating CERT event for {evf_date} "
                  f"(>30 days past). Admin must create manually.")
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

        # Ingest all SPWS results (pass all_results for correct participant count)
        _ingest_evf_results(ref, token, cert_event_id, spws_results, evf_date, all_results=all_results)
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
        ingested = _ingest_evf_results(ref, token, cert_event_id, evf_only_results, evf_date, all_results=all_results)
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
    """Create a new EVF event on CERT from results-path discovery (Phase 2).

    Delegates code allocation + organizer assignment to
    fn_create_evf_event_from_results, which calls the same allocator the
    calendar path uses. Returns the new id_event (or existing one if a row
    with the same allocated code already existed).
    """
    season = _management_query(ref, token,
        "SELECT id_season FROM tbl_season WHERE bool_active = TRUE"
    )
    if not season:
        return None

    name     = (evf_evt.get("name") or "").replace("'", "''")
    dt_start = evf_evt["date"]
    location = (evf_evt.get("location") or "").replace("'", "''")
    country  = (evf_evt.get("country")  or "").replace("'", "''")
    is_team  = "true" if evf_evt.get("is_team") else "false"
    evf_id   = evf_evt.get("evf_id")
    evf_id_sql = f"{int(evf_id)}" if evf_id else "NULL"

    result = _management_query(ref, token,
        f"SELECT id_event, txt_code FROM fn_create_evf_event_from_results("
        f"{season[0]['id_season']}, '{name}', '{dt_start}'::DATE, "
        f"'{location}', '{country}', {is_team}::BOOLEAN, {evf_id_sql})"
    )
    if result:
        return result[0]["id_event"]
    return None


def _ingest_evf_results(
    ref: str, token: str,
    event_id: int, results: list[dict], event_date: str,
    all_results: list[dict] | None = None,
) -> int:
    """Ingest EVF results into CERT via fn_find_or_create_tournament + fn_ingest_tournament_results.

    Args:
        all_results: Full scraped results (all fencers, not just SPWS matches).
                     Used to compute correct int_participant_count per tournament.
    """
    ingested = 0

    # Group SPWS-matched results by weapon+gender+category
    groups: dict[tuple, list[dict]] = {}
    for r in results:
        key = (r["weapon"], r["gender"], r["category"])
        groups.setdefault(key, []).append(r)

    # Group ALL results for total participant count + EVF competition id
    total_counts: dict[tuple, int] = {}
    comp_ids: dict[tuple, int] = {}
    if all_results:
        for r in all_results:
            key = (r["weapon"], r["gender"], r["category"])
            total_counts[key] = total_counts.get(key, 0) + 1
            cid = r.get("competition_id")
            if cid and key not in comp_ids:
                comp_ids[key] = int(cid)

    for (weapon, gender, category), group_results in groups.items():
        # Find or create tournament; pass EVF competition id when known so
        # the FK is set/backfilled at ingest time.
        comp_id = comp_ids.get((weapon, gender, category))
        comp_id_sql = f"{int(comp_id)}" if comp_id else "NULL"
        tourn_result = _management_query(ref, token,
            f"SELECT fn_find_or_create_tournament("
            f"{event_id}, '{weapon}', '{gender}', '{category}', "
            f"'{event_date}'::DATE, 'PEW', {comp_id_sql})"
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

        # Total participant count for this tournament (all fencers, not just SPWS)
        total_count = total_counts.get((weapon, gender, category))
        count_param = f", {total_count}" if total_count else ""

        try:
            _management_query(ref, token,
                f"SELECT fn_ingest_tournament_results({tourn_id}, '{json_str}'::JSONB{count_param})"
            )
            ingested += len(group_results)
            count_info = f" (N={total_count})" if total_count else ""
            print(f"    {weapon} {gender} {category}: {len(group_results)} results ingested{count_info}")
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
    parser.add_argument("--filter-stale", action="store_true",
                        help="Results mode: skip events that already have results in CERT.")
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
        sync_results(ref, token, bot_token, chat_id, cal_events, args.event_code,
                     args.dry_run, args.filter_stale)


if __name__ == "__main__":
    main()
