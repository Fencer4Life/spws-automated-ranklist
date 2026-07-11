"""
CERT → PROD promotion (ADR-026 + reconciler amendment, pending sign-off).

Two modes:

* ``--mode event --event PPW4``  (default — original contract, per-event,
  promotes tournaments + results).
* ``--mode calendar``            (reconciler — converges PROD's active-season
  event set to CERT's via full Create/Update/Delete, keyed on txt_code, through
  the single RPC ``fn_mirror_events_to_prod``. No code-prefix filter: this is
  ALL active-season events, not just EVF-coded ones. Does NOT touch tournaments
  or results — those stay owned by ``promote_event``/``--mode event``).

Calendar mode shares the ``prod-write`` GitHub Actions concurrency group with
event-promote so the two never overlap. The RPC's own guards (organizer must
resolve, delete only a PLANNED zero-result event) are the backstop if the
group is bypassed (e.g. local runs).
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from functools import partial

import httpx

from python.pipeline import md_writer
from python.pipeline.md_writer import Target
from python.pipeline.reconcile_report import compute_changes, render_report


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


def _prod_code_to_id(
    prod_query_fn, table: str, id_col: str, codes: set[str | None]
) -> dict[str, int]:
    """Map txt_code → target id_* for the given table (codes are FK-resolved on PROD).

    Shared with promote_season.py — ids diverge between CERT and PROD (the
    one-time natural-key baseline left legacy ids misaligned), so every
    cross-env FK is resolved by code against the TARGET, never copied raw.
    """
    clean_codes: set[str] = {c for c in codes if c}
    if not clean_codes:
        return {}
    in_list = ", ".join("'" + c.replace("'", "''") + "'" for c in sorted(clean_codes))
    rows = prod_query_fn(
        f"SELECT txt_code, {id_col} AS id FROM {table} WHERE txt_code IN ({in_list})"
    )
    return {r["txt_code"]: int(r["id"]) for r in rows}


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
        assert cert_ref is not None and access_token is not None, (
            "read_cert_event: cert_ref and access_token are required when query_fn is not supplied"
        )
        query_fn = partial(_management_query, cert_ref, access_token)

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
            f"SELECT r.id_fencer, r.int_place, "
            f"COALESCE(NULLIF(r.txt_scraped_name,''), mc.txt_scraped_name, "
            f"  f.txt_surname || ' ' || f.txt_first_name) AS txt_scraped_name, "
            f"COALESCE(mc.num_confidence, r.num_match_confidence, 100) AS num_confidence, "
            f"r.enum_match_method::TEXT AS enum_match_method, "
            f"mc.enum_status::TEXT AS enum_match_status, "
            f"r.enum_source_age_category::TEXT AS enum_source_age_category "
            f"FROM tbl_result r "
            f"JOIN tbl_fencer f ON f.id_fencer = r.id_fencer "
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
        assert prod_ref is not None and access_token is not None, (
            "write_prod_tournament: prod_ref and access_token are required when query_fn is not supplied"
        )
        query_fn = partial(_management_query, prod_ref, access_token)

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
        assert prod_ref is not None and access_token is not None, (
            "write_prod_results: prod_ref and access_token are required when query_fn is not supplied"
        )
        query_fn = partial(_management_query, prod_ref, access_token)

    results_json = json.dumps(results).replace("'", "''")
    if participant_count is not None:
        rpc_sql = (
            f"SELECT fn_ingest_tournament_results("
            f"{tournament_id}, '{results_json}'::JSONB, {int(participant_count)})"
        )
    else:
        rpc_sql = f"SELECT fn_ingest_tournament_results({tournament_id}, '{results_json}'::JSONB)"
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
        assert prod_ref is not None and access_token is not None, (
            "promote_event: prod_ref and access_token are required when prod_query_fn is not supplied"
        )
        prod_query_fn = partial(_management_query, prod_ref, access_token)

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
            write_prod_results(
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

    # Update event status on PROD. fn_validate_event_transition rejects
    # PLANNED → COMPLETED directly, so step through IN_PROGRESS.
    try:
        prod_query_fn(
            f"UPDATE tbl_event SET enum_status = 'IN_PROGRESS' "
            f"WHERE id_event = {prod_event_id} "
            f"AND enum_status = 'PLANNED'"
        )
        prod_query_fn(
            f"UPDATE tbl_event SET enum_status = 'COMPLETED' "
            f"WHERE id_event = {prod_event_id} "
            f"AND enum_status = 'IN_PROGRESS'"
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


def _read_cert_promotable_events(query_fn, id_season: int) -> list[dict]:
    """Fetch ALL events in the active season from CERT — no code-prefix filter.

    Joins tbl_organizer to carry the REAL organizer as a code (never a raw
    id — ids diverge between CERT and PROD), and resolves id_prior_event to
    its code too, so the caller can FK-resolve both against PROD by code.
    """
    return query_fn(
        "SELECT e.txt_code, e.txt_name, e.enum_status::TEXT AS enum_status, "
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
        "e.id_evf_event, e.txt_evf_slug, "
        "o.txt_code AS organizer_code, "
        "(SELECT pe.txt_code FROM tbl_event pe WHERE pe.id_event = e.id_prior_event) AS prior_code "
        "FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {id_season} "
        "ORDER BY e.dt_start"
    )


def _build_create_payload(
    evt: dict, id_season: int, id_organizer: int | None, id_prior_event: int | None
) -> dict:
    """Shape a CERT event row + PROD-resolved FKs into fn_mirror_events_to_prod's CREATE shape."""
    return {
        "txt_code": evt["txt_code"],
        "txt_name": evt.get("txt_name") or "",
        "id_season": id_season,
        "id_organizer": id_organizer,
        "dt_start": evt.get("dt_start") or "",
        "dt_end": evt.get("dt_end") or evt.get("dt_start") or "",
        "txt_location": evt.get("txt_location") or "",
        "txt_country": evt.get("txt_country") or "",
        "enum_status": evt.get("enum_status") or "PLANNED",
        "txt_venue_address": evt.get("txt_venue_address") or "",
        "url_event": evt.get("url_event") or "",
        "url_event_2": evt.get("url_event_2") or "",
        "url_event_3": evt.get("url_event_3") or "",
        "url_event_4": evt.get("url_event_4") or "",
        "url_event_5": evt.get("url_event_5") or "",
        "url_invitation": evt.get("url_invitation") or "",
        "url_registration": evt.get("url_registration") or "",
        "dt_registration_deadline": evt.get("dt_registration_deadline") or "",
        "num_entry_fee": "" if evt.get("num_entry_fee") is None else str(evt["num_entry_fee"]),
        "txt_entry_fee_currency": evt.get("txt_entry_fee_currency") or "",
        "arr_weapons": evt.get("weapons") or [],
        "id_prior_event": id_prior_event,
        "id_evf_event": evt.get("id_evf_event"),
        "txt_evf_slug": evt.get("txt_evf_slug") or "",
    }


