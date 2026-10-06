"""PZSz start lists — the birth year of every starter (ADR-111 §3).

FencingTimeLive gives a PZSz field's places but carries no birth year. The
PZSz tournament page (``/zawody/kalendarium-zawodow/turniej/?id=N``) lists
every starter with a birth date (column *Data urodzenia*), and the year of
that date is the birth year the PZSz admission compares. The event page
(``/zawody/kalendarium-zawodow/zawody/?id=N``, the event's ``id_pzsz_event``)
lists its tournaments with weapon and gender.

Pure: this module reads HTML and never fetches. ``pzszerm.pl`` sometimes
answers a client with a JavaScript check instead of the page; the reader
recognises that page and refuses it. Nothing here tries to get past the
check — a run that meets it fails, writes nothing, and is run again later.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from datetime import date

from bs4 import BeautifulSoup, Tag

PZSZ_BASE = "https://pzszerm.pl"
PZSZ_EVENT_PAGE = f"{PZSZ_BASE}/zawody/kalendarium-zawodow/zawody/"
PZSZ_TOURNAMENT_PAGE = f"{PZSZ_BASE}/zawody/kalendarium-zawodow/turniej/"

_DATE = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")
_TOURNAMENT_ID = re.compile(r"turniej/\?id=(\d+)")
_WEAPONS = {"szabla": "SABRE", "szpada": "EPEE", "floret": "FOIL"}
_GENDERS = {"mezczyzna": "M", "kobieta": "F"}


class PzszPageError(RuntimeError):
    """The page is not the one expected, so nothing on it is used."""


@dataclass(frozen=True)
class Starter:
    """One start-list entry: the name as printed and the birth date."""

    name: str
    birth_date: date

    @property
    def birth_year(self) -> int:
        return self.birth_date.year


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


def _soup(html: str) -> BeautifulSoup:
    soup = BeautifulSoup(html, "html.parser")
    if soup.find(id="pzs-m") is not None and soup.find("table") is None:
        raise PzszPageError(
            "pzszerm.pl answered with its JavaScript check instead of the page; "
            "nothing was read. Run it again later."
        )
    return soup


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
        starters.append(Starter(name, date(year, month, day)))
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
