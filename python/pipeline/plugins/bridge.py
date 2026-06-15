"""The M2 stage bridge — run existing `stages.py` on a shared PipelineContext.

A single legacy `PipelineContext` lives in the new `Context` under the private
key `_legacy`. Each plugin delegates to one or more `stages.sN_*` functions via
`run_stage`, which translates a `HaltError` into a non-blocking `ctx.fault`
(ADR-074) — or, for unresolvable reasons, a genuine `Abort`.

Stage functions are resolved by NAME from the `stages` module at call time (the
same pattern as `orchestrator.run_pipeline`), so tests can monkeypatch them.

This bridge is transitional: it exists so M2 reuses today's domain code verbatim
and the parity gate holds. M3+ inlines the logic and retires the bridge.
"""
from __future__ import annotations

from python.pipeline import stages
from python.pipeline.core.contract import Abort, Context
from python.pipeline.plugins.remediation import ABORT_REASONS, HALT_TO_FAULT
from python.pipeline.types import HaltError, Overrides, PipelineContext

LEGACY = "_legacy"


def get_pctx(ctx: Context) -> PipelineContext | None:
    return ctx.get(LEGACY)


def ensure_pctx(
    ctx: Context,
    *,
    parsed=None,
    overrides=None,
    season_end_year: int | None = None,
    event_code: str | None = None,
) -> PipelineContext:
    """Get the bridged PipelineContext, constructing it once if absent."""
    pctx = ctx.get(LEGACY)
    if pctx is None:
        pctx = PipelineContext(
            parsed=parsed,
            overrides=overrides if overrides is not None else Overrides(),
            season_end_year=season_end_year,
            event_code=event_code,
        )
        ctx.set(LEGACY, pctx)
    return pctx


def run_stage(ctx: Context, stage_name: str, db) -> None:
    """Run a legacy stage on the bridged pctx; map HaltError -> fault / Abort."""
    pctx = ctx.get(LEGACY)
    if pctx is None:
        raise Abort(plugin=stage_name, detail="bridge pctx missing (ParseSource did not run)")
    fn = getattr(stages, stage_name)
    try:
        fn(pctx, db)
    except HaltError as h:
        if h.reason in ABORT_REASONS:
            raise Abort(
                plugin=ctx._active_plugin or stage_name,
                detail=f"{h.reason.value}: {h.detail}",
            )
        kind = HALT_TO_FAULT.get(h.reason)
        if kind is None:
            # An unmapped domestic halt should not happen; surface it loudly.
            raise Abort(
                plugin=ctx._active_plugin or stage_name,
                detail=f"unmapped halt {h.reason.value}: {h.detail}",
            )
        ctx.fault(kind, h.detail)
