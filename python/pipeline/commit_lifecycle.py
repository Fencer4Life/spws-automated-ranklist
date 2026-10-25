"""
Phase 4 (ADR-046, ADR-053) — post-commit hooks for the unified pipeline.

Stages 8b (PEW cascade-rename) and the post-commit EVF parity gate run
*after* fn_commit_event_draft has flipped draft rows into live tables.
This module owns the orchestration:

  1. If ctx.pew_cascade_pending was set by Stage 7, call
     db.pew_recompute_event_code(id_event). Capture renamed-to txt_code.
  2. If the event is EVF-organized and we have a fetched-from-EVF parity
     payload, run check_parity(local, evf) and report the outcome. It writes
     nothing: no score is overwritten and no parity note stored (ADR-053
     amendment of 2026-10-25; results reach PROD only through promote).
  3. Emit a single combined Telegram message via TelegramNotifier.notify_event_commit
     so commit + cascade + parity reach the operator as one event.

Parity payload extraction is the orchestrator's responsibility (it has the
parsed IR for the EVF API path); this module accepts a pre-built `evf_results`
list of {name, pos, points} dicts.

Tests: python/tests/test_commit_lifecycle.py.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from python.pipeline.evf_parity import ParityResult, check_parity


@dataclass
class CommitLifecycleResult:
    """Aggregated outcome for the post-commit chain — used by callers/tests."""

    cascade_ran: bool = False
    cascade_renamed_to: str | None = None
    cascade_rows: int = 0
    parity_ran: bool = False
    parity_passed: bool | None = None
    parity_result: ParityResult | None = None
    fencers_overwritten: int = 0
    parity_notes: str | None = None
    warnings: list[str] = field(default_factory=list)


def run_post_commit_hooks(
    *,
    db: Any,
    ctx: Any,
    summary: dict,
    evf_results: list[dict] | None,
    notifier: Any | None,
) -> CommitLifecycleResult:
    """Run Stage 8b cascade + EVF parity gate + emit combined Telegram message.

    Args:
        db: DbConnector with pew_recompute_event_code, event_results_for_parity,
            find_event_by_code.
        ctx: PipelineContext from run_pipeline (has event, pew_cascade_pending).
        summary: ingestion counts for the Telegram batch line
                 (matched / pending / auto_created / skipped).
        evf_results: pre-fetched EVF API per-fencer payload — list of
                     {name, pos, points}. Pass None or [] to skip parity.
        notifier: TelegramNotifier (or None for dry-run / test).

    Returns:
        CommitLifecycleResult — caller-facing summary of what happened.
    """
    out = CommitLifecycleResult()
    event = ctx.event or {}
    id_event = event.get("id_event")
    event_code = event.get("txt_code") or "<unknown>"

    # --------------- (a) Stage 8b PEW cascade rename ---------------
    if ctx.pew_cascade_pending and id_event is not None:
        try:
            renamed = db.pew_recompute_event_code(id_event)
            out.cascade_ran = True
            out.cascade_rows = renamed or 0
            if out.cascade_rows > 0:
                # Re-read the event row to learn the new txt_code
                refreshed = db.find_event_by_code(event_code)
                if refreshed and refreshed.get("txt_code") != event_code:
                    out.cascade_renamed_to = refreshed["txt_code"]
        except Exception as e:  # pragma: no cover — defensive, surface to operator
            out.warnings.append(f"PEW cascade failed: {e}")

    # --------------- (b) EVF parity gate ---------------
    organizer = _organizer_code(event)
    if organizer == "EVF" and evf_results and id_event is not None:
        try:
            local = db.event_results_for_parity(id_event)
            parity = check_parity(local, evf_results)
            out.parity_ran = True
            out.parity_result = parity
            out.parity_passed = parity.overall_pass

            # Reports only (REVCHK.01–03, ADR-053 amendment 2026-10-25): results
            # reach PROD only through promote (ADR-113 §8), so a pass overwrites
            # no score and a difference writes no note.
            shown = out.cascade_renamed_to or event_code
            if parity.overall_pass:
                if notifier is not None:
                    notifier.success(
                        f"{shown}: EVF parity passed — every result carries EVF's place "
                        "and points; nothing written."
                    )
            else:
                fail_lines = [f"[{f.sub_check}] {f.fencer_name}" for f in parity.fail_details]
                notes = "; ".join(fail_lines[:10])
                if len(fail_lines) > 10:
                    notes += f"; +{len(fail_lines) - 10} more"
                out.parity_notes = notes
                if notifier is not None:
                    notifier.notify_evf_parity_fail(shown, parity.fail_details, notes)
        except Exception as e:  # pragma: no cover — defensive
            out.warnings.append(f"EVF parity gate failed: {e}")

    # --------------- (c) combined commit notification ---------------
    if notifier is not None:
        notifier.notify_event_commit(
            event_code=out.cascade_renamed_to or event_code,
            summary=summary,
            cascade_renamed_to=out.cascade_renamed_to,
            parity_passed=out.parity_passed,
        )

    return out


# ---------------------------------------------------------------------------
# Local helpers (kept private to avoid name pollution)
# ---------------------------------------------------------------------------


def _organizer_code(event: dict) -> str:
    """Derive organizer code from event dict.

    Supports two shapes: explicit `txt_organizer_code` field, or by-prefix
    inference from `txt_code` (PPW/MPW = SPWS, PEW/MEW = EVF, MSW = FIE).
    """
    if not event:
        return "UNKNOWN"
    if event.get("txt_organizer_code"):
        return str(event["txt_organizer_code"]).upper()
    code = (event.get("txt_code") or "").upper()
    if code.startswith(("PPW", "MPW")):
        return "SPWS"
    if code.startswith(("PEW", "MEW")):
        return "EVF"
    if code.startswith("MSW"):
        return "FIE"
    return "UNKNOWN"
