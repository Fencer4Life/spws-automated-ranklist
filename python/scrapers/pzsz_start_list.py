"""PZSz start lists — the birth year of every starter (ADR-111 §3).

FencingTimeLive gives a PZSz field's places but carries no birth year. The
PZSz tournament page (``/zawody/kalendarium-zawodow/turniej/?id=N``) lists
every starter with a birth date (column *Data urodzenia*), and the year of
that date is the birth year the PZSz admission compares. The event page
(``/zawody/kalendarium-zawodow/zawody/?id=N``, the event's ``id_pzsz_event``)
lists its tournaments with weapon and gender.

Pure: this module reads HTML and never fetches; ``read_event_start_lists``
is given the fetch. ``pzszerm.pl`` sometimes answers a client with a
JavaScript check instead of the page; the reader recognises that page and
refuses it. Nothing here tries to get past the check — a run that meets it
fails, writes nothing, and is run again later.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from bs4 import BeautifulSoup, Tag

from python.pipeline.promotion.lifecycle import WARSAW

PZSZ_BASE = "https://pzszerm.pl"
PZSZ_EVENT_PAGE = f"{PZSZ_BASE}/zawody/kalendarium-zawodow/zawody/"
PZSZ_TOURNAMENT_PAGE = f"{PZSZ_BASE}/zawody/kalendarium-zawodow/turniej/"

_DATE = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")
_TOURNAMENT_ID = re.compile(r"turniej/\?id=(\d+)")
_WEAPONS = {"szabla": "SABRE", "szpada": "EPEE", "floret": "FOIL"}
_GENDERS = {"mezczyzna": "M", "kobieta": "F"}


class PzszPageError(RuntimeError):
    """The page is not the one expected, so nothing on it is used."""


class PzszGateError(PzszPageError):
    """pzszerm.pl answered with its JavaScript gate. It is on for every page
    while it is on, so a reader stops at the first one (ADR-112 §2)."""


class PzszWindowError(PzszPageError):
    """An event's start list was asked for outside its capture window, D-4 to
    the morning of the event's last day, so the reader refuses the request
    before any page is fetched (ADR-112 §2, check 2)."""


# The capture window: from four days before the event's first day, when the
# list appears, to noon (Warsaw) on the event's last day. pzszerm.pl still
# serves the list during the event (PPS1e, 25 Oct 2026), so a run due on the
# last day's morning catches an entry added late (K2 A; ADR-112 §2 amended).
WINDOW_OPEN_DAYS_BEFORE = 4
WINDOW_CLOSE_HOUR = 12


def start_list_window(first_day: date, last_day: date) -> tuple[date, date]:
    """The first and the last day of the capture window: D-4 and the event's
    last day, whose morning only counts (``in_start_list_window``)."""
    return first_day - timedelta(days=WINDOW_OPEN_DAYS_BEFORE), max(first_day, last_day)


def in_start_list_window(first_day: date, last_day: date, due: datetime) -> bool:
    """True for a run due from D-4 to noon of the event's last day. ``due`` is
    the moment the run was due, read in Warsaw: never before the list
    appears, never from the last day's noon."""
    opens, closes = start_list_window(first_day, last_day)
    local = due.astimezone(WARSAW)
    day = local.date()
    return opens <= day < closes or (day == closes and local.hour < WINDOW_CLOSE_HOUR)


@dataclass(frozen=True)
class Starter:
    """One start-list entry: the name as printed and the birth year. The
    birth date is read only to check it is a date and is never kept: the
    year is what the admission compares and all that is stored (ADR-112 §1,
    ADR-078 §1)."""

    name: str
    birth_year: int


@dataclass(frozen=True)
class PzszTournament:
    """One individual tournament of a PZSz event."""

    id_pzsz_tournament: int
    name: str
    weapon: str
    gender: str


def _fold(text: str) -> str:
    """Lower case without Polish letters, whitespace collapsed (ł has no
    Unicode decomposition, so it is mapped by hand)."""
    decomposed = unicodedata.normalize("NFKD", text.replace("ł", "l").replace("Ł", "L"))
    plain = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(plain.lower().split())


