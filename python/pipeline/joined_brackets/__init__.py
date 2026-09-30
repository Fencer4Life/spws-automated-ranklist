"""Joined-bracket modules, paired one-to-one with scoring engines (ADR-103 §4).

A joined bracket is one listing fenced by two or more age categories. How its
results are filed is decided by the engine assigned to the tournament type,
never by the listing:

- ``PER_CATEGORY_RENUMBER`` ↔ ``EVF_CLASSIC_V1_2025_2026``. Split per category,
  dense-renumber places 1..K and store the category's own size as N (ADR-049).
  This is the behaviour before ADR-103, byte for byte.
- ``JOINED_BRACKET_CATEGORY_PLACE``. Keep the joined place and the joined N and
  file each fencer under their own category's tournament as before. ADR-104
  removed the engine it was paired with, and K, m and b with it; no released
  engine names it until the joined engine does.

The module names are the two values ``tbl_scoring_engine.
txt_joined_bracket_module`` admits. The registry is the only place an engine
code chooses a module, and an unknown code is refused, as the SQL dispatcher
refuses it. International results never reach the joined module: EVF and FIE
publish per category (ADR-103 Context).
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from typing import Protocol

PER_CATEGORY_RENUMBER = "PER_CATEGORY_RENUMBER"
JOINED_BRACKET_CATEGORY_PLACE = "JOINED_BRACKET_CATEGORY_PLACE"

MODULE_BY_ENGINE: dict[str, str] = {
    "EVF_CLASSIC_V1_2025_2026": PER_CATEGORY_RENUMBER,
}

INTERNATIONAL_TYPES = frozenset({"PEW", "MEW", "MSW", "PSW"})


class UnknownScoringEngine(ValueError):
    """The engine assigned to a tournament type has no joined-bracket module."""


class JoinedBracketNotAllowed(ValueError):
    """An international tournament type was assigned the joined module."""


@dataclass(frozen=True)
class RowPlan:
    """What one written result stores: the place the module decided on."""

    place: int


@dataclass(frozen=True)
class CategoryPlan:
    """One category's tournament: its stored N and a row per kept fencer."""

    participant_count: int
    rows: tuple[RowPlan, ...]


@dataclass(frozen=True)
class BracketField:
    """The whole bracket as the engine sees it: its size N and its places."""

    size: int
    places: tuple[int, ...]

    @classmethod
    def from_places(cls, places: Iterable[int]) -> BracketField:
        """Ingestion: every listed fencer's place, matched or not."""
        ps = tuple(places)
        return cls(size=len(ps), places=ps)

    @classmethod
    def stored(cls, size: int, places: Iterable[int]) -> BracketField:
        """Recompute: N as stored at ingestion, which counts fencers who were
        never stored, so it is read back rather than recounted."""
        return cls(size=size, places=tuple(places))


class JoinedBracketModule(Protocol):
    name: str

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        """Plan one category's tournament.

        ``kept`` are the places of the fencers to write, in write order;
        ``category`` the places of every fencer of that category in the
        bracket, written or not; ``field`` the whole bracket.
        """
        ...


def dense_rank(places: Sequence[int | None]) -> list[int]:
    """Dense-rank places, aligned to the input order: overall {1,4,4,7} ->
    {1,2,2,3}. Moved unchanged from ``plugins.ingest._rerank_places``
    (ADR-049 amend / ADR-014/022)."""
    order = sorted(range(len(places)), key=lambda i: (places[i] is None, places[i]))
    out = [0] * len(places)
    rank = 0
    prev = None
    for pos, i in enumerate(order):
        p = places[i]
        if pos == 0 or p != prev:
            rank += 1
            prev = p
        out[i] = rank
    return out


class PerCategoryRenumber:
    """EVF classic: each category is its own bracket of its written fencers."""

    name = PER_CATEGORY_RENUMBER

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        del category, field  # a split category is scored on its own rows alone
        return CategoryPlan(
            participant_count=len(kept),
            rows=tuple(RowPlan(place=p) for p in dense_rank(list(kept))),
        )


class JoinedBracketCategoryPlace:
    """A joined bracket kept whole: every category keeps the joined place and N."""

    name = JOINED_BRACKET_CATEGORY_PLACE

    def plan_category(
        self, kept: Sequence[int], category: Sequence[int], field: BracketField
    ) -> CategoryPlan:
        del category  # the joined place is the fencer's own; nothing is recounted
        for place in kept:
            if place < 1 or place > field.size:
                raise ValueError(
                    f"Joined place {place} exceeds the bracket of {field.size}; "
                    "a place outside the listing is corrupt input, not a weak result."
                )
        return CategoryPlan(
            participant_count=field.size, rows=tuple(RowPlan(place=p) for p in kept)
        )


_MODULES: dict[str, JoinedBracketModule] = {
    PER_CATEGORY_RENUMBER: PerCategoryRenumber(),
    JOINED_BRACKET_CATEGORY_PLACE: JoinedBracketCategoryPlace(),
}


def module_for(engine_code: str | None, tourn_type: str | None) -> JoinedBracketModule:
    """The module paired with the engine assigned to a tournament type.

    Raises ``UnknownScoringEngine`` for a code the pipeline does not know, and
    ``JoinedBracketNotAllowed`` for an international type assigned the joined
    module.
    """
    name = MODULE_BY_ENGINE.get(engine_code) if isinstance(engine_code, str) else None
    if name is None:
        raise UnknownScoringEngine(
            f"Unknown scoring engine: {engine_code!r} has no joined-bracket module. "
            "An engine is assigned deliberately, never inferred."
        )
    if name == JOINED_BRACKET_CATEGORY_PLACE and tourn_type in INTERNATIONAL_TYPES:
        raise JoinedBracketNotAllowed(
            f"{tourn_type} is international and is published per category; it cannot "
            f"be filed by {JOINED_BRACKET_CATEGORY_PLACE} (engine {engine_code})."
        )
    return _MODULES[name]


__all__ = [
    "INTERNATIONAL_TYPES",
    "JOINED_BRACKET_CATEGORY_PLACE",
    "MODULE_BY_ENGINE",
    "PER_CATEGORY_RENUMBER",
    "BracketField",
    "CategoryPlan",
    "JoinedBracketModule",
    "JoinedBracketNotAllowed",
    "RowPlan",
    "UnknownScoringEngine",
    "dense_rank",
    "module_for",
]
