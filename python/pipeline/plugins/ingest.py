"""INGEST_DOMESTIC forward plugins — thin wrappers over `stages.py` (ADR-073/074).

Each class is one concern. They delegate to the existing stage functions on the
shared `_legacy` PipelineContext (see `bridge.py`) and translate former halts to
non-blocking `ctx.fault`s (see `remediation.py`). The M2 plugin order matches the
final design §6.4; to keep byte-parity with today's `run_pipeline`, `ResolveFencers`
runs the s0→s3→s4→s6 cluster on the shared pctx, and `DetectCombinedPool`/
`SplitByAge` then mirror the already-computed pctx fields. M3 inlines this and
switches the split to read governed BY.
"""
from __future__ import annotations

from python.pipeline.core.contract import Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin
from python.pipeline.plugins.bridge import ensure_pctx, get_pctx, run_stage
from python.pipeline.stages import vcat_for_age


# ---------------------------------------------------------------------------
# Source
# ---------------------------------------------------------------------------

class ParseSource(BasePlugin):
    """Produce the initial Context: parse the source IR + build the bridge pctx.

    M2 takes the parsed IR + admin context from `svc.config` (a dict). Live
    PARSERS dispatch + `source_artifact_path` retention is M4 (BR-13).
    """
    name = "ParseSource"
    kind = PluginKind.SOURCE
    writes = frozenset({"parsed"})

    def run(self, ctx: Context, svc: Services) -> None:
        cfg = svc.config or {}
        parsed = cfg.get("parsed")
        if parsed is None:
            from python.pipeline.core.contract import Abort
            raise Abort(plugin=self.name, detail="no parsed IR provided (svc.config['parsed'])")
        ensure_pctx(
            ctx,
            parsed=parsed,
            overrides=cfg.get("overrides"),
            season_end_year=cfg.get("season_end_year"),
            event_code=cfg.get("event_code"),
        )
        ctx.set("parsed", parsed)


# ---------------------------------------------------------------------------
# Gates / transforms
# ---------------------------------------------------------------------------

