"""Backfill `tbl_event.id_evf_event` and `tbl_tournament.id_evf_competition`
for already-ingested PEW + IMEW rows.

For every event with `txt_code LIKE 'PEW%' OR 'IMEW%'` that has NULL
`id_evf_event`, scan the EVF API event ID range, find the event whose
date matches our `dt_start` (±3 day tolerance), and UPDATE the FK.

For every child tournament under those events with NULL
`id_evf_competition`, look up the EVF competition by (date, weapon, gender,
category) and UPDATE the FK.

Domestic FTL/XML/Engarde-sourced rows are NEVER touched — those FKs stay
NULL by design.

Usage:
    python -m python.tools.backfill_evf_fks --env LOCAL [--dry-run]
    python -m python.tools.backfill_evf_fks --env CERT  [--dry-run]
    python -m python.tools.backfill_evf_fks --env PROD  [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import date as date_cls

from python.scrapers.evf_results import CATEGORY_MAP, EvfApiClient
from python.tools._backends import make_backend


EVF_SCAN_START = "2022-09-01"
EVF_SCAN_END   = "2026-09-01"
EVF_SCAN_RANGE = (1, 160)
EVF_DATE_TOLERANCE_DAYS = 3

# weaponId → (weapon, gender). 1-3 men's, 4-6 women's.
EVF_WEAPON_GENDER = {
    1: ("FOIL", "M"), 2: ("EPEE", "M"), 3: ("SABRE", "M"),
    4: ("FOIL", "F"), 5: ("EPEE", "F"), 6: ("SABRE", "F"),
}


@dataclass
class CompEntry:
    starts: str
    weapon: str
    gender: str
    category: str
    comp_id: int
    event_id: int


def scan_evf(client: EvfApiClient) -> list[CompEntry]:
    lo, hi = EVF_SCAN_RANGE
    entries: list[CompEntry] = []
    print(f"  scanning EVF event IDs {lo}-{hi}…", file=sys.stderr)
    for eid in range(lo, hi):
        try:
            comps = client.get_competitions(eid)
        except Exception:
            continue
        if not comps:
            continue
        # Skip events outside scan window (cheap pre-filter).
        first_starts = str(comps[0].get("starts", ""))
        if not first_starts or first_starts < EVF_SCAN_START or first_starts > EVF_SCAN_END:
            continue
        for c in comps:
            wid = c.get("weaponId")
            cat = CATEGORY_MAP.get(c.get("categoryId"))
            wg = EVF_WEAPON_GENDER.get(wid)
            if not wg or not cat:
                continue
            starts = str(c.get("starts", ""))
            if not starts or starts < EVF_SCAN_START or starts > EVF_SCAN_END:
                continue
            entries.append(CompEntry(
                starts=starts, weapon=wg[0], gender=wg[1], category=cat,
                comp_id=int(c["id"]), event_id=eid,
            ))
    print(f"  cached {len(entries)} EVF competitions", file=sys.stderr)
    return entries


def fetch_pending_events(b) -> list[dict]:
    sql = """
    SELECT json_agg(row_to_json(x))
      FROM (
        SELECT id_event, txt_code, dt_start::TEXT AS dt_start
          FROM tbl_event
         WHERE (txt_code LIKE 'PEW%' OR txt_code LIKE 'IMEW%')
           AND id_evf_event IS NULL
         ORDER BY dt_start
      ) x;
    """
    rows = b.query(sql)
    if not rows:
        return []
    if isinstance(rows[0], dict):
        return rows[0].get("json_agg") or []
    return json.loads(rows[0][0]) if rows[0][0] else []


def fetch_pending_tournaments(b) -> list[dict]:
    sql = """
    SELECT json_agg(row_to_json(x))
      FROM (
        SELECT t.id_tournament, t.txt_code,
               t.enum_weapon::TEXT  AS weapon,
               t.enum_gender::TEXT  AS gender,
               t.enum_age_category::TEXT AS category,
               t.dt_tournament::TEXT AS dt,
               e.id_event, e.id_evf_event
          FROM tbl_tournament t
          JOIN tbl_event e ON e.id_event = t.id_event
         WHERE (e.txt_code LIKE 'PEW%' OR e.txt_code LIKE 'IMEW%')
           AND t.id_evf_competition IS NULL
         ORDER BY t.dt_tournament, t.id_tournament
      ) x;
    """
    rows = b.query(sql)
    if not rows:
        return []
    if isinstance(rows[0], dict):
        return rows[0].get("json_agg") or []
    return json.loads(rows[0][0]) if rows[0][0] else []


def find_event_for_date(entries: list[CompEntry], target: str) -> int | None:
    """Match an event by date proximity (±3d) using any of its comps' starts.

    Returns the EVF event_id with the smallest delta; None if nothing within
    tolerance.
    """
    try:
        target_d = date_cls.fromisoformat(target)
    except ValueError:
        return None
    best_eid: int | None = None
    best_delta = 99
    for e in entries:
        try:
            d = date_cls.fromisoformat(e.starts)
        except ValueError:
            continue
        delta = abs((d - target_d).days)
        if delta <= EVF_DATE_TOLERANCE_DAYS and delta < best_delta:
            best_eid = e.event_id
            best_delta = delta
    return best_eid


def find_comp(entries: list[CompEntry], target_dt: str, weapon: str,
              gender: str, category: str, evf_event: int | None) -> int | None:
    """Match a competition. Prefer same evf_event; fall back to date-only."""
    try:
        target_d = date_cls.fromisoformat(target_dt)
    except ValueError:
        return None
    best: int | None = None
    best_delta = 99
    for e in entries:
        if e.weapon != weapon or e.gender != gender or e.category != category:
            continue
        if evf_event is not None and e.event_id != evf_event:
            continue
        try:
            d = date_cls.fromisoformat(e.starts)
        except ValueError:
            continue
        delta = abs((d - target_d).days)
        if delta <= EVF_DATE_TOLERANCE_DAYS and delta < best_delta:
            best = e.comp_id
            best_delta = delta
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--env", choices=["LOCAL", "CERT", "PROD"], required=True)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    b = make_backend(args.env)
    print(f"[{args.env}] loading EVF API…")
    client = EvfApiClient()
    client.connect()
    try:
        entries = scan_evf(client)
    finally:
        client.close()

    print(f"[{args.env}] fetching pending events…")
    pending_events = fetch_pending_events(b)
    print(f"[{args.env}] {len(pending_events)} events with NULL id_evf_event")

    event_updates = 0
    event_skips = 0
    sql_chunks: list[str] = []
    for ev in pending_events:
        eid_evf = find_event_for_date(entries, ev["dt_start"])
        if eid_evf is None:
            event_skips += 1
            print(f"  ! no EVF event near {ev['dt_start']} for {ev['txt_code']}",
                  file=sys.stderr)
            continue
        sql_chunks.append(
            f"UPDATE tbl_event SET id_evf_event = {eid_evf} "
            f"WHERE id_event = {ev['id_event']};"
        )
        event_updates += 1

    if sql_chunks and not args.dry_run:
        b.execute("BEGIN;\n" + "\n".join(sql_chunks) + "\nCOMMIT;")
    print(f"[{args.env}] events: {event_updates} updated, {event_skips} skipped")

    print(f"[{args.env}] fetching pending tournaments…")
    pending_tournaments = fetch_pending_tournaments(b)
    print(f"[{args.env}] {len(pending_tournaments)} tournaments with NULL id_evf_competition")

    # Re-read events post-update to get freshly-set id_evf_event values for
    # the tournament FK lookups (when not dry-run).
    if not args.dry_run and event_updates > 0:
        # Build a quick lookup id_event → id_evf_event by reading once more.
        rows = b.query(
            "SELECT id_event, id_evf_event FROM tbl_event "
            "WHERE id_evf_event IS NOT NULL"
        )
        ev_to_evf: dict[int, int] = {}
        if rows and isinstance(rows[0], dict):
            for r in rows:
                ev_to_evf[int(r["id_event"])] = int(r["id_evf_event"])
        elif rows:
            for r in rows:
                ev_to_evf[int(r[0])] = int(r[1])
    else:
        ev_to_evf = {}

    tour_updates = 0
    tour_skips = 0
    sql_chunks2: list[str] = []
    for t in pending_tournaments:
        evf_evt = t.get("id_evf_event") or ev_to_evf.get(int(t["id_event"]))
        comp_id = find_comp(entries, t["dt"], t["weapon"], t["gender"],
                            t["category"], evf_evt)
        if comp_id is None:
            tour_skips += 1
            continue
        sql_chunks2.append(
            f"UPDATE tbl_tournament SET id_evf_competition = {comp_id} "
            f"WHERE id_tournament = {t['id_tournament']};"
        )
        tour_updates += 1

    if sql_chunks2 and not args.dry_run:
        # Apply in batches of 200 to keep SQL chunk sizes reasonable.
        for i in range(0, len(sql_chunks2), 200):
            chunk = sql_chunks2[i:i+200]
            b.execute("BEGIN;\n" + "\n".join(chunk) + "\nCOMMIT;")

    print(f"[{args.env}] tournaments: {tour_updates} updated, {tour_skips} skipped")
    print(f"[{args.env}] done")


if __name__ == "__main__":
    main()
