"""RECOMPUTE_DOMESTIC source — `LoadCommitted` (ADR-072).

Loads an affected event's stored, FK-linked results across its V-cat brackets so
`AssignFinalVcat`/`ValidateCounts`/`Commit` can re-derive + re-score from durable
data — no source fetch, no re-match. The full event-granular reader lands in M4;
this M2 stub establishes the contract so the RECOMPUTE_DOMESTIC plan validates.
"""
from __future__ import annotations

from python.pipeline.core.contract import Abort, Context, PluginKind, Services
from python.pipeline.plugins.base import BasePlugin


class LoadCommitted(BasePlugin):
    name = "LoadCommitted"
    kind = PluginKind.SOURCE
    writes = frozenset({"matches", "event"})

    def run(self, ctx: Context, svc: Services) -> None:  # pragma: no cover - M4
        raise Abort(plugin=self.name, detail="LoadCommitted is implemented in M4 (RECOMPUTE_DOMESTIC)")
