"""JB27.JOIN — the joining rules and the automatic joining check (ADR-104 §7).

The organiser forms the brackets on the day; § 2 of the scoring table says how
categories should be joined. Every listing is scored as fenced. After each event
run, and after each recompute, the pipeline compares the fenced grouping with
§ 2's, stores the verdict in tbl_joining_check and sends one Telegram message
when the verdict changes. It never blocks and needs no sign-off.

`plan_brackets` is a port of the spec's reference `brackets()`
(doc/plans/joined-scoring-final-spec-2026-09-30.html, A14); the ten line-ups
below are its C1 table, verified against the reference on 30 Sep 2026.
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from python.pipeline.joined_brackets.joining_check import (
    fenced_grouping,
    plan_brackets,
    run_joining_check,
)

# ---------------------------------------------------------------------------
# JB27.JOIN.01 — plan_brackets reproduces the spec's C1 groupings
# ---------------------------------------------------------------------------

C1 = [
    # GP3-2023-2024 foil M: the exception brings V0 of 2 into V1 of 5.
    ({"V0": 2, "V1": 5, "V2": 5, "V3": 4, "V4": 1}, [["V0", "V1"], ["V2"], ["V3", "V4"]]),
    # GP1-2023-2024 épée F: V2 and V3 have 3 together, so V1 of 7 takes both.
    ({"V0": 4, "V1": 7, "V2": 2, "V3": 1}, [["V0"], ["V1", "V2", "V3"]]),
    # MPW-2025-2026 épée F: V3 is absent, so V4 joins V2.
    ({"V0": 4, "V1": 3, "V2": 5, "V4": 2}, [["V0", "V1"], ["V2", "V4"]]),
    # PPW4-2025-2026 épée M: the exception in a big field.
    ({"V0": 3, "V1": 7, "V2": 11, "V3": 7, "V4": 6}, [["V0", "V1"], ["V2"], ["V3"], ["V4"]]),
    # PPW5-2024-2025 foil M: all five categories fence together.
    ({"V0": 1, "V1": 2, "V2": 4, "V3": 1, "V4": 2}, [["V0", "V1", "V2", "V3", "V4"]]),
    # PPW3-2025-2026 sabre M: V3 of 2 joins V2, not the older V4 of 4.
    ({"V0": 1, "V1": 2, "V2": 12, "V3": 2, "V4": 4}, [["V0", "V1", "V2", "V3"], ["V4"]]),
    # PPW4-2024-2025 foil M: key 6 decides a tie, largest bracket 7 against 8.
    ({"V0": 1, "V1": 4, "V2": 3, "V3": 2, "V4": 2}, [["V0", "V1"], ["V2", "V3", "V4"]]),
    # PPW4-2025-2026 foil M: key 6 decides a tie, largest bracket 6 against 7.
    ({"V0": 3, "V1": 1, "V2": 2, "V3": 3, "V4": 2}, [["V0", "V1", "V2"], ["V3", "V4"]]),
    # GP1-2023-2024 foil F: two women, one meeting.
    ({"V3": 2}, [["V3"]]),
    # PPW5-2024-2025 sabre F: three categories, three women, one meeting.
    ({"V0": 1, "V3": 1, "V4": 1}, [["V0", "V3", "V4"]]),
]


@pytest.mark.parametrize(("sizes", "expected"), C1)
def test_plan_brackets_reproduces_c1(sizes, expected):
    """JB27.JOIN.01 § 2's grouping for each real line-up of the spec's C1."""
    assert plan_brackets(sizes) == expected


def test_fenced_grouping_reads_the_stored_orders():
    """JB27.JOIN.01 the stored orders give the fenced grouping and every
    category's size, fencers never stored included; siblings share one order."""
    groups, sizes = fenced_grouping(["22333", "22333", "4"])
    assert groups == [["V2", "V3"], ["V4"]]
    assert sizes == {"V2": 2, "V3": 3, "V4": 1}


# ---------------------------------------------------------------------------
# JB27.JOIN.02 — the end-of-run check
# ---------------------------------------------------------------------------

EVENT = {"id_event": 9, "txt_code": "PPW2-2026-2027"}


def _db(orders, previous=None):
    db = MagicMock()
    db.fetch_event_joined_orders.return_value = [
        {"weapon": "SABRE", "gender": "M", "order": o} for o in orders
    ]
    db.fetch_joining_check.return_value = previous
    return db


