"""
CERT → PROD promotion (ADR-026 + 2026-04-20 amendment).

Two modes:

* ``--mode event --event PPW4``  (default — original contract, per-event,
  promotes tournaments + results).
* ``--mode calendar``            (ADR-026 amendment — propagates EVF calendar:
  new events + URL enrichment via the idempotent RPCs ``fn_import_evf_events``
  and ``fn_refresh_evf_event_urls``. Does NOT touch tournaments or results).

Calendar mode shares the ``prod-write`` GitHub Actions concurrency group with
event-promote so the two never overlap. The RPCs' idempotency is the backstop
if the group is bypassed (e.g. local runs).
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import httpx


def _management_query(ref: str, access_token: str, sql: str) -> list[dict]:
    """Execute SQL via Supabase Management API."""
    resp = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        json={"query": sql},
        timeout=30,
    )
    if resp.status_code >= 400:
        raise RuntimeError(f"Management API error ({resp.status_code}): {resp.text}")
    return resp.json()


def read_cert_event(
    event_prefix: str,
    query_fn=None,
    cert_ref: str | None = None,
    access_token: str | None = None,
) -> dict | None:
    """Read event + tournaments + results from CERT.

    Returns dict with keys: event, tournaments, results (keyed by tournament_id).
    """
    if query_fn is None:
        query_fn = lambda sql: _management_query(cert_ref, access_token, sql)

    # Find event
    rows = query_fn(
        f"SELECT id_event, txt_code AS event_code, txt_name AS event_name, "
        f"id_season, id_organizer, dt_start::TEXT, enum_status::TEXT "
        f"FROM tbl_event WHERE txt_code LIKE '{event_prefix}%' "
        f"AND id_season = (SELECT id_season FROM tbl_season WHERE bool_active = TRUE) LIMIT 1"
    )
    if not rows:
        return None

    event_row = rows[0]
    event_id = event_row["id_event"]

    event = {
        "id_event": event_id,
        "txt_code": event_row["event_code"],
        "txt_name": event_row["event_name"],
        "id_season": event_row["id_season"],
        "id_organizer": event_row["id_organizer"],
        "dt_start": event_row["dt_start"],
        "enum_status": event_row["enum_status"],
    }

    # Fetch tournaments
    tourn_rows = query_fn(
        f"SELECT id_tournament, txt_code, enum_type::TEXT, enum_weapon::TEXT, "
        f"enum_gender::TEXT, enum_age_category::TEXT, dt_tournament::TEXT, "
        f"int_participant_count, url_results "
        f"FROM tbl_tournament WHERE id_event = {event_id} ORDER BY txt_code"
    )

    # Fetch results per tournament
    results: dict[int, list[dict]] = {}
    for t in tourn_rows:
        tid = t["id_tournament"]
        result_rows = query_fn(
            f"SELECT r.id_fencer, r.int_place, mc.txt_scraped_name, "
            f"mc.num_confidence, mc.enum_status::TEXT AS enum_match_status "
            f"FROM tbl_result r "
            f"LEFT JOIN tbl_match_candidate mc ON mc.id_result = r.id_result "
            f"WHERE r.id_tournament = {tid} ORDER BY r.int_place"
        )
        results[tid] = result_rows

    # Fetch fencer names for seed export
    all_fencer_ids = set()
    for rlist in results.values():
        for r in rlist:
            if r.get("id_fencer"):
                all_fencer_ids.add(r["id_fencer"])

    fencers: dict[int, dict] = {}
    if all_fencer_ids:
        ids_str = ",".join(str(fid) for fid in all_fencer_ids)
        fencer_rows = query_fn(
            f"SELECT id_fencer, txt_surname, txt_first_name FROM tbl_fencer "
            f"WHERE id_fencer IN ({ids_str})"
        )
        for fr in fencer_rows:
            fencers[fr["id_fencer"]] = {
                "txt_surname": fr["txt_surname"],
                "txt_first_name": fr["txt_first_name"],
            }

    return {"event": event, "tournaments": tourn_rows, "results": results, "fencers": fencers}


def write_prod_tournament(
    event_id: int,
    tournament: dict,
    query_fn=None,
    prod_ref: str | None = None,
    access_token: str | None = None,
) -> int:
    """Create or find tournament on PROD. Returns PROD tournament_id."""
    if query_fn is None:
        query_fn = lambda sql: _management_query(prod_ref, access_token, sql)

    rows = query_fn(
        f"SELECT fn_find_or_create_tournament("
        f"{event_id}, "
        f"'{tournament['enum_weapon']}'::enum_weapon_type, "
        f"'{tournament['enum_gender']}'::enum_gender_type, "
        f"'{tournament['enum_age_category']}'::enum_age_category, "
        f"'{tournament['dt_tournament']}'::DATE, "
        f"'{tournament['enum_type']}'::enum_tournament_type)"
    )
    return rows[0]["fn_find_or_create_tournament"]


def write_prod_results(
    tournament_id: int,
    results: list[dict],
    query_fn=None,
    prod_ref: str | None = None,
    access_token: str | None = None,
    participant_count: int | None = None,
) -> dict:
    """Ingest results into PROD tournament. Returns summary.

    `participant_count` (optional) is forwarded to the 3-param RPC so PROD
    records the actual tournament field size. Required for international
    tournaments under ADR-038 where the POL-only payload is smaller than
    the real field — otherwise PROD scoring deflates. Falls back to
    jsonb_array_length(payload) when NULL (pre-ADR-038 behavior).
    """
    if query_fn is None:
        query_fn = lambda sql: _management_query(prod_ref, access_token, sql)

    results_json = json.dumps(results).replace("'", "''")
    if participant_count is not None:
        rpc_sql = (
            f"SELECT fn_ingest_tournament_results("
            f"{tournament_id}, '{results_json}'::JSONB, {int(participant_count)})"
        )
    else:
        rpc_sql = (
            f"SELECT fn_ingest_tournament_results("
            f"{tournament_id}, '{results_json}'::JSONB)"
        )
    rows = query_fn(rpc_sql)
    return rows[0]["fn_ingest_tournament_results"]


def promote_event(
    cert_data: dict,
    prod_event_id: int,
    prod_query_fn=None,
    prod_ref: str | None = None,
    access_token: str | None = None,
) -> dict:
    """Promote all tournaments+results from CERT to PROD.

    Returns summary with tournaments_promoted, total_results, errors.
    """
    if prod_query_fn is None:
        prod_query_fn = lambda sql: _management_query(prod_ref, access_token, sql)

    promoted = 0
    total_results = 0
    errors: list[str] = []

    for tourn in cert_data["tournaments"]:
        cert_tid = tourn["id_tournament"]
        tourn_code = tourn["txt_code"]
        results = cert_data["results"].get(cert_tid, [])

        if not results:
            # Clean up stale PROD data for tournaments with 0 results on CERT
            try:
                prod_query_fn(
                    f"DELETE FROM tbl_result WHERE id_tournament = "
                    f"(SELECT id_tournament FROM tbl_tournament WHERE txt_code = '{tourn_code}')"
                )
            except Exception:
                pass  # tournament may not exist on PROD
            continue

        try:
            # Create/find tournament on PROD
            prod_tid = write_prod_tournament(
                event_id=prod_event_id,
                tournament=tourn,
                query_fn=prod_query_fn,
            )

            # Ingest results — thread CERT's int_participant_count so PROD
            # records the actual field size, not the POL-filtered payload
            # length (ADR-038 deflation fix).
            summary = write_prod_results(
                tournament_id=prod_tid,
                results=results,
                query_fn=prod_query_fn,
                participant_count=tourn.get("int_participant_count"),
            )

            # Copy url_results if set on CERT
            if tourn.get("url_results"):
                url_escaped = tourn["url_results"].replace("'", "''")
                prod_query_fn(
                    f"UPDATE tbl_tournament SET url_results = '{url_escaped}' "
                    f"WHERE id_tournament = {prod_tid}"
                )

            promoted += 1
            total_results += len(results)
        except Exception as e:
            errors.append(f"{tourn_code}: {e}")

    # Update event status on PROD
    try:
        prod_query_fn(
            f"UPDATE tbl_event SET enum_status = 'COMPLETED' "
            f"WHERE id_event = {prod_event_id} "
            f"AND enum_status IN ('PLANNED', 'IN_PROGRESS')"
        )
    except Exception as e:
        errors.append(f"Event status update: {e}")

    return {
        "tournaments_promoted": promoted,
        "total_results": total_results,
        "errors": errors,
    }


def _get_active_season(query_fn) -> dict | None:
    """Read active season row via the given query function."""
    rows = query_fn(
        "SELECT txt_code, dt_start::TEXT, dt_end::TEXT, id_season "
        "FROM tbl_season WHERE bool_active = TRUE"
    )
    return rows[0] if rows else None


def _read_cert_evf_events(query_fn, id_season: int) -> list[dict]:
    """Fetch EVF events in the active season from CERT with all URL / enrichment fields."""
    return query_fn(
        "SELECT e.txt_code, e.txt_name, "
        "e.dt_start::TEXT AS dt_start, e.dt_end::TEXT AS dt_end, "
        "COALESCE(e.txt_location,'') AS txt_location, "
        "COALESCE(e.txt_country,'') AS txt_country, "
        "COALESCE(e.txt_venue_address,'') AS txt_venue_address, "
        "e.url_event, e.url_event_2, e.url_event_3, e.url_event_4, e.url_event_5, "
        "e.url_invitation, e.url_registration, "
        "e.dt_registration_deadline::TEXT AS dt_registration_deadline, "
        "e.num_entry_fee, "
        "COALESCE(e.txt_entry_fee_currency,'') AS txt_entry_fee_currency, "
        "(SELECT COALESCE(ARRAY_AGG(w::TEXT), ARRAY[]::TEXT[]) "
        "   FROM UNNEST(e.arr_weapons) w) AS weapons, "
        "EXISTS(SELECT 1 FROM tbl_tournament t WHERE t.id_event = e.id_event "
        "  AND t.enum_type IN ('MEW','MSW','PSW')) AS is_team "
        f"FROM tbl_event e WHERE e.id_season = {id_season} "
        "AND (e.txt_code LIKE 'PEW%' OR e.txt_code LIKE 'MEW%') "
        "ORDER BY e.dt_start"
    )


def _build_import_payload(evt: dict) -> dict:
    """Shape a CERT EVF event row into the JSONB payload fn_import_evf_events expects."""
    return {
        "code": evt["txt_code"],
        "name": evt.get("txt_name") or "",
        "dt_start": evt.get("dt_start") or "",
        "dt_end": evt.get("dt_end") or evt.get("dt_start") or "",
        "location": evt.get("txt_location") or "",
        "country": evt.get("txt_country") or "",
        "address": evt.get("txt_venue_address") or "",
        "weapons": evt.get("weapons") or [],
        "is_team": bool(evt.get("is_team", False)),
        "url_event": evt.get("url_event") or "",
        "url_invitation": evt.get("url_invitation") or "",
        "url_registration": evt.get("url_registration") or "",
        "dt_registration_deadline": evt.get("dt_registration_deadline") or "",
        "fee": "" if evt.get("num_entry_fee") is None else str(evt["num_entry_fee"]),
        "fee_currency": evt.get("txt_entry_fee_currency") or "",
    }


def _build_refresh_payload(prod_id_event: int, evt: dict) -> dict:
    """Shape a refresh payload targeting an existing PROD event by id_event.

    ADR-040: includes url_event_2..5 slots; the receiving RPC applies per-slot
    NULL-only invariant and re-compacts. Keys are always present (empty string
    when source is NULL/empty) so payload shape is stable.
    """
    return {
        "id_event": prod_id_event,
        "url_event": evt.get("url_event") or "",
        "url_event_2": evt.get("url_event_2") or "",
        "url_event_3": evt.get("url_event_3") or "",
        "url_event_4": evt.get("url_event_4") or "",
        "url_event_5": evt.get("url_event_5") or "",
        "url_invitation": evt.get("url_invitation") or "",
        "url_registration": evt.get("url_registration") or "",
        "dt_registration_deadline": evt.get("dt_registration_deadline") or "",
        "address": evt.get("txt_venue_address") or "",
        "fee": "" if evt.get("num_entry_fee") is None else str(evt["num_entry_fee"]),
        "fee_currency": evt.get("txt_entry_fee_currency") or "",
        "weapons": evt.get("weapons") or [],
    }


def promote_calendar(
    cert_query_fn=None,
    prod_query_fn=None,
    cert_ref: str | None = None,
    prod_ref: str | None = None,
    access_token: str | None = None,
    dry_run: bool = False,
) -> dict:
    """Propagate EVF calendar (new events + URL enrichment) from CERT to PROD.

    Reuses the idempotent RPCs ``fn_import_evf_events`` (insert by code, skip
    existing) and ``fn_refresh_evf_event_urls`` (fill NULLs only, never
    overwrites admin edits).

    Returns ``{"imported": int, "refreshed": int, "new_codes": [...],
    "refreshed_codes": [...]}``.
    """
    if cert_query_fn is None:
        cert_query_fn = lambda sql: _management_query(cert_ref, access_token, sql)
    if prod_query_fn is None:
        prod_query_fn = lambda sql: _management_query(prod_ref, access_token, sql)

    # Active season must exist on both sides (PROD is the driver — what PROD
    # thinks is active dictates which window we care about).
    prod_season = _get_active_season(prod_query_fn)
    if not prod_season:
        raise RuntimeError("No active season on PROD — cannot promote calendar")
    cert_season = _get_active_season(cert_query_fn)
    if not cert_season:
        raise RuntimeError("No active season on CERT — cannot promote calendar")

    # Read EVF events on both sides for the active season.
    cert_events = _read_cert_evf_events(cert_query_fn, cert_season["id_season"])
    prod_existing = prod_query_fn(
        f"SELECT id_event, txt_code FROM tbl_event "
        f"WHERE id_season = {prod_season['id_season']} "
        f"AND (txt_code LIKE 'PEW%' OR txt_code LIKE 'MEW%')"
    )
    prod_by_code = {row["txt_code"]: row["id_event"] for row in prod_existing}

    # Diff.
    new_events: list[dict] = []
    refresh_events: list[tuple[int, dict]] = []
    for evt in cert_events:
        code = evt["txt_code"]
        if code in prod_by_code:
            refresh_events.append((prod_by_code[code], evt))
        else:
            new_events.append(evt)

    summary = {
        "imported": 0,
        "refreshed": 0,
        "new_codes": [e["txt_code"] for e in new_events],
        "refreshed_codes": [e["txt_code"] for _, e in refresh_events],
    }

    if dry_run:
        return summary

    # Import new events via fn_import_evf_events on PROD.
    if new_events:
        payload = [_build_import_payload(e) for e in new_events]
        payload_json = json.dumps(payload).replace("'", "''")
        result = prod_query_fn(
            f"SELECT fn_import_evf_events('{payload_json}'::JSONB, "
            f"{prod_season['id_season']}) AS r"
        )
        rpc = (result[0].get("r") if result else {}) or {}
        if isinstance(rpc, str):
            rpc = json.loads(rpc)
        summary["imported"] = int(rpc.get("created", len(new_events)))

    # Refresh URL fields on already-present events.
    if refresh_events:
        payload = [_build_refresh_payload(pid, e) for pid, e in refresh_events]
        payload_json = json.dumps(payload).replace("'", "''")
        result = prod_query_fn(
            f"SELECT fn_refresh_evf_event_urls('{payload_json}'::JSONB) AS r"
        )
        rpc = (result[0].get("r") if result else {}) or {}
        if isinstance(rpc, str):
            rpc = json.loads(rpc)
        summary["refreshed"] = int(rpc.get("refreshed", 0))

    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Promote CERT → PROD (ADR-026)")
    parser.add_argument("--mode", choices=("event", "calendar"), default="event",
                        help="event: single-event per-result promotion (default). "
                             "calendar: EVF calendar + URL refresh (ADR-026 amendment).")
    parser.add_argument("--event", default=None,
                        help="Event code prefix (e.g. PPW4) — required when --mode event")
    parser.add_argument("--dry-run", action="store_true", help="Read but don't write PROD")
    args = parser.parse_args()

    if args.mode == "event" and not args.event:
        parser.error("--event is required when --mode=event")
    if args.mode == "calendar" and args.event:
        parser.error("--event is not accepted when --mode=calendar (calendar promotes "
                     "all EVF events for the active season)")

    access_token = os.environ["SUPABASE_ACCESS_TOKEN"]
    cert_ref = os.environ["SUPABASE_CERT_REF"]
    prod_ref = os.environ["SUPABASE_PROD_REF"]

    # Optional Telegram notification
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")

    def notify(msg: str) -> None:
        if bot_token and chat_id:
            try:
                httpx.post(
                    f"https://api.telegram.org/bot{bot_token}/sendMessage",
                    data={"chat_id": chat_id, "text": msg, "parse_mode": "HTML"},
                    timeout=10,
                )
            except Exception:
                pass

    # -------------------------- Calendar mode ---------------------------------
    if args.mode == "calendar":
        print(f"EVF calendar promote CERT ({cert_ref}) → PROD ({prod_ref})"
              + (" [DRY RUN]" if args.dry_run else ""))
        try:
            summary = promote_calendar(
                cert_ref=cert_ref,
                prod_ref=prod_ref,
                access_token=access_token,
                dry_run=args.dry_run,
            )
        except Exception as exc:
            notify(f"<b>EVF Calendar → PROD FAILED</b>\n<pre>{str(exc)[:500]}</pre>")
            raise
        print(f"  Imported: {summary['imported']} new event(s)")
        print(f"  Refreshed: {summary['refreshed']} existing event(s)")
        if summary["new_codes"]:
            print("  New: " + ", ".join(summary["new_codes"]))
        if summary["refreshed_codes"]:
            print("  Refreshed: " + ", ".join(summary["refreshed_codes"]))
        if not args.dry_run:
            notify(
                f"<b>EVF Calendar → PROD</b>\n"
                f"Imported: <b>{summary['imported']}</b> new event(s)\n"
                f"Refreshed: <b>{summary['refreshed']}</b> existing event(s)"
            )
        return

    # -------------------------- Event mode (original ADR-026) -----------------
    print(f"Reading event '{args.event}' from CERT ({cert_ref})...")
    cert_data = read_cert_event(args.event, cert_ref=cert_ref, access_token=access_token)
    if cert_data is None:
        msg = f"Event '{args.event}' not found on CERT"
        print(msg)
        notify(f"Promotion failed: {msg}")
        sys.exit(1)

    event = cert_data["event"]
    print(f"Found: {event['txt_code']} — {len(cert_data['tournaments'])} tournaments")

    if args.dry_run:
        print("DRY RUN — not writing to PROD")
        for t in cert_data["tournaments"]:
            results = cert_data["results"].get(t["id_tournament"], [])
            print(f"  {t['txt_code']}: {len(results)} results")
        return

    # Find or create event on PROD
    print(f"Finding event on PROD ({prod_ref})...")
    prod_query = lambda sql: _management_query(prod_ref, access_token, sql)

    prod_events = prod_query(
        f"SELECT id_event FROM tbl_event WHERE txt_code = '{event['txt_code']}'"
    )
    if prod_events:
        prod_event_id = prod_events[0]["id_event"]
    else:
        msg = f"Event '{event['txt_code']}' not found on PROD — create it first"
        print(msg)
        notify(f"Promotion failed: {msg}")
        sys.exit(1)

    # Promote
    print(f"Promoting to PROD event_id={prod_event_id}...")
    result = promote_event(
        cert_data=cert_data,
        prod_event_id=prod_event_id,
        prod_query_fn=prod_query,
    )

    summary = (
        f"Promoted {event['txt_code']} to PROD: "
        f"{result['tournaments_promoted']} tournaments, "
        f"{result['total_results']} results"
    )
    if result["errors"]:
        summary += f"\nErrors ({len(result['errors'])}): " + "; ".join(result["errors"])

    print(summary)
    notify(summary)


if __name__ == "__main__":
    main()
