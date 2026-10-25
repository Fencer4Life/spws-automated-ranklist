"""
The daily EVF parity check (ADR-053, amended 2026-10-25). It reads only.

For every EVF event at ENGINE_COMPUTED whose end date is within --max-age-days
(future events included) and that holds results on PROD:

  1. Pair it with the EVF event of EVF's results API (EvfApiClient, the client
     evf-sync reads with) dated from three days before its start to three days
     after its end: EVF dates a championship by its last day. When two or more
     fit, the ones sharing a weapon with the results PROD holds are kept (an
     épée and a sabre event on one day). None → nothing from EVF yet; still two
     or more → named and not compared.
  2. Compare every PROD result with EVF's row of the same weapon, gender,
     category, place and surname (Polish letters folded): the field size N and
     the points (python/tools/compare_evf_points.py, EVF.PTS.01). An EVF event
     is scored by EVF's rules (ADR-066 amendment), so both are equal when PROD
     holds what EVF published. A fencer EVF lists without a place (place 9999)
     is in EVF's N but not in ours, which counts placed fencers only; where that
     alone moves the points, it is named as EVF's count, not as a difference of
     ours.
  3. Send one Telegram message per event with a difference, naming every
     difference, and one summary per run.

It promotes nothing and annotates nothing: results reach PROD only through
promote (ADR-113 §8). A run is red only when a read fails.

CLI::

    python -m python.pipeline.evf_parity_sweep [--max-age-days 60] [--evf-empty-stop-days 30]

Tests: python/tests/test_evf_parity_sweep.py (EVFCHK.01–10).
"""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Any

from python.pipeline.promotion.lifecycle import warsaw_today
from python.tools.compare_evf_points import compare_with_evf

PAIRING_DAYS = 3  # EVF's date may fall three days either side of our event's dates
EVF_NO_PLACE = 9999  # EVF's place for a fencer it lists without one


@dataclass
class CheckCounters:
    checked: int = 0
    matched: int = 0
    differ: int = 0
    evf_unplaced: int = 0
    empty: int = 0
    no_results: int = 0
    ambiguous: int = 0
    errors: list[str] = field(default_factory=list)
    still_empty: list[str] = field(default_factory=list)
    ambiguous_lines: list[str] = field(default_factory=list)
    unplaced_lines: list[str] = field(default_factory=list)


def _to_date(s: Any) -> date | None:
    """Accept date / datetime / ISO string."""
    if s is None:
        return None
    if isinstance(s, datetime):
        return s.date()
    if isinstance(s, date):
        return s
    try:
        return date.fromisoformat(str(s)[:10])
    except ValueError:
        return None


def pair_evf_event(
    our_start: date,
    evf_events: list[dict],
    *,
    our_end: date | None = None,
    weapons: set[str] | None = None,
) -> tuple[int | None, list[int] | None]:
    """The EVF event with individual results dated from three days before our
    start to three days after our end (EVF dates a championship by its last day):
    (its id, None); (None, None) when there is none; (None, the ids) when two or
    more remain once those sharing none of our weapons are set aside. Pure
    (EVFCHK.04, .08, .09)."""
    first, last = (
        our_start - timedelta(days=PAIRING_DAYS),
        (our_end or our_start) + timedelta(days=PAIRING_DAYS),
    )
    found = [
        e
        for e in evf_events
        if e.get("has_results")
        and not e.get("is_team")
        and (dated := _to_date(e.get("date"))) is not None
        and first <= dated <= last
    ]
    if len(found) > 1 and weapons:
        sharing = [e for e in found if set(e.get("weapons") or ()) & weapons]
        found = sharing or found
    ids = sorted(int(e["evf_id"]) for e in found)
    if len(ids) == 1:
        return ids[0], None
    if not ids:
        return None, None
    return None, ids


def _no_place(row: dict) -> bool:
    return row.get("p") is None or int(row["p"]) >= EVF_NO_PLACE


def _bracket(row: dict) -> tuple[str, str, str]:
    return (row["w"], row["g"], row["v"])


