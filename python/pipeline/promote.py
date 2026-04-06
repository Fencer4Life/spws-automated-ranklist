"""
CERT → PROD event promotion (ADR-026).

Reads event data from CERT, writes to PROD via Supabase Management API.
Per-tournament error handling — one failure doesn't block the rest.

Usage:
    python -m python.pipeline.promote --event PPW4 [--dry-run]
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
        f"int_participant_count "
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
) -> dict:
    """Ingest results into PROD tournament. Returns summary."""
    if query_fn is None:
        query_fn = lambda sql: _management_query(prod_ref, access_token, sql)

    results_json = json.dumps(results).replace("'", "''")
    rows = query_fn(
        f"SELECT fn_ingest_tournament_results({tournament_id}, '{results_json}'::JSONB)"
    )
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

            # Ingest results
            summary = write_prod_results(
                tournament_id=prod_tid,
                results=results,
                query_fn=prod_query_fn,
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Promote event from CERT to PROD")
    parser.add_argument("--event", required=True, help="Event code prefix (e.g. PPW4)")
    parser.add_argument("--dry-run", action="store_true", help="Read CERT but don't write PROD")
    args = parser.parse_args()

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
                    data={"chat_id": chat_id, "text": msg},
                    timeout=10,
                )
            except Exception:
                pass

    # Read from CERT
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