def _build_update_payload(prod_id_event: int, evt: dict, id_organizer: int | None) -> dict:
    """Shape the UPDATE branch's payload: identity fields overwrite, URL fields
    fill-blank-only on the SQL side (see fn_mirror_events_to_prod). Keys are
    always present (empty string when source is NULL/empty) so payload shape
    is stable regardless of which fields a given event actually has.
    """
    return {
        "id_event": prod_id_event,
        "txt_name": evt.get("txt_name") or "",
        "dt_start": evt.get("dt_start") or "",
        "dt_end": evt.get("dt_end") or evt.get("dt_start") or "",
        "txt_location": evt.get("txt_location") or "",
        "txt_country": evt.get("txt_country") or "",
        "id_organizer": id_organizer,
        "arr_weapons": evt.get("weapons") or [],
        "id_evf_event": evt.get("id_evf_event"),
        "txt_evf_slug": evt.get("txt_evf_slug") or "",
        "url_event": evt.get("url_event") or "",
        "url_event_2": evt.get("url_event_2") or "",
        "url_event_3": evt.get("url_event_3") or "",
        "url_event_4": evt.get("url_event_4") or "",
        "url_event_5": evt.get("url_event_5") or "",
        "url_invitation": evt.get("url_invitation") or "",
        "url_registration": evt.get("url_registration") or "",
        "dt_registration_deadline": evt.get("dt_registration_deadline") or "",
        "num_entry_fee": "" if evt.get("num_entry_fee") is None else str(evt["num_entry_fee"]),
        "txt_entry_fee_currency": evt.get("txt_entry_fee_currency") or "",
    }


