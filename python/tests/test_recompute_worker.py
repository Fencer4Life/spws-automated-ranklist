"""M5 — debounced recompute worker + DEDUP_SWEEP (ADR-072 / ADR-071).

Plan IDs N5.1–N5.6. Maps to FR-114 (dedup sweep via fn_merge_fencers) and
FR-115 (self-healing recompute: debounce / claim / coalesce / quiescence).
The CDC trigger + enqueue + merge SQL is covered live by pgTAP 44.1–44.11.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from python.pipeline import run as run_module
from python.pipeline.core.contract import Services
from python.pipeline.engine.flows import Flow, FlowParams
from python.pipeline.recompute.worker import drain_recompute_queue, report_identity_overrides


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
        now = datetime(2026, 6, 15, 12, 0, tzinfo=UTC)
        db = _queue_db(now - timedelta(seconds=30), [5, 7])
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=MagicMock())
        assert out == []
        db.claim_recompute_batch.assert_not_called()

    def test_drains_once_quiet(self):
        """N5.2 quiet >= window -> claim, recompute each event once, mark done."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=UTC)
        db = _queue_db(now - timedelta(seconds=200), [5, 7])
        run = MagicMock()
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=run)
        assert out == [5, 7]
        assert [c.args[0] for c in run.call_args_list] == [5, 7]  # one run per event
        db.mark_recompute_done.assert_called_once_with([5, 7])

    def test_quiescent_when_queue_empty(self):
        """N5.3 quiet but empty queue -> no-op (the loop has settled)."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=UTC)
        db = _queue_db(now - timedelta(seconds=300), [])
        run = MagicMock()
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=run)
        assert out == []
        run.assert_not_called()
        db.mark_recompute_done.assert_not_called()

    def test_iso_string_watermark_parsed(self):
        """N5.4 a string watermark (PostgREST returns ISO text) is handled."""
        now = datetime(2026, 6, 15, 12, 0, tzinfo=UTC)
        db = _queue_db((now - timedelta(seconds=10)).isoformat(), [9])
        out = drain_recompute_queue(db, now=now, debounce_window=120, run_recompute=MagicMock())
        assert out == []  # 10s < 120s -> still holds


# ---------------------------------------------------------------------------
# DEDUP_SWEEP — whole-roster dedup via fn_merge_fencers
# ---------------------------------------------------------------------------


class TestDedupSweep:
    def test_sweep_merges_exact_duplicates(self):
        """N5.5 DEDUP_SWEEP merges duplicate fencers via the merge primitive."""
        fencers = [
            {
                "id_fencer": 1,
                "txt_surname": "KOWALSKI",
                "txt_first_name": "Jan",
                "txt_nationality": "PL",
                "json_name_aliases": [],
            },
            {
                "id_fencer": 2,
                "txt_surname": "KOWALSKI",
                "txt_first_name": "Jan",
                "txt_nationality": "POL",
                "json_name_aliases": [],
            },  # same person (PL==POL)
            {
                "id_fencer": 3,
                "txt_surname": "NOWAK",
                "txt_first_name": "Ola",
                "txt_nationality": "PL",
                "json_name_aliases": [],
            },  # unique -> untouched
        ]
        db = MagicMock()
        db.fetch_fencer_db.return_value = fencers
        run_module.run_flow(FlowParams(Flow.DEDUP_SWEEP), svc=Services(db=db))
        db.merge_fencers.assert_called_once_with(1, 2)  # lowest id is the survivor

    def test_sweep_noop_without_duplicates(self):
        """N5.6 a clean roster -> no merges."""
        db = MagicMock()
        db.fetch_fencer_db.return_value = [
            {
                "id_fencer": 1,
                "txt_surname": "A",
                "txt_first_name": "X",
                "txt_nationality": "PL",
                "json_name_aliases": [],
            },
            {
                "id_fencer": 2,
                "txt_surname": "B",
                "txt_first_name": "Y",
                "txt_nationality": "PL",
                "json_name_aliases": [],
            },
        ]
        run_module.run_flow(FlowParams(Flow.DEDUP_SWEEP), svc=Services(db=db))
        db.merge_fencers.assert_not_called()


# ---------------------------------------------------------------------------
# Worker CLI entry (Step C scheduling) — N5.7
# ---------------------------------------------------------------------------


class TestWorkerCli:
    def test_drain_cli_invokes_drain(self, monkeypatch):
        """N5.7 `python -m ...worker --drain` builds a connector and drains once."""
        from python.pipeline.recompute import worker

        class _FakeDb:
            """Stands in for the connector. Carries claim_identity_override_alerts
            because main() reports overrides before draining — a bare object()
            stopped modelling the interface the moment that was added."""

            def claim_identity_override_alerts(self):
                return []

        fake_db = _FakeDb()
        monkeypatch.setattr(worker, "create_db_connector", lambda: fake_db, raising=False)
        seen = {}

        def fake_drain(db, **kw):
            seen["db"] = db
            seen["debounce"] = kw.get("debounce_window")
            return [42]

        monkeypatch.setattr(worker, "drain_recompute_queue", fake_drain)
        rc = worker.main(["--drain", "--debounce", "0"])
        assert rc == 0
        assert seen["db"] is fake_db
        assert seen["debounce"] == 0


# ---------------------------------------------------------------------------
# Confirmed-birth-year overrides are announced, not merely recorded
# ---------------------------------------------------------------------------
class TestIdentityOverrideAlerts:
    """A member of the public changing a birth year somebody already CONFIRMED
    is allowed — a fencer's own declaration outranks a scraped value — but it
    must never pass unremarked. The database records it; this is the half that
    actually tells someone. Plan IDs N5.8-N5.11.
    """

    def test_reports_each_override_to_the_operator(self):
        """N5.8 every claimed override produces an alert naming both years."""
        db = MagicMock()
        db.claim_identity_override_alerts.return_value = [
            {
                "id_override": 1,
                "id_fencer": 30,
                "txt_surname": "BUJKO",
                "txt_first_name": "Paulina",
                "int_birth_year_before": 1979,
                "int_birth_year_after": 1982,
                "ts_created": "2026-09-12T10:00:00Z",
            }
        ]
        notifier = MagicMock()
        sent = report_identity_overrides(db, notifier=notifier)

        assert sent == 1
        notifier.warning.assert_called_once()
        msg = notifier.warning.call_args[0][0]
        # Both years must be in the text: "a birth year changed" is not
        # actionable, "1979 -> 1982" is.
        assert "1979" in msg and "1982" in msg
        assert "BUJKO" in msg

    def test_silent_when_there_is_nothing_to_report(self):
        """N5.9 no overrides -> no message at all.

        The value of this alert is that it is rare. A drain that says
        "0 overrides" every fifteen minutes trains the reader to ignore it,
        and the one that matters then arrives into a muted channel.
        """
        db = MagicMock()
        db.claim_identity_override_alerts.return_value = []
        notifier = MagicMock()

        assert report_identity_overrides(db, notifier=notifier) == 0
        notifier.warning.assert_not_called()

    def test_claims_even_with_no_notifier_configured(self):
        """N5.10 LOCAL has no Telegram token; the claim must not blow up."""
        db = MagicMock()
        db.claim_identity_override_alerts.return_value = [
            {
                "id_override": 1,
                "id_fencer": 30,
                "txt_surname": "BUJKO",
                "txt_first_name": "Paulina",
                "int_birth_year_before": 1979,
                "int_birth_year_after": 1982,
                "ts_created": "2026-09-12T10:00:00Z",
            }
        ]
        # Nothing is SENT (there is nowhere to send it), but the rows must
        # still be claimed — otherwise a developer's machine accumulates a
        # backlog that PROD then re-reports as if it were new.
        assert report_identity_overrides(db, notifier=None) == 0
        db.claim_identity_override_alerts.assert_called_once()

    def test_a_failed_send_never_breaks_the_drain(self):
        """N5.11 the recompute is the load-bearing work; the alert is not.

        Losing an alert is bad. Losing the self-heal that keeps the ranking
        consistent, because Telegram happened to be down, is worse.
        """
        db = MagicMock()
        db.claim_identity_override_alerts.return_value = [
            {
                "id_override": 1,
                "id_fencer": 30,
                "txt_surname": "BUJKO",
                "txt_first_name": "Paulina",
                "int_birth_year_before": 1979,
                "int_birth_year_after": 1982,
                "ts_created": "2026-09-12T10:00:00Z",
            }
        ]
        notifier = MagicMock()
        notifier.warning.side_effect = RuntimeError("telegram down")

        assert report_identity_overrides(db, notifier=notifier) == 0