def _cells(row: Tag) -> list[str]:
    return [" ".join(c.get_text(" ").split()) for c in row.find_all(["td", "th"])]


def is_js_check(html: str) -> bool:
    """True when pzszerm.pl answered with its JavaScript check — the `pzs-m`
    message and no table — instead of the page asked for. This is the one
    definition of the gate: the browser fetcher (ADR-116) reloads while it is
    true, and the readers refuse a page that is."""
    soup = BeautifulSoup(html, "html.parser")
    return soup.find(id="pzs-m") is not None and soup.find("table") is None


def refuse_js_check(html: str) -> None:
    """Raise when the page is pzszerm.pl's JavaScript check
    (:func:`is_js_check`) instead of the page asked for. Every PZSz reader
    calls it: the start lists, the event pages and the calendar listing.
    Nothing tries to get past the check."""
    if is_js_check(html):
        raise PzszGateError(
            "pzszerm.pl answered with its JavaScript check instead of the page; "
            "nothing was read. Run it again later."
        )


def _soup(html: str) -> BeautifulSoup:
    refuse_js_check(html)
    return BeautifulSoup(html, "html.parser")


def _table_with_header(soup: BeautifulSoup, *labels: str) -> Tag | None:
    """The first table whose header row starts with these column labels."""
    wanted = [_fold(label) for label in labels]
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if rows and [_fold(c) for c in _cells(rows[0])][: len(wanted)] == wanted:
            return table
    return None


def parse_start_list(html: str) -> list[Starter]:
    """Every starter on a PZSz tournament page, in the page's order.

    The start list is the table headed *L. p. · Imię i Nazwisko ·
    Rozstawienie · Klub · Data urodzenia*; the final classification further
    down is not read. A page without that table, or a starter without a
    readable birth date, is refused rather than read as an empty field.
    """
    table = _table_with_header(
        _soup(html), "L. p.", "Imię i Nazwisko", "Rozstawienie", "Klub", "Data urodzenia"
    )
    if table is None:
        raise PzszPageError("The PZSz page has no start list (Lista startowa).")
    starters: list[Starter] = []
    for row in table.find_all("tr")[1:]:
        cells = _cells(row)
        if len(cells) < 5:
            continue
        name, born = cells[1], cells[4]
        match = _DATE.fullmatch(born)
        if not name or match is None:
            raise PzszPageError(
                f"The start list has no readable birth date for {name or '(no name)'}: {born!r}."
            )
        day, month, year = (int(g) for g in match.groups())
        try:
            date(year, month, day)
        except ValueError:
            raise PzszPageError(
                f"The start list has no readable birth date for {name}: {born!r}."
            ) from None
        starters.append(Starter(name, year))
    if not starters:
        raise PzszPageError("The PZSz page has no start list (Lista startowa).")
    return starters


def parse_event_tournaments(html: str) -> list[PzszTournament]:
    """The individual tournaments a PZSz event page lists, with each one's
    PZSz id, weapon and gender. Team tournaments are not results we keep."""
    soup = _soup(html)
    table = _table_with_header(soup, "Nazwa Turnieju", "Typ", "Kategoria wiekowa", "Broń", "Płeć")
    if table is None:
        raise PzszPageError("The PZSz event page lists no individual tournaments.")
    tournaments: list[PzszTournament] = []
    for row in table.find_all("tr")[1:]:
        link = row.find("a", href=_TOURNAMENT_ID)
        cells = _cells(row)
        if link is None or len(cells) < 5 or _fold(cells[1]) != "indywidualny":
            continue
        weapon = next((w for k, w in _WEAPONS.items() if _fold(cells[3]).startswith(k)), None)
        gender = _GENDERS.get(_fold(cells[4]))
        if weapon is None or gender is None:
            raise PzszPageError(f"Unknown weapon or gender for {cells[0]!r}: {cells[3:5]}.")
        found = _TOURNAMENT_ID.search(str(link["href"]))
        assert found is not None  # the link was selected by this pattern
        tournaments.append(PzszTournament(int(found.group(1)), cells[0], weapon, gender))
    return tournaments