def _read_full_events(query_fn, id_season: int) -> dict[str, dict]:
    """Snapshot every event in a season as a comparable projection keyed by txt_code.

    Column-agnostic: ``to_jsonb(row)`` minus env-local noise (raw ids,
    timestamps), with ``id_organizer``/``id_prior_event`` resolved to codes — so
    the reconcile-report diff picks up ANY field, including columns a future
    migration adds, with no change here.
    """
    rows = query_fn(
        "SELECT e.txt_code, "
        "  to_jsonb(e) "
        "    - 'id_event' - 'id_season' - 'id_organizer' - 'id_prior_event' "
        "    - 'ts_created' - 'ts_updated' "
        "  || jsonb_build_object("
        "       'organizer_code', o.txt_code, "
        "       'prior_code', (SELECT pe.txt_code FROM tbl_event pe "
        "                        WHERE pe.id_event = e.id_prior_event)"
        "     ) AS j "
        "FROM tbl_event e JOIN tbl_organizer o ON o.id_organizer = e.id_organizer "
        f"WHERE e.id_season = {id_season}"
    )
    out: dict[str, dict] = {}
    for r in rows:
        j = r["j"]
        out[r["txt_code"]] = json.loads(j) if isinstance(j, str) else dict(j)
    return out


def promote_calendar(
    cert_query_fn=None,
    prod_query_fn=None,
    cert_ref: str | None = None,
    prod_ref: str | None = None,
    access_token: str | None = None,
    dry_run: bool = False,
    report_target: Target = "none",
    supabase_client=None,
    staging_dir=None,
    timestamp: str | None = None,
    trigger: str = "manual",
) -> dict:
    """Reconcile PROD's active-season event set to CERT's — the source of truth.

    Full Create/Update/Delete, keyed on txt_code, through the single RPC
    ``fn_mirror_events_to_prod``. Every event in the active season is in
    scope (no code-prefix filter): CERT-only events are created, events on
    both sides have their identity fields overwritten from CERT (URLs stay
    fill-blank-only), and PROD-only events are deleted — guarded server-side
    to a PLANNED event with zero results. Tournaments/results are never
    touched here (owned by ``promote_event``).

    Returns ``{"created": int, "updated": int, "deleted": int,
    "delete_skipped": [...], "new_codes": [...], "updated_codes": [...],
    "deleted_codes": [...]}``.
    """
    if cert_query_fn is None:
        assert cert_ref is not None and access_token is not None, (
            "promote_calendar: cert_ref and access_token are required when cert_query_fn is not supplied"
        )
        cert_query_fn = partial(_management_query, cert_ref, access_token)
    if prod_query_fn is None:
        assert prod_ref is not None and access_token is not None, (
            "promote_calendar: prod_ref and access_token are required when prod_query_fn is not supplied"
        )
        prod_query_fn = partial(_management_query, prod_ref, access_token)

    # Active season must exist on both sides AND be the SAME season. The
    # reconciler converges one season's event set — if CERT has already
    # rolled to a new season that PROD hasn't been bootstrapped onto yet
    # (via promote_season.py), comparing CERT's new-season events against
    # PROD's old-season events would misfile creates under the wrong
    # id_season and propose deleting PROD's entire outgoing season. Fail
    # loud instead of guessing which window applies.
    prod_season = _get_active_season(prod_query_fn)
    if not prod_season:
        raise RuntimeError("No active season on PROD — cannot promote calendar")
    cert_season = _get_active_season(cert_query_fn)
    if not cert_season:
        raise RuntimeError("No active season on CERT — cannot promote calendar")
    if cert_season["txt_code"] != prod_season["txt_code"]:
        raise RuntimeError(
            f"promote_calendar: active season mismatch — CERT is on "
            f"{cert_season['txt_code']!r}, PROD is on {prod_season['txt_code']!r}. "
            "Bootstrap the new season on PROD via promote_season.py first."
        )

    # Read the full promotable event set on both sides for the active season.
    cert_events = _read_cert_promotable_events(cert_query_fn, cert_season["id_season"])
    prod_existing = prod_query_fn(
        f"SELECT id_event, txt_code FROM tbl_event WHERE id_season = {prod_season['id_season']}"
    )
    prod_by_code = {row["txt_code"]: row["id_event"] for row in prod_existing}
    cert_codes = {evt["txt_code"] for evt in cert_events}

    # Resolve organizer + prior-event codes to PROD ids in bulk (by code,
    # never a raw cross-env id — reuses the same helper promote_season.py
    # uses for the identical hazard).
    org_codes: set[str | None] = {evt.get("organizer_code") for evt in cert_events}
    prior_codes: set[str | None] = {evt.get("prior_code") for evt in cert_events}
    org_map = _prod_code_to_id(prod_query_fn, "tbl_organizer", "id_organizer", org_codes)
    prior_map = _prod_code_to_id(prod_query_fn, "tbl_event", "id_event", prior_codes)

    # Diff by txt_code.
    creates: list[dict] = []
    updates: list[dict] = []
    for evt in cert_events:
        code = evt["txt_code"]
        org_code: str | None = evt.get("organizer_code")
        prior_code: str | None = evt.get("prior_code")
        id_organizer = org_map.get(org_code) if org_code else None
        id_prior_event = prior_map.get(prior_code) if prior_code else None
        if code in prod_by_code:
            updates.append(_build_update_payload(prod_by_code[code], evt, id_organizer))
        else:
            creates.append(
                _build_create_payload(evt, prod_season["id_season"], id_organizer, id_prior_event)
            )

    deletes: list[int] = [
        prod_id for code, prod_id in prod_by_code.items() if code not in cert_codes
    ]

    summary = {
        "created": 0,
        "updated": 0,
        "deleted": 0,
        "delete_skipped": [],
        "new_codes": [e["txt_code"] for e in creates],
        "updated_codes": [u_evt["id_event"] for u_evt in updates],
        "deleted_codes": [code for code, pid in prod_by_code.items() if pid in deletes],
    }

    if dry_run:
        return summary

    # Snapshot PROD BEFORE (full projections) for the run report — only when a
    # report is actually wanted, to avoid the extra read otherwise.
    want_report = report_target != "none"
    prod_before = _read_full_events(prod_query_fn, prod_season["id_season"]) if want_report else {}

    creates_json = json.dumps(creates).replace("'", "''")
    updates_json = json.dumps(updates).replace("'", "''")
    deletes_json = json.dumps(deletes).replace("'", "''")
    result = prod_query_fn(
        "SELECT fn_mirror_events_to_prod("
        f"'{creates_json}'::JSONB, '{updates_json}'::JSONB, '{deletes_json}'::JSONB"
        ") AS r"
    )
    rpc = (result[0].get("r") if result else {}) or {}
    if isinstance(rpc, str):
        rpc = json.loads(rpc)

    summary["created"] = int(rpc.get("created", 0))
    summary["updated"] = int(rpc.get("updated", 0))
    summary["deleted"] = int(rpc.get("deleted", 0))
    summary["delete_skipped"] = rpc.get("delete_skipped", [])

    if want_report:
        # PROD after + CERT snapshots → applied changes (before→after) and
        # divergences-not-synced (CERT vs PROD-after). Column-agnostic diffs.
        prod_after = _read_full_events(prod_query_fn, prod_season["id_season"])
        cert_full = _read_full_events(cert_query_fn, cert_season["id_season"])
        applied = compute_changes(prod_before, prod_after)
        divergences = compute_changes(prod_after, cert_full)
        deleted_evidence = {
            code: f"{prod_before[code].get('enum_status', '?')}, 0 results"
            for code in applied["deleted"]
        }
        created_rows = {code: prod_after[code] for code in applied["created"]}
        ts = timestamp or datetime.datetime.now(datetime.UTC).strftime("%Y%m%d-%H%M%SZ")
        md = render_report(
            season=prod_season["txt_code"],
            timestamp=ts,
            cert_ref=cert_ref or "cert",
            prod_ref=prod_ref or "prod",
            trigger=trigger,
            season_guard_ok=True,
            applied=applied,
            deleted_evidence=deleted_evidence,
            divergences=divergences,
            rpc=rpc,
            prod_count=len(prod_after),
            cert_count=len(cert_full),
            created_rows=created_rows,
        )
        summary["report_path"] = md_writer.write_reconcile(
            season=prod_season["txt_code"],
            md_text=md,
            target=report_target,
            timestamp=ts,
            staging_dir=staging_dir,
            supabase_client=supabase_client,
        )

    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Promote CERT → PROD (ADR-026)")
    parser.add_argument(
        "--mode",
        choices=("event", "calendar"),
        default="event",
        help="event: single-event per-result promotion (default). "
        "calendar: EVF calendar + URL refresh (ADR-026 amendment).",
    )
    parser.add_argument(
        "--event", default=None, help="Event code prefix (e.g. PPW4) — required when --mode event"
    )
    parser.add_argument("--dry-run", action="store_true", help="Read but don't write PROD")
    args = parser.parse_args()

    if args.mode == "event" and not args.event:
        parser.error("--event is required when --mode=event")
    if args.mode == "calendar" and args.event:
        parser.error(
            "--event is not accepted when --mode=calendar (calendar promotes "
            "all EVF events for the active season)"
        )

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

    # -------------------------- Calendar mode (reconciler) --------------------
    if args.mode == "calendar":
        print(
            f"Calendar reconcile CERT ({cert_ref}) → PROD ({prod_ref})"
            + (" [DRY RUN]" if args.dry_run else "")
        )
        # Build a CERT Supabase client for the run-report bucket upload (best
        # effort — the local repo report is always written; the bucket upload
        # is a bonus if supabase-py + the service-role key are available).
        sb_cert = None
        cert_key = os.environ.get("SUPABASE_CERT_SERVICE_ROLE_KEY")
        if cert_key and not args.dry_run:
            try:
                from supabase import create_client

                sb_cert = create_client(f"https://{cert_ref}.supabase.co", cert_key)
            except Exception:  # noqa: BLE001 — report is best-effort, never fails the promote
                sb_cert = None
        report_target: Target = "none" if args.dry_run else ("both" if sb_cert else "local")
        trigger = os.environ.get("GITHUB_EVENT_NAME", "manual")

        try:
            summary = promote_calendar(
                cert_ref=cert_ref,
                prod_ref=prod_ref,
                access_token=access_token,
                dry_run=args.dry_run,
                report_target=report_target,
                supabase_client=sb_cert,
                trigger=trigger,
            )
        except Exception as exc:
            notify(f"<b>Calendar reconcile → PROD FAILED</b>\n<pre>{str(exc)[:500]}</pre>")
            raise
        if summary.get("report_path"):
            print(f"  Report: {summary['report_path']}")
        print(f"  Created: {summary['created']} new event(s)")
        print(f"  Updated: {summary['updated']} existing event(s)")
        print(f"  Deleted: {summary['deleted']} orphaned event(s)")
        if summary["new_codes"]:
            print("  New: " + ", ".join(summary["new_codes"]))
        if summary["deleted_codes"]:
            print("  Deleted: " + ", ".join(summary["deleted_codes"]))
        if summary["delete_skipped"]:
            print(
                "  Delete SKIPPED (results-bearing, needs investigation): "
                + ", ".join(str(x) for x in summary["delete_skipped"])
            )
        if not args.dry_run:
            notify(
                f"<b>Calendar reconcile → PROD</b>\n"
                f"Created: <b>{summary['created']}</b>  "
                f"Updated: <b>{summary['updated']}</b>  "
                f"Deleted: <b>{summary['deleted']}</b>"
                + (
                    f"\n⚠️ delete_skipped: {summary['delete_skipped']}"
                    if summary["delete_skipped"]
                    else ""
                )
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
    prod_query = partial(_management_query, prod_ref, access_token)

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
