"""
List the EVF events of a season that have results at EVF and no event row. Reads only.

doc/plans/criterium-2026-add-on-all-environments-2026-10-02.html. The Paris
Criterium 2026 (EVF event 92) was scored by EVF and had no event row on any
environment. This check scans EVF's results API for the season's dates
(ADR-028) and pairs each EVF event with at most one of our international
events (PEW, MEW, MSW) whose dates lie within two days of it. An EVF event
with results and no pair is reported and the exit code is 1.

    python -m python.tools.evf_event_completeness --season SPWS-2025-2026

Tests: python/tests/test_evf_event_completeness.py (EVF.CAL.01).
"""

from __future__ import annotations

import argparse
import sys
from datetime import date

from python.pipeline.db_connector import derive_tourn_type_from_event_code

EVF_SCORED_TYPES = {"PEW", "MEW", "MSW"}
TOLERANCE_DAYS = 2


def _day(value) -> date:
    return value if isinstance(value, date) else date.fromisoformat(str(value)[:10])


def _distance(evf_day: date, start: date, end: date) -> int:
    if start <= evf_day <= end:
        return 0
    return (start - evf_day).days if evf_day < start else (evf_day - end).days


def uncovered_evf_events(
    evf_events: list[dict], our_events: list[dict], *, tolerance_days: int = TOLERANCE_DAYS
) -> list[dict]:
    """EVF events with results that no international event row covers.

    evf_events carry evf_id, name, date and has_results; our_events carry
    txt_code, dt_start and dt_end. Pairs are taken nearest first and each
    event row covers one EVF event, so two EVF events of one weekend need two
    rows.
    """
    ours = [
        (e["txt_code"], _day(e["dt_start"]), _day(e["dt_end"] or e["dt_start"]))
        for e in our_events
        if derive_tourn_type_from_event_code(e["txt_code"]) in EVF_SCORED_TYPES
    ]
    scored = [e for e in evf_events if e["has_results"]]
    pairs = sorted(
        (_distance(_day(e["date"]), start, end), i, code)
        for i, e in enumerate(scored)
        for code, start, end in ours
        if _distance(_day(e["date"]), start, end) <= tolerance_days
    )
    covered: set[int] = set()
    used: set[str] = set()
    for _dist, i, code in pairs:
        if i not in covered and code not in used:
            covered.add(i)
            used.add(code)
    return [e for i, e in enumerate(scored) if i not in covered]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--season", required=True, help="season code, e.g. SPWS-2025-2026")
    parser.add_argument("--scan-from", type=int, default=26, help="first EVF event id to scan")
    parser.add_argument("--scan-to", type=int, default=150, help="EVF event id to stop before")
    args = parser.parse_args(argv)

    from python.pipeline.db_connector import create_db_connector
    from python.scrapers.evf_results import EvfApiClient

    sb = create_db_connector()._sb
    season = (
        sb.table("tbl_season")
        .select("id_season, dt_start, dt_end")
        .eq("txt_code", args.season)
        .single()
        .execute()
        .data
    )
    ours = (
        sb.table("tbl_event")
        .select("txt_code, dt_start, dt_end")
        .eq("id_season", season["id_season"])
        .execute()
        .data
    )
    client = EvfApiClient()
    client.connect()
    try:
        evf = client.discover_season_events(
            str(season["dt_start"]),
            str(season["dt_end"]),
            scan_range=(args.scan_from, args.scan_to),
        )
    finally:
        client.close()

    missing = uncovered_evf_events(evf, [e for e in ours if e["dt_start"]])
    print(
        f"{args.season}: {sum(e['has_results'] for e in evf)} EVF events with results, "
        f"{len(missing)} without an event row"
    )
    for e in missing:
        print(f"  EVF {e['evf_id']} {e['date']} {e['name']} ({e['total_fencers']} fencers)")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
