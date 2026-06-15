"""The plugin contract + forward Context + fault model (ADR-073 / ADR-074).

This module is **domain-ignorant**. It defines the seam every plugin plugs
into and the rules the Orchestrator enforces:

- `IngestPlugin`  — the protocol: `name/kind/reads/writes/effects` + `applies/run`.
- `Context`       — the forward payload (data + trace + warnings + faults).
- `Services`      — injected dependencies (db, config, matcher, calibration, notifier).
- `FaultKind`     — a *recoverable* domain problem; `ctx.fault(kind)` records it and
                    the run continues (ADR-074, no hard halt). The REMEDIATIONBOOK
                    that turns a fault into an inline fix lands in M2.
- `Abort`         — the ONLY thing that stops a run (genuine infra failure; retried).
- write-discipline — a plugin may only write keys it declared in `writes`.

There is no `HaltError` here: the old halt-by-exception model (types.py) is
replaced by `FaultKind` (recorded, non-blocking) + a narrow `Abort`.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Protocol, runtime_checkable


# ===========================================================================
# Plugin kinds + side-effects + faults
# ===========================================================================

class PluginKind(str, Enum):
    """What a plugin is, which determines where it runs (design §4.1a)."""
    SOURCE = "SOURCE"        # produces the initial Context
    GATE = "GATE"            # pure check; records ctx.fault, never halts
    TRANSFORM = "TRANSFORM"  # pure; enriches Context
    MUTATOR = "MUTATOR"      # persists state and emits a signal
    REACTOR = "REACTOR"      # observes a signal -> emits a Flow (outside the plan)


class FaultKind(str, Enum):
    """A recoverable domain problem (design §5.2, ADR-074). Never a halt.

    The REMEDIATIONBOOK (M2) maps each kind to an inline deterministic fix
    (drop_bracket / skip_bracket / accept_parsed / ...) + an escalation policy.
    """
    BELOW_MIN = "BELOW_MIN"
    COUNT_MISMATCH = "COUNT_MISMATCH"
    POOL_ROUND = "POOL_ROUND"
    SPLITTER_UNRESOLVED = "SPLITTER_UNRESOLVED"
    IR_INVALID = "IR_INVALID"
    URL_DATA_MISMATCH = "URL_DATA_MISMATCH"


class Outcome(str, Enum):
    """Per-plugin trace outcome (design §4.1)."""
    RAN = "RAN"
    SKIPPED = "SKIPPED"      # applies() returned False
    FAULT = "FAULT"          # the plugin recorded a ctx.fault (run still continued)
    ABORTED = "ABORTED"      # an Abort broke the run at this plugin


class Abort(Exception):
    """Genuine infra failure (e.g. DB down) — the ONLY thing that stops a run.

    It is retried by the dispatch layer, never gated by a human (ADR-074).
    A domain problem is a `ctx.fault`, NOT an Abort.
    """
    def __init__(self, plugin: str = "", detail: str = "") -> None:
        super().__init__(f"{plugin}: {detail}" if plugin else detail)
        self.plugin = plugin
        self.detail = detail


class WriteDisciplineError(Exception):
    """A plugin wrote a Context key it did not declare in `writes`.

    This is a programming error in the plugin, not a domain fault — it surfaces
    loudly so contracts stay honest (design §4.1 invariants).
    """


# ===========================================================================
# Trace
# ===========================================================================

@dataclass(frozen=True)
class Fault:
    plugin: str
    kind: FaultKind
    detail: str = ""


@dataclass(frozen=True)
class TraceEntry:
    plugin: str
    outcome: Outcome


@dataclass
class Trace:
    """Ordered record of what the orchestrator did, plugin by plugin."""
    entries: list[TraceEntry] = field(default_factory=list)

    def record(self, plugin: str, outcome: Outcome) -> None:
        self.entries.append(TraceEntry(plugin, outcome))

    def outcome_of(self, plugin: str) -> Outcome | None:
        for e in reversed(self.entries):
            if e.plugin == plugin:
                return e.outcome
        return None

    @property
    def names(self) -> list[str]:
        return [e.plugin for e in self.entries]


# ===========================================================================
# Services (injected dependencies)
# ===========================================================================

@dataclass
class Services:
    """Everything a plugin needs from the outside world, injected for testability."""
    db: Any = None
    config: Any = None
    matcher: Any = None
    calibration: Any = None
    notifier: Any = None


# ===========================================================================
# Context (the forward payload)
# ===========================================================================

@dataclass
class Context:
    """Flows one direction through the plugins.

    `data` holds the named Context keys (the DAG currency). `trace` records
    outcomes, `warnings` soft diagnostics, `faults` recoverable problems.

    The orchestrator brackets each plugin with `_begin`/`_end` so that
    `set()` can enforce write-discipline and `fault()` can attribute the fault
    to the active plugin. Plugins themselves never touch the underscore fields.
    """
    data: dict[str, Any] = field(default_factory=dict)
    trace: Trace = field(default_factory=Trace)
    warnings: list[str] = field(default_factory=list)
    faults: list[Fault] = field(default_factory=list)

    _active_plugin: str | None = field(default=None, repr=False)
    _active_writes: frozenset[str] | None = field(default=None, repr=False)
    _faulted_active: bool = field(default=False, repr=False)

    # -- data access -------------------------------------------------------
    def get(self, key: str, default: Any = None) -> Any:
        return self.data.get(key, default)

    def __contains__(self, key: str) -> bool:
        return key in self.data

    def set(self, key: str, value: Any) -> None:
        # Underscore-prefixed keys are PRIVATE scratch (not part of the declared
        # DAG contract) and bypass write-discipline — e.g. the M2 `_legacy`
        # PipelineContext bridge. Public keys must be declared in `writes`.
        if (
            not key.startswith("_")
            and self._active_writes is not None
            and key not in self._active_writes
        ):
            raise WriteDisciplineError(
                f"plugin {self._active_plugin!r} wrote undeclared key {key!r} "
                f"(declared writes: {sorted(self._active_writes)})"
            )
        self.data[key] = value

    # -- domain signals ----------------------------------------------------
    def fault(self, kind: FaultKind, detail: str = "") -> None:
        """Record a recoverable domain problem. Does NOT raise / halt (ADR-074)."""
        self.faults.append(Fault(self._active_plugin or "?", kind, detail))
        self._faulted_active = True

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def faults_of(self, kind: FaultKind) -> list[Fault]:
        return [f for f in self.faults if f.kind == kind]

    # -- orchestrator bookkeeping (not for plugins) ------------------------
    def _begin(self, plugin: "IngestPlugin") -> None:
        self._active_plugin = plugin.name
        self._active_writes = frozenset(plugin.writes)
        self._faulted_active = False

    def _end(self) -> bool:
        faulted = self._faulted_active
        self._active_plugin = None
        self._active_writes = None
        self._faulted_active = False
        return faulted


# ===========================================================================
# The plugin protocol + middleware composition
# ===========================================================================

@runtime_checkable
class IngestPlugin(Protocol):
    """One concern; all I/O via injected Services; forward-only; idempotent."""
    name: str
    kind: PluginKind
    reads: frozenset[str]
    writes: frozenset[str]
    effects: frozenset[str]

    def applies(self, ctx: Context) -> bool: ...
    def run(self, ctx: Context, svc: Services) -> None: ...


# A middleware wraps a plugin's run: it receives the next callable and may run
# logic before/after it (Chain-of-Responsibility / decorator, design §4.4).
Runner = Callable[[Context, Services], None]
Middleware = Callable[[Context, Services, Runner], None]


def compose(middlewares: list[Middleware], run: Runner) -> Runner:
    """Fold middlewares around `run` so the FIRST is outermost.

    compose([A, B], R) -> A(B(R)): on call the order is
    A-before, B-before, R, B-after, A-after.
    """
    handler = run
    for mw in reversed(middlewares):
        nxt = handler

        def make(mw: Middleware, nxt: Runner) -> Runner:
            def wrapped(ctx: Context, svc: Services) -> None:
                mw(ctx, svc, nxt)
            return wrapped

        handler = make(mw, nxt)
    return handler
