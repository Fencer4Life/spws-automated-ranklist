"""
Tests for python/pipeline/commit_lifecycle.py — Phase 4 (ADR-046, ADR-053)
post-commit chain: cascade rename + EVF parity gate + combined Telegram.

Plan IDs P4.CL.1 – P4.CL.7.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from unittest.mock import MagicMock

import pytest

from python.pipeline.commit_lifecycle import (
    CommitLifecycleResult,
    run_post_commit_hooks,
)


# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------

@dataclass
class _Ctx:
    event: dict = field(default_factory=dict)
    pew_cascade_pending: bool = False


def _ctx(*, event_code: str = "PPW1-2025-2026", pew: bool = False, id_event: int = 7):
    return _Ctx(
        event={"id_event": id_event, "txt_code": event_code},
        pew_cascade_pending=pew,
    )


def _summary(matched=10, pending=0, auto_created=0, skipped=0):
    return {"matched": matched, "pending": pending,
            "auto_created": auto_created, "skipped": skipped}


# ===========================================================================
# Cascade rename
# ===========================================================================

class TestCascade:
    def test_pew_cascade_runs_when_flagged(self):
        """P4.CL.1 ctx.pew_cascade_pending=True triggers fn_pew_recompute_event_code."""
        db = MagicMock()
        db.pew_recompute_event_code.return_value = 4
        # After cascade, event row's txt_code is the new one
        db.find_event_by_code.return_value = {
            "id_event": 7, "txt_code": "PEW3ef-2025-2026"
        }
        ctx = _ctx(event_code="PEW3-2025-2026", pew=True)

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=None, notifier=None
        )

        db.pew_recompute_event_code.assert_called_once_with(7)
        assert out.cascade_ran is True
        assert out.cascade_renamed_to == "PEW3ef-2025-2026"
        assert out.cascade_rows == 4

    def test_cascade_skipped_when_flag_clear(self):
        """P4.CL.2 cascade no-ops when flag is False."""
        db = MagicMock()
        ctx = _ctx(event_code="PPW1-2025-2026", pew=False)

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=None, notifier=None
        )

        db.pew_recompute_event_code.assert_not_called()
        assert out.cascade_ran is False


# ===========================================================================
# EVF parity gate — pass / fail / skip
# ===========================================================================

class TestParityGate:
    def test_evf_parity_pass_promotes(self):
        """P4.CL.3 EVF event + parity PASS → fn_promote_evf_published called + status flip recorded."""
        db = MagicMock()
        db.event_results_for_parity.return_value = [
            {"id_fencer": 1, "fencer_name": "Adam Kowalski",
             "int_place": 1, "num_final_score": 50.0},
        ]
        db.promote_evf_published.return_value = {
            "id_event": 7, "fencers_overwritten": 1,
            "old_status": "ENGINE_COMPUTED", "new_status": "EVF_PUBLISHED"
        }
        ctx = _ctx(event_code="PEW3-2025-2026")
        evf = [{"name": "Adam Kowalski", "pos": 1, "points": 50.0}]
        notifier = MagicMock()

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=evf, notifier=notifier
        )

        assert out.parity_ran is True
        assert out.parity_passed is True
        db.promote_evf_published.assert_called_once()
        notifier.notify_evf_promoted.assert_called_once()

    def test_evf_parity_fail_annotates(self):
        """P4.CL.4 EVF event + parity FAIL → fn_annotate_parity_fail called; no promote."""
        db = MagicMock()
        db.event_results_for_parity.return_value = [
            {"id_fencer": 1, "fencer_name": "Adam Kowalski",
             "int_place": 1, "num_final_score": 50.0},
            {"id_fencer": 2, "fencer_name": "Jan Nowak",
             "int_place": 2, "num_final_score": 40.0},
        ]
        ctx = _ctx(event_code="PEW3-2025-2026")
        evf = [
            {"name": "Adam Kowalski", "pos": 1, "points": 50.0},
            {"name": "Jan Nowak", "pos": 2, "points": 44.0},  # 4 > 0.5 tolerance
        ]
        notifier = MagicMock()

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=evf, notifier=notifier
        )

        assert out.parity_ran is True
        assert out.parity_passed is False
        db.annotate_parity_fail.assert_called_once()
        db.promote_evf_published.assert_not_called()
        notifier.notify_evf_parity_fail.assert_called_once()

    def test_non_evf_event_skips_parity(self):
        """P4.CL.5 SPWS event + evf_results passed → parity stays inert."""
        db = MagicMock()
        ctx = _ctx(event_code="PPW1-2025-2026")
        evf = [{"name": "X", "pos": 1, "points": 1.0}]

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=evf, notifier=None
        )

        assert out.parity_ran is False
        db.promote_evf_published.assert_not_called()
        db.annotate_parity_fail.assert_not_called()

    def test_evf_no_payload_skips_parity(self):
        """P4.CL.6 EVF event but no evf_results → parity skipped (e.g. operator picked path/url)."""
        db = MagicMock()
        ctx = _ctx(event_code="PEW3-2025-2026")

        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(), evf_results=None, notifier=None
        )

        assert out.parity_ran is False


# ===========================================================================
# Combined Telegram batch
# ===========================================================================

class TestCombinedTelegram:
    def test_combined_message_sent_with_cascade_and_parity(self):
        """P4.CL.7 single notify_event_commit call carries cascade + parity flags."""
        db = MagicMock()
        db.pew_recompute_event_code.return_value = 4
        db.find_event_by_code.return_value = {
            "id_event": 7, "txt_code": "PEW3ef-2025-2026"
        }
        db.event_results_for_parity.return_value = []
        notifier = MagicMock()
        ctx = _ctx(event_code="PEW3-2025-2026", pew=True)
        evf = [{"name": "X", "pos": 1, "points": 1.0}]
        # No local rows ↔ count mismatch → parity FAIL path
        out = run_post_commit_hooks(
            db=db, ctx=ctx, summary=_summary(matched=42),
            evf_results=evf, notifier=notifier,
        )
        # Combined message must be the *last* notify_event_commit call,
        # carrying both the cascade renamed_to + parity_passed=False flag.
        notifier.notify_event_commit.assert_called_once()
        kwargs = notifier.notify_event_commit.call_args.kwargs
        assert kwargs["cascade_renamed_to"] == "PEW3ef-2025-2026"
        assert kwargs["parity_passed"] is False
        assert out.parity_passed is False
