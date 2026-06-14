"""The PLUGINS registry + the RULEBOOK of domestic flows (ADR-073, design §6).

Two registries, kept apart:

- `PLUGINS`  — each plugin defined ONCE: its contract metadata (kind + reads +
  writes + effects). This is the "plugin list" (design §5 catalog). In M1 these
  are metadata-only `PluginSpec`s — the runnable `applies`/`run` bodies attach
  in M2 when the plugins wrap the existing `stages.py` functions.
- `RULEBOOK` — `dict[Flow -> Rule]`: the ordered plugin sequences that ARE the
  business logic. Adding a scenario = adding a Rule, no orchestrator change.

The Context-key vocabulary below is the DAG contract. Its load-bearing facts:
  * only `ResolveFencers` / `LoadCommitted` write `matches` (the governed roster),
    and `SplitByAge` reads `matches` -> ResolveFencers MUST precede SplitByAge;
  * `LoadCommitted` writes the same `matches`/`event` keys as the ingest source,
    so `AssignFinalVcat` / `ValidateCounts` / `Commit` are reused unchanged across
    INGEST_DOMESTIC and RECOMPUTE_DOMESTIC.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from python.pipeline.core.contract import PluginKind
from python.pipeline.engine.flows import Flow, Rule, Step


# ===========================================================================
# PLUGINS registry (metadata only in M1)
# ===========================================================================

@dataclass(frozen=True)
class PluginSpec:
    """Contract metadata for one plugin. Runnable bodies attach in M2."""
    name: str
    kind: PluginKind
    reads: frozenset[str] = field(default_factory=frozenset)
    writes: frozenset[str] = field(default_factory=frozenset)
    effects: frozenset[str] = field(default_factory=frozenset)


def _spec(name, kind, reads=(), writes=(), effects=()) -> PluginSpec:
    return PluginSpec(name, kind, frozenset(reads), frozenset(writes), frozenset(effects))


PLUGINS: dict[str, PluginSpec] = {
    # ── INGEST_DOMESTIC forward plan (design §5 / §6.4) ──────────────────
    "ParseSource":        _spec("ParseSource",        PluginKind.SOURCE,
                                 writes={"parsed"}),
    "ValidateIR":         _spec("ValidateIR",         PluginKind.GATE,
                                 reads={"parsed"}),
    "ResolveEvent":       _spec("ResolveEvent",       PluginKind.TRANSFORM,
                                 reads={"parsed"}, writes={"event"}),
    "ResolveFencers":     _spec("ResolveFencers",     PluginKind.MUTATOR,
                                 reads={"parsed", "event"}, writes={"matches"},
                                 effects={"master_data"}),
    "DetectCombinedPool": _spec("DetectCombinedPool", PluginKind.TRANSFORM,
                                 reads={"matches"}, writes={"combined"}),
    "SplitByAge":         _spec("SplitByAge",         PluginKind.TRANSFORM,
                                 reads={"matches", "combined"}, writes={"splits"}),
    "DetectJointPool":    _spec("DetectJointPool",    PluginKind.TRANSFORM,
                                 reads={"event", "matches"}, writes={"joint_pool"}),
    "ValidateCounts":     _spec("ValidateCounts",     PluginKind.GATE,
                                 reads={"matches", "event"}),
    "DetectPoolRound":    _spec("DetectPoolRound",    PluginKind.GATE,
                                 reads={"matches"}),
    "AssignFinalVcat":    _spec("AssignFinalVcat",    PluginKind.TRANSFORM,
                                 reads={"matches"}, writes={"final_vcats"}),
    "Commit":             _spec("Commit",             PluginKind.MUTATOR,
                                 reads={"matches", "final_vcats", "event"},
                                 writes={"committed"}, effects={"live"}),
    # ── RECOMPUTE_DOMESTIC source ────────────────────────────────────────
    "LoadCommitted":      _spec("LoadCommitted",      PluginKind.SOURCE,
                                 writes={"matches", "event"}),
    # ── POST_COMMIT members ──────────────────────────────────────────────
    "ParticipantCount":   _spec("ParticipantCount",   PluginKind.GATE,
                                 reads={"event"}),
    "Notify":             _spec("Notify",             PluginKind.MUTATOR,
                                 reads={"event"}, effects={"external"}),
}


# ===========================================================================
# RULEBOOK — the 4 domestic flows
# ===========================================================================

def _organizer_evf(p) -> bool:  # plan-time predicate placeholder for deferred §12
    return p.organizer_hint == "EVF"


RULEBOOK: dict[Flow, Rule] = {

    # 1. Keep the active season current. Source produces `parsed`.
    Flow.INGEST_DOMESTIC: Rule(
        Flow.INGEST_DOMESTIC,
        "Ingest an active-season SPWS (PPW/MPW) event: admit everyone, auto-create "
        "unmatched, V0 allowed, combined pools split + counted per V-cat. Never halts.",
        steps=(
            Step("ParseSource"),
            Step("ValidateIR"),
            Step("ResolveEvent"),
            Step("ResolveFencers", params={"intake": "DOMESTIC"}),
            Step("DetectCombinedPool"),
            Step("SplitByAge"),
            Step("DetectJointPool"),
            Step("ValidateCounts"),
            Step("DetectPoolRound"),
            Step("AssignFinalVcat"),
            Step("Commit"),
        ),
        seeds=frozenset(),
    ),

    # 2. Self-heal an event after a BY / identity correction. LoadCommitted
    #    re-produces `matches` + `event` from stored FK rows (no source, no re-match).
    Flow.RECOMPUTE_DOMESTIC: Rule(
        Flow.RECOMPUTE_DOMESTIC,
        "Re-derive + re-score an AFFECTED EVENT after a master-data change, from "
        "stored FK-linked results. Event-granular (a BY change relocates a result "
        "between V-cat brackets). Never halts. Fired by the SelfHealing reactor.",
        steps=(
            Step("LoadCommitted"),
            Step("AssignFinalVcat"),
            Step("ValidateCounts"),
            Step("Commit"),
        ),
        seeds=frozenset(),
    ),

    # 3. Whole-roster dedup + BY reconcile. In whole_roster scope ResolveFencers
    #    and Notify source from the db (Services), so their context keys are
    #    supplied at flow entry rather than produced by a Source plugin.
    Flow.DEDUP_SWEEP: Rule(
        Flow.DEDUP_SWEEP,
        "Whole-roster master-data maintenance: dedup duplicate fencers + reconcile "
        "conflicting birth years. Each merge/reconcile emits master_data.changed, "
        "which the SelfHealing reactor turns into RECOMPUTE_DOMESTIC per event.",
        steps=(
            Step("ResolveFencers", params={"scope": "whole_roster"}),
            Step("Notify"),
        ),
        seeds=frozenset({"parsed", "event"}),
    ),

    # 4. Validate + notify after every commit. The PostCommit reactor supplies the
    #    committed `event` from the live.committed signal.
    Flow.POST_COMMIT: Rule(
        Flow.POST_COMMIT,
        "Fired by the PostCommit reactor on live.committed (from both INGEST_DOMESTIC "
        "and RECOMPUTE_DOMESTIC). Validates participant count and notifies; Escalate "
        "fires Telegram only per REMEDIATIONBOOK policy.",
        steps=(
            Step("ParticipantCount"),
            Step("Notify"),
        ),
        seeds=frozenset({"event"}),
    ),
}