class ValidateIR(BasePlugin):
    name = "ValidateIR"
    kind = PluginKind.GATE
    reads = frozenset({"parsed"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s1_validate_ir", svc.db)


class ResolveEvent(BasePlugin):
    name = "ResolveEvent"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"parsed"})
    writes = frozenset({"event"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s2_resolve_event", svc.db)  # EVENT_NOT_RESOLVED -> Abort
        pctx = get_pctx(ctx)
        if pctx is not None and pctx.event is not None:
            ctx.set("event", pctx.event)


# ResolveFencers (the merged, early identity plugin) lives in resolve_fencers.py.


def _governed_vcats(matches, season_end) -> dict:
    """Group matched rows by the V-cat derived from their GOVERNED birth year
    (ADR-070/056). The governed BY is emitted by ResolveFencers per row."""
    groups: dict[str, list] = {}
    for m in matches:
        by = getattr(m, "governed_birth_year", None)
        vcat = vcat_for_age(season_end - by) if by is not None else None
        if vcat is not None:
            groups.setdefault(vcat, []).append(m)
    return groups


class DetectCombinedPool(BasePlugin):
    """Detect a combined (multi-V-cat) pool from the GOVERNED birth-year spread
    of the resolved roster (ADR-024/070) — robust even when the source omitted
    age markers, since the fencers' governed BYs are known."""
    name = "DetectCombinedPool"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches"})
    writes = frozenset({"combined"})

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        season_end = pctx.season_end_year if pctx else None
        matches = ctx.get("matches") or []
        combined = season_end is not None and len(_governed_vcats(matches, season_end)) >= 2
        ctx.set("combined", combined)
        if pctx is not None:
            pctx.is_combined_pool = combined


class SplitByAge(BasePlugin):
    """Group the resolved rows by GOVERNED birth year (ADR-070). Replaces the
    old splitter's reliance on scraped birth years / the batch RPC."""
    name = "SplitByAge"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches", "combined"})
    writes = frozenset({"splits"})

    def applies(self, ctx: Context) -> bool:
        return bool(ctx.get("combined"))

    def run(self, ctx: Context, svc: Services) -> None:
        pctx = get_pctx(ctx)
        season_end = pctx.season_end_year if pctx else None
        matches = ctx.get("matches") or []
        splits = _governed_vcats(matches, season_end) if season_end is not None else {}
        ctx.set("splits", splits)
        if pctx is not None:
            pctx.splits = splits


class DetectJointPool(BasePlugin):
    name = "DetectJointPool"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"event", "matches"})
    writes = frozenset({"joint_pool"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s5_detect_joint_pool", svc.db)
        pctx = get_pctx(ctx)
        if pctx is not None:
            ctx.set("joint_pool", list(pctx.joint_pool_siblings))


class ValidateCounts(BasePlugin):
    """Count + URL→data (s7), plus the min-participants gate (ADR-066) that the
    NEW pipeline pulls into ingestion. Below-min -> ctx.fault(BELOW_MIN) ->
    drop_bracket (ADR-074); count/URL mismatch -> fault(accept_parsed)."""
    name = "ValidateCounts"
    kind = PluginKind.GATE
    reads = frozenset({"matches", "event"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s7_validate", svc.db)  # COUNT_MISMATCH / URL_DATA_MISMATCH -> fault
        self._check_min_participants(ctx, svc)

    def _check_min_participants(self, ctx: Context, svc: Services) -> None:
        from python.pipeline.core.contract import FaultKind

        pctx = get_pctx(ctx)
        if pctx is None:
            return
        n = sum(
            1 for m in pctx.matches
            if getattr(m, "id_fencer", None) is not None
        ) or len(pctx.matches)
        cfg = svc.config or {}
        threshold = cfg.get("min_participants", self._default_min(pctx))
        if threshold and n < threshold:
            ctx.fault(FaultKind.BELOW_MIN, f"{n}<{threshold} participants")

    @staticmethod
    def _default_min(pctx) -> int:
        # Domestic PPW/MPW default = 1 (international default 5 is deferred §12).
        return 1


class DetectPoolRound(BasePlugin):
    name = "DetectPoolRound"
    kind = PluginKind.GATE
    reads = frozenset({"matches"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s7_pool_round_check", svc.db)  # POOL_ROUND_DETECTED -> fault


class AssignFinalVcat(BasePlugin):
    name = "AssignFinalVcat"
    kind = PluginKind.TRANSFORM
    reads = frozenset({"matches"})
    writes = frozenset({"final_vcats"})

    def run(self, ctx: Context, svc: Services) -> None:
        run_stage(ctx, "s7_split_by_vcat", svc.db)
        pctx = get_pctx(ctx)
        if pctx is not None:
            ctx.set("final_vcats", dict(pctx.vcat_groups))


class Commit(BasePlugin):
    """Atomic delete-old + insert + score -> live (ADR-014/022). Skips when an
    inline remediation marked the artifact unrankable (`_skip_commit`)."""
    name = "Commit"
    kind = PluginKind.MUTATOR
    reads = frozenset({"matches", "final_vcats", "event"})
    writes = frozenset({"committed"})
    effects = frozenset({"live"})

    def run(self, ctx: Context, svc: Services) -> None:
        if ctx.get("_skip_commit"):
            ctx.set("committed", {
                "skipped": True,
                "dropped": list(ctx.get("_dropped_brackets", [])),
            })
            return
        pctx = get_pctx(ctx)
        db = svc.db
        result = None
        if db is not None and hasattr(db, "ingest_results"):
            result = db.ingest_results(pctx)
        ctx.set("committed", {
            "skipped": False,
            "vcat_groups": sorted((pctx.vcat_groups or {}).keys()) if pctx else [],
            "result": result,
        })
