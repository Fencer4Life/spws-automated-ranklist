"""The automatic check of the scoring table's § 2 joining rules (ADR-104 §7).

The organiser forms the brackets on the day. Every listing is scored as
fenced; this check only reports. At the end of each event run, and after each
recompute, it reads the stored category orders of the event's listings per
weapon and gender. They give every category's exact size, fencers never stored
included, and which categories fenced together. It computes § 2's grouping
for the same sizes with ``plan_brackets``, stores the verdict in
``tbl_joining_check``, and sends one Telegram message when the verdict changes:
to a mismatch, or back to a match. A repeat run, or a first-ever match, is
silent. Nothing waits for a person, and nothing here can fail a run.

``plan_brackets`` is a port of ``brackets()`` from the spec's reference
implementation (doc/plans/joined-scoring-final-spec-2026-09-30.html, A14).
"""

from __future__ import annotations

import logging
from collections import Counter
from collections.abc import Iterable, Iterator, Mapping
from dataclasses import dataclass
from typing import Any

log = logging.getLogger(__name__)

CATS = ("V0", "V1", "V2", "V3", "V4")

_WEAPON_PL = {"EPEE": "szpada", "FOIL": "floret", "SABRE": "szabla"}
_GENDER_PL = {"M": "M", "F": "K"}


def _set_partitions(items: list[str]) -> Iterator[list[list[str]]]:
    if not items:
        yield []
        return
    first, rest = items[0], items[1:]
    for p in _set_partitions(rest):
        for i in range(len(p)):
            yield p[:i] + [[first] + p[i]] + p[i + 1 :]
        yield [[first]] + p


def plan_brackets(size: Mapping[str, int]) -> list[list[str]]:
    """§ 2's brackets for one event, weapon and gender.

    ``size`` maps a category to its number of fencers. Of every way to split
    the present categories into runs of neighbours in which no category below
    4 stays alone, the one with the smallest key wins:

    1. the fewest brackets below 4;
    2. the fewest uses of the exception (a category of 4 or more that is not
       the youngest of its bracket);
    3. the fewest categories beyond two in a bracket;
    4. small with small first;
    5. the most brackets;
    6. the largest bracket as small as possible.
    """
    present = [c for c in CATS if size.get(c, 0) > 0]
    if not present:
        return []
    best: tuple[tuple[int, ...], list[list[str]]] | None = None
    for raw in _set_partitions(present):
        groups = [sorted(g, key=CATS.index) for g in raw]
        # A bracket never skips a category that is present.
        if any(present.index(g[-1]) - present.index(g[0]) != len(g) - 1 for g in groups):
            continue
        # A category below 4 never stays alone.
        if len(present) > 1 and any(len(g) == 1 and size[g[0]] < 4 for g in groups):
            continue
        key = (
            sum(sum(size[c] for c in g) < 4 for g in groups),
            sum(size[c] >= 4 for g in groups for c in g[1:]),
            sum(max(0, len(g) - 2) for g in groups),
            sum(len(g) > 1 and any(size[c] >= 4 for c in g) for g in groups),
            -len(groups),
            max(sum(size[c] for c in g) for g in groups),
        )
        if best is None or key < best[0]:
            best = (key, sorted(groups, key=lambda g: CATS.index(g[0])))
    return best[1] if best else []


def fenced_grouping(orders: Iterable[str]) -> tuple[list[list[str]], dict[str, int]]:
    """How the listings were fenced, from their stored orders.

    Every category tournament of a listing stores the same order, so repeats
    collapse. Returns the brackets, ordered by their youngest category, and
    every category's size, fencers never stored included.
    """
    groups: list[list[str]] = []
    sizes: dict[str, int] = {}
    for order in sorted(set(orders)):
        counts = Counter(f"V{d}" for d in order)
        overlap = sorted(set(counts) & set(sizes))
        if overlap:
            raise ValueError(f"Categories {overlap} appear in two listings' orders.")
        sizes.update(counts)
        groups.append(sorted(counts, key=CATS.index))
    groups.sort(key=lambda g: CATS.index(g[0]))
    return groups, {c: sizes[c] for c in sorted(sizes, key=CATS.index)}


def _describe(groups: list[list[str]], sizes: Mapping[str, int]) -> str:
    return " | ".join(f"{'+'.join(g)} ({sum(sizes[c] for c in g)})" for g in groups)


@dataclass(frozen=True)
class JoiningVerdict:
    weapon: str
    gender: str
    fenced: str
    rule: str
    match: bool


def run_joining_check(db: Any, notifier: Any, event: Mapping[str, Any]) -> list[JoiningVerdict]:
    """Check one event's joining against § 2; store and report each verdict.

    Never raises: the results are already committed and scored as fenced.
    ``notifier`` may be None, in which case the verdicts are stored and logged.
    """
    id_event = event.get("id_event")
    code = event.get("txt_code") or str(id_event)
    try:
        rows = db.fetch_event_joined_orders(id_event)
    except Exception:
        log.exception("joining check: cannot read the orders of %s", code)
        return []

    by_listing: dict[tuple[str, str], list[str]] = {}
    for r in rows or []:
        by_listing.setdefault((r["weapon"], r["gender"]), []).append(r["order"])

    verdicts: list[JoiningVerdict] = []
    for (weapon, gender), orders in sorted(by_listing.items()):
        try:
            fenced, sizes = fenced_grouping(orders)
            rule = plan_brackets(sizes)
            verdict = JoiningVerdict(
                weapon=weapon,
                gender=gender,
                fenced=_describe(fenced, sizes),
                rule=_describe(rule, sizes),
                match=fenced == rule,
            )
            previous = db.fetch_joining_check(id_event, weapon, gender)
            db.upsert_joining_check(
                id_event, weapon, gender, verdict.fenced, verdict.rule, verdict.match
            )
        except Exception:
            log.exception("joining check: %s %s %s failed", code, weapon, gender)
            continue
        verdicts.append(verdict)

        label = f"{code} {_WEAPON_PL.get(weapon, weapon)} {_GENDER_PL.get(gender, gender)}"
        message = None
        if not verdict.match and previous is not False:
            message = (
                f"{label}: fenced {verdict.fenced}; § 2: {verdict.rule}. Scored as fenced.",
                "warning",
            )
        elif verdict.match and previous is False:
            message = (f"{label}: the brackets now follow § 2: {verdict.rule}.", "info")
        if message is None:
            continue
        text, level = message
        log.info("joining check: %s", text)
        if notifier is not None:
            try:
                getattr(notifier, level)(text)
            except Exception:
                log.exception("joining check: the message for %s was not sent", label)
    return verdicts


__all__ = ["CATS", "JoiningVerdict", "fenced_grouping", "plan_brackets", "run_joining_check"]
