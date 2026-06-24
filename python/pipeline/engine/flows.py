"""Flows, params, steps and rules — the declarative vocabulary (ADR-073).

A `Rule` is a named `Flow` = an ordered tuple of `Step`s. The `RuleBook`
(rulebook.py) is `dict[Flow -> Rule]`. `FlowParams` is everything knowable
*before* execution; a `Step.when` predicate prunes at plan time on those params.

`Rule.seeds` are the Context keys available at flow entry — keys a Source
plugin will produce, or that the trigger supplies (e.g. POST_COMMIT receives
the committed `event` from the PostCommit reactor's signal). The DAG validator
(rule_engine.py) starts from `seeds` and requires every `reads` to be satisfied
by an earlier `writes`.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from enum import StrEnum


class Flow(StrEnum):
    """The full domestic automated pipeline — 4 flows (design §6.2).

    International flows (FRESH_INGEST_INTERNATIONAL, EVF_SYNC) are deferred — §12.
    """

    INGEST_DOMESTIC = "ingest_domestic"
    RECOMPUTE_DOMESTIC = "recompute_domestic"
    DEDUP_SWEEP = "dedup_sweep"
    POST_COMMIT = "post_commit"


@dataclass(frozen=True)
class FlowParams:
    """Everything knowable BEFORE execution (design §4.3)."""

    flow: Flow
    source_kind: object | None = None  # SourceKind | None (kept loose: no import cycle)
    environment: str = "LOCAL"
    organizer_hint: str | None = None
    id_event: int | None = None  # RECOMPUTE/POST_COMMIT target


def always(_p: FlowParams) -> bool:
    return True


@dataclass(frozen=True)
class Step:
    """One plugin call in a Rule.

    `plugin` is a name looked up in the PLUGINS registry. `when` gates the step
    at PLAN time on FlowParams. `params` are passed to the plugin at run time
    (e.g. scope="whole_roster", source="retained").
    """

    plugin: str
    when: Callable[[FlowParams], bool] = always
    params: dict = field(default_factory=dict)


@dataclass(frozen=True)
class Rule:
    """A named Flow = ordered steps (+ the keys available at flow entry)."""

    flow: Flow
    description: str
    steps: tuple[Step, ...]
    seeds: frozenset[str] = frozenset()
