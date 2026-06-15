"""M5 — debounced recompute worker + DEDUP_SWEEP (ADR-072 / ADR-071).

Plan IDs N5.1–N5.6. Maps to FR-114 (dedup sweep via fn_merge_fencers) and
FR-115 (self-healing recompute: debounce / claim / coalesce / quiescence).
The CDC trigger + enqueue + merge SQL is covered live by pgTAP 44.1–44.11.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

from python.pipeline.core.contract import Services
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline import run as run_module
from python.pipeline.recompute.worker import drain_recompute_queue


def _queue_db(watermark, pending):
    db = MagicMock()
    db.recompute_watermark.return_value = watermark
    db.claim_recompute_batch.return_value = list(pending)
    return db


# ---------------------------------------------------------------------------
# Debounce / claim / coalesce / quiescence
# ---------------------------------------------------------------------------

class TestDrainWorker:
    def test_holds_within_debounce_window(self):
        """N5.1 quiet < DEBOUNCE_WINDOW -> hold; the queue is not even claimed."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=timezone.utc)
        db = _queue_db(now - timedelta(seconds=30), [5, 7])
        out = drain_recompute_queue(db, now=now, debounce_window=120,
                                    run_recompute=MagicMock())
        assert out == []
        db.claim_recompute_batch.assert_not_called()

    def test_drains_once_quiet(self):
        """N5.2 quiet >= window -> claim, recompute each event once, mark done."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=timezone.utc)
        db = _queue_db(now - timedelta(seconds=200), [5, 7])
        run = MagicMock()
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=run)
        assert out == [5, 7]
        assert [c.args[0] for c in run.call_args_list] == [5, 7]  # one run per event
        db.mark_recompute_done.assert_called_once_with([5, 7])

    def test_quiescent_when_queue_empty(self):
        """N5.3 quiet but empty queue -> no-op (the loop has settled)."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=timezone.utc)
        db = _queue_db(now - timedelta(seconds=300), [])
        run = MagicMock()
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=run)
        assert out == []
        run.assert_not_called()
        db.mark_recompute_done.assert_not_called()

    def test_iso_string_watermark_parsed(self):
        """N5.4 a string watermark (PostgREST returns ISO text) is handled."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=timezone.utc)
        db = _queue_db((now - timedelta(seconds=10)).isoformat(), [9])
        out = drain_recompute_queue(db, now=now, debounce_window=120,
                                    run_recompute=MagicMock())
        assert out == []  # 10s < 120s -> still holds


# ---------------------------------------------------------------------------
# DEDUP_SWEEP — whole-roster dedup via fn_merge_fencers
# ---------------------------------------------------------------------------

class TestDedupSweep:
    def test_sweep_merges_exact_duplicates(self):
        """N5.5 DEDUP_SWEEP merges duplicate fencers via the merge primitive."""
        fencers = [
            {"id_fencer": 1, "txt_surname": "KOWALSKI", "txt_first_name": "Jan",
             "txt_nationality": "PL", "json_name_aliases": []},
            {"id_fencer": 2, "txt_surname": "KOWALSKI", "txt_first_name": "Jan",
             "txt_nationality": "POL", "json_name_aliases": []},  # same person (PL==POL)
            {"id_fencer": 3, "txt_surname": "NOWAK", "txt_first_name": "Ola",
             "txt_nationality": "PL", "json_name_aliases": []},   # unique -> untouched
        ]
        db = MagicMock()
        db.fetch_fencer_db.return_value = fencers
        run_module.run_flow(FlowParams(Flow.DEDUP_SWEEP), svc=Services(db=db))
        db.merge_fencers.assert_called_once_with(1, 2)  # lowest id is the survivor

    def test_sweep_noop_without_duplicates(self):
        """N5.6 a clean roster -> no merges."""
        db = MagicMock()
        db.fetch_fencer_db.return_value = [
            {"id_fencer": 1, "txt_surname": "A", "txt_first_name": "X",
             "txt_nationality": "PL", "json_name_aliases": []},
            {"id_fencer": 2, "txt_surname": "B", "txt_first_name": "Y",
             "txt_nationality": "PL", "json_name_aliases": []},
        ]
        run_module.run_flow(FlowParams(Flow.DEDUP_SWEEP), svc=Services(db=db))
        db.merge_fencers.assert_not_called()
