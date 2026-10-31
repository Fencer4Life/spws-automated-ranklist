"""The PZSz calendar write rules — one rule set decides every field (ADR-116 §9).

Per field the run holds three things: the value now in tbl_event, the value it
last wrote with that value's source (:class:`FieldState`), and each source's
last report. :func:`decide` turns those plus this run's candidates into one
decision: a compare-and-set :class:`Change` (or none), the source reports to
record, any warnings for the digest, and whether the field is held for the
operator to settle.

Source ranks are letter > listing > home: a reschedule or a renamed round in
the letter outranks the listing, which outranks the home page. The rules are
stated in the module tests; rule 7 (a started event) is handled upstream — the
run simply never calls :func:`decide` for a past event. Rule 8 (link and fee
read only while empty) was removed by ADR-118: the link and fee follow the same
rules as every field, the calendar contract every scraper keeps, and an event
page in the letter counts as empty (ADR-117 D7 A). Pure: no I/O.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass

from python.pipeline.calendar_details import is_calendar_page

RANK: dict[str, int] = {"letter": 3, "listing": 2, "home": 1}


@dataclass(frozen=True)
class Candidate:
    """A value one source produced this run, with the evidence line behind it."""

    source: str
    value: str
    evidence: str | None = None


@dataclass(frozen=True)
class FieldState:
    """What the run last wrote for a field, and from which source."""

    value: str
    source: str


@dataclass(frozen=True)
class Change:
    """A compare-and-set write: set the field to ``value`` only while it still
    holds ``expected`` (NULL when the field was empty)."""

    value: str
    expected: str | None
    source: str
    evidence: str | None


@dataclass(frozen=True)
class Decision:
    """One field's outcome: the change to apply (or none), the source reports
    to record, the digest warnings, and whether it is held for the operator."""

    change: Change | None
    reports: list[tuple[str, str]]
    warnings: list[str]
    held: bool


def _empty(value: str | None) -> bool:
    return value is None or value == ""


def decide(
    field: str,
    *,
    current: str | None,
    state: FieldState | None,
    candidates: Sequence[Candidate],
    reports: Mapping[str, str],
) -> Decision:
    """Decide one field's write for this run. ``current`` is tbl_event's value,
    ``state`` what the run last wrote, ``candidates`` this run's findings (each
    a non-empty value from a source), ``reports`` each source's last recorded
    value."""
    recorded = [(c.source, c.value) for c in candidates]
    if not candidates:
        return Decision(None, recorded, [], False)  # rule 1

    winner = max(candidates, key=lambda c: RANK[c.source])

    # rule 2; an event page is not a letter, so it counts as empty (D7 A)
    if _empty(current) or (field == "url_invitation" and is_calendar_page(current)):
        return Decision(
            Change(winner.value, current, winner.source, winner.evidence), recorded, [], False
        )

    last_written = state.value if state else None
    last_source = state.source if state else None

    if last_written is None or current != last_written:  # rule 3: a hand value
        warnings: list[str] = []
        if winner.value != current:
            warnings.append(
                f"{field}: a {winner.source} value {winner.value!r} differs from the "
                f"hand-entered {current!r}; kept the hand value"
            )
        return Decision(None, recorded, warnings, False)

    # current == last_written: the run owns the value.
    last_rank = RANK.get(last_source or "", 0)
    higher = [c for c in candidates if RANK[c.source] >= last_rank and c.value != current]
    if higher:  # rule 4: an equal/higher-rank source differs -> replace
        best = max(higher, key=lambda c: RANK[c.source])
        return Decision(
            Change(best.value, current, best.source, best.evidence),
            recorded,
            [f"{field}: replaced {current!r} with the {best.source}'s {best.value!r}"],
            False,
        )

    warnings = []
    held = False
    for c in candidates:
        if RANK[c.source] >= last_rank or c.value == current:
            continue
        prev = reports.get(c.source)
        if prev is not None and prev != c.value:  # rule 6: a lower-rank source moved
            held = True
            warnings.append(
                f"{field}: the {c.source} moved to {c.value!r} against the applied "
                f"{current!r} — you decide"
            )
        elif prev != c.value:  # rule 5: a new standing disagreement, reported once
            warnings.append(
                f"{field}: the {c.source} says {c.value!r}, kept the applied {current!r}"
            )
    return Decision(None, recorded, warnings, held)
