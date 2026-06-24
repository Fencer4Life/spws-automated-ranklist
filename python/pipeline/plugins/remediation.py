"""No-halt fault resolution — the REMEDIATIONBOOK + Escalation policy (ADR-074).

A gate/transform that hits a domain problem calls `ctx.fault(kind, detail)`; the
run does NOT stop. Resolution is governed by this explicit, declarative policy
(a sibling of the RuleBook — error policy is business logic, kept out of hidden
`if`s inside plugins). Each `Remediation` carries:

  * `auto`     — a deterministic inline fix applied in-pass so the flow reaches
                 Commit (`drop_bracket` / `skip_bracket` / `accept_parsed` /
                 `keep_combined` / `skip_artifact`), and
  * `escalate` — when to Telegram (NEVER / ON_LOSS / ALWAYS), consumed by the
                 `Escalate` plugin in POST_COMMIT — informational, never blocking.

`HALT_TO_FAULT` maps the legacy `HaltReason`s the wrapped stages still raise onto
`FaultKind`s; the reasons in `ABORT_REASONS` instead become a genuine `Abort`
(you cannot ingest into a nonexistent / ambiguous event).
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from enum import StrEnum

from python.pipeline.core.contract import Context, Fault, FaultKind
from python.pipeline.types import HaltReason

# ===========================================================================
# Escalation policy
# ===========================================================================


class Escalation(StrEnum):
    NEVER = "NEVER"
    ON_LOSS = "ON_LOSS"  # only if the inline fix actually dropped data
    ALWAYS = "ALWAYS"


# ===========================================================================
# Inline auto-fixes (operate on the bridged state in ctx)
# ===========================================================================
# Private Context keys the fixes use (underscore => off the DAG contract):
#   _skip_commit     : bool   — Commit writes nothing (whole artifact unrankable)
#   _dropped_brackets: list   — record of dropped data (drives ON_LOSS escalation)


def _record_drop(ctx: Context, detail: str) -> None:
    dropped = ctx.data.setdefault("_dropped_brackets", [])
    dropped.append(detail)


def drop_bracket(ctx: Context, fault: Fault) -> None:
    """BELOW_MIN — the sub-min bracket is not a rankable tournament; drop it."""
    pctx = ctx.get("_legacy")
    vcat = (fault.detail or "").strip()
    if pctx is not None and getattr(pctx, "vcat_groups", None) and vcat in pctx.vcat_groups:
        pctx.vcat_groups.pop(vcat, None)
        if not pctx.vcat_groups:
            ctx.set("_skip_commit", True)
    else:
        ctx.set("_skip_commit", True)
    _record_drop(ctx, fault.detail or "below-min bracket")


def skip_bracket(ctx: Context, fault: Fault) -> None:
    """POOL_ROUND — a qualifier round / gender-mixed pool, not a scored bracket."""
    ctx.set("_skip_commit", True)
    _record_drop(ctx, fault.detail or "pool-round bracket")


def skip_artifact(ctx: Context, fault: Fault) -> None:
    """IR_INVALID — the source artifact is unusable; skip the whole thing."""
    ctx.set("_skip_commit", True)
    _record_drop(ctx, fault.detail or "invalid IR")


def accept_parsed(ctx: Context, fault: Fault) -> None:
    """COUNT_MISMATCH / URL_DATA_MISMATCH — keep the parsed values, flag loudly."""
    # No data change: the flow commits the parsed result as-is; the loud part is
    # the ALWAYS escalation. (Old pipeline halted here; we accept + continue.)
    return None


def keep_combined(ctx: Context, fault: Fault) -> None:
    """SPLITTER_UNRESOLVED — leave the pool combined rather than guess a split."""
    # Rare: governed BY should prevent it (M3). Keep combined + escalate.
    return None


# ===========================================================================
# The REMEDIATIONBOOK (domestic policy — small, explicit, no V0 rule: domestic
# admits V0; V0-exclusion is international, design §12)
# ===========================================================================


@dataclass(frozen=True)
class Remediation:
    auto: Callable[[Context, Fault], None]
    escalate: Escalation


REMEDIATIONBOOK: dict[FaultKind, Remediation] = {
    FaultKind.BELOW_MIN: Remediation(drop_bracket, Escalation.ON_LOSS),
    FaultKind.POOL_ROUND: Remediation(skip_bracket, Escalation.ON_LOSS),
    FaultKind.COUNT_MISMATCH: Remediation(accept_parsed, Escalation.ALWAYS),
    FaultKind.URL_DATA_MISMATCH: Remediation(accept_parsed, Escalation.ALWAYS),
    FaultKind.SPLITTER_UNRESOLVED: Remediation(keep_combined, Escalation.ALWAYS),
    FaultKind.IR_INVALID: Remediation(skip_artifact, Escalation.ALWAYS),
}


# ===========================================================================
# Legacy HaltReason -> FaultKind / Abort
# ===========================================================================

# Reasons that are NOT recoverable inline: you cannot ingest into an event that
# does not resolve. These become a genuine Abort (retried, never gated).
ABORT_REASONS: frozenset[HaltReason] = frozenset(
    {
        HaltReason.EVENT_NOT_RESOLVED,
        HaltReason.EVENT_AMBIGUOUS,
        HaltReason.OVERRIDE_INVALID,
    }
)

HALT_TO_FAULT: dict[HaltReason, FaultKind] = {
    HaltReason.IR_INVALID: FaultKind.IR_INVALID,
    HaltReason.POOL_ROUND_DETECTED: FaultKind.POOL_ROUND,
    HaltReason.SPLITTER_UNRESOLVED: FaultKind.SPLITTER_UNRESOLVED,
    HaltReason.COUNT_MISMATCH: FaultKind.COUNT_MISMATCH,
    HaltReason.URL_DATA_MISMATCH: FaultKind.URL_DATA_MISMATCH,
    HaltReason.PARTICIPANT_COUNT_MISMATCH: FaultKind.COUNT_MISMATCH,
    # V0_PROHIBITED_ON_INTERNATIONAL is international (deferred §12) — not mapped here.
}


def escalation_for(kind: FaultKind) -> Escalation:
    rem = REMEDIATIONBOOK.get(kind)
    return rem.escalate if rem else Escalation.ALWAYS


def apply_remediations(ctx: Context, new_faults: list[Fault]) -> None:
    """Apply the inline auto-fix for each freshly-recorded fault (ADR-074)."""
    for fault in new_faults:
        rem = REMEDIATIONBOOK.get(fault.kind)
        if rem is not None:
            rem.auto(ctx, fault)


def remediation_middleware(ctx: Context, svc, nxt) -> None:
    """Middleware that applies the REMEDIATIONBOOK inline after each plugin.

    Keeps the orchestrator domain-ignorant: it just records faults; this
    domain-policy middleware turns each fresh fault into its deterministic inline
    fix so the flow runs on to Commit (ADR-074, design §5.2).
    """
    before = len(ctx.faults)
    nxt(ctx, svc)
    new_faults = ctx.faults[before:]
    if new_faults:
        apply_remediations(ctx, new_faults)
