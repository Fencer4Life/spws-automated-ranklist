"""Base class for forward-flow plugins (ADR-073).

A plugin declares its contract (`name/kind/reads/writes/effects`) as class
attributes and implements `applies`/`run`. Defaults: `applies` → True. Most M2
plugins delegate to `bridge.run_stage` and mirror one pctx field into their
declared public Context key.
"""
from __future__ import annotations

from python.pipeline.core.contract import Context, PluginKind, Services


class BasePlugin:
    name: str = ""
    kind: PluginKind = PluginKind.TRANSFORM
    reads: frozenset[str] = frozenset()
    writes: frozenset[str] = frozenset()
    effects: frozenset[str] = frozenset()

    def applies(self, ctx: Context) -> bool:  # noqa: D401 - simple default
        return True

    def run(self, ctx: Context, svc: Services) -> None:  # pragma: no cover - abstract
        raise NotImplementedError