def _compare(
    ours: list[dict], evf_rows: list[dict]
) -> tuple[dict, dict[tuple[str, str, str], list[str]]]:
    """compare_with_evf, with EVF's fencers without a place set apart (EVFCHK.10).

    In a bracket where EVF lists a fencer without a place, EVF's N counts him and
    ours does not (placed fencers only), so EVF's N becomes its number of placed
    fencers there. A result whose N then agrees and whose points still differ
    differs by EVF's count alone: it leaves "mismatched" and its bracket is
    returned with the surnames EVF lists without a place."""
    unplaced: dict[tuple[str, str, str], list[str]] = {}
    for row in evf_rows:
        if _no_place(row):
            unplaced.setdefault(_bracket(row), []).append(str(row["surname"]))
    placed_n: dict[tuple[str, str, str], int] = {}
    for row in evf_rows:
        if not _no_place(row) and _bracket(row) in unplaced:
            placed_n[_bracket(row)] = placed_n.get(_bracket(row), 0) + 1
    evf_placed = [
        dict(row, n=placed_n[_bracket(row)]) if _bracket(row) in placed_n else row
        for row in evf_rows
        if not _no_place(row)
    ]
    out = compare_with_evf(ours, evf_placed)
    by_count = [
        m for m in out["mismatched"] if _bracket(m) in unplaced and int(m["n"]) == int(m["evf_n"])
    ]
    out["mismatched"] = [m for m in out["mismatched"] if m not in by_count]
    counted = {_bracket(m): unplaced[_bracket(m)] for m in by_count}
    return out, counted


def _evf_count_lines(counted: dict[tuple[str, str, str], list[str]]) -> list[str]:
    return [
        f"  EVF counts an unplaced fencer: {', '.join(names)} in {v} {g} {w} is in EVF's N "
        "and not in ours (placed fencers only), so the points there differ by that alone"
        for (w, g, v), names in sorted(counted.items())
    ]


def _differences(code: str, ours: list[dict], out: dict, counted: dict) -> str:
    lines = [f"{code}: {out['matched']} of {len(ours)} PROD results carry EVF's N and points"]
    for m in out["mismatched"]:
        lines.append(
            f"  differs: {m['surname']} {m['v']} {m['g']} {m['w']} {m['p']}/{m['n']} "
            f"{m['pts']} — EVF {m['p']}/{m['evf_n']} {m['evf_pts']}"
        )
    for m in out["missing"]:
        lines.append(
            f"  not in EVF's results: {m['surname']} {m['v']} {m['g']} {m['w']} {m['p']}/{m['n']}"
        )
    lines.extend(_evf_count_lines(counted))
    return "\n".join(lines)


def _summary(c: CheckCounters, stop_days: int) -> str:
    lines = [
        f"📊 EVF parity check (reads only): {c.checked} events; {c.matched} match EVF; "
        f"{c.differ} differ; {c.evf_unplaced} differ only because EVF counts an unplaced "
        f"fencer; {c.empty} with nothing from EVF yet; {c.no_results} without results on "
        f"PROD; {c.ambiguous} not paired; {len(c.errors)} could not be read."
    ]
    if c.still_empty:
        lines.append(f"Nothing from EVF {stop_days} days after the end: {', '.join(c.still_empty)}")
    lines.extend(c.unplaced_lines)
    lines.extend(c.ambiguous_lines)
    lines.extend(f"Read failed: {e}" for e in c.errors)
    return "\n".join(lines)


