"""The organizers on the results route, and the code families of their events (ADR-119 §2).

Everything that needs to know who organizes an event, which tournament type
its code stands for, or how its results are ingested reads this registry; no
other module matches an event-code prefix (D13 A, 31 Oct 2026). Before it,
five places did, and the organizer they guessed disagreed with the one PROD
stores for IMEW, IMSW, PSW and DMEW events.

A route class says how an organizer's results reach the ranklist:

- ``domestic``: SPWS. One FTL schedule; the keep-rule chooses one source per
  category, and a combined pool is split by birth year (ADR-076, ADR-056).
- ``roster``: PZSz. A row is ours only when a stored start list confirms its
  surname, first name and birth year (ADR-111, ADR-112).
- ``international``: EVF, FIE and any federation to come. One tournament per
  source bracket, with the source N and place, our fencers admitted by
  identity (ADR-105, ADR-106, ADR-113).

``fie_like`` marks the organizers whose rows are admitted under ADR-106's FIE
amendment (no PPW/MPW start needed, a user-confirmed alias counts).

Adding an organizer is one ``Organizer`` and its ``Family`` entries here, after
its own decisions: its ``tbl_organizer`` row, its tournament type and scoring,
and its calendar scraper (the checklist is in
``doc/handbook/reference/organizers-and-engines.html``). The ingest drivers,
promote, the daily close and the sync read this module and do not change.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

DOMESTIC = "domestic"
ROSTER = "roster"
INTERNATIONAL = "international"
ROUTES = (DOMESTIC, ROSTER, INTERNATIONAL)


@dataclass(frozen=True)
class Organizer:
    code: str  # tbl_organizer.txt_code
    name: str
    route: str
    fie_like: bool = False


@dataclass(frozen=True)
class Family:
    """The events of one code family: the first segment of the code, before
    the season, matched whole (``PEW2efs`` of ``PEW2efs-2026-2027``)."""

    name: str
    pattern: str
    tournament_type: str
    organizer: str
    # False for a family whose results are not ingested: the team championship,
    # and a closed season's family, which is never re-ingested.
    ingested: bool = True


ORGANIZERS: dict[str, Organizer] = {
    o.code: o
    for o in (
        Organizer("SPWS", "Stowarzyszenie Polskich Weteranów Szermierki", DOMESTIC),
        Organizer("PZSz", "Polski Związek Szermierczy", ROSTER),
        Organizer("EVF", "European Veterans Fencing", INTERNATIONAL),
        Organizer("FIE", "Fédération Internationale d'Escrime", INTERNATIONAL, fie_like=True),
    )
}

# The order is irrelevant: the patterns are disjoint and matched whole.
FAMILIES: tuple[Family, ...] = (
    Family("PPW", r"PPW[0-9]+", "PPW", "SPWS"),  # Puchar Polski Weteranów, round N
    Family("MPW", r"MPW", "MPW", "SPWS"),  # Mistrzostwa Polski Weteranów
    Family("PPS", r"PPS[0-9]+[WM]?[efsEFS]*", "PPS", "PZSz"),  # Puchar Polski Seniorów
    Family("MPS", r"MPS[WM]?[efsEFS]*", "MPS", "PZSz"),  # Mistrzostwa Polski Seniorów
    Family("PEW", r"PEW[0-9]+[efsEFS]*", "PEW", "EVF"),  # the EVF circuit (ADR-046)
    Family("MEW", r"MEW", "MEW", "EVF"),  # European individual championships
    Family("IMEW", r"IMEW", "MEW", "EVF"),  # its alternation code (ADR-105 §5.2)
    Family("DMEW", r"DMEW", "MPW", "EVF", ingested=False),  # the team championship
    Family("MSW", r"MSW", "MSW", "FIE"),  # World championships (ADR-008)
    Family("IMSW", r"IMSW", "MSW", "FIE"),  # its alternation code
    Family("PSW", r"PSW", "PSW", "FIE"),  # reserved for FIE events (ADR-008)
    # The 2023/24 Grand Prix rounds, stored under SPWS on every environment; read
    # by the historical seed tools, never ingested again.
    Family("GP", r"GP[0-9]+", "PPW", "SPWS", ingested=False),
)


def family_of(code: str | None) -> Family | None:
    """The registered family of an event code, or None."""
    head = (code or "").split("-", 1)[0]
    if not head:
        return None
    return next((f for f in FAMILIES if re.fullmatch(f.pattern, head)), None)


def tournament_type(code: str | None) -> str | None:
    """The tournament type an event code stands for (ADR-046), or None."""
    family = family_of(code)
    return family.tournament_type if family else None


def organizer_of(code: str | None) -> str:
    """The organizer of an event code's family, or "UNKNOWN"."""
    family = family_of(code)
    return family.organizer if family else "UNKNOWN"


def route_of(code: str | None) -> str | None:
    """How the event's results are ingested, or None when they are not."""
    family = family_of(code)
    return route_of_family(family) if family else None


def require_route(code: str | None) -> str:
    """The event's route class; refuses, naming the code, an event the route
    does not carry. Called before anything is read or recorded."""
    route = route_of(code)
    if route is not None:
        return route
    family = family_of(code)
    why = (
        f"its family {family.name} is not ingested"
        if family is not None
        else "its code belongs to no registered family"
    )
    raise ValueError(
        f"Event {code!r} is not on the results route: {why} "
        "(python/pipeline/organizers.py). Nothing was read or written."
    )


def fie_like_types() -> frozenset[str]:
    """The tournament types of FIE-like organizers (ADR-106's FIE amendment)."""
    return frozenset(
        f.tournament_type
        for f in FAMILIES
        if f.ingested and f.organizer in ORGANIZERS and ORGANIZERS[f.organizer].fie_like
    )


def fie_like_type(tournament_type_: str | None) -> bool:
    """True when the type is an FIE-like organizer's."""
    return (tournament_type_ or "").upper() in fie_like_types()


def international_types() -> frozenset[str]:
    """The tournament types of the international route's families."""
    return types_of_route(INTERNATIONAL)


def domestic_types() -> frozenset[str]:
    """The tournament types of the domestic route's families: the matcher's
    domestic branch (ADR-064, ADR-020)."""
    return types_of_route(DOMESTIC)


def types_of_route(route: str) -> frozenset[str]:
    """The tournament types of the families a route class carries."""
    return frozenset(f.tournament_type for f in FAMILIES if route_of_family(f) == route)


def route_code_regex() -> str:
    """One regular expression for every event code the route carries, for SQL
    (PostgreSQL ``~``) and Python alike."""
    alternatives = "|".join(f.pattern for f in FAMILIES if route_of_family(f) is not None)
    return f"^({alternatives})-"


def route_of_family(family: Family) -> str | None:
    """A family's route class: its organizer's, unless it is not ingested."""
    if not family.ingested:
        return None
    organizer = ORGANIZERS.get(family.organizer)
    return organizer.route if organizer else None