class TestJoiningCheck:
    def test_stores_the_verdict(self):
        """JB27.JOIN.02 V2 (5) and V3 (5) fenced together; § 2 keeps them apart
        (V3 has 4 or more and is not the youngest): stored as a mismatch."""
        db = _db(["2222233333"])
        (verdict,) = run_joining_check(db, MagicMock(), EVENT)
        assert verdict.match is False
        db.upsert_joining_check.assert_called_once_with(
            9, "SABRE", "M", "V2+V3 (10)", "V2 (5) | V3 (5)", False
        )

    def test_a_new_mismatch_sends_one_message(self):
        """JB27.JOIN.02 the first mismatch sends one message; the scores stand."""
        notifier = MagicMock()
        run_joining_check(_db(["2222233333"]), notifier, EVENT)
        notifier.warning.assert_called_once_with(
            "PPW2-2026-2027 szabla M: fenced V2+V3 (10); § 2: V2 (5) | V3 (5). Scored as fenced."
        )
        notifier.info.assert_not_called()

    def test_a_repeated_verdict_sends_nothing(self):
        """JB27.JOIN.02 a second run with the same mismatch stays silent."""
        notifier = MagicMock()
        run_joining_check(_db(["2222233333"], previous=False), notifier, EVENT)
        notifier.warning.assert_not_called()
        notifier.info.assert_not_called()

    def test_a_mismatch_resolved_sends_one_message(self):
        """JB27.JOIN.02 a re-ingest that now follows § 2 says so once."""
        notifier = MagicMock()
        run_joining_check(_db(["22222", "33333"], previous=False), notifier, EVENT)
        notifier.info.assert_called_once_with(
            "PPW2-2026-2027 szabla M: the brackets now follow § 2: V2 (5) | V3 (5)."
        )
        notifier.warning.assert_not_called()

    def test_a_first_match_sends_nothing(self):
        """JB27.JOIN.02 brackets that follow § 2 from the start are not news."""
        notifier = MagicMock()
        (verdict,) = run_joining_check(_db(["22222", "33333"]), notifier, EVENT)
        assert verdict.match is True
        notifier.warning.assert_not_called()
        notifier.info.assert_not_called()

    def test_it_never_blocks(self):
        """JB27.JOIN.02 a failing read or write is logged, never raised: the
        results are already committed."""
        db = _db(["2222233333"])
        db.fetch_event_joined_orders.side_effect = RuntimeError("database down")
        assert run_joining_check(db, MagicMock(), EVENT) == []
        db = _db(["2222233333"])
        db.upsert_joining_check.side_effect = RuntimeError("database down")
        run_joining_check(db, MagicMock(), EVENT)

    def test_it_runs_at_the_end_of_an_event_run(self):
        """JB27.JOIN.02 the event run calls the check once, after the event's
        listings are committed, and a failing check never fails the run."""
        from python.pipeline import ingest_cli

        db, notifier = MagicMock(), MagicMock()
        with patch(
            "python.pipeline.joined_brackets.joining_check.run_joining_check",
            side_effect=RuntimeError("boom"),
        ) as check:
            ingest_cli._after_event_run(EVENT, db, notifier)
        check.assert_called_once_with(db, notifier, EVENT)

    def test_it_runs_after_a_recompute(self):
        """JB27.JOIN.02 a recompute of an event re-checks its joining."""
        from python.pipeline.core.contract import Services
        from python.pipeline.recompute import worker

        db, notifier = MagicMock(), MagicMock()
        db.find_event_by_id.return_value = EVENT
        with (
            patch("python.pipeline.run.run_flow"),
            patch("python.pipeline.joined_brackets.joining_check.run_joining_check") as check,
        ):
            worker._default_run_recompute(9, db=db, svc=Services(db=db, notifier=notifier))
        check.assert_called_once_with(db, notifier, EVENT)


# ---------------------------------------------------------------------------
# JB27.JOIN.02 — the connector: the stored orders in, the verdict out
# ---------------------------------------------------------------------------


class TestJoiningCheckConnector:
    def test_reads_the_orders_of_the_event(self):
        """JB27.JOIN.02 one row per category tournament that stores an order."""
        from python.pipeline.db_connector import DbConnector

        sb = MagicMock()
        q = sb.table.return_value.select.return_value.eq.return_value.not_.is_.return_value
        q.execute.return_value.data = [
            {"enum_weapon": "SABRE", "enum_gender": "M", "txt_joined_order": "2222233333"},
        ]
        rows = DbConnector(sb).fetch_event_joined_orders(9)
        assert rows == [{"weapon": "SABRE", "gender": "M", "order": "2222233333"}]
        sb.table.assert_called_with("tbl_tournament")
        sb.table.return_value.select.return_value.eq.assert_called_with("id_event", 9)

    def test_reads_the_previous_verdict(self):
        """JB27.JOIN.02 the stored verdict, or None before the first check."""
        from python.pipeline.db_connector import DbConnector

        sb = MagicMock()
        q = sb.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value
        q.execute.return_value.data = [{"bool_match": False}]
        assert DbConnector(sb).fetch_joining_check(9, "SABRE", "M") is False
        q.execute.return_value.data = []
        assert DbConnector(sb).fetch_joining_check(9, "SABRE", "M") is None

    def test_stores_the_verdict_once_per_listing(self):
        """JB27.JOIN.02 one row per event, weapon and gender, replaced each run."""
        from python.pipeline.db_connector import DbConnector

        sb = MagicMock()
        DbConnector(sb).upsert_joining_check(
            9, "SABRE", "M", "V2+V3 (10)", "V2 (5) | V3 (5)", False
        )
        sb.table.assert_called_with("tbl_joining_check")
        (row,), kwargs = sb.table.return_value.upsert.call_args
        assert row == {
            "id_event": 9,
            "enum_weapon": "SABRE",
            "enum_gender": "M",
            "txt_fenced": "V2+V3 (10)",
            "txt_rule": "V2 (5) | V3 (5)",
            "bool_match": False,
        }
        assert kwargs == {"on_conflict": "id_event,enum_weapon,enum_gender"}