def run_check(
    *,
    db: Any,
    discover: Callable[[str, str], list[dict]],
    read_evf: Callable[[int], list[dict]],
    notifier: Any | None = None,
    max_age_days: int = 60,
    evf_empty_stop_days: int = 30,
    today: date | None = None,
) -> CheckCounters:
    """Compare each selected PROD event with EVF's published results; write nothing.

    Args:
        db: exposes evf_events_pending_parity(max_age_days) and
            evf_results_for_check(event_code) (rows w, g, v, n, p, surname, pts).
        discover: function(start, end) -> EVF events of the results API starting
            in that range (EvfApiClient.discover_season_events).
        read_evf: function(evf_id) -> EVF's rows w, g, v, n, p, surname, pts.
        notifier: has info() and warning(), or None.
        evf_empty_stop_days: an event this many days past its end with nothing
            from EVF is named in the summary.
    """
    c = CheckCounters()
    today = today or warsaw_today()
    held: list[tuple[dict, list[dict]]] = []
    for event in db.evf_events_pending_parity(max_age_days):
        c.checked += 1
        ours = db.evf_results_for_check(event["txt_code"])
        if ours:
            held.append((event, ours))
        else:
            c.no_results += 1

    evf_events: list[dict] = []
    if held:
        starts = [d for e, _ in held if (d := _to_date(e.get("dt_start"))) is not None]
        ends = [_to_date(e.get("dt_end")) or _to_date(e.get("dt_start")) for e, _ in held]
        window = timedelta(days=PAIRING_DAYS)
        try:
            evf_events = discover(
                str(min(starts) - window), str(max(d for d in ends if d is not None) + window)
            )
        except Exception as exc:  # noqa: BLE001 -- reported, every event counted as unread
            c.errors.extend(f"{e['txt_code']}: EVF events not listed ({exc})" for e, _ in held)
            held = []

    for event, ours in held:
        code = event["txt_code"]
        try:
            start = _to_date(event.get("dt_start"))
            end = _to_date(event.get("dt_end")) or start
            evf_id, ambiguous = (
                pair_evf_event(start, evf_events, our_end=end, weapons={r["w"] for r in ours})
                if start
                else (None, None)
            )
            if ambiguous:
                c.ambiguous += 1
                ids = " and ".join(str(i) for i in ambiguous)
                c.ambiguous_lines.append(
                    f"{code}: EVF events {ids} both fall within {PAIRING_DAYS} days of its dates "
                    "and share its weapons; not compared."
                )
                continue
            evf_rows = read_evf(evf_id) if evf_id is not None else []
            if not evf_rows:
                c.empty += 1
                if end is not None and (today - end).days >= evf_empty_stop_days:
                    c.still_empty.append(code)
                continue
            out, counted = _compare(ours, evf_rows)
            if out["mismatched"] or out["missing"]:
                c.differ += 1
                if notifier is not None:
                    notifier.warning(_differences(code, ours, out, counted))
            elif counted:
                c.evf_unplaced += 1
                c.unplaced_lines.extend(f"{code}:{line[1:]}" for line in _evf_count_lines(counted))
            else:
                c.matched += 1
        except Exception as exc:  # noqa: BLE001 -- one event never stops another
            c.errors.append(f"{code}: {exc}")

    if notifier is not None:
        notifier.info(_summary(c, evf_empty_stop_days))
    return c


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------


def _discover(start: str, end: str) -> list[dict]:
    from python.scrapers.evf_results import EvfApiClient

    client = EvfApiClient()
    client.connect()
    try:
        return client.discover_season_events(start, end)
    finally:
        client.close()


def main() -> int:
    from python.pipeline.db_connector import create_db_connector
    from python.pipeline.notifications import TelegramNotifier
    from python.tools.compare_evf_points import read_evf

    parser = argparse.ArgumentParser(description="Daily EVF parity check (ADR-053); reads only")
    parser.add_argument("--max-age-days", type=int, default=60)
    parser.add_argument("--evf-empty-stop-days", type=int, default=30)
    args = parser.parse_args()

    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"),
        os.environ.get("TELEGRAM_CHAT_ID"),
    )
    c = run_check(
        db=create_db_connector(),
        discover=_discover,
        read_evf=read_evf,
        notifier=notifier,
        max_age_days=args.max_age_days,
        evf_empty_stop_days=args.evf_empty_stop_days,
    )
    print(
        f"checked={c.checked} matched={c.matched} differ={c.differ} empty={c.empty} "
        f"no_results={c.no_results} ambiguous={c.ambiguous} errors={len(c.errors)}"
    )
    return 1 if c.errors else 0


if __name__ == "__main__":
    sys.exit(main())
