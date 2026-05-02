"""
Tests for python/pipeline/evf_parity_sweep.py — Phase 4 (ADR-053) daily cron.

Plan IDs P4.SW.1 – P4.SW.5.
"""

from __future__ import annotations

from datetime import date
from unittest.mock import MagicMock

import pytest

from python.pipeline.evf_parity_sweep import run_sweep


def _make_db(events, local_results=None, promote_response=None):
    db = MagicMock()
    db.evf_events_pending_parity.return_value = events
    db.event_results_for_parity.return_value = local_results or []
    db.promote_evf_published.return_value = promote_response or {
        "id_event": 1, "fencers_overwritten": 1
    }
    return db


def test_sweep_promotes_on_parity_pass():
    """P4.SW.1 sweep promotes EVF event when parity PASSes."""
    events = [{
        "id_event": 1, "txt_code": "PEW3-2025-2026",
        "dt_end": date(2026, 4, 1),
    }]
    local = [{
        "id_fencer": 10, "fencer_name": "Adam Kowalski",
        "int_place": 1, "num_final_score": 50.0,
    }]
    db = _make_db(events, local_results=local)
    notifier = MagicMock()

    def fetch(event):
        return [{"name": "Adam Kowalski", "pos": 1, "points": 50.0}]

    counters = run_sweep(
        db=db, fetch_evf_api=fetch, notifier=notifier,
        max_age_days=365, evf_empty_stop_days=30,
        today=date(2026, 4, 15),
    )

    assert counters.promoted == 1
    assert counters.failed == 0
    db.promote_evf_published.assert_called_once()
    notifier.notify_evf_promoted.assert_called_once()
    notifier.notify_parity_sweep_summary.assert_called_once()


def test_sweep_annotates_on_parity_fail():
    """P4.SW.2 sweep annotates txt_parity_notes when parity FAILs."""
    events = [{
        "id_event": 1, "txt_code": "PEW3-2025-2026",
        "dt_end": date(2026, 4, 1),
    }]
    local = [{
        "id_fencer": 10, "fencer_name": "Adam Kowalski",
        "int_place": 1, "num_final_score": 50.0,
    }]
    db = _make_db(events, local_results=local)

    def fetch(event):
        return [{"name": "Adam Kowalski", "pos": 1, "points": 60.0}]  # Δ=10 > 0.5

    counters = run_sweep(
        db=db, fetch_evf_api=fetch, notifier=None,
        max_age_days=365, today=date(2026, 4, 15),
    )

    assert counters.failed == 1
    assert counters.promoted == 0
    db.annotate_parity_fail.assert_called_once()
    db.promote_evf_published.assert_not_called()


def test_sweep_empty_evf_within_window_no_op():
    """P4.SW.3 EVF empty + within retry window → counted as empty, no annotation."""
    events = [{
        "id_event": 1, "txt_code": "PEW3-2025-2026",
        "dt_end": date(2026, 4, 1),
    }]
    db = _make_db(events)

    counters = run_sweep(
        db=db, fetch_evf_api=lambda e: [], notifier=None,
        max_age_days=365, evf_empty_stop_days=30,
        today=date(2026, 4, 15),  # 14 days past dt_end → within window
    )

    assert counters.empty == 1
    assert counters.annotated_30d == 0
    db.annotate_parity_fail.assert_not_called()


def test_sweep_empty_evf_after_30d_annotates():
    """P4.SW.4 EVF empty + past 30d window → annotate "EVF API empty after 30 days"."""
    events = [{
        "id_event": 1, "txt_code": "PEW3-2025-2026",
        "dt_end": date(2026, 4, 1),
    }]
    db = _make_db(events)
    notifier = MagicMock()

    counters = run_sweep(
        db=db, fetch_evf_api=lambda e: [], notifier=notifier,
        max_age_days=365, evf_empty_stop_days=30,
        today=date(2026, 5, 5),  # 34 days past dt_end → past window
    )

    assert counters.annotated_30d == 1
    db.annotate_parity_fail.assert_called_once()
    args = db.annotate_parity_fail.call_args[0]
    assert "30 days" in args[1]
    notifier.notify_evf_api_empty.assert_called_once()


def test_sweep_summary_reflects_buckets():
    """P4.SW.5 sweep summary aggregates per-bucket counts correctly."""
    events = [
        {"id_event": 1, "txt_code": "A", "dt_end": date(2026, 4, 1)},  # pass
        {"id_event": 2, "txt_code": "B", "dt_end": date(2026, 4, 1)},  # empty (in window)
    ]
    db = MagicMock()
    db.evf_events_pending_parity.return_value = events
    db.event_results_for_parity.return_value = [{
        "id_fencer": 10, "fencer_name": "Adam Kowalski",
        "int_place": 1, "num_final_score": 50.0,
    }]
    db.promote_evf_published.return_value = {"fencers_overwritten": 1}

    def fetch(event):
        if event["id_event"] == 1:
            return [{"name": "Adam Kowalski", "pos": 1, "points": 50.0}]
        return []

    notifier = MagicMock()
    counters = run_sweep(
        db=db, fetch_evf_api=fetch, notifier=notifier,
        today=date(2026, 4, 15),
    )

    assert counters.checked == 2
    assert counters.promoted == 1
    assert counters.empty == 1
    notifier.notify_parity_sweep_summary.assert_called_once_with(
        n_checked=2, n_promoted=1, n_failed=0, n_empty=1
    )
