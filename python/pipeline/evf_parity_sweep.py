"""
The daily EVF parity check (ADR-053, amended 2026-10-25). It reads only.

For every EVF event at ENGINE_COMPUTED whose end date is within --max-age-days
(future events included) and that holds results on PROD:

  1. Pair it with the EVF event of EVF's results API (EvfApiClient, the client
     evf-sync reads with) that starts within three days of it, as evf-sync's
     single-event results mode does. None → nothing from EVF yet; two or more →
     named and not compared.
  2. Compare every PROD result with EVF's row of the same weapon, gender,
     category, place and surname (Polish letters folded): the field size N and
     the points (python/tools/compare_evf_points.py, EVF.PTS.01). An EVF event
     is scored by EVF's rules (ADR-066 amendment), so both are equal when PROD
     holds what EVF published.
  3. Send one Telegram message per event with a difference, naming every
     difference, and one summary per run.

It promotes nothing and annotates nothing: results reach PROD only through
promote (ADR-113 §8). A run is red only when a read fails.

CLI::

    python -m python.pipeline.evf_parity_sweep [--max-age-days 60] [--evf-empty-stop-days 30]

Tests: python/tests/test_evf_parity_sweep.py (EVFCHK.01–06).
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

PAIRING_DAYS = 3  # evf-sync pairs an event with EVF's by start date within three days


@dataclass
class CheckCounters:
    checked: int = 0
    matched: int = 0
    differ: int = 0
    empty: int = 0
    no_results: int = 0
    ambiguous: int = 0
    errors: list[str] = field(default_factory=list)
    still_empty: list[str] = field(default_factory=list)
    ambiguous_lines: list[str] = field(default_factory=list)


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


def pair_evf_event(our_start: date, evf_events: list[dict]) -> tuple[int | None, list[int] | None]:
    """The EVF event with individual results starting within three days of ours:
    (its id, None); (None, None) when there is none; (None, the ids) when there
    are two or more. Pure (EVFCHK.04)."""
    found = [
        int(e["evf_id"])
        for e in evf_events
        if e.get("has_results")
        and not e.get("is_team")
        and (starts := _to_date(e.get("date"))) is not None
        and abs((starts - our_start).days) <= PAIRING_DAYS
    ]
    if len(found) == 1:
        return found[0], None
    if not found:
        return None, None
    return None, sorted(found)


def _differences(code: str, ours: list[dict], out: dict) -> str:
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
    return "\n".join(lines)


def _summary(c: CheckCounters, stop_days: int) -> str:
    lines = [
        f"📊 EVF parity check (reads only): {c.checked} events; {c.matched} match EVF; "
        f"{c.differ} differ; {c.empty} with nothing from EVF yet; {c.no_results} without "
        f"results on PROD; {c.ambiguous} not paired; {len(c.errors)} could not be read."
    ]
    if c.still_empty:
        lines.append(f"Nothing from EVF {stop_days} days after the end: {', '.join(c.still_empty)}")
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
        window = timedelta(days=PAIRING_DAYS)
        try:
            evf_events = discover(str(min(starts) - window), str(max(starts) + window))
        except Exception as exc:  # noqa: BLE001 -- reported, every event counted as unread
            c.errors.extend(f"{e['txt_code']}: EVF events not listed ({exc})" for e, _ in held)
            held = []

    for event, ours in held:
        code = event["txt_code"]
        try:
            start = _to_date(event.get("dt_start"))
            evf_id, ambiguous = pair_evf_event(start, evf_events) if start else (None, None)
            if ambiguous:
                c.ambiguous += 1
                ids = " and ".join(str(i) for i in ambiguous)
                c.ambiguous_lines.append(
                    f"{code}: EVF events {ids} both start within {PAIRING_DAYS} days; not compared."
                )
                continue
            evf_rows = read_evf(evf_id) if evf_id is not None else []
            if not evf_rows:
                c.empty += 1
                end = _to_date(event.get("dt_end")) or start
                if end is not None and (today - end).days >= evf_empty_stop_days:
                    c.still_empty.append(code)
                continue
            out = compare_with_evf(ours, evf_rows)
            if out["mismatched"] or out["missing"]:
                c.differ += 1
                if notifier is not None:
                    notifier.warning(_differences(code, ours, out))
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