def read_event_start_lists(
    id_pzsz_event: int, fetch: Callable[[str, dict], str]
) -> dict[tuple[str, str], tuple[PzszTournament, list[Starter]]]:
    """Every individual tournament of a PZSz event with its start list, keyed
    by (weapon, gender). `fetch(url, params)` returns a page's HTML. One page
    that cannot be read refuses the whole event, so a run never goes on with
    some birth years missing."""
    tournaments = parse_event_tournaments(fetch(PZSZ_EVENT_PAGE, {"id": id_pzsz_event}))
    if not tournaments:
        raise PzszPageError(f"PZSz event {id_pzsz_event} lists no individual tournament.")
    lists: dict[tuple[str, str], tuple[PzszTournament, list[Starter]]] = {}
    for t in tournaments:
        key = (t.weapon, t.gender)
        if key in lists:
            raise PzszPageError(
                f"PZSz event {id_pzsz_event} has two {t.weapon}/{t.gender} tournaments; "
                "which start list belongs to which FencingTimeLive listing cannot be told."
            )
        page = fetch(PZSZ_TOURNAMENT_PAGE, {"id": t.id_pzsz_tournament})
        lists[key] = (t, parse_start_list(page))
    return lists


@dataclass(frozen=True)
class EventStartLists:
    """One capture attempt at an event: the tournaments whose start list was
    read, keyed by (weapon, gender), and the ones that were not, each with the
    reason. ``missing`` being non-empty is not a failure — another attempt in
    the same window catches the stragglers (ADR-112 §2)."""

    captured: dict[tuple[str, str], tuple[PzszTournament, list[Starter]]]
    missing: list[tuple[PzszTournament, str]]


def read_event_start_lists_for_capture(
    id_pzsz_event: int,
    fetch: Callable[[str, dict], str],
    *,
    first_day: date,
    last_day: date,
    due: datetime,
) -> EventStartLists:
    """The capture's best-effort read of a PZSz event's start lists, inside
    its window only.

    Check 2 of the window rule (ADR-112 §2): the event's first and last day are re-read
    from CERT each run, and this reader refuses — before fetching any page —
    an event whose window is closed, whoever asked. A bug in the run's
    selection (check 1) therefore cannot cause a request outside the window.

    Unlike :func:`read_event_start_lists` (the ingest's all-or-nothing read),
    one tournament page that will not render does not drop the others: its
    list is named in ``missing`` and the rest are captured. The event page
    itself not rendering serves nothing (there are no ids to read), so that
    raises, and the whole event is 'not served' for this attempt."""
    if not in_start_list_window(first_day, last_day, due):
        opens, closes = start_list_window(first_day, last_day)
        raise PzszWindowError(
            f"PZSz event {id_pzsz_event} is outside its start-list window "
            f"({opens} to noon of {closes}); the run was due "
            f"{due.astimezone(WARSAW):%Y-%m-%d %H:%M}. Nothing was requested."
        )
    tournaments = parse_event_tournaments(fetch(PZSZ_EVENT_PAGE, {"id": id_pzsz_event}))
    captured: dict[tuple[str, str], tuple[PzszTournament, list[Starter]]] = {}
    missing: list[tuple[PzszTournament, str]] = []
    for t in tournaments:
        key = (t.weapon, t.gender)
        if key in captured:
            missing.append(
                (
                    t,
                    f"two {t.weapon}/{t.gender} tournaments; which list belongs to which cannot be told",
                )
            )
            continue
        try:
            page = fetch(PZSZ_TOURNAMENT_PAGE, {"id": t.id_pzsz_tournament})
            captured[key] = (t, parse_start_list(page))
        except PzszPageError as exc:
            missing.append((t, str(exc)))
    return EventStartLists(captured, missing)
