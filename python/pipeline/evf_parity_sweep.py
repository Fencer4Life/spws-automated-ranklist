"""
Phase 4 (ADR-053) — daily EVF parity sweep cron.

Walks every event with `txt_organizer_code = 'EVF'` and
`txt_source_status = 'ENGINE_COMPUTED'`. For each:

  1. If the event is older than `--max-age-days` (default 60) → skip.
  2. Probe the EVF API for per-fencer published values.
     - On non-empty payload → run check_parity vs local.
       - PASS  → fn_promote_evf_published; flip to EVF_PUBLISHED; Telegram.
       - FAIL  → fn_annotate_parity_fail; Telegram.
     - On empty payload → if event is past +30d window, annotate
       "EVF API empty after 30 days" and stop probing.
  3. Emit a single sweep summary on completion (📊 Telegram).

CLI::

    python -m pipeline.evf_parity_sweep [--max-age-days 60] [--evf-empty-stop-days 30]

Tests: python/tests/test_evf_parity_sweep.py.
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Callable

from python.pipeline.commit_lifecycle import _fold
from python.pipeline.evf_parity import check_parity


@dataclass
class SweepCounters:
    checked: int = 0
    promoted: int = 0
    failed: int = 0
    empty: int = 0
    annotated_30d: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)


def _today() -> date:
    return date.today()


def _to_date(s: Any) -> date | None:
    """Accept date / datetime / ISO string."""
    if s is None:
        return None
    if isinstance(s, date) and not isinstance(s, datetime):
        return s
    if isinstance(s, datetime):
        return s.date()
    try:
        return date.fromisoformat(str(s)[:10])
    except ValueError:
        return None


def run_sweep(
    *,
    db: Any,
    fetch_evf_api: Callable[[dict], list[dict]],
    notifier: Any | None = None,
    max_age_days: int = 60,
    evf_empty_stop_days: int = 30,
    today: date | None = None,
) -> SweepCounters:
    """Walk pending EVF events and run the parity gate on each.

    Args:
        db: DbConnector exposing evf_events_pending_parity,
            event_results_for_parity, promote_evf_published,
            annotate_parity_fail.
        fetch_evf_api: function(event) -> list of {name, pos, points} dicts.
            Empty list = EVF API returned no rows yet for this event.
        notifier: TelegramNotifier or None.
        max_age_days: ignore events older than today − max_age_days.
        evf_empty_stop_days: after this many days past dt_end with empty
            EVF payload, annotate and stop checking.

    Returns:
        SweepCounters with per-bucket counts + any errors.
    """
    counters = SweepCounters()
    today = today or _today()
    events = db.evf_events_pending_parity(max_age_days)

    for event in events:
        counters.checked += 1
        try:
            id_event = event.get("id_event")
            event_code = event.get("txt_code") or "<unknown>"
            dt_end = _to_date(event.get("dt_end")) or _to_date(event.get("dt_start"))

            evf_payload = fetch_evf_api(event) or []
            if not evf_payload:
                # EVF API empty
                if dt_end is not None and (today - dt_end).days >= evf_empty_stop_days:
                    db.annotate_parity_fail(
                        id_event,
                        f"EVF API empty after {evf_empty_stop_days} days",
                    )
                    counters.annotated_30d += 1
                    if notifier is not None:
                        notifier.notify_evf_api_empty(event_code, evf_empty_stop_days)
                else:
                    counters.empty += 1
                continue

            local = db.event_results_for_parity(id_event)
            parity = check_parity(local, evf_payload)
            if parity.overall_pass:
                # Build promotion payload
                evf_by_name = {_fold(r.get("name")): r for r in evf_payload}
                payload = []
                for lr in local:
                    e = evf_by_name.get(_fold(lr.get("fencer_name")))
                    if e is None:
                        continue
                    payload.append({
                        "id_fencer": lr.get("id_fencer"),
                        "int_place": lr.get("int_place"),
                        "num_final_score": float(e.get("points", 0) or 0),
                    })
                promoted = db.promote_evf_published(id_event, payload)
                counters.promoted += 1
                if notifier is not None:
                    notifier.notify_evf_promoted(
                        event_code,
                        int(promoted.get("fencers_overwritten", len(payload))),
                    )
            else:
                fail_lines = [
                    f"[{f.sub_check}] {f.fencer_name}" for f in parity.fail_details
                ]
                notes = "; ".join(fail_lines[:10])
                if len(fail_lines) > 10:
                    notes += f"; +{len(fail_lines) - 10} more"
                db.annotate_parity_fail(id_event, notes)
                counters.failed += 1
                if notifier is not None:
                    notifier.notify_evf_parity_fail(event_code, parity.fail_details, notes)

        except Exception as e:  # pragma: no cover — defensive
            counters.errors.append(f"{event.get('txt_code', '?')}: {e}")
            counters.skipped += 1

    if notifier is not None:
        notifier.notify_parity_sweep_summary(
            n_checked=counters.checked,
            n_promoted=counters.promoted,
            n_failed=counters.failed,
            n_empty=counters.empty + counters.annotated_30d,
        )
    return counters


# ---------------------------------------------------------------------------
# Default fetcher — production EVF API path
# ---------------------------------------------------------------------------


def _default_fetch_evf_api(event: dict) -> list[dict]:
    """Probe the EVF API per-event and shape into [{name, pos, points}] rows.

    Real impl reuses python.scrapers.evf_results.parse_results, which knows
    how to build the EVF API URL from event_code/dt_start. Empty list when
    EVF hasn't yet published for this event.
    """
    url = (event or {}).get("url_event")
    if not url:
        return []
    try:
        import httpx
        from python.scrapers.evf_results import parse_results
    except ImportError:
        return []
    try:
        resp = httpx.get(url, timeout=30.0, follow_redirects=True)
        resp.raise_for_status()
        parsed = parse_results(resp.text, source_url=url)
    except Exception:
        return []
    out: list[dict] = []
    for r in getattr(parsed, "results", []) or []:
        pts = getattr(r, "points", None)
        if pts is None:
            continue
        out.append({
            "name": getattr(r, "fencer_name", ""),
            "pos": getattr(r, "place", 0),
            "points": float(pts),
        })
    return out


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

def main() -> int:
    from python.pipeline.db_connector import create_db_connector
    from python.pipeline.notifications import TelegramNotifier

    parser = argparse.ArgumentParser(
        description="Phase 4 (ADR-053) daily EVF parity sweep"
    )
    parser.add_argument("--max-age-days", type=int, default=60)
    parser.add_argument("--evf-empty-stop-days", type=int, default=30)
    args = parser.parse_args()

    db = create_db_connector()
    notifier = TelegramNotifier(
        os.environ.get("TELEGRAM_BOT_TOKEN"),
        os.environ.get("TELEGRAM_CHAT_ID"),
    )

    counters = run_sweep(
        db=db,
        fetch_evf_api=_default_fetch_evf_api,
        notifier=notifier,
        max_age_days=args.max_age_days,
        evf_empty_stop_days=args.evf_empty_stop_days,
    )
    print(
        f"checked={counters.checked} promoted={counters.promoted} "
        f"failed={counters.failed} empty={counters.empty} "
        f"annotated_30d={counters.annotated_30d} errors={len(counters.errors)}"
    )
    return 0 if not counters.errors else 1


if __name__ == "__main__":
    sys.exit(main())
